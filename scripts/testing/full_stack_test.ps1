param(
    [string]$DockerCliPath = "C:\Program Files\Docker\Docker\resources\bin\docker.exe",
    [string]$PythonPath = "c:\Users\lasse\serverprojekt\.venv\Scripts\python.exe",
    [switch]$ColdStart,
    [switch]$SeedMqtt,
    [switch]$SkipPreflight,
    [switch]$SkipQualityGate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..\..")

if ($ColdStart -and $SkipPreflight) {
    Write-Error "-ColdStart cannot be combined with -SkipPreflight"
    exit 1
}

if ($ColdStart) {
    Write-Output "[full] cold-start reset"
    & (Join-Path $scriptRoot "ensure_docker_ready.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    & (Join-Path $scriptRoot "stop_stack.ps1") -RemoveVolumes -RemoveOrphans -PruneUnused -StopDesktop
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if (-not $SkipPreflight) {
    & (Join-Path $scriptRoot "ensure_docker_ready.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Set-Location $repoRoot

Write-Output "[full] compose up all services"
& $DockerCliPath compose up -d
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($SeedMqtt) {
    Write-Output "[full] seed MQTT telemetry"
    & (Join-Path $scriptRoot "seed_mqtt_telemetry.ps1") -SkipPreflight
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Write-Output "[full] run batch jobs"
& $DockerCliPath compose --profile jobs run --rm energidata-ingest
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& $DockerCliPath compose --profile jobs run --rm power-price-transform
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if (-not $SkipQualityGate -and (Test-Path $PythonPath)) {
    Write-Output "[full] run local quality gate"
    & $PythonPath -m scripts.local_quality_gate
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
elseif ($SkipQualityGate) {
    Write-Output "[full] skipping local quality gate"
}
else {
    Write-Warning "Python venv not found at $PythonPath, skipping local quality gate"
}

function Get-HttpStatus {
    param(
        [string]$Url,
        [int]$MaxAttempts = 20,
        [int]$SleepSeconds = 3
    )

    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            $status = (Invoke-WebRequest -UseBasicParsing $Url -TimeoutSec 20).StatusCode
            if ($status -eq 200) {
                return $status
            }
        }
        catch {
            # service might still be warming up
        }

        Start-Sleep -Seconds $SleepSeconds
    }

    return 0
}

$grafana = Get-HttpStatus -Url "http://localhost:3000"
if ($grafana -ne 200) {
    Write-Error "Grafana did not return HTTP 200"
    exit 1
}
Write-Output "[full] Grafana HTTP 200"

$metabase = Get-HttpStatus -Url "http://localhost:3001"
if ($metabase -ne 200) {
    Write-Error "Metabase did not return HTTP 200"
    exit 1
}
Write-Output "[full] Metabase HTTP 200"

Write-Output "[full] final compose status"
& $DockerCliPath compose ps
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Output "[full] completed successfully"
