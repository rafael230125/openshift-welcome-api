function Import-ProjectEnv {
    param(
        [string]$EnvFile = (Join-Path $PSScriptRoot "..\.env")
    )

    if (-not (Test-Path $EnvFile)) {
        Write-Warning "Arquivo .env nao encontrado em $EnvFile. Use .env.example como base."
        return @{}
    }

    $vars = @{}

    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()

        if ($line -eq "" -or $line.StartsWith("#")) {
            return
        }

        $parts = $line -split "=", 2
        if ($parts.Count -lt 2) {
            return
        }

        $name = $parts[0].Trim()
        $value = $parts[1].Trim().Trim('"').Trim("'")
        $vars[$name] = $value
        Set-Item -Path "Env:$name" -Value $value
    }

    return $vars
}

function Get-EnvOrDefault {
    param(
        [string]$Name,
        [string]$Default = ""
    )

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    return $value
}

function Convert-CommandOutput {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $Item
    )

    process {
        if ($Item -is [System.Management.Automation.ErrorRecord]) {
            return $Item.ToString()
        }

        return [string]$Item
    }
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $rawOutput = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        $lines = @($rawOutput | ForEach-Object { Convert-CommandOutput $_ })
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Lines    = $lines
        Text     = ($lines -join [Environment]::NewLine)
    }
}

function Test-DockerRunning {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker nao encontrado. Instale o Docker Desktop: https://www.docker.com/products/docker-desktop/"
    }

    $result = Invoke-ExternalCommand -FilePath "docker" -Arguments @("info")
    if ($result.ExitCode -ne 0) {
        throw "Docker Desktop nao esta rodando. Abra o Docker Desktop, aguarde iniciar e tente novamente."
    }
}

function Invoke-Docker {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [string]$ErrorMessage = "Comando docker falhou."
    )

    $result = Invoke-ExternalCommand -FilePath "docker" -Arguments $Arguments
    if ($result.Lines) {
        $result.Lines | ForEach-Object { Write-Host $_ }
    }

    if ($result.ExitCode -ne 0) {
        $details = $result.Text.Trim()
        if ($details -match "insufficient scopes") {
            throw @"
Falha no docker push: token do Docker Hub sem permissao de escrita.

Como corrigir:
1. Acesse https://hub.docker.com/settings/security
2. Crie um Access Token com permissao Read & Write (ou Read, Write, Delete)
3. Atualize DOCKER_HUB_TOKEN no arquivo .env
4. Rode novamente: .\scripts\deploy-all.ps1

Alternativa: deixe DOCKER_HUB_TOKEN vazio no .env e use login interativo (docker login).
"@
        }

        if ($details) {
            throw "$ErrorMessage`n$details"
        }

        throw $ErrorMessage
    }
}

function New-DeployShortId {
    $chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    return -join (1..6 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

function Get-DeployStateFile {
    return Join-Path $PSScriptRoot "..\openshift\.deploy-state.env"
}

function Save-DeployState {
    param(
        [string]$AppName,
        [string]$ImageTag,
        [string]$Strategy
    )

    $stateFile = Get-DeployStateFile
    @(
        "DEPLOY_APP_NAME=$AppName"
        "DEPLOY_IMAGE_TAG=$ImageTag"
        "DEPLOY_STRATEGY=$Strategy"
    ) | Set-Content -Path $stateFile -Encoding UTF8

    Set-Item -Path "Env:DEPLOY_APP_NAME" -Value $AppName
    Set-Item -Path "Env:DEPLOY_IMAGE_TAG" -Value $ImageTag
}

function Import-DeployState {
    $stateFile = Get-DeployStateFile
    if (-not (Test-Path $stateFile)) {
        return
    }

    Get-Content $stateFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $parts = $line -split "=", 2
        if ($parts.Count -lt 2) { return }
        Set-Item -Path "Env:$($parts[0].Trim())" -Value $parts[1].Trim()
    }
}

function Initialize-DeploySession {
    $strategy = (Get-EnvOrDefault "DEPLOY_STRATEGY" "clean").ToLowerInvariant()
    $baseApp = Get-EnvOrDefault "OPENSHIFT_APP_NAME" "welcome-api"
    $baseTag = Get-EnvOrDefault "DOCKER_IMAGE_TAG" "1.0"
    $deployId = New-DeployShortId

    switch ($strategy) {
        "unique" {
            $appName = "$baseApp-$deployId"
            $imageTag = "$baseTag-$deployId"
            Write-Host "Estrategia unique: app=$appName tag=$imageTag"
        }
        default {
            $strategy = "clean"
            $appName = $baseApp
            $imageTag = $baseTag
            Write-Host "Estrategia clean: reutiliza app=$appName tag=$imageTag e remove recursos antigos"
        }
    }

    Save-DeployState -AppName $appName -ImageTag $imageTag -Strategy $strategy

    return [PSCustomObject]@{
        Strategy = $strategy
        AppName  = $appName
        ImageTag = $imageTag
        DeployId = $deployId
    }
}

function Remove-OpenShiftApp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName
    )

    Write-Host "Removendo recursos OpenShift existentes: $AppName"
    $result = Invoke-ExternalCommand -FilePath "oc" -Arguments @(
        "delete", "deployment,service,route", $AppName, "--ignore-not-found"
    )
    if ($result.Lines) {
        $result.Lines | ForEach-Object { Write-Host $_ }
    }
}

function New-OpenShiftManifests {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        [Parameter(Mandatory = $true)]
        [string]$Image,
        [string]$OutputDir = (Join-Path $PSScriptRoot "..\openshift\.generated")
    )

    $sourceDir = Join-Path $PSScriptRoot "..\openshift"
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

    foreach ($file in @("deployment.yaml", "service.yaml", "route.yaml")) {
        $content = Get-Content (Join-Path $sourceDir $file) -Raw
        $content = $content -replace '(?m)^(\s*name: )welcome-api(\s*)$', "`${1}${AppName}`${2}"
        $content = $content -replace '(?m)^(\s*app: )welcome-api(\s*)$', "`${1}${AppName}`${2}"
        $content = $content -replace 'docker\.io/[^/\s"]+/openshift-welcome-api:[^\s"]+', $Image
        Set-Content -Path (Join-Path $OutputDir $file) -Value $content -NoNewline
    }

    return $OutputDir
}

function Select-OpenShiftProject {
    param(
        [string]$ProjectName,
        [string]$RedHatUsername
    )

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
        $candidates += $ProjectName
    }
    if (-not [string]::IsNullOrWhiteSpace($RedHatUsername)) {
        $candidates += "${RedHatUsername}-dev"
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        oc get project $candidate -o name 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            oc project $candidate 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Nao foi possivel selecionar o projeto '$candidate'."
            }
            Write-Host "Projeto selecionado: $candidate"
            return $candidate
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
        Write-Host "Tentando criar projeto '$ProjectName'..."
        oc new-project $ProjectName 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Projeto criado: $ProjectName"
            return $ProjectName
        }
    }

    $current = oc project -q 2>$null
    if (-not [string]::IsNullOrWhiteSpace($current)) {
        Write-Warning "Sandbox nao permite criar projetos. Usando projeto atual: $current"
        Write-Warning "Defina OPENSHIFT_PROJECT=$current no .env para evitar este aviso."
        return $current
    }

    throw "Nenhum projeto OpenShift disponivel. Defina OPENSHIFT_PROJECT no .env (ex.: seu-usuario-dev)."
}
