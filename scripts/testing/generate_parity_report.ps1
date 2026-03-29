param(
    [string]$DockerCliPath = "C:\Program Files\Docker\Docker\resources\bin\docker.exe",
    [string]$PythonPath = "c:\Users\lasse\serverprojekt\.venv\Scripts\python.exe",
    [switch]$SkipQualityGate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..\..")
$reportPath = Join-Path $repoRoot "docs\testing\parity-report-windows-laptop.md"

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    try {
        $global:LASTEXITCODE = 0
        $null = & $Action
        $code = if ($null -eq $global:LASTEXITCODE) { 0 } else { [int]$global:LASTEXITCODE }

        if ($code -ne 0) {
            return [pscustomobject]@{ Name = $Name; Status = "FAIL"; Detail = "Exit code $code" }
        }

        return [pscustomobject]@{ Name = $Name; Status = "PASS"; Detail = "OK" }
    }
    catch {
        return [pscustomobject]@{ Name = $Name; Status = "FAIL"; Detail = $_.Exception.Message }
    }
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
            return $status
        }
        catch {
            Start-Sleep -Seconds $SleepSeconds
        }
    }

    return 0
}

function Get-PsqlCount {
    param()

    $counts = @{
        mqtt_rows = "ERR"
        energinet_rows = "ERR"
        mart_rows = "ERR"
    }

    if (-not (Test-Path $PythonPath)) {
        return $counts
    }

    $pyCodeLines = @(
        "from pathlib import Path",
        "import psycopg",
        "",
        "env = {}",
        "for line in Path('.env').read_text(encoding='utf-8').splitlines():",
        "    line = line.strip()",
        "    if not line or line.startswith('#') or '=' not in line:",
        "        continue",
        "    k, v = line.split('=', 1)",
        "    env[k.strip()] = v.strip()",
        "",
        "pwd = Path(env['POSTGRES_PASSWORD_FILE']).read_text(encoding='utf-8').strip()",
        "conn = psycopg.connect(",
        "    host='127.0.0.1',",
        "    port=5432,",
        "    user=env['POSTGRES_USER'],",
        "    dbname=env['POSTGRES_DB'],",
        "    password=pwd,",
        ")",
        "",
        "queries = {",
        "    'mqtt_rows': 'select count(*) from staging.mqtt_raw',",
        "    'energinet_rows': 'select count(*) from staging.energinet_raw',",
        "    'mart_rows': 'select count(*) from mart.power_price_15min',",
        "}",
        "",
        "with conn, conn.cursor() as cur:",
        "    for name, query in queries.items():",
        "        cur.execute(query)",
        "        print(name + '=' + str(cur.fetchone()[0]))"
    )
    $pyCode = $pyCodeLines -join "`n"

    $raw = @(& $PythonPath -c $pyCode)
    if ($LASTEXITCODE -ne 0) {
        return $counts
    }

    $text = ($raw | Out-String)
    if ($text -match "(?m)^mqtt_rows=(.+)$") {
        $counts.mqtt_rows = $Matches[1].Trim()
    }
    if ($text -match "(?m)^energinet_rows=(.+)$") {
        $counts.energinet_rows = $Matches[1].Trim()
    }
    if ($text -match "(?m)^mart_rows=(.+)$") {
        $counts.mart_rows = $Matches[1].Trim()
    }

    return $counts
}

Set-Location $repoRoot

$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
$steps = @()

$steps += Invoke-Step -Name "Docker preflight" -Action {
    & (Join-Path $scriptRoot "ensure_docker_ready.ps1")
}

$steps += Invoke-Step -Name "Windows full stack test" -Action {
    & (Join-Path $scriptRoot "full_stack_test.ps1") -SkipPreflight -SkipQualityGate:$SkipQualityGate
}

$steps += Invoke-Step -Name "Linux container parity sanity" -Action {
    & (Join-Path $scriptRoot "linux_container_parity.ps1") -SkipPreflight
}

$grafana = Get-HttpStatus -Url "http://localhost:3000"
$metabase = Get-HttpStatus -Url "http://localhost:3001"

$composeStatus = & $DockerCliPath compose ps

$counts = Get-PsqlCount
$mqttRows = $counts.mqtt_rows
$energinetRows = $counts.energinet_rows
$martRows = $counts.mart_rows

$overall = "PASS"
$failedSteps = @($steps | Where-Object { $_.Status -eq "FAIL" })
if ($failedSteps.Count -gt 0) {
    $overall = "FAIL"
}
if ($grafana -ne 200 -or $metabase -ne 200) {
    $overall = "FAIL"
}

$lines = @()
$lines += "# Parity Report - Windows laptop"
$lines += ""
$lines += "Generated: $timestamp"
$lines += ""
$lines += "## Overall"
$lines += ""
$lines += "- Status: **$overall**"
$lines += "- Target parity baseline: Lenovo Tiny Ubuntu pre-deployment"
$lines += ""
$lines += "## Step results"
$lines += ""
$lines += "| Step | Status | Detail |"
$lines += "|---|---|---|"
foreach ($step in $steps) {
    $lines += "| $($step.Name) | $($step.Status) | $($step.Detail) |"
}
$lines += ""
$lines += "## Endpoint checks"
$lines += ""
$lines += "- Grafana HTTP status: $grafana"
$lines += "- Metabase HTTP status: $metabase"
$lines += ""
$lines += "## Data checks"
$lines += ""
$lines += "- staging.mqtt_raw rows: $mqttRows"
$lines += "- staging.energinet_raw rows: $energinetRows"
$lines += "- mart.power_price_15min rows: $martRows"
$lines += ""
$lines += "## Compose status snapshot"
$lines += ""
$lines += '```text'
$lines += ($composeStatus | Out-String).TrimEnd()
$lines += '```'
$lines += ""
$lines += "## Notes"
$lines += ""
if ($SkipQualityGate) {
    $lines += "- Local quality gate was skipped for this run."
}
$lines += "- Linux container parity validates container/runtime behavior but not host-level Linux operations."
$lines += "- Run the Linux scripts on Lenovo Tiny for final parity sign-off."

Set-Content -Path $reportPath -Value ($lines -join "`r`n") -Encoding utf8
Write-Output "Report written: $reportPath"

if ($overall -eq "FAIL") {
    exit 1
}
