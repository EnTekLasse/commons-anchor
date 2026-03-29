param(
    [int]$MaxChecks = 30,
    [int]$SleepSeconds = 4,
    [string]$DockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe",
    [string]$DockerCliPath = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-DockerDaemonReady {
    param(
        [string]$DockerCli
    )

    # Docker writes daemon connection failures to stderr; treat that as "not ready".
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $DockerCli version 1>$null 2>$null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}

if (-not (Test-Path $DockerCliPath)) {
    Write-Error "Docker CLI not found at $DockerCliPath"
    exit 1
}

$dockerBinDir = Split-Path -Parent $DockerCliPath
if ($env:Path -notlike "*$dockerBinDir*") {
    $env:Path = "$dockerBinDir;$($env:Path)"
}

if (Test-DockerDaemonReady -DockerCli $DockerCliPath) {
    Write-Output "Docker daemon already ready"
    exit 0
}

if (Test-Path $DockerDesktopPath) {
    Start-Process $DockerDesktopPath -ErrorAction SilentlyContinue | Out-Null
}

for ($i = 1; $i -le $MaxChecks; $i++) {
    Start-Sleep -Seconds $SleepSeconds
    if (Test-DockerDaemonReady -DockerCli $DockerCliPath) {
        Write-Output "Docker daemon ready after $i checks"
        exit 0
    }
}

Write-Error "Docker daemon not ready after $MaxChecks checks"
exit 1
