param(
    [string]$DockerHubUser,
    [string]$ProjectName
)

. (Join-Path $PSScriptRoot "load-env.ps1")
Import-ProjectEnv | Out-Null
Import-DeployState

$ErrorActionPreference = "Stop"

if (-not (Get-Command oc -ErrorAction SilentlyContinue)) {
    throw "CLI 'oc' nao encontrada. Instale o OpenShift Client e faca login com 'oc login'."
}

$DockerHubUser = if ($DockerHubUser) { $DockerHubUser } else { Get-EnvOrDefault "DOCKER_HUB_USER" }
$ProjectName = if ($ProjectName) { $ProjectName } else { Get-EnvOrDefault "OPENSHIFT_PROJECT" "welcome-api" }
$RedHatUsername = Get-EnvOrDefault "REDHAT_USERNAME"
if (-not (Test-Path (Get-DeployStateFile))) {
    Initialize-DeploySession | Out-Null
    Import-DeployState
}

$ImageName = Get-EnvOrDefault "DOCKER_IMAGE_NAME" "openshift-welcome-api"
$Tag = Get-EnvOrDefault "DEPLOY_IMAGE_TAG"
$AppName = Get-EnvOrDefault "DEPLOY_APP_NAME"
$Strategy = (Get-EnvOrDefault "DEPLOY_STRATEGY" "clean").ToLowerInvariant()
$OpenShiftServer = Get-EnvOrDefault "OPENSHIFT_SERVER"
$OpenShiftToken = Get-EnvOrDefault "OPENSHIFT_TOKEN"

if ([string]::IsNullOrWhiteSpace($DockerHubUser) -or $DockerHubUser -eq "seu_usuario_dockerhub") {
    throw "Defina DOCKER_HUB_USER no arquivo .env ou passe -DockerHubUser."
}

if (-not [string]::IsNullOrWhiteSpace($OpenShiftToken) -and -not [string]::IsNullOrWhiteSpace($OpenShiftServer)) {
    Write-Host "Fazendo login no OpenShift..."
    oc login --token=$OpenShiftToken --server=$OpenShiftServer 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Falha no login OpenShift. Verifique OPENSHIFT_TOKEN e OPENSHIFT_SERVER no .env."
    }
}

Select-OpenShiftProject -ProjectName $ProjectName -RedHatUsername $RedHatUsername | Out-Null

if ($Strategy -eq "clean") {
    Remove-OpenShiftApp -AppName $AppName
}

$image = "docker.io/${DockerHubUser}/${ImageName}:${Tag}"
$manifestDir = New-OpenShiftManifests -AppName $AppName -Image $image

Write-Host "Aplicando manifests gerados em $manifestDir ..."
oc apply -f (Join-Path $manifestDir "deployment.yaml")
oc apply -f (Join-Path $manifestDir "service.yaml")
oc apply -f (Join-Path $manifestDir "route.yaml")

Write-Host ""
Write-Host "Aguardando deployment..."
oc rollout status "deployment/$AppName"

Write-Host ""
Write-Host "URL da Route:"
$routeUrl = oc get route $AppName -o jsonpath='https://{.spec.host}{"\n"}'
Write-Host $routeUrl
