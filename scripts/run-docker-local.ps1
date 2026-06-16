. (Join-Path $PSScriptRoot "load-env.ps1")
Import-ProjectEnv | Out-Null

$ErrorActionPreference = "Stop"

$ImageName = Get-EnvOrDefault "DOCKER_IMAGE_NAME" "openshift-welcome-api"
$Tag = Get-EnvOrDefault "DOCKER_IMAGE_TAG" "1.0"
$AppPort = Get-EnvOrDefault "APP_PORT" "3000"
$AppEnvironment = Get-EnvOrDefault "APP_ENVIRONMENT" "local"
$LocalImage = "${ImageName}:${Tag}"

Test-DockerRunning

Write-Host "Construindo imagem Docker..."
Invoke-Docker -Arguments @("build", "-t", $LocalImage, ".") -ErrorMessage "Falha no docker build."

Write-Host "Executando container localmente na porta $AppPort..."
docker run --rm -p "${AppPort}:${AppPort}" `
    -e "PORT=$AppPort" `
    -e "APP_ENVIRONMENT=$AppEnvironment" `
    -e "NODE_ENV=production" `
    $LocalImage
