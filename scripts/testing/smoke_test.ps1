param(
    [string]$DockerCliPath = "C:\Program Files\Docker\Docker\resources\bin\docker.exe",
    [switch]$SkipPreflight
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..\..")

if (-not $SkipPreflight) {
    & (Join-Path $scriptRoot "ensure_docker_ready.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Set-Location $repoRoot

Write-Output "[smoke] compose up core services"
& $DockerCliPath compose up -d postgres grafana mqtt
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Output "[smoke] compose ps"
& $DockerCliPath compose ps
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

function Get-HttpStatus {
    param(
        [string]$Url,
        [int]$MaxAttempts = 20,
        [int]$SleepSeconds = 3
    )

    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            $status = (Invoke-WebRequest -UseBasicParsing $Url -TimeoutSec 15).StatusCode
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
Write-Output "[smoke] Grafana HTTP 200"

Write-Output "[smoke] completed successfully"
