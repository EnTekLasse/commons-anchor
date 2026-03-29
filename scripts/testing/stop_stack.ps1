param(
    [string]$DockerCliPath = "C:\Program Files\Docker\Docker\resources\bin\docker.exe",
    [switch]$RemoveVolumes,
    [switch]$RemoveOrphans,
    [switch]$PruneUnused,
    [switch]$StopDesktop
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Stop-DockerDesktopProcesses {
    param(
        [int]$MaxChecks = 10,
        [int]$SleepSeconds = 2
    )

    $processNames = @("Docker Desktop", "com.docker.backend", "com.docker.service")

    for ($attempt = 1; $attempt -le $MaxChecks; $attempt++) {
        $processes = Get-Process -Name $processNames -ErrorAction SilentlyContinue
        if (-not $processes) {
            return $true
        }

        foreach ($process in $processes) {
            try {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
            catch {
                # Retry loop below handles transient process state.
            }
        }

        Start-Sleep -Seconds $SleepSeconds
    }

    return (-not (Get-Process -Name $processNames -ErrorAction SilentlyContinue))
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..\..")

if (-not (Test-Path $DockerCliPath)) {
    Write-Error "Docker CLI not found at $DockerCliPath"
    exit 1
}

$dockerBinDir = Split-Path -Parent $DockerCliPath
if ($env:Path -notlike "*$dockerBinDir*") {
    $env:Path = "$dockerBinDir;$($env:Path)"
}

& $DockerCliPath version *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Output "Docker daemon not running; nothing to stop"
    exit 0
}

Set-Location $repoRoot

Write-Output "[stop] compose down"
$downArgs = @("compose", "down")
if ($RemoveVolumes) {
    $downArgs += "-v"
}
if ($RemoveOrphans) {
    $downArgs += "--remove-orphans"
}

& $DockerCliPath @downArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($PruneUnused) {
    Write-Output "[stop] pruning unused Docker resources"
    & $DockerCliPath system prune -f
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if ($StopDesktop) {
    if (Get-Process -Name "Docker Desktop", "com.docker.backend", "com.docker.service" -ErrorAction SilentlyContinue) {
        Write-Output "[stop] stopping Docker Desktop"
        if (-not (Stop-DockerDesktopProcesses)) {
            Write-Error "Docker Desktop processes are still running after repeated stop attempts"
            exit 1
        }
    }
}

Write-Output "[stop] completed successfully"
