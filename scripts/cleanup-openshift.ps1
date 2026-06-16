. (Join-Path $PSScriptRoot "load-env.ps1")
Import-ProjectEnv | Out-Null
Import-DeployState

$ErrorActionPreference = "Stop"

$AppName = Get-EnvOrDefault "DEPLOY_APP_NAME" (Get-EnvOrDefault "OPENSHIFT_APP_NAME" "welcome-api")
$OpenShiftServer = Get-EnvOrDefault "OPENSHIFT_SERVER"
$OpenShiftToken = Get-EnvOrDefault "OPENSHIFT_TOKEN"

if (-not (Get-Command oc -ErrorAction SilentlyContinue)) {
    throw "CLI 'oc' nao encontrada."
}

if (-not [string]::IsNullOrWhiteSpace($OpenShiftToken) -and -not [string]::IsNullOrWhiteSpace($OpenShiftServer)) {
    oc login --token=$OpenShiftToken --server=$OpenShiftServer 2>&1 | Out-Null
}

Remove-OpenShiftApp -AppName $AppName
Write-Host "Recursos removidos: $AppName"
