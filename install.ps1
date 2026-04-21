# ============================================================
#  硅基API - Claude Code 一键部署脚本 (Windows PowerShell)
#  用法: irm https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/install.ps1 | iex
# ============================================================

$ErrorActionPreference = "Stop"

$API_BASE_URL = "https://api.guijiapi.net"
$MODEL_1 = "claude-sonnet-4-6-20260218"
$MODEL_2 = "claude-opus-4-6-20260205"
$MODEL_3 = "claude-sonnet-4-5-20250514"
$NODE_MIN_VER = "16.0.0"
$PROVIDER_NAME = "anthropic"

# ── 颜色函数 ─────────────────────────────────────────────────
function Write-Info($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Success($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Error($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }
function Write-Step($msg) { Write-Host ""; Write-Host "▶ $msg" -ForegroundColor Blue }
function Write-Skip($msg) { Write-Host "[跳过]  $msg" -ForegroundColor Green }

# ── Banner ───────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║     硅基API - Claude Code 一键部署脚本           ║" -ForegroundColor Blue
Write-Host "╠══════════════════════════════════════════════════╣" -ForegroundColor Blue
Write-Host "║  本脚本由 硅基API (api.guijiapi.net) 提供        ║" -ForegroundColor Blue
Write-Host "║  使用专属 API 端点，无需自备 Anthropic 账号      ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

# ── 工具函数 ─────────────────────────────────────────────────

function Read-Secret($prompt) {
    $cred = Read-Host -Prompt $prompt -AsSecureString
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred)
    $result = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    return $result
}

function Normalize-BaseUrl($url) {
    $url = $url -replace '\?.*$', ''
    $url = $url -replace '#.*$', ''
    $url = $url.TrimEnd('/')
    $url = $url -replace '/v1/messages$', ''
    $url = $url -replace '/v1$', ''
    return $url.TrimEnd('/')
}

function Get-NpmGlobalBin {
    $prefix = npm prefix -g 2>$null
    if ($prefix) {
        return "$prefix"
    }
    return $null
}

function Get-InstalledNpmVersion($pkg) {
    $result = npm list -g $pkg --depth=0 2>$null
    $match = $result | Select-String "$pkg@"
    if ($match) {
        return $match -replace '.*@', '' -replace ' .*', ''
    }
    return $null
}

function Get-LatestNpmVersion($pkg) {
    $result = npm view $pkg version 2>$null
    return $result.Trim()
}

function Install-Or-SkipNpmPkg($pkg, $display) {
    $installed = Get-InstalledNpmVersion $pkg
    if (-not $installed) {
        Write-Info "安装 $display..."
        npm install -g $pkg 2>&1 | Select-Object -Last 3
        Write-Success "$display 安装完成"
    } else {
        Write-Info "检查 $display 最新版本..."
        $latest = Get-LatestNpmVersion $pkg
        if ($latest -and $installed -eq $latest) {
            Write-Skip "$display $installed 已是最新版本"
        } else {
            Write-Info "$display $installed → $latest，升级中..."
            npm install -g $pkg 2>&1 | Select-Object -Last 3
            Write-Success "$display 升级完成"
        }
    }
}

function Test-NodeVersion {
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $ver = (node --version).TrimStart('v')
        $minVer = $NODE_MIN_VER
        if ([version]$ver -ge [version]$minVer) {
            return $true
        }
        return $false
    }
    return $null
}

# ── 1. 询问 API Key ──────────────────────────────────────────
Write-Step "API 配置"
Write-Host "请在硅基API官网获取您的 API Key: $API_BASE_URL" -ForegroundColor Cyan

$API_KEY = Read-Secret "请输入 API Key（输入时不显示）: "
if ([string]::IsNullOrWhiteSpace($API_KEY)) {
    Write-Error "API Key 不能为空"
}
Write-Success "API Key 已设置"

# ── 2. 选择模型 ──────────────────────────────────────────────
Write-Step "选择默认模型"
Write-Host "  1) $MODEL_1（推荐，速度快）"
Write-Host "  2) $MODEL_2（最强，较慢）"
Write-Host "  3) $MODEL_3（稳定版本）"
Write-Host "  4) 手动输入其他模型名"
Write-Host ""

$MODEL_CHOICE = Read-Host "请选择 (1/2/3/4，默认 1): "
if ([string]::IsNullOrWhiteSpace($MODEL_CHOICE)) { $MODEL_CHOICE = "1" }

switch ($MODEL_CHOICE) {
    "1" { $MODEL = $MODEL_1 }
    "2" { $MODEL = $MODEL_2 }
    "3" { $MODEL = $MODEL_3 }
    "4" {
        $MODEL = Read-Host "请输入模型名: "
    }
    default {
        Write-Warn "无效选择，使用默认模型 1"
        $MODEL = $MODEL_1
    }
}
Write-Success "已选择模型: $MODEL"

# ── 3. 检测 Node.js ──────────────────────────────────────────
Write-Step "检查 Node.js 环境"

$nodeTest = Test-NodeVersion
if ($nodeTest -eq $null) {
    Write-Info "Node.js 未安装，正在安装..."
    # 使用 winget 安装 Node.js
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    } else {
        Write-Error "无法自动安装 Node.js，请手动安装: https://nodejs.org/"
    }
    Write-Success "Node.js 安装完成"
} elseif (-not $nodeTest) {
    Write-Warn "Node.js 版本过低，正在更新..."
    winget upgrade OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements 2>$null
    Write-Success "Node.js 已更新"
} else {
    $ver = (node --version).TrimStart('v')
    Write-Skip "Node.js v$ver 已安装且版本满足要求"
}

# ── 4. 安装 Claude Code ──────────────────────────────────────
Write-Step "检查 Claude Code"

Install-Or-SkipNpmPkg "@anthropic-ai/claude-code" "claude-code"
Install-Or-SkipNpmPkg "@musistudio/claude-code-router" "claude-code-router"

# 刷新 PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# ── 5. 生成 config.json ──────────────────────────────────────
Write-Step "生成配置文件"

$CONFIG_DIR = "$env:USERPROFILE\.claude-code-router"
$CONFIG_FILE = "$CONFIG_DIR\config.json"
New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null

$DEFAULT_PROVIDER = "$PROVIDER_NAME,$MODEL"
$NORMALIZED_URL = Normalize-BaseUrl $API_BASE_URL
$API_ENDPOINT = "$NORMALIZED_URL/v1/messages"

$config = @{
    LOG = $false
    CLAUDE_PATH = ""
    HOST = "127.0.0.1"
    PORT = 3456
    APIKEY = $API_KEY
    API_TIMEOUT_MS = "600000"
    PROXY_URL = ""
    Transformers = @()
    Providers = @(
        @{
            name = $PROVIDER_NAME
            api_base_url = $API_ENDPOINT
            api_key = $API_KEY
            models = @($MODEL)
            transformer = @{ use = @("Anthropic") }
        }
    )
    Router = @{
        default = $DEFAULT_PROVIDER
        background = $DEFAULT_PROVIDER
        think = $DEFAULT_PROVIDER
        longContext = $DEFAULT_PROVIDER
        longContextThreshold = 60000
        webSearch = $DEFAULT_PROVIDER
    }
}

$config | ConvertTo-Json -Depth 10 | Set-Content -Path $CONFIG_FILE -Encoding UTF8
Write-Success "配置文件已写入: $CONFIG_FILE"
Write-Info "已配置 API 端点: $API_ENDPOINT"

# ── 6. 配置环境变量 ──────────────────────────────────────────
Write-Step "配置环境变量"

# 设置用户环境变量（持久化）
[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $API_KEY, "User")
[Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $API_BASE_URL, "User")

# 清除可能冲突的 AUTH_TOKEN
[Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $null, "User")

# 当前会话生效
$env:ANTHROPIC_API_KEY = $API_KEY
$env:ANTHROPIC_BASE_URL = $API_BASE_URL
$env:ANTHROPIC_AUTH_TOKEN = $null

Write-Success "环境变量已写入用户环境"

# ── 7. 同步 ~/.claude/settings.json ─────────────────────────────
Write-Step "同步 Claude 配置"

$CLAUDE_DIR = "$env:USERPROFILE\.claude"
$CLAUDE_SETTINGS = "$CLAUDE_DIR\settings.json"
New-Item -ItemType Directory -Path $CLAUDE_DIR -Force | Out-Null

if (Test-Path $CLAUDE_SETTINGS) {
    $settingsJson = Get-Content $CLAUDE_SETTINGS -Raw
    try {
        $settings = $settingsJson | ConvertFrom-Json
    } catch {
        $settings = [PSCustomObject]@{}
    }
} else {
    $settings = [PSCustomObject]@{}
}

# 确保 env 属性存在
if (-not $settings.PSObject.Properties.Match('env')) {
    $settings | Add-Member -MemberType NoteProperty -Name "env" -Value ([PSCustomObject]@{}) -Force
}

# 设置 env 中的属性
$envObj = $settings.env
if (-not $envObj.PSObject.Properties.Match('ANTHROPIC_API_KEY')) {
    $envObj | Add-Member -MemberType NoteProperty -Name "ANTHROPIC_API_KEY" -Value $API_KEY -Force
} else {
    $envObj.ANTHROPIC_API_KEY = $API_KEY
}
if (-not $envObj.PSObject.Properties.Match('ANTHROPIC_BASE_URL')) {
    $envObj | Add-Member -MemberType NoteProperty -Name "ANTHROPIC_BASE_URL" -Value $API_BASE_URL -Force
} else {
    $envObj.ANTHROPIC_BASE_URL = $API_BASE_URL
}
if ($envObj.PSObject.Properties.Match('ANTHROPIC_AUTH_TOKEN')) {
    $envObj.PSObject.Properties.Remove('ANTHROPIC_AUTH_TOKEN')
}

# 移除顶层可能冲突的属性
$settings.PSObject.Properties.Remove('apiKey')
$settings.PSObject.Properties.Remove('authToken')
$settings.PSObject.Properties.Remove('sessionToken')

$settings | ConvertTo-Json -Depth 10 | Set-Content -Path $CLAUDE_SETTINGS -Encoding UTF8
Write-Success "已同步 ~/.claude/settings.json"

# ── 8. 写入 ~/.claude.json ─────────────────────────────────────
Write-Step "初始化 Claude Code 状态"

$CLAUDE_JSON = "$env:USERPROFILE\.claude.json"
$CLAUDE_VERSION = "2.1.0"

try {
    $verResult = claude --version 2>$null
    if ($verResult) {
        $CLAUDE_VERSION = ($verResult | Select-String '\d+\.\d+\.\d+').Matches.Value
    }
} catch {}

$claudeState = @{
    hasCompletedOnboarding = $true
    lastOnboardingVersion = $CLAUDE_VERSION
    primaryApiKey = $API_KEY
}

$claudeState | ConvertTo-Json | Set-Content -Path $CLAUDE_JSON -Encoding UTF8
Write-Success "已创建 ~/.claude.json"

# ── 9. 完成 ──────────────────────────────────────────────────
Write-Step "完成"

Write-Host ""
Write-Host "✅ Claude Code 部署完成！" -ForegroundColor Green
Write-Host ""
Write-Host "使用方法:" -ForegroundColor Cyan
Write-Host "  claude            # 启动 Claude Code"
Write-Host ""
Write-Host "说明:" -ForegroundColor Cyan
Write-Host "  环境变量已写入用户环境，重启终端后生效。"
Write-Host "  如果直接运行 claude 仍提示未登录，请重启 PowerShell。"
Write-Host ""
Write-Host "── 当前环境变量诊断 ────────────────────────────────" -ForegroundColor Cyan
$keyDisplay = $env:ANTHROPIC_API_KEY.Substring(0, [Math]::Min(10, $env:ANTHROPIC_API_KEY.Length)) + "..."
Write-Host "  ANTHROPIC_API_KEY  : $keyDisplay"
Write-Host "  ANTHROPIC_BASE_URL : $env:ANTHROPIC_BASE_URL"
Write-Host "  ANTHROPIC_AUTH_TOKEN: (未设置，正常)"
Write-Success "无 Auth Token 冲突，Claude Code 将使用 ANTHROPIC_API_KEY"
Write-Host ""