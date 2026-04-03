param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 5432,
    [string]$Database = "dw",
    [string]$UserName = "dw_admin",
    [switch]$IncludeDmiClimate
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$projectRoot = Split-Path -Parent $repoRoot
$venvPython = Join-Path $projectRoot ".venv\Scripts\python.exe"

if (-not (Test-Path $venvPython)) {
    throw "Python venv not found: $venvPython"
}

$secretPath = Join-Path $repoRoot "infra\secrets\postgres_password.secret"
if (-not (Test-Path $secretPath)) {
    throw "Secret file not found: $secretPath"
}

$env:POSTGRES_PASSWORD = (Get-Content $secretPath -Raw).Trim()

if ($IncludeDmiClimate) {
    $totalSteps = 3
} else {
    $totalSteps = 2
}

Write-Host "Step 1/${totalSteps}: Ingest energidata..."
& $venvPython (Join-Path $PSScriptRoot "energidataservice_ingest.py") --db-host $HostName --db-port $Port --db-name $Database --db-user $UserName
if ($LASTEXITCODE -ne 0) { throw "Ingest failed with exit code $LASTEXITCODE" }

if ($IncludeDmiClimate) {
    Write-Host "Step 2/${totalSteps}: Ingest DMI climate incrementally..."
    & $venvPython (Join-Path $PSScriptRoot "dmi_climate_ingest.py") --since-latest --db-host $HostName --db-port $Port --db-name $Database --db-user $UserName
    if ($LASTEXITCODE -ne 0) { throw "DMI Climate ingest failed with exit code $LASTEXITCODE" }
}

Write-Host "Step ${totalSteps}/${totalSteps}: Refresh curated views..."
& $venvPython (Join-Path $PSScriptRoot "refresh_curated.py") --view all --host $HostName --port $Port --db $Database --user $UserName --verbose
if ($LASTEXITCODE -ne 0) { throw "Refresh failed with exit code $LASTEXITCODE" }

Write-Host "Pipeline completed successfully."
