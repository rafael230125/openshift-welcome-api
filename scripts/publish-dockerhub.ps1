param(
    [string]$DockerHubUser
)

. (Join-Path $PSScriptRoot "load-env.ps1")
Import-ProjectEnv | Out-Null
Import-DeployState

$ErrorActionPreference = "Stop"

if (-not (Test-Path (Get-DeployStateFile))) {
    Initialize-DeploySession | Out-Null
    Import-DeployState
}

$DockerHubUser = if ($DockerHubUser) { $DockerHubUser } else { Get-EnvOrDefault "DOCKER_HUB_USER" }
if ([string]::IsNullOrWhiteSpace($DockerHubUser) -or $DockerHubUser -eq "seu_usuario_dockerhub") {
    throw "Defina DOCKER_HUB_USER no arquivo .env ou passe -DockerHubUser."
}

$ImageName = Get-EnvOrDefault "DOCKER_IMAGE_NAME" "openshift-welcome-api"
$Tag = Get-EnvOrDefault "DEPLOY_IMAGE_TAG"
$Token = Get-EnvOrDefault "DOCKER_HUB_TOKEN"
$LocalImage = "${ImageName}:${Tag}"
$RemoteImage = "${DockerHubUser}/${ImageName}:${Tag}"

Test-DockerRunning

Write-Host "Construindo imagem Docker (tag: $Tag)..."
Invoke-Docker -Arguments @("build", "-t", $LocalImage, ".") -ErrorMessage "Falha no docker build."

Write-Host "Marcando imagem para Docker Hub..."
Invoke-Docker -Arguments @("tag", $LocalImage, $RemoteImage) -ErrorMessage "Falha no docker tag."

Write-Host "Publicando no Docker Hub..."
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $Token | docker login -u $DockerHubUser --password-stdin 2>&1 | Out-Null
    } else {
        docker login -u $DockerHubUser
    }
    $loginExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorAction
}
if ($loginExitCode -ne 0) {
    throw "Falha no docker login."
}

Invoke-Docker -Arguments @("push", $RemoteImage) -ErrorMessage "Falha no docker push."

Write-Host ""
Write-Host "Imagem publicada: docker.io/$RemoteImage"
