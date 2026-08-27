# 硅基API - 多模型支持安装脚本设计

**日期：** 2026-05-16
**状态：** 初稿

## 背景

当前 `install.ps1` 和 `install.sh` 仅支持 4 个硬编码的 Anthropic Claude 模型选择。用户希望能够选择更多支持的模型，包括国产大模型（DeepSeek、ChatGLM、Minimax、Moonshot、Bailian）。

## 支持的模型列表

### Anthropic 系列（5个模型）
- `claude-opus-4-7`
- `claude-sonnet-4-6`
- `claude-opus-4-6`
- `claude-opus-4-5-20251101`
- `claude-sonnet-4-5-20250929`

### DeepSeek 系列（3个模型）
- `deepseek-v4-flash`
- `deepseek-v4-pro`
- `deepseek-v3.2`

### ChatGLM 系列（3个模型）
- `glm-5.1`
- `glm-5`
- `glm-4.7`

### Minimax 系列（2个模型）
- `MiniMax-M2.7`
- `MiniMax-M2.5`

### Moonshot 系列（2个模型）
- `kimi-k2.5`
- `kimi-k2`

### Bailian 系列（3个模型）
- `qwen3.6-max-preview`
- `qwen3.6-plus`

**总计：** 6个供应商，18个模型

## API 端点分析

| 供应商 | Anthropic 格式 (`/v1/messages`) | OpenAI 格式 (`/v1/chat/completions`) |
|--------|--------------------------------|---------------------------------------|
| Anthropic | ✅ | ✅ |
| DeepSeek | ✅ | ✅ |
| ChatGLM | ❌ | ✅ |
| Minimax | ❌ | ✅ |
| Moonshot | ❌ | ✅ |
| Bailian | ❌ | ✅ |

## 架构设计

### Provider 配置策略

在 `~/.claude-code-router/config.json` 中配置两个 Provider：

```json
{
  "Providers": [
    {
      "name": "anthropic",
      "api_base_url": "https://api.guijiapi.net/v1/messages",
      "api_key": "<USER_API_KEY>",
      "models": ["claude-opus-4-7", "claude-sonnet-4-6", "claude-opus-4-6", ...],
      "transformer": { "use": ["Anthropic"] }
    },
    {
      "name": "openai",
      "api_base_url": "https://api.guijiapi.net/v1/chat/completions",
      "api_key": "<USER_API_KEY>",
      "models": ["glm-5.1", "glm-5", "glm-4.7", ...],
      "transformer": { "use": ["OpenAI"] }
    }
  ]
}
```

### Router 配置

```json
{
  "Router": {
    "default": "anthropic,<DEFAULT_MODEL>",
    "background": "anthropic,<DEFAULT_MODEL>",
    "think": "anthropic,<DEFAULT_MODEL>",
    "longContext": "anthropic,<DEFAULT_MODEL>",
    "longContextThreshold": 60000,
    "webSearch": "anthropic,<DEFAULT_MODEL>"
  }
}
```

当用户选择不同模型时，`default` provider 会自动映射到对应的 Provider：

| 用户选择 | Router.default 格式 | 实际 Provider |
|----------|---------------------|---------------|
| Claude 系列 | `anthropic,claude-sonnet-4-6` | anthropic provider |
| DeepSeek 系列 | `anthropic,deepseek-v4-flash` | anthropic provider |
| ChatGLM 系列 | `openai,glm-5.1` | openai provider |
| Minimax 系列 | `openai,MiniMax-M2.7` | openai provider |
| Moonshot 系列 | `openai,kimi-k2.5` | openai provider |
| Bailian 系列 | `openai,qwen3.6-max-preview` | openai provider |

## 交互流程设计

### 模型选择界面

```
请选择模型供应商：
  1) Anthropic（Claude 系列）
  2) DeepSeek
  3) ChatGLM（智谱）
  4) Minimax
  5) Moonshot（月之暗面）
  6) Bailian（阿里云百炼）

请选择 (1/2/3/4/5/6，默认 1):
```

### 子模型选择（以 Anthropic 为例）

```
  1) claude-sonnet-4-6（推荐，速度快）⭐ Anthropic
  2) claude-opus-4-7（最新最强，较慢）⭐ Anthropic
  3) claude-opus-4-6（旗舰级）⭐ Anthropic
  4) claude-opus-4-5-20251101（最新版本）
  5) claude-sonnet-4-5-20250929（稳定版本）

请选择 (1/2/3/4/5，默认 1):
```

## 配置文件写入逻辑

1. 根据用户选择的模型，确定使用哪个 Provider：
   - Anthropic 系列 → `anthropic`
   - DeepSeek 系列 → `anthropic`（两种格式都支持）
   - 其他（ChatGLM、Minimax、Moonshot、Bailian）→ `openai`

2. 构建完整的 Providers 数组，包含所有18个模型

3. 设置 Router.default 为 `<PROVIDER_NAME>,<SELECTED_MODEL>`

## 脚本修改清单

### install.ps1 修改点

1. **常量定义** - 添加 MODEL_PROVIDERS 映射表
2. **选择函数** - 修改模型选择逻辑，支持分组选择
3. **配置生成** - 修改 config.json 生成逻辑，支持双 Provider
4. **环境变量** - 保持不变（ANTHROPIC_API_KEY 和 ANTHROPIC_BASE_URL）

### install.sh 修改点

1. **常量定义** - 添加 MODEL_PROVIDERS 映射表
2. **选择函数** - 修改模型选择逻辑，支持分组选择
3. **配置生成** - 修改 config.json 生成逻辑，支持双 Provider
4. **环境变量** - 保持不变

## 兼容性考虑

1. **向后兼容** - 现有用户升级后，原有配置不受影响
2. **幂等性** - 重复运行脚本不会破坏现有配置
3. **验证** - 配置写入后验证 API 连通性

## 验证计划

1. 验证 config.json 格式正确
2. 验证每个 Provider 的模型数量
3. 验证 Router.default 指向正确的 Provider
4. 实际调用 API 测试不同模型

## 风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| Transformer 配置不正确导致模型不工作 | 预设经过验证的 transformer 配置 |
| API 端点变更 | 配置中预留端点自定义能力 |
| 新模型上线后需要手动更新 | 未来可考虑从 API 动态获取模型列表 |