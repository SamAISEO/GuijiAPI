# ============================================================
#  硅基API - Claude Code 一键部署脚本 (Windows PowerShell)
#  用法: irm https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/install.ps1 | iex
# ============================================================

$ErrorActionPreference = "Stop"

$API_BASE_URL = "https://api.guijiapi.net"
$MODEL_1 = "claude-sonnet-4-6"
$MODEL_2 = "claude-opus-4-7"
$MODEL_3 = "claude-opus-4-6"
$MODEL_4 = "claude-sonnet-4-5-20250929"
$NODE_MIN_VER = "16.0.0"
$PROVIDER_NAME = "anthropic"

# ── 颜色函数 ─────────────────────────────────────────────────
function Write-Info($msg)    { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Success($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn($msg)    { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Step($msg)    { Write-Host ""; Write-Host "▶ $msg" -ForegroundColor Blue }
function Write-Skip($msg)    { Write-Host "[跳过]  $msg" -ForegroundColor Green }
function Exit-WithError($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

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
    if ($prefix) { return "$prefix" }
    return $null
}

function Get-InstalledNpmVersion($pkg) {
    $result = npm list -g $pkg --depth=0 2>$null
    $match = $result | Select-String "$pkg@"
    if ($match) {
        return ($match -replace '.*@', '' -replace ' .*', '').Trim()
    }
    return $null
}

function Get-LatestNpmVersion($pkg) {
    $result = npm view $pkg version 2>$null
    if ($result) { return $result.Trim() }
    return $null
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
        if ([version]$ver -ge [version]$NODE_MIN_VER) { return $true }
        return $false
    }
    return $null
}

function Is-OfficialBaseUrl($url) {
    $normalized = Normalize-BaseUrl $url
    $official = Normalize-BaseUrl $API_BASE_URL
    return ($normalized -eq $official) -or ($normalized -eq "https://api.anthropic.com")
}

# 检测认证冲突
function Test-AuthConflict {
    # 检查环境变量
    if ($env:ANTHROPIC_AUTH_TOKEN) { return $true }

    # 检查持久化环境变量
    $userToken = [Environment]::GetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", "User")
    if ($userToken) { return $true }

    # 检查 OAuth 登录凭证
    if (Test-Path "$env:USERPROFILE\.claude\.credentials.json") { return $true }

    # 检查 settings.json 中的 AUTH_TOKEN
    $settingsFile = "$env:USERPROFILE\.claude\settings.json"
    if (Test-Path $settingsFile) {
        $content = Get-Content $settingsFile -Raw -ErrorAction SilentlyContinue
        if ($content -match 'ANTHROPIC_AUTH_TOKEN') { return $true }
    }

    return $false
}

# 清理认证冲突
function Invoke-CleanupAuthConflict {
    Write-Warn "检测到认证冲突："

    if ($env:ANTHROPIC_AUTH_TOKEN) {
        Write-Warn "  - 当前会话环境变量 ANTHROPIC_AUTH_TOKEN 已设置"
    }

    $userToken = [Environment]::GetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", "User")
    if ($userToken) {
        Write-Warn "  - 用户环境变量 ANTHROPIC_AUTH_TOKEN 已设置"
    }

    if (Test-Path "$env:USERPROFILE\.claude\.credentials.json") {
        Write-Warn "  - OAuth 登录凭证存在: ~/.claude/.credentials.json"
    }

    $settingsFile = "$env:USERPROFILE\.claude\settings.json"
    if (Test-Path $settingsFile) {
        $content = Get-Content $settingsFile -Raw -ErrorAction SilentlyContinue
        if ($content -match 'ANTHROPIC_AUTH_TOKEN') {
            Write-Warn "  - settings.json 中存在 ANTHROPIC_AUTH_TOKEN"
        }
    }

    Write-Warn ""
    Write-Warn "⚠ 认证冲突会导致 Claude Code 无法正确使用硅基API"
    Write-Warn "建议：执行 'claude /logout' 清除 OAuth 登录凭证"
    Write-Warn "       或让本脚本自动清理冲突配置"

    $confirm = Read-Host "是否自动清理认证冲突？(Y/n，默认 Y): "
    if ([string]::IsNullOrWhiteSpace($confirm)) { $confirm = "Y" }
    if ($confirm -match '^[Nn]') {
        Write-Warn "跳过清理，安装完成后请手动清理："
        Write-Warn "  1. 执行 'claude /logout' 清除 OAuth 登录凭证"
        Write-Warn "  2. 在 PowerShell 中执行: \$env:ANTHROPIC_AUTH_TOKEN = \$null"
        Write-Warn "  3. 重启 Claude Code"
        return
    }

    # 清理 OAuth 凭证
    if (Test-Path "$env:USERPROFILE\.claude\.credentials.json") {
        Write-Info "删除 OAuth 登录凭证..."
        Remove-Item -Force "$env:USERPROFILE\.claude\.credentials.json" -ErrorAction SilentlyContinue
        Write-Success "已删除 ~/.claude/.credentials.json"
    }

    # 清理环境变量
    if ($env:ANTHROPIC_AUTH_TOKEN -or $userToken) {
        Write-Info "清除 ANTHROPIC_AUTH_TOKEN 环境变量..."
        [Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $null, "User")
        $env:ANTHROPIC_AUTH_TOKEN = $null
        Write-Success "已清除 ANTHROPIC_AUTH_TOKEN"
    }

    # 清理 settings.json
    if (Test-Path $settingsFile) {
        Write-Info "清理 settings.json 中的认证冲突..."
        try {
            $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
            if ($settings.env -and $settings.env.PSObject.Properties.Match('ANTHROPIC_AUTH_TOKEN')) {
                $settings.env.PSObject.Properties.Remove('ANTHROPIC_AUTH_TOKEN')
                $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsFile -Encoding UTF8
                Write-Success "已移除 settings.json 中的 ANTHROPIC_AUTH_TOKEN"
            }
        } catch {
            Write-Warn "settings.json 处理失败，请手动检查"
        }
    }

    Write-Success "认证冲突已清理"
}

function Get-ExistingClaudeUrl {
    $cfg = "$env:USERPROFILE\.claude-code-router\config.json"
    $claudeJson = "$env:USERPROFILE\.claude.json"
    $claudeSettings = "$env:USERPROFILE\.claude\settings.json"

    foreach ($file in @($cfg, $claudeJson, $claudeSettings)) {
        if (Test-Path $file) {
            $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
            if ($content -match 'https?://[^\s"'']+') {
                $url = $Matches[0]
                if (-not (Is-OfficialBaseUrl $url)) { return $url }
            }
        }
    }
    return $null
}

function Test-ThirdPartyConfig {
    # 检查 ANTHROPIC_BASE_URL 环境变量
    if ($env:ANTHROPIC_BASE_URL -and -not (Is-OfficialBaseUrl $env:ANTHROPIC_BASE_URL)) {
        return $true
    }
    # 检查配置文件中的 URL
    $existingUrl = Get-ExistingClaudeUrl
    if ($existingUrl) { return $true }
    # 检查 OAuth 凭证
    if (Test-Path "$env:USERPROFILE\.claude\.credentials.json") { return $true }
    # 检查 settings.json 中的认证覆盖字段
    $settingsFile = "$env:USERPROFILE\.claude\settings.json"
    if (Test-Path $settingsFile) {
        $content = Get-Content $settingsFile -Raw -ErrorAction SilentlyContinue
        if ($content -match 'apiKeyHelper|forceLoginMethod|ANTHROPIC_AUTH_TOKEN') { return $true }
    }
    return $false
}

function Invoke-CleanupThirdParty {
    $oldUrl = Get-ExistingClaudeUrl
    Write-Warn "检测到第三方中转站配置: $(if ($oldUrl) { $oldUrl } else { '（未知）' })"
    Write-Warn "将删除旧的 Claude 配置目录和缓存文件，然后重建。"
    $confirm = Read-Host "是否继续清理并重装？(Y/n，默认 Y): "
    if ([string]::IsNullOrWhiteSpace($confirm)) { $confirm = "Y" }
    if ($confirm -match '^[Nn]') { Exit-WithError "用户取消，退出" }

    Write-Info "卸载旧 npm 包..."
    npm uninstall -g @anthropic-ai/claude-code 2>$null | Out-Null
    npm uninstall -g @musistudio/claude-code-router 2>$null | Out-Null
    Write-Success "旧 npm 包已卸载"

    $dirs = @(
        "$env:USERPROFILE\.claude-code-router",
        "$env:USERPROFILE\.claude"
    )
    foreach ($dir in $dirs) {
        if (Test-Path $dir) {
            Write-Info "删除 $dir ..."
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
            Write-Success "已删除 $dir"
        }
    }

    $files = @("$env:USERPROFILE\.claude.json")
    foreach ($file in $files) {
        if (Test-Path $file) {
            Write-Info "删除 $file ..."
            Remove-Item -Force $file -ErrorAction SilentlyContinue
            Write-Success "已删除 $file"
        }
    }

    Write-Info "清除旧环境变量..."
    [Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $null, "User")
    [Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $null, "User")
    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $null, "User")
    $env:ANTHROPIC_AUTH_TOKEN = $null
    $env:ANTHROPIC_API_KEY = $null
    $env:ANTHROPIC_BASE_URL = $null
    Write-Success "旧环境变量已清除"
}

# ── 1. 检测并清理第三方配置 ──────────────────────────────────
Write-Step "检测现有配置"
if (Test-ThirdPartyConfig) {
    Invoke-CleanupThirdParty
    Write-Success "清理完成，继续安装..."
} else {
    Write-Skip "未检测到第三方配置，无需清理"
}

# ── 1.5 检测认证冲突 ────────────────────────────────────────────
Write-Step "检测认证冲突"
if (Test-AuthConflict) {
    Invoke-CleanupAuthConflict
} else {
    Write-Skip "未检测到认证冲突"
}

# ── 2. 检测 Node.js ──────────────────────────────────────────
Write-Step "检查 Node.js 环境"

$nodeTest = Test-NodeVersion
if ($null -eq $nodeTest) {
    Write-Info "Node.js 未安装，正在安装..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    } else {
        Exit-WithError "无法自动安装 Node.js，请手动安装: https://nodejs.org/"
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

# ── 3. 安装 Claude Code ──────────────────────────────────────
Write-Step "检查 Claude Code"

Install-Or-SkipNpmPkg "@anthropic-ai/claude-code" "claude-code"
Install-Or-SkipNpmPkg "@musistudio/claude-code-router" "claude-code-router"

# 刷新 PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# ── 4. 询问 API Key ──────────────────────────────────────────
Write-Step "API 配置"
Write-Host "请在硅基API官网获取您的 API Key: $API_BASE_URL" -ForegroundColor Cyan

$API_KEY = Read-Secret "请输入 API Key（输入时不显示）: "
if ([string]::IsNullOrWhiteSpace($API_KEY)) {
    Exit-WithError "API Key 不能为空"
}
# 格式校验
if ($API_KEY -notmatch '^[A-Za-z0-9_-]{10,}$') {
    Write-Warn "API Key 格式可能不正确（含特殊字符或过短），请确认后继续"
}
Write-Success "API Key 已设置"

# ── 5. 选择模型 ──────────────────────────────────────────────
Write-Step "选择默认模型"
Write-Host "  1) $MODEL_1（推荐，速度快）"
Write-Host "  2) $MODEL_2（最新最强，较慢）"
Write-Host "  3) $MODEL_3（旗舰级）"
Write-Host "  4) $MODEL_4（稳定版本）"
Write-Host "  5) 手动输入其他模型名"
Write-Host ""

$MODEL_CHOICE = Read-Host "请选择 (1/2/3/4/5，默认 1): "
if ([string]::IsNullOrWhiteSpace($MODEL_CHOICE)) { $MODEL_CHOICE = "1" }

switch ($MODEL_CHOICE) {
    "1" { $MODEL = $MODEL_1 }
    "2" { $MODEL = $MODEL_2 }
    "3" { $MODEL = $MODEL_3 }
    "4" { $MODEL = $MODEL_4 }
    "5" {
        $MODEL = (Read-Host "请输入模型名: ").Trim()
        if ([string]::IsNullOrWhiteSpace($MODEL)) {
            Write-Warn "模型名为空，使用默认模型"
            $MODEL = $MODEL_1
        }
    }
    default {
        Write-Warn "无效选择，使用默认模型 1"
        $MODEL = $MODEL_1
    }
}
Write-Success "已选择模型: $MODEL"

# ── 6. 生成 config.json ──────────────────────────────────────
Write-Step "生成配置文件"

$CONFIG_DIR = "$env:USERPROFILE\.claude-code-router"
$CONFIG_FILE = "$CONFIG_DIR\config.json"
New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null

$DEFAULT_PROVIDER = "$PROVIDER_NAME,$MODEL"
$NORMALIZED_URL = Normalize-BaseUrl $API_BASE_URL
$API_ENDPOINT = "$NORMALIZED_URL/v1/messages"

# 显式使用 [string[]] 确保单元素时序列化为 JSON 数组而非字符串
$config = [ordered]@{
    LOG            = $false
    CLAUDE_PATH    = ""
    HOST           = "127.0.0.1"
    PORT           = 3456
    APIKEY         = $API_KEY
    API_TIMEOUT_MS = "600000"
    PROXY_URL      = ""
    Transformers   = @()
    Providers      = @(
        [ordered]@{
            name         = $PROVIDER_NAME
            api_base_url = $API_ENDPOINT
            api_key      = $API_KEY
            models       = [string[]]@($MODEL)
            transformer  = [ordered]@{ use = [string[]]@("Anthropic") }
        }
    )
    Router         = [ordered]@{
        default              = $DEFAULT_PROVIDER
        background           = $DEFAULT_PROVIDER
        think                = $DEFAULT_PROVIDER
        longContext          = $DEFAULT_PROVIDER
        longContextThreshold = 60000
        webSearch            = $DEFAULT_PROVIDER
    }
}

$config | ConvertTo-Json -Depth 10 | Set-Content -Path $CONFIG_FILE -Encoding UTF8
Write-Success "配置文件已写入: $CONFIG_FILE"
Write-Info "已配置 API 端点: $API_ENDPOINT"

# ── 7. 配置环境变量 ──────────────────────────────────────────
Write-Step "配置环境变量"

# 持久化到用户环境
[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $API_KEY, "User")
[Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $API_BASE_URL, "User")
[Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", $null, "User")

# 当前会话生效
$env:ANTHROPIC_API_KEY = $API_KEY
$env:ANTHROPIC_BASE_URL = $API_BASE_URL
$env:ANTHROPIC_AUTH_TOKEN = $null

Write-Success "环境变量已写入用户环境"

# ── 8. 同步 ~/.claude/settings.json ─────────────────────────
Write-Step "同步 Claude 配置"

$CLAUDE_DIR = "$env:USERPROFILE\.claude"
$CLAUDE_SETTINGS = "$CLAUDE_DIR\settings.json"
New-Item -ItemType Directory -Path $CLAUDE_DIR -Force | Out-Null

# 读取已有配置，转换为 hashtable 以便可靠修改
$settingsHash = @{}
if (Test-Path $CLAUDE_SETTINGS) {
    try {
        $settingsObj = Get-Content $CLAUDE_SETTINGS -Raw | ConvertFrom-Json
        # 将 PSCustomObject 转换为 hashtable
        foreach ($prop in $settingsObj.PSObject.Properties) {
            if ($prop.Value -is [PSCustomObject]) {
                # 递归转换嵌套的 PSCustomObject
                $nestedHash = @{}
                foreach ($nestedProp in $prop.Value.PSObject.Properties) {
                    $nestedHash[$nestedProp.Name] = $nestedProp.Value
                }
                $settingsHash[$prop.Name] = $nestedHash
            } else {
                $settingsHash[$prop.Name] = $prop.Value
            }
        }
    } catch {
        $settingsHash = @{}
    }
}

# 处理 env：保留非 ANTHROPIC 字段，设置正确的 ANTHROPIC 值
$envHash = @{}
if ($settingsHash.ContainsKey('env') -and $settingsHash['env'] -is [hashtable]) {
    foreach ($key in $settingsHash['env'].Keys) {
        if ($key -notmatch '^ANTHROPIC_') {
            $envHash[$key] = $settingsHash['env'][$key]
        }
    }
}
$envHash['ANTHROPIC_API_KEY'] = $API_KEY
$envHash['ANTHROPIC_BASE_URL'] = $API_BASE_URL
# 确保 AUTH_TOKEN 不存在（已在过滤中排除，显式移除以防万一）
$envHash.Remove('ANTHROPIC_AUTH_TOKEN')

$settingsHash['env'] = $envHash

# 移除顶层认证字段
foreach ($key in @('apiKey', 'authToken', 'sessionToken')) {
    $settingsHash.Remove($key)
}

# 转换 hashtable 为 PSCustomObject 再序列化（确保 JSON 格式正确）
$settingsOut = [PSCustomObject]@{}
foreach ($key in $settingsHash.Keys) {
    if ($settingsHash[$key] -is [hashtable]) {
        $nestedObj = [PSCustomObject]$settingsHash[$key]
        $settingsOut | Add-Member -MemberType NoteProperty -Name $key -Value $nestedObj
    } else {
        $settingsOut | Add-Member -MemberType NoteProperty -Name $key -Value $settingsHash[$key]
    }
}

$settingsOut | ConvertTo-Json -Depth 10 | Set-Content -Path $CLAUDE_SETTINGS -Encoding UTF8
Write-Success "已同步 ~/.claude/settings.json"

# ── 9. 写入 ~/.claude.json ─────────────────────────────────────
Write-Step "初始化 Claude Code 状态"

$CLAUDE_JSON = "$env:USERPROFILE\.claude.json"
$CLAUDE_VERSION = "2.1.0"

try {
    $verResult = claude --version 2>$null
    if ($verResult) {
        $match = $verResult | Select-String '\d+\.\d+\.\d+'
        if ($match) { $CLAUDE_VERSION = $match.Matches.Value }
    }
} catch {}

# 增量更新已有 claude.json，避免覆盖其他字段
if (Test-Path $CLAUDE_JSON) {
    try {
        $claudeState = Get-Content $CLAUDE_JSON -Raw | ConvertFrom-Json
    } catch {
        $claudeState = [PSCustomObject]@{}
    }
} else {
    $claudeState = [PSCustomObject]@{}
}

foreach ($key in @('hasCompletedOnboarding', 'lastOnboardingVersion', 'primaryApiKey')) {
    if ($claudeState.PSObject.Properties.Match($key)) {
        $claudeState.PSObject.Properties.Remove($key)
    }
}
$claudeState | Add-Member -MemberType NoteProperty -Name "hasCompletedOnboarding" -Value $true -Force
$claudeState | Add-Member -MemberType NoteProperty -Name "lastOnboardingVersion"  -Value $CLAUDE_VERSION -Force
$claudeState | Add-Member -MemberType NoteProperty -Name "primaryApiKey"          -Value $API_KEY -Force
foreach ($key in @('apiBaseUrl', 'oauthAccount', 'authToken', 'sessionToken')) {
    if ($claudeState.PSObject.Properties.Match($key)) {
        $claudeState.PSObject.Properties.Remove($key)
    }
}

$claudeState | ConvertTo-Json -Depth 5 | Set-Content -Path $CLAUDE_JSON -Encoding UTF8
Write-Success "已创建/更新 ~/.claude.json"

# ── 10. API 连通性验证 ─────────────────────────────────────────
Write-Step "验证 API 连通性"

try {
    $response = Invoke-WebRequest `
        -Uri "$API_BASE_URL/v1/models" `
        -Headers @{ "x-api-key" = $API_KEY; "anthropic-version" = "2023-06-01" } `
        -Method GET `
        -TimeoutSec 10 `
        -ErrorAction Stop `
        -UseBasicParsing
    Write-Success "API 连通性验证通过 (HTTP $($response.StatusCode))"
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    switch ($code) {
        401 { Write-Warn "API Key 无效或已过期 (HTTP 401)，请检查 Key 是否正确" }
        403 { Write-Warn "API Key 无权限 (HTTP 403)，请确认账号状态" }
        $null { Write-Warn "连通性检查失败（网络超时或不可达），请手动验证 API Key" }
        default { Write-Warn "API 连通性返回 HTTP $code，请检查配置是否正确" }
    }
}

# ── 11. 完成 ──────────────────────────────────────────────────
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
$keyLen = [Math]::Min(10, $env:ANTHROPIC_API_KEY.Length)
$keyDisplay = $env:ANTHROPIC_API_KEY.Substring(0, $keyLen) + "..."
Write-Host "  ANTHROPIC_API_KEY  : $keyDisplay"
Write-Host "  ANTHROPIC_BASE_URL : $env:ANTHROPIC_BASE_URL"
Write-Host "  ANTHROPIC_AUTH_TOKEN: $(if ($env:ANTHROPIC_AUTH_TOKEN) { $env:ANTHROPIC_AUTH_TOKEN } else { '(未设置)' })"

if ($env:ANTHROPIC_AUTH_TOKEN) {
    Write-Warn "⚠ ANTHROPIC_AUTH_TOKEN 仍然存在！请在安装完成后执行: claude /logout"
} else {
    Write-Success "无 Auth Token 冲突，Claude Code 将正确使用硅基API"
}

# 检查 OAuth 凭证残留
if (Test-Path "$env:USERPROFILE\.claude\.credentials.json") {
    Write-Warn "⚠ OAuth 登录凭证残留！请在安装完成后执行: claude /logout"
}
Write-Host ""
