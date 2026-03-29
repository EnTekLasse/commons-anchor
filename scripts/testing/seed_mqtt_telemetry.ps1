param(
    [string]$DockerCliPath = "C:\Program Files\Docker\Docker\resources\bin\docker.exe",
    [string]$Topic = "ca/dev/phone01/telemetry",
    [string]$DeviceId = "phone01",
    [int]$MaxAttempts = 15,
    [int]$SleepSeconds = 2,
    [switch]$SkipPreflight
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..\..")

function Get-MqttRowCount {
    $raw = & $DockerCliPath compose exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select count(*) from staging.mqtt_raw"'
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read staging.mqtt_raw row count"
    }

    return [int](($raw | Out-String).Trim())
}

if (-not $SkipPreflight) {
    & (Join-Path $scriptRoot "ensure_docker_ready.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Set-Location $repoRoot

$initialCount = Get-MqttRowCount
Write-Output "[mqtt-seed] initial staging.mqtt_raw rows: $initialCount"

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $payload = @{
        device_id = $DeviceId
        temp_c = [Math]::Round(22.0 + ($attempt / 10.0), 1)
        hum_pct = [Math]::Round(41.0 + ($attempt / 10.0), 1)
        ts = $timestamp
    } | ConvertTo-Json -Compress

    Write-Output "[mqtt-seed] publish attempt $attempt to $Topic"
    & $DockerCliPath compose exec -T mqtt sh -lc "mosquitto_pub -h localhost -t '$Topic' -q 1 -m '$payload'"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    Start-Sleep -Seconds $SleepSeconds
    $currentCount = Get-MqttRowCount
    if ($currentCount -gt $initialCount) {
        Write-Output "[mqtt-seed] stored MQTT row successfully ($initialCount -> $currentCount)"
        exit 0
    }
}

Write-Error "MQTT seed message was published but no new row appeared in staging.mqtt_raw"
exit 1