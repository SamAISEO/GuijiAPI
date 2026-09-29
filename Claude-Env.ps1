# ============================================================
#  Claude 环境切换器 - 多服务商一键切换（CLI 版）
#  支持: DeepSeek / 智谱清言 / Kimi / 硅基API / OpenAI / 其他
#  仅切换 CLI 版配置 (~/.claude/settings.json)，不影响桌面版
#
#  用法:
#    右键 -> 使用 PowerShell 运行        # 交互式菜单
#    .\Claude-Env.ps1 -list              # 列出所有环境
#    .\Claude-Env.ps1 -switch <名称>     # 直接切换到指定环境
#    .\Claude-Env.ps1 -add <名称>        # 保存当前配置为新环境
# ============================================================

param(
    [string]$add,
    [switch]$list,
    [string]$switch
)

$ErrorActionPreference = "Stop"
$ENV_DIR = Join-Path $env:USERPROFILE ".claude\environments"
$SETTINGS = Join-Path $env:USERPROFILE ".claude\settings.json"

# ── 工具函数 ─────────────────────────────────────────────────
function Write-NoBom($path, $content) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $content, $utf8)
}

function Get-CurrentBaseUrl {
    if (-not (Test-Path $SETTINGS)) { return $null }
    try {
        $s = Get-Content $SETTINGS -Raw | ConvertFrom-Json
        return $s.env.ANTHROPIC_BASE_URL
    } catch { return $null }
}

function Get-EnvList {
    $result = @()
    if (-not (Test-Path $ENV_DIR)) { return $result }
    Get-ChildItem $ENV_DIR -Directory -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
        $p = Join-Path $_.FullName "settings.json"
        $url = ""
        if (Test-Path $p) {
            try { $url = ((Get-Content $p -Raw | ConvertFrom-Json).env.ANTHROPIC_BASE_URL) } catch { $url = "" }
        }
        $result += [PSCustomObject]@{ Name = $_.Name; BaseUrl = $url }
    }
    return $result
}

function Save-CurrentEnv($name) {
    if (-not (Test-Path $SETTINGS)) {
        Write-Host "[WARN] 当前没有 ~/.claude/settings.json，无法保存" -ForegroundColor Yellow
        return $false
    }
    if ($name -match '[\s\\/:*?"<>|]') {
        Write-Host "[ERROR] 环境名称不能包含空格或特殊字符" -ForegroundColor Red
        return $false
    }
    $dir = Join-Path $ENV_DIR $name
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Copy-Item $SETTINGS (Join-Path $dir "settings.json") -Force
    $url = Get-CurrentBaseUrl
    Write-Host "[OK] 已保存当前环境: $name" -ForegroundColor Green
    if ($url) { Write-Host "     API: $url" }
    return $true
}

function Switch-Env($name) {
    $target = Join-Path $ENV_DIR "$name\settings.json"
    if (-not (Test-Path $target)) {
        Write-Host "[ERROR] 环境不存在: $name" -ForegroundColor Red
        Write-Host "  可用环境: $((Get-EnvList | ForEach-Object { $_.Name }) -join ', ')"
        return 1
    }

    # 先把当前 settings 存回它所属的环境（避免丢失未保存的修改）
    $current = Get-CurrentBaseUrl
    if ($current) {
        $envs = Get-EnvList
        $match = $envs | Where-Object { $_.BaseUrl -eq $current -and $_.Name -ne $name } | Select-Object -First 1
        if ($match) {
            Save-CurrentEnv $match.Name | Out-Null
            Write-Host "[INFO] 已同步更新环境快照: $($match.Name)" -ForegroundColor Cyan
        }
    }

    # 读取目标环境并写入（统一去 BOM）
    $content = [System.IO.File]::ReadAllText($target, [System.Text.Encoding]::UTF8)
    Write-NoBom $SETTINGS $content

    $targetUrl = (Get-EnvList | Where-Object { $_.Name -eq $name }).BaseUrl
    Write-Host "[OK] 已切换到环境: $name" -ForegroundColor Green
    if ($targetUrl) { Write-Host "     API: $targetUrl" }
    Write-Host ""
    Write-Host "请重启 claude 会话使配置生效" -ForegroundColor Yellow
    return 0
}

# ── 命令行模式 ───────────────────────────────────────────────
if ($add) {
    Save-CurrentEnv $add | Out-Null
    exit 0
}
if ($list) {
    Write-Host "=== 已保存的环境 ===" -ForegroundColor Cyan
    $envs = Get-EnvList
    if ($envs.Count -eq 0) {
        Write-Host "  （无，可通过交互模式或 -add 保存当前环境）"
    } else {
        $current = Get-CurrentBaseUrl
        foreach ($e in $envs) {
            $mark = if ($e.BaseUrl -and $e.BaseUrl -eq $current) { "  <- 当前" } else { "" }
            Write-Host "  $($e.Name)  -  $($e.BaseUrl)$mark"
        }
    }
    exit 0
}
if ($switch) {
    exit (Switch-Env $switch)
}

# ── 交互模式 ─────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║     Claude 环境切换器（CLI 版）                  ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

$current = Get-CurrentBaseUrl
Write-Host "当前环境: $(if ($current) { $current } else { '（未配置）' })" -ForegroundColor Cyan
Write-Host ""

$envs = Get-EnvList
Write-Host "可用环境:"
$i = 0
foreach ($e in $envs) {
    $i++
    Write-Host "  $i) $($e.Name)  -  $($e.BaseUrl)"
}
$i++
Write-Host "  $i) 保存当前环境为新环境"
$i++
Write-Host "  $i) 退出"

Write-Host ""
$choice = Read-Host "请选择 (1-$i)"
$choice = $choice.Trim()

if ($choice -eq $i) { Write-Host "再见！"; exit 0 }
if ($choice -eq ($i - 1)) {
    $name = Read-Host "请输入新环境名称（如 deepseek/zhipu/kimi）"
    if (-not [string]::IsNullOrWhiteSpace($name)) { Save-CurrentEnv $name.Trim() | Out-Null }
    else { Write-Host "[WARN] 名称不能为空" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "按 Enter 键退出..." -ForegroundColor Yellow
    Read-Host
    exit 0
}

$idx = [int]$choice - 1
if ($idx -lt 0 -or $idx -ge $envs.Count) {
    Write-Host "[ERROR] 无效选择" -ForegroundColor Red
} else {
    Switch-Env $envs[$idx].Name | Out-Null
}

Write-Host ""
Write-Host "按 Enter 键退出..." -ForegroundColor Yellow
Read-Host
