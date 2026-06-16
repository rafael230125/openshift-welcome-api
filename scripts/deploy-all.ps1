$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "load-env.ps1")
Import-ProjectEnv | Out-Null
$deploy = Initialize-DeploySession

Write-Host "=== Etapa 1/3: Build e push Docker Hub ==="
& "$PSScriptRoot\publish-dockerhub.ps1"

Write-Host "`n=== Etapa 2/3: Deploy no OpenShift ==="
& "$PSScriptRoot\deploy-openshift.ps1"

Write-Host "`n=== Etapa 3/3: Validacao ==="
& "$PSScriptRoot\validate-openshift.ps1"

Write-Host "`nDeploy concluido."
Write-Host "App OpenShift: $($deploy.AppName)"
Write-Host "Tag Docker: $($deploy.ImageTag)"
