param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 5432,
    [string]$Database = "dw",
    [string]$UserName = "dw_admin",
    [string]$SecretPath = "./infra/secrets/postgres_password.secret"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $repoRoot
$secretFullPath = Join-Path $repoRoot $SecretPath

if (-not (Test-Path $secretFullPath)) {
    throw "Secret file not found: $secretFullPath"
}

$password = (Get-Content $secretFullPath -Raw).Trim()
if (-not $password) {
    throw "Secret file is empty: $secretFullPath"
}

$env:POSTGRES_PASSWORD = $password

$venvPython = Join-Path $projectRoot ".venv\Scripts\python.exe"
$pythonCmd = if (Test-Path $venvPython) { $venvPython } else { "python" }

Write-Host "Refreshing materialized views on ${HostName}:$Port/$Database ..."
& $pythonCmd (Join-Path $PSScriptRoot "refresh_serving.py") --view all --host $HostName --port $Port --db $Database --user $UserName --verbose

if ($LASTEXITCODE -ne 0) {
    throw "Refresh failed with exit code $LASTEXITCODE"
}

Write-Host "Refresh completed successfully."
