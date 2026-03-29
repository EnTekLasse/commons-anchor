param(
    [string]$DockerCliPath = "C:\Program Files\Docker\Docker\resources\bin\docker.exe",
    [string]$Topic = "ca/dev/phone01/telemetry",
    [int]$WaitSeconds = 45,
    [switch]$SkipPreflight
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..\..")

function Get-MqttRowCount {
    $raw = & $DockerCliPath exec ca-postgres psql -U dw_admin -d dw -tAc "select count(*) from staging.mqtt_raw"
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read staging.mqtt_raw row count"
    }

    return [int](($raw | Out-String).Trim())
}

function Get-RecentMqttRows {
    & $DockerCliPath exec ca-postgres psql -U dw_admin -d dw -c "SELECT id, topic, payload, ingested_at FROM staging.mqtt_raw ORDER BY id DESC LIMIT 5;"
}

function Get-WifiIpAddress {
    $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike '169.254*' -and
            $_.IPAddress -ne '127.0.0.1' -and
            ($_.InterfaceAlias -like '*Wi-Fi*' -or $_.InterfaceAlias -like '*WiFi*')
        }

    if (-not $candidates) {
        $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object {
                $_.IPAddress -notlike '169.254*' -and
                $_.IPAddress -ne '127.0.0.1'
            }
    }

    return ($candidates | Select-Object -First 1 -ExpandProperty IPAddress)
}

if (-not $SkipPreflight) {
    & (Join-Path $scriptRoot "ensure_docker_ready.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Set-Location $repoRoot

$wifiIp = Get-WifiIpAddress
$baselineCount = Get-MqttRowCount
$payload = '{"device_id":"phone01","temp_c":22.7,"hum_pct":41.8,"ts":"2026-03-29T20:30:00Z"}'

Write-Output "[manual-mqtt] Host: $wifiIp"
Write-Output "[manual-mqtt] Port: 1883"
Write-Output "[manual-mqtt] Topic: $Topic"
Write-Output "[manual-mqtt] Payload: $payload"
Write-Output "[manual-mqtt] Baseline staging.mqtt_raw rows: $baselineCount"
Write-Output "[manual-mqtt] Send MQTT now"

for ($elapsed = 1; $elapsed -le $WaitSeconds; $elapsed++) {
    Start-Sleep -Seconds 1
    $currentCount = Get-MqttRowCount
    if ($currentCount -gt $baselineCount) {
        $delta = $currentCount - $baselineCount
        Write-Output "[manual-mqtt] Received $delta new MQTT row(s)"
        Write-Output "[manual-mqtt] Latest rows:"
        Get-RecentMqttRows
        exit 0
    }

    if (($elapsed % 5) -eq 0) {
        Write-Output "[manual-mqtt] Waiting... ${elapsed}s/${WaitSeconds}s"
    }
}

Write-Error "No new MQTT rows arrived within ${WaitSeconds}s"
exit 1