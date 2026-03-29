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

Write-Output "[parity] linux runtime sanity"
& $DockerCliPath run --rm alpine:3.20 sh -lc "uname -a && cat /etc/os-release"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Linux container sanity failed"
    exit $LASTEXITCODE
}

Write-Output "[parity] python toolchain sanity in Linux container"
& $DockerCliPath run --rm python:3.13-slim python --version
if ($LASTEXITCODE -ne 0) {
    Write-Error "Python Linux container sanity failed"
    exit $LASTEXITCODE
}

Write-Output "[parity] repo mount sanity in Linux container"
& $DockerCliPath run --rm -v "${repoRoot}:/workspace" -w /workspace alpine:3.20 sh -lc "test -f docker-compose.yml && ls -1 scripts/testing"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Repo mount sanity failed"
    exit $LASTEXITCODE
}

Write-Output "[parity] compose config render"
& $DockerCliPath compose config -q
if ($LASTEXITCODE -ne 0) {
    Write-Error "Compose config is invalid"
    exit $LASTEXITCODE
}

Write-Output "[parity] completed successfully"
