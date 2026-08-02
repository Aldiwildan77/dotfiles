#Requires -Version 5.1
<#
.SYNOPSIS
    Provision a Windows machine from this repo.

.DESCRIPTION
    Windows is best-effort parity. The zsh configuration in this repo does not
    apply here at all, so this script covers packages only.

    For the full environment, install WSL2 and run install/bootstrap.sh inside
    the Linux distro — that path is a first-class target and gets you the same
    setup as a Linux box.

.EXAMPLE
    .\install\windows.ps1
    .\install\windows.ps1 -DryRun
    .\install\windows.ps1 -Wsl
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Wsl,        # install WSL2 + Ubuntu instead of native packages
    [switch]$SkipScoop
)

$ErrorActionPreference = 'Continue'
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Write-Step { param($m) Write-Host "==> $m" -ForegroundColor Blue }
function Write-Ok   { param($m) Write-Host "  ok $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "warn $m" -ForegroundColor Yellow }
function Write-Skip { param($m) Write-Host "skip $m" -ForegroundColor DarkGray }

function Read-Manifest {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Warn "manifest not found: $Path"
        return @()
    }
    Get-Content $Path |
        ForEach-Object { ($_ -replace '#.*$', '').Trim() } |
        Where-Object { $_ -ne '' }
}

function Install-Wsl {
    Write-Step 'installing WSL2 with Ubuntu'
    if ($DryRun) { Write-Host '  would run: wsl --install -d Ubuntu'; return }
    wsl --install -d Ubuntu
    Write-Ok 'WSL2 requested — reboot, then inside Ubuntu run:'
    Write-Host '     git clone https://github.com/Aldiwildan77/dotfiles ~/dotfiles'
    Write-Host '     cd ~/dotfiles && ./setup.sh'
}

function Install-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn 'winget not found — install "App Installer" from the Microsoft Store'
        return
    }
    $packages = Read-Manifest (Join-Path $RepoRoot 'packages\windows\winget.txt')
    Write-Step "installing $($packages.Count) winget packages"
    foreach ($pkg in $packages) {
        if ($DryRun) { Write-Host "  would run: winget install $pkg"; continue }
        # --accept-*-agreements keeps this non-interactive; a package already
        # present exits non-zero, which is not an error worth surfacing.
        winget install --id $pkg --exact --silent `
            --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok $pkg } else { Write-Skip "$pkg (present or unavailable)" }
    }
}

function Install-Scoop {
    if ($SkipScoop) { Write-Skip 'scoop (-SkipScoop)'; return }
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Step 'installing scoop'
        if ($DryRun) { Write-Host '  would install scoop'; return }
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    }
    if ($DryRun) { Write-Host '  would add buckets and install scoop packages'; return }

    scoop bucket add main   2>&1 | Out-Null
    scoop bucket add extras 2>&1 | Out-Null

    $packages = Read-Manifest (Join-Path $RepoRoot 'packages\windows\scoop.txt')
    Write-Step "installing $($packages.Count) scoop packages"
    foreach ($pkg in $packages) {
        scoop install $pkg 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok $pkg } else { Write-Skip "$pkg (present or unavailable)" }
    }
}

function Install-GoTools {
    if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
        Write-Warn 'go not on PATH yet — open a new shell and re-run to get the Go tools'
        return
    }
    $packages = Read-Manifest (Join-Path $RepoRoot 'packages\go.txt')
    Write-Step "installing $($packages.Count) go tools"
    foreach ($pkg in $packages) {
        if ($DryRun) { Write-Host "  would run: go install $pkg"; continue }
        go install $pkg
        if ($LASTEXITCODE -eq 0) { Write-Ok $pkg } else { Write-Warn "go install $pkg failed" }
    }
}

Write-Step "dotfiles bootstrap (windows) — repo=$RepoRoot"
if ($DryRun) { Write-Warn 'DryRun — nothing will be modified' }

if ($Wsl) {
    Install-Wsl
} else {
    Install-Winget
    Install-Scoop
    Install-GoTools
    Write-Ok 'windows packages done — open a new shell to pick up PATH changes'
    Write-Host ''
    Write-Warn 'the shell config in this repo is zsh-only. For the full environment run:'
    Write-Host '     .\install\windows.ps1 -Wsl'
}
