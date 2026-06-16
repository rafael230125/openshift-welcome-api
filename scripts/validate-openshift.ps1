. (Join-Path $PSScriptRoot "load-env.ps1")
Import-ProjectEnv | Out-Null
Import-DeployState

$ErrorActionPreference = "Stop"

if (-not (Get-Command oc -ErrorAction SilentlyContinue)) {
    throw "CLI 'oc' nao encontrada. Instale o OpenShift Client e faca login com 'oc login'."
}

$AppName = Get-EnvOrDefault "DEPLOY_APP_NAME" (Get-EnvOrDefault "OPENSHIFT_APP_NAME" "welcome-api")
$OpenShiftServer = Get-EnvOrDefault "OPENSHIFT_SERVER"
$OpenShiftToken = Get-EnvOrDefault "OPENSHIFT_TOKEN"

if (-not [string]::IsNullOrWhiteSpace($OpenShiftToken) -and -not [string]::IsNullOrWhiteSpace($OpenShiftServer)) {
    Write-Host "Fazendo login no OpenShift..."
    oc login --token=$OpenShiftToken --server=$OpenShiftServer 2>&1 | Out-Null
}

Write-Host "=== App: $AppName ==="

Write-Host "`n=== Pods ==="
oc get pods -l "app=$AppName"

Write-Host "`n=== Deployment ==="
oc get deployment $AppName

Write-Host "`n=== Service ==="
oc get svc $AppName

Write-Host "`n=== Route ==="
oc get route $AppName

$routeHost = oc get route $AppName -o jsonpath='{.spec.host}'
if (-not $routeHost) {
    throw "Route $AppName nao encontrada."
}

$baseUrl = "https://$routeHost"

Write-Host "`n=== Logs (ultimas 20 linhas) ==="
oc logs "deployment/$AppName" --tail=20

Write-Host "`n=== Teste GET / ==="
curl.exe -sS "$baseUrl/"

Write-Host "`n`n=== Teste GET /status ==="
curl.exe -sS "$baseUrl/status"

Write-Host "`n`nValidacao concluida para $baseUrl"
