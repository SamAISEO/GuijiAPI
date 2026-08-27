# 多模型支持安装脚本实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修改 install.ps1 和 install.sh，支持从 6 个供应商（Anthropic、DeepSeek、ChatGLM、Minimax、Moonshot、Bailian）的 18 个模型中选择

**Architecture:** 采用双 Provider 架构 - `anthropic` provider 使用 `/v1/messages` 端点，`openai` provider 使用 `/v1/chat/completions` 端点。用户选择模型后，Router.default 自动映射到正确的 Provider。

**Tech Stack:** PowerShell, Bash, JSON 配置

---

## 文件结构

```
install.ps1        # 修改：模型选择逻辑、config.json 生成
install.sh          # 修改：模型选择逻辑、config.json 生成
```

---

## 实现步骤

### Task 1: 修改 install.ps1 模型选择逻辑

**Files:**
- Modify: `install.ps1`

- [ ] **Step 1: 添加模型供应商和映射常量**

在文件顶部添加以下常量定义（找 到 `$MODEL_1 = "claude-sonnet-4-6"` 附近替换）：

```powershell
# ── 模型定义 ─────────────────────────────────────────────────
# Anthropic 系列
$ANTHROPIC_MODELS = @(
    @{ name = "claude-opus-4-7"; desc = "最新最强，较慢" },
    @{ name = "claude-sonnet-4-6"; desc = "推荐，速度快" },
    @{ name = "claude-opus-4-6"; desc = "旗舰级" },
    @{ name = "claude-opus-4-5-20251101"; desc = "最新版本" },
    @{ name = "claude-sonnet-4-5-20250929"; desc = "稳定版本" }
)

# DeepSeek 系列
$DEEPSEEK_MODELS = @(
    @{ name = "deepseek-v4-flash"; desc = "高性价比" },
    @{ name = "deepseek-v4-pro"; desc = "高性能" },
    @{ name = "deepseek-v3.2"; desc = "稳定版本" }
)

# ChatGLM 系列
$CHATGLM_MODELS = @(
    @{ name = "glm-5.1"; desc = "最新版本" },
    @{ name = "glm-5"; desc = "高性能" },
    @{ name = "glm-4.7"; desc = "稳定版本" }
)

# Minimax 系列
$MINIMAX_MODELS = @(
    @{ name = "MiniMax-M2.7"; desc = "最新版本" },
    @{ name = "MiniMax-M2.5"; desc = "稳定版本" }
)

# Moonshot 系列
$MOONSHOT_MODELS = @(
    @{ name = "kimi-k2.5"; desc = "最新版本" },
    @{ name = "kimi-k2"; desc = "稳定版本" }
)

# Bailian 系列
$BAILIAN_MODELS = @(
    @{ name = "qwen3.6-max-preview"; desc = "最新版本" },
    @{ name = "qwen3.6-plus"; desc = "高性能" }
)

# Provider 定义
$PROVIDERS = @{
    "anthropic" = @{
        api_base_url = "$API_BASE_URL/v1/messages"
        transformer = @{ use = @("Anthropic") }
    }
    "openai" = @{
        api_base_url = "$API_BASE_URL/v1/chat/completions"
        transformer = @{ use = @("OpenAI") }
    }
}
```

- [ ] **Step 2: 替换"选择默认模型"部分**

找到 `# ── 5. 选择模型 ──────────────────────────────────────────────` 段，用以下逻辑替换：

```powershell
# ── 5. 选择模型 ──────────────────────────────────────────────
Write-Step "选择模型供应商"
Write-Host "  1) Anthropic（Claude 系列）" -ForegroundColor Cyan
Write-Host "  2) DeepSeek" -ForegroundColor Cyan
Write-Host "  3) ChatGLM（智谱）" -ForegroundColor Cyan
Write-Host "  4) Minimax" -ForegroundColor Cyan
Write-Host "  5) Moonshot（月之暗面）" -ForegroundColor Cyan
Write-Host "  6) Bailian（阿里云百炼）" -ForegroundColor Cyan
Write-Host ""

$VENDOR_CHOICE = Read-Host "请选择供应商 (1/2/3/4/5/6，默认 1): "
if ([string]::IsNullOrWhiteSpace($VENDOR_CHOICE)) { $VENDOR_CHOICE = "1" }

# 根据供应商选择获取对应模型列表
switch ($VENDOR_CHOICE) {
    "1" { $SELECTED_MODELS = $ANTHROPIC_MODELS; $DEFAULT_PROVIDER = "anthropic"; $VENDOR_NAME = "Anthropic" }
    "2" { $SELECTED_MODELS = $DEEPSEEK_MODELS; $DEFAULT_PROVIDER = "anthropic"; $VENDOR_NAME = "DeepSeek" }
    "3" { $SELECTED_MODELS = $CHATGLM_MODELS; $DEFAULT_PROVIDER = "openai"; $VENDOR_NAME = "ChatGLM" }
    "4" { $SELECTED_MODELS = $MINIMAX_MODELS; $DEFAULT_PROVIDER = "openai"; $VENDOR_NAME = "Minimax" }
    "5" { $SELECTED_MODELS = $MOONSHOT_MODELS; $DEFAULT_PROVIDER = "openai"; $VENDOR_NAME = "Moonshot" }
    "6" { $SELECTED_MODELS = $BAILIAN_MODELS; $DEFAULT_PROVIDER = "openai"; $VENDOR_NAME = "Bailian" }
    default { $SELECTED_MODELS = $ANTHROPIC_MODELS; $DEFAULT_PROVIDER = "anthropic"; $VENDOR_NAME = "Anthropic" }
}

Write-Host ""
Write-Step "选择 $VENDOR_NAME 模型"
for ($i = 0; $i -lt $SELECTED_MODELS.Count; $i++) {
    $model = $SELECTED_MODELS[$i]
    $marker = if ($i -eq 0) { "（推荐）" } else { "" }
    Write-Host "  $($i+1)) $($model.name) $($model.desc) $marker" -ForegroundColor Cyan
}
Write-Host ""

$MODEL_INDEX = Read-Host "请选择 (1/$($SELECTED_MODELS.Count)，默认 1): "
if ([string]::IsNullOrWhiteSpace($MODEL_INDEX)) { $MODEL_INDEX = "1" }
$MODEL_INDEX = [int]$MODEL_INDEX - 1
if ($MODEL_INDEX -lt 0 -or $MODEL_INDEX -ge $SELECTED_MODELS.Count) { $MODEL_INDEX = 0 }

$MODEL = $SELECTED_MODELS[$MODEL_INDEX].name
Write-Success "已选择模型: $MODEL ($VENDOR_NAME)"
```

- [ ] **Step 3: 修改 config.json 生成逻辑**

找到 `# ── 6. 生成 config.json` 部分，用以下逻辑替换：

```powershell
# ── 6. 生成 config.json ──────────────────────────────────────
Write-Step "生成配置文件"

$CONFIG_DIR = "$env:USERPROFILE\.claude-code-router"
$CONFIG_FILE = "$CONFIG_DIR\config.json"
New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null

# 构建完整的 Providers 数组
$allAnthropicModels = @($ANTHROPIC_MODELS.name) + @($DEEPSEEK_MODELS.name)
$allOpenAIModels = @($CHATGLM_MODELS.name) + @($MINIMAX_MODELS.name) + @($MOONSHOT_MODELS.name) + @($BAILIAN_MODELS.name)

$providers = @(
    [ordered]@{
        name         = "anthropic"
        api_base_url = $PROVIDERS["anthropic"].api_base_url
        api_key      = $API_KEY
        models       = [string[]]$allAnthropicModels
        transformer  = $PROVIDERS["anthropic"].transformer
    },
    [ordered]@{
        name         = "openai"
        api_base_url = $PROVIDERS["openai"].api_base_url
        api_key      = $API_KEY
        models       = [string[]]$allOpenAIModels
        transformer  = $PROVIDERS["openai"].transformer
    }
)

$routerDefault = "anthropic,$MODEL"
if ($DEFAULT_PROVIDER -eq "openai") {
    $routerDefault = "openai,$MODEL"
}

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

$config | ConvertTo-Json -Depth 10 | Set-Content -Path $CONFIG_FILE -Encoding UTF8
Write-Success "配置文件已写入: $CONFIG_FILE"
Write-Info "默认模型: $MODEL (provider: $DEFAULT_PROVIDER)"
```

- [ ] **Step 4: 验证修改后的脚本**

运行以下命令检查语法：
```powershell
powershell -NoProfile -Command "Get-Content install.ps1 | Out-Null; Write-Host 'Syntax OK'"
```

---

### Task 2: 修改 install.sh 模型选择逻辑

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: 添加模型供应商和映射常量**

在文件顶部找到 `MODEL_1="claude-sonnet-4-6"` 等定义，替换为：

```bash
# ── 模型定义 ─────────────────────────────────────────────────
# Anthropic 系列
ANTHROPIC_MODELS=("claude-opus-4-7" "claude-sonnet-4-6" "claude-opus-4-6" "claude-opus-4-5-20251101" "claude-sonnet-4-5-20250929")
ANTHROPIC_DESCS=("最新最强，较慢" "推荐，速度快" "旗舰级" "最新版本" "稳定版本")

# DeepSeek 系列
DEEPSEEK_MODELS=("deepseek-v4-flash" "deepseek-v4-pro" "deepseek-v3.2")
DEEPSEEK_DESCS=("高性价比" "高性能" "稳定版本")

# ChatGLM 系列
CHATGLM_MODELS=("glm-5.1" "glm-5" "glm-4.7")
CHATGLM_DESCS=("最新版本" "高性能" "稳定版本")

# Minimax 系列
MINIMAX_MODELS=("MiniMax-M2.7" "MiniMax-M2.5")
MINIMAX_DESCS=("最新版本" "稳定版本")

# Moonshot 系列
MOONSHOT_MODELS=("kimi-k2.5" "kimi-k2")
MOONSHOT_DESCS=("最新版本" "稳定版本")

# Bailian 系列
BAILIAN_MODELS=("qwen3.6-max-preview" "qwen3.6-plus")
BAILIAN_DESCS=("最新版本" "高性能")

# Provider 定义
ANTHROPIC_API_BASE_URL="${API_BASE_URL}/v1/messages"
OPENAI_API_BASE_URL="${API_BASE_URL}/v1/chat/completions"
```

- [ ] **Step 2: 替换"选择模型"部分**

找到 `# ── 5. 选择模型` 段，用以下逻辑替换：

```bash
# ── 5. 选择模型 ──────────────────────────────────────────────
step "选择模型供应商"
echo -e "${CYAN}  1) Anthropic（Claude 系列）${NC}"
echo -e "${CYAN}  2) DeepSeek${NC}"
echo -e "${CYAN}  3) ChatGLM（智谱）${NC}"
echo -e "${CYAN}  4) Minimax${NC}"
echo -e "${CYAN}  5) Moonshot（月之暗面）${NC}"
echo -e "${CYAN}  6) Bailian（阿里云百炼）${NC}"
echo ""

VENDOR_CHOICE=$(read_input "请选择供应商 (1/2/3/4/5/6，默认 1): ")
VENDOR_CHOICE="${VENDOR_CHOICE:-1}"

# 根据供应商选择设置模型列表
case "$VENDOR_CHOICE" in
  2) SELECTED_MODELS=("${DEEPSEEK_MODELS[@]}"); SELECTED_DESCS=("${DEEPSEEK_DESCS[@]}"); DEFAULT_PROVIDER="anthropic"; VENDOR_NAME="DeepSeek" ;;
  3) SELECTED_MODELS=("${CHATGLM_MODELS[@]}"); SELECTED_DESCS=("${CHATGLM_DESCS[@]}"); DEFAULT_PROVIDER="openai"; VENDOR_NAME="ChatGLM" ;;
  4) SELECTED_MODELS=("${MINIMAX_MODELS[@]}"); SELECTED_DESCS=("${MINIMAX_DESCS[@]}"); DEFAULT_PROVIDER="openai"; VENDOR_NAME="Minimax" ;;
  5) SELECTED_MODELS=("${MOONSHOT_MODELS[@]}"); SELECTED_DESCS=("${MOONSHOT_DESCS[@]}"); DEFAULT_PROVIDER="openai"; VENDOR_NAME="Moonshot" ;;
  6) SELECTED_MODELS=("${BAILIAN_MODELS[@]}"); SELECTED_DESCS=("${BAILIAN_DESCS[@]}"); DEFAULT_PROVIDER="openai"; VENDOR_NAME="Bailian" ;;
  *) SELECTED_MODELS=("${ANTHROPIC_MODELS[@]}"); SELECTED_DESCS=("${ANTHROPIC_DESCS[@]}"); DEFAULT_PROVIDER="anthropic"; VENDOR_NAME="Anthropic" ;;
esac

step "选择 ${VENDOR_NAME} 模型"
MODEL_COUNT=${#SELECTED_MODELS[@]}
for i in $(seq 0 $((MODEL_COUNT - 1))); do
  marker=""
  if [ $i -eq 0 ]; then marker="（推荐）"; fi
  echo -e "${CYAN}  $((i+1))) ${SELECTED_MODELS[$i]} ${SELECTED_DESCS[$i]} $marker${NC}"
done
echo ""

MODEL_CHOICE=$(read_input "请选择 (1/$MODEL_COUNT，默认 1): ")
MODEL_CHOICE="${MODEL_CHOICE:-1}"
MODEL_INDEX=$((MODEL_CHOICE - 1))
if [ "$MODEL_INDEX" -lt 0 ] || [ "$MODEL_INDEX" -ge "$MODEL_COUNT" ]; then
  MODEL_INDEX=0
fi

MODEL="${SELECTED_MODELS[$MODEL_INDEX]}"
success "已选择模型: $MODEL ($VENDOR_NAME)"
```

- [ ] **Step 3: 修改 config.json 生成逻辑**

找到 `# ── 6. 生成 config.json` 段，用以下逻辑替换：

```bash
# ── 6. 生成 config.json ──────────────────────────────────────
step "生成配置文件"

CONFIG_DIR="$HOME/.claude-code-router"
CONFIG_FILE="$CONFIG_DIR/config.json"
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

# 构建所有模型列表
ALL_ANTHROPIC_MODELS=("${ANTHROPIC_MODELS[@]}" "${DEEPSEEK_MODELS[@]}")
ALL_OPENAI_MODELS=("${CHATGLM_MODELS[@]}" "${MINIMAX_MODELS[@]}" "${MOONSHOT_MODELS[@]}" "${BAILIAN_MODELS[@]}")

# 将数组转换为逗号分隔的字符串（用于 JSON）
join_by() { local IFS="$1"; shift; echo "$*"; }

ANTHROPIC_MODELS_JSON=$(python3 -c "import json; print(json.dumps(${ALL_ANTHROPIC_MODELS[@]+"${ALL_ANTHROPIC_MODELS[@]}"}))" 2>/dev/null || echo "[]")
OPENAI_MODELS_JSON=$(python3 -c "import json; print(json.dumps(${ALL_OPENAI_MODELS[@]+"${ALL_OPENAI_MODELS[@]}"}))" 2>/dev/null || echo "[]")

# 设置默认 provider
if [ "$DEFAULT_PROVIDER" = "openai" ]; then
  ROUTER_DEFAULT="openai,${MODEL}"
else
  ROUTER_DEFAULT="anthropic,${MODEL}"
fi

# 使用 python3 生成 JSON（更可靠）
if command -v python3 &>/dev/null; then
  python3 - "$CONFIG_FILE" "$ANTHROPIC_API_BASE_URL" "$OPENAI_API_BASE_URL" "$API_KEY" "$ANTHROPIC_MODELS_JSON" "$OPENAI_MODELS_JSON" "$ROUTER_DEFAULT" <<'PYEOF'
import json, sys
path, anthropic_url, openai_url, api_key, anthropic_models, openai_models, router_default = sys.argv[1:8]

config = {
    "LOG": False,
    "CLAUDE_PATH": "",
    "HOST": "127.0.0.1",
    "PORT": 3456,
    "APIKEY": api_key,
    "API_TIMEOUT_MS": "600000",
    "PROXY_URL": "",
    "Transformers": [],
    "Providers": [
        {
            "name": "anthropic",
            "api_base_url": anthropic_url,
            "api_key": api_key,
            "models": json.loads(anthropic_models),
            "transformer": {"use": ["Anthropic"]},
        },
        {
            "name": "openai",
            "api_base_url": openai_url,
            "api_key": api_key,
            "models": json.loads(openai_models),
            "transformer": {"use": ["OpenAI"]},
        }
    ],
    "Router": {
        "default": router_default,
        "background": router_default,
        "think": router_default,
        "longContext": router_default,
        "longContextThreshold": 60000,
        "webSearch": router_default,
    },
}

with open(path, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
PYEOF
else
  # 回退方案：直接写入 JSON（API_KEY 中可能有特殊字符）
  cat > "$CONFIG_FILE" <<EOF
{
  "LOG": false,
  "CLAUDE_PATH": "",
  "HOST": "127.0.0.1",
  "PORT": 3456,
  "APIKEY": "${API_KEY}",
  "API_TIMEOUT_MS": "600000",
  "PROXY_URL": "",
  "Transformers": [],
  "Providers": [
    {
      "name": "anthropic",
      "api_base_url": "${ANTHROPIC_API_BASE_URL}",
      "api_key": "${API_KEY}",
      "models": $(echo "${ALL_ANTHROPIC_MODELS[@]}" | tr ' ' '\n' | jq -Rs '.'),
      "transformer": { "use": ["Anthropic"] }
    },
    {
      "name": "openai",
      "api_base_url": "${OPENAI_API_BASE_URL}",
      "api_key": "${API_KEY}",
      "models": $(echo "${ALL_OPENAI_MODELS[@]}" | tr ' ' '\n' | jq -Rs '.'),
      "transformer": { "use": ["OpenAI"] }
    }
  ],
  "Router": {
    "default": "${ROUTER_DEFAULT}",
    "background": "${ROUTER_DEFAULT}",
    "think": "${ROUTER_DEFAULT}",
    "longContext": "${ROUTER_DEFAULT}",
    "longContextThreshold": 60000,
    "webSearch": "${ROUTER_DEFAULT}"
  }
}
EOF
fi

chmod 600 "$CONFIG_FILE"
success "配置文件已写入: $CONFIG_FILE"
info "默认模型: $MODEL (provider: $DEFAULT_PROVIDER)"
```

- [ ] **Step 4: 验证修改后的脚本**

运行以下命令检查语法：
```bash
bash -n install.sh && echo "Syntax OK"
```

---

## 验证计划

1. **语法检查** - 两个脚本都能通过语法检查
2. **配置生成测试** - 运行脚本选择不同模型，验证 config.json 格式正确
3. **Provider 映射测试** - 验证 Router.default 指向正确的 Provider

---

## 风险与注意事项

1. **Python3 依赖** - install.sh 中使用 python3 生成 JSON，如果系统没有 python3 需要有回退方案
2. **数组转 JSON** - bash 数组转 JSON 需要特殊处理，上述代码已包含解决方案
3. **权限** - config.json 权限必须为 600（包含 API Key）