# GuijiAPI Quick Install Script
# Desktop entry point for Claude Code + GuijiAPI installation

param(
    [switch]$SkipVersionCheck
)

$ErrorActionPreference = "Stop"
$INSTALL_SCRIPT_URL = "https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/install.ps1"
$SCRIPT_VERSION_URL = "https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/version.txt"
$QUICK_INSTALL_VERSION = "2.0.0"

function Write-Banner {
    param([string]$Title, [string]$Subtitle = "")
    $width = 50
    $padding = [Math]::Max(0, ($width - $Title.Length) / 2)
    Write-Host ""
    Write-Host ("=" * $width) -ForegroundColor Cyan
    $leftSpaces = " " * [Math]::Max(0, [Math]::Floor($padding))
    $rightSpaces = " " * [Math]::Max(0, [Math]::Ceiling($padding))
    Write-Host "$leftSpaces$Title$rightSpaces" -ForegroundColor Cyan
    if ($Subtitle) {
        $subPadding = [Math]::Max(0, ($width - $Subtitle.Length) / 2)
        $subLeft = " " * [Math]::Max(0, [Math]::Floor($subPadding))
        $subRight = " " * [Math]::Max(0, [Math]::Ceiling($subPadding))
        Write-Host "$subLeft$Subtitle$subRight" -ForegroundColor Gray
    }
    Write-Host ("=" * $width) -ForegroundColor Cyan
    Write-Host ""
}

function Get-GitHubVersion {
    try {
        $response = Invoke-WebRequest -Uri $SCRIPT_VERSION_URL -UseBasicParsing -TimeoutSec 5
        return ($response.Content -replace '[\r\n]', '').Trim()
    } catch {
        return $null
    }
}

function Test-Network {
    try {
        $null = Invoke-WebRequest -Uri "https://api.guijiapi.net" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

# Main
Clear-Host
Write-Banner -Title "GuijiAPI Claude Code Installer" -Subtitle "v$QUICK_INSTALL_VERSION"

Write-Host "Checking network..." -ForegroundColor Yellow
if (-not (Test-Network)) {
    Write-Host ""
    Write-Host "[ERROR] Network unreachable. Please check your connection." -ForegroundColor Red
    Write-Host "Or run manually:" -ForegroundColor Yellow
    Write-Host 'irm https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/install.ps1 | iex' -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "[OK] Network OK" -ForegroundColor Green

# Version check
$localVersion = $QUICK_INSTALL_VERSION
$githubVersion = $null

if (-not $SkipVersionCheck) {
    Write-Host "Checking for updates..." -ForegroundColor Yellow
    $githubVersion = Get-GitHubVersion
    if ($githubVersion) {
        Write-Host "[OK] Latest version: v$githubVersion" -ForegroundColor Green
        if ([version]$githubVersion -gt [version]$localVersion) {
            Write-Host "[INFO] New version found, updating..." -ForegroundColor Cyan
            try {
                $scriptContent = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/quick-install.ps1" -UseBasicParsing
                $scriptContent.Content | Set-Content -Path $PSCommandPath -Encoding UTF8
                Write-Host "[OK] Installer updated to v$githubVersion" -ForegroundColor Green
                Write-Host "Please run again" -ForegroundColor Yellow
                Read-Host "Press Enter to exit"
                exit 0
            } catch {
                Write-Host "[WARN] Auto-update failed, continuing with current version" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "[INFO] Cannot check latest version, using current" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "Preparing installation script..." -ForegroundColor Yellow

try {
    Write-Host "Downloading install script..." -ForegroundColor Cyan
    $installScript = Invoke-WebRequest -Uri $INSTALL_SCRIPT_URL -UseBasicParsing -TimeoutSec 30
    Write-Host "[OK] Download complete" -ForegroundColor Green
    Write-Host ""
    Write-Host "Starting installation..." -ForegroundColor Yellow
    Write-Host ""

    Invoke-Expression $installScript.Content

} catch [System.Net.WebException] {
    Write-Host ""
    Write-Host "[ERROR] Download failed: Network error" -ForegroundColor Red
    Write-Host "Please check network and retry, or run manually:" -ForegroundColor Yellow
    Write-Host 'irm https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/install.ps1 | iex' -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1

} catch {
    Write-Host ""
    Write-Host "[ERROR] Installation failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual installation:" -ForegroundColor Yellow
    Write-Host 'irm https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/install.ps1 | iex' -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}