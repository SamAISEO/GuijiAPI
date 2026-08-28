# ============================================================
#  硅基API 2.0 - Claude Code 一键部署脚本 (Windows PowerShell)
#  用法: irm https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/install.ps1 | iex
# ============================================================

$ErrorActionPreference = "Stop"

$API_BASE_URL = "https://api.guiji.co"
$NODE_MIN_VER = "16.0.0"

# ── 模型定义 ─────────────────────────────────────────────────
# Anthropic 系列
$ANTHROPIC_MODELS = @(
    @{ name = "claude-sonnet-5"; desc = "推荐，速度快，性价比高" },
    @{ name = "claude-opus-5"; desc = "最新最强" },
    @{ name = "claude-fable-5"; desc = "高性能，长上下文" },
    @{ name = "claude-opus-4-8"; desc = "稳定旗舰" },
    @{ name = "claude-sonnet-4-6"; desc = "旧版稳定" }
)

# API 端点
$API_ENDPOINT = "/v1/messages"

# Provider 定义（仅 Anthropic）
$PROVIDERS = @{
    "anthropic" = @{
        api_base_url = "$API_BASE_URL$API_ENDPOINT"
        transformer = @{ use = @("Anthropic") }
    }
}

# ── 颜色函数 ─────────────────────────────────────────────────
function Write-Info($msg)    { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Success($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn($msg)    { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Step($msg)    { Write-Host ""; Write-Host "▶ $msg" -ForegroundColor Blue }
function Write-Skip($msg)    { Write-Host "[跳过]  $msg" -ForegroundColor Green }
function Exit-WithError($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

# 写入无 BOM 的 UTF-8 JSON 文件（避免 EchoBird 等工具无法解析带 BOM 的 JSON）
function Write-JsonFile {
    param([string]$Path, [object]$Data, [int]$Depth = 10)
    $json = $Data | ConvertTo-Json -Depth $Depth
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

# ── Banner ───────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║   硅基API 2.0 - Claude Code 一键部署脚本         ║" -ForegroundColor Blue
Write-Host "╠══════════════════════════════════════════════════╣" -ForegroundColor Blue
Write-Host "║  本脚本由 硅基API (api.guiji.co) 提供            ║" -ForegroundColor Blue
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
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if (-not $installed) {
            Write-Info "安装 $display..."
            npm install -g $pkg 2>&1 | Select-Object -Last 3
            if ($LASTEXITCODE -ne 0) { throw "$display 安装失败 (exit code $LASTEXITCODE)" }
            Write-Success "$display 安装完成"
        } else {
            Write-Info "检查 $display 最新版本..."
            $latest = Get-LatestNpmVersion $pkg
            if ($latest -and $installed -eq $latest) {
                Write-Skip "$display $installed 已是最新版本"
            } else {
                Write-Info "$display $installed → $latest，升级中..."
                npm install -g $pkg 2>&1 | Select-Object -Last 3
                if ($LASTEXITCODE -ne 0) { throw "$display 升级失败 (exit code $LASTEXITCODE)" }
                Write-Success "$display 升级完成"
            }
        }
    } finally {
        $ErrorActionPreference = $oldEAP
    }
}

function Get-AvailableModels {
    param([string]$ApiKey)
    try {
        $headers = @{
            "x-api-key" = $ApiKey
            "anthropic-version" = "2023-06-01"
        }
        $response = Invoke-RestMethod -Uri "$API_BASE_URL/v1/models" -Headers $headers -Method Get -TimeoutSec 15
        $models = @()
        if ($response.data) {
            foreach ($m in $response.data) {
                $modelId = if ($m.id) { $m.id } elseif ($m.name) { $m.name } else { $null }
                # 只保留 claude- 开头的对话模型
                if ($modelId -and $modelId -match '^claude-' -and $modelId -notmatch 'instant|ping') {
                    $models += $modelId
                }
            }
        }
        return @($models | Sort-Object)
    } catch {
        Write-Warn "动态拉取模型列表失败: $($_.Exception.Message)"
        return $null
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

    $confirm = Read-Host "是否自动清理认证冲突？(Y/n，默认 Y)"
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
                Write-JsonFile -Path $settingsFile -Data $settings
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
    $confirm = Read-Host "是否继续清理并重装？(Y/n，默认 Y)"
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

$API_KEY = Read-Secret "请输入 API Key（输入时不显示）"
if ([string]::IsNullOrWhiteSpace($API_KEY)) {
    Exit-WithError "API Key 不能为空"
}
# 格式校验
if ($API_KEY -notmatch '^[A-Za-z0-9_-]{10,}$') {
    Write-Warn "API Key 格式可能不正确（含特殊字符或过短），请确认后继续"
}
Write-Success "API Key 已设置"

# ── 5. 动态拉取 Anthropic 模型列表并选择默认模型 ─────────────
Write-Step "拉取最新 Anthropic 模型列表"

$ALL_MODELS = $null
$fetchedModels = Get-AvailableModels -ApiKey $API_KEY
if ($fetchedModels -and $fetchedModels.Count -gt 0) {
    # 只保留 claude- 开头的模型
    $claudeModels = @($fetchedModels | Where-Object { $_ -match '^claude-' })
    if ($claudeModels.Count -gt 0) {
        $ALL_MODELS = $claudeModels
        Write-Success "成功拉取 $($claudeModels.Count) 个 Anthropic 模型（实时更新）"
    }
}

if (-not $ALL_MODELS -or $ALL_MODELS.Count -eq 0) {
    Write-Warn "动态拉取失败，使用内置模型列表"
    $ALL_MODELS = @($ANTHROPIC_MODELS.name)
}

Write-Host ""
for ($i = 0; $i -lt $ALL_MODELS.Count; $i++) {
    $marker = if ($i -eq 0) { "（推荐）" } else { "" }
    Write-Host "  $($i+1)) $($ALL_MODELS[$i]) $marker" -ForegroundColor Cyan
}
Write-Host ""

$MODEL_INDEX = Read-Host "请选择默认模型 (1/$($ALL_MODELS.Count)，默认 1)"
if ([string]::IsNullOrWhiteSpace($MODEL_INDEX)) { $MODEL_INDEX = "1" }
$MODEL_INDEX = [int]$MODEL_INDEX - 1
if ($MODEL_INDEX -lt 0 -or $MODEL_INDEX -ge $ALL_MODELS.Count) { $MODEL_INDEX = 0 }

$MODEL = $ALL_MODELS[$MODEL_INDEX]

Write-Success "已选择默认模型: $MODEL"
Write-Info "共配置 $($ALL_MODELS.Count) 个模型，可在 Claude Code 中随时切换"

# ── 6. 生成 config.json ──────────────────────────────────────
Write-Step "生成配置文件"

$CONFIG_DIR = "$env:USERPROFILE\.claude-code-router"
$CONFIG_FILE = "$CONFIG_DIR\config.json"
New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null

# 构建 Providers 数组（仅 Anthropic 格式，直接连接硅基API）
$providers = @(
    [ordered]@{
        name         = "guijiapi"
        api_base_url = "$API_BASE_URL/v1/messages"
        api_key      = $API_KEY
        models       = [string[]]$ALL_MODELS
        transformer  = @{ use = @("Anthropic") }
    }
)

$routerDefault = "guijiapi,$MODEL"

$config = [ordered]@{
    LOG            = $false
    CLAUDE_PATH    = ""
    HOST           = "127.0.0.1"
    PORT           = 3456
    APIKEY         = $API_KEY
    API_TIMEOUT_MS = "600000"
    PROXY_URL      = ""
    Transformers   = @()
    Providers      = $providers
    Router         = [ordered]@{
        default              = $routerDefault
        background           = $routerDefault
        think                = $routerDefault
        longContext          = $routerDefault
        longContextThreshold = 60000
        webSearch            = $routerDefault
    }
}

Write-JsonFile -Path $CONFIG_FILE -Data $config
Write-Success "配置文件已写入: $CONFIG_FILE"
Write-Info "默认模型: $MODEL"

# ── 7. 配置环境变量（仅当前会话，不设置全局用户环境变量，避免影响 EchoBird 等其他工具） ──
Write-Step "配置环境变量"

# 仅当前会话生效（不写入用户环境变量，避免全局影响其他工具）
$env:ANTHROPIC_API_KEY = $API_KEY
$env:ANTHROPIC_BASE_URL = $API_BASE_URL
$env:ANTHROPIC_AUTH_TOKEN = $null

Write-Success "当前会话环境变量已设置（未写入全局用户环境，不影响其他工具）"
Write-Info "持久化配置通过 ~/.claude/settings.json 的 env 块生效，仅影响 Claude Code"

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

# 写入选中的模型到顶层 model 字段，确保 `claude` 直连模式也能用到
$settingsHash['model'] = $MODEL

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

Write-JsonFile -Path $CLAUDE_SETTINGS -Data $settingsOut
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

Write-JsonFile -Path $CLAUDE_JSON -Data $claudeState -Depth 5
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
Write-Host "  配置已写入 ~/.claude/settings.json（仅影响 Claude Code，不影响其他工具）。"
Write-Host "  当前终端可直接运行 claude；新开终端也会自动读取 settings.json 配置。"
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

# ── 暂停等待用户确认 ───────────────────────────────────────────
Write-Host "按 Enter 键退出..." -ForegroundColor Yellow
Read-Host
