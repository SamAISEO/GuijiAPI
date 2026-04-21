# Claude Code 安装及对接硅基API指南

## 一、安装 Claude Code

给大家准备了一个一键安装脚本，大家可以用以下命令来一键安装 Claude Code 并配置好硅基API。

### Linux / MacOS

```bash
curl -fsSL https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/install.sh | bash
```

### Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/install.ps1 | iex
```

复制上面的脚本命令到命令行窗口，按回车键运行，运行后根据指引输入你在硅基API平台创建的 API KEY 并选择相应模型即可。

### 安装步骤说明

1. 获取 API Key：访问 [硅基API官网](https://api.guijiapi.net) 注册并获取 API Key
2. 运行安装脚本
3. 输入 API Key（输入时不显示）
4. 选择默认模型：
   - `claude-sonnet-4-6-20260218`（推荐，速度快）
   - `claude-opus-4-6-20260205`（最强，较慢）
   - `claude-sonnet-4-5-20250514`（稳定版本）
   - 或手动输入其他模型名

## 二、使用 Claude Code

按以上步骤配置完成后：

1. **关闭当前终端**，重新打开一个新的终端
2. 输入 `claude` 命令，即可打开 Claude Code 界面

### 首次启动选择

第一次进入时会让你确认是否使用刚配置好的 key：

```
? Allow Claude Code to use your account?
> 1. Yes, I trust this folder
```

选择第一个 **1. Yes, I trust this folder**

如果看到 Claude Code 的界面出来了，说明安装成功 ✅，然后就可以正常使用了。

## 三、常见问题

### Q: 运行 claude 命令提示未登录？

请先执行：
```bash
# Linux/Mac
source ~/.bashrc  # 或 source ~/.zshrc

# Windows
# 重启 PowerShell 终端
```

### Q: 提示 command not found？

检查 npm 全局路径是否在 PATH 中：
```bash
npm prefix -g
```

将输出路径添加到 PATH 环境变量。

### Q: 如何检查配置是否正确？

查看环境变量：
```bash
echo $ANTHROPIC_API_KEY
echo $ANTHROPIC_BASE_URL
```

应显示：
- `ANTHROPIC_API_KEY`: 你的 API Key（前10位）
- `ANTHROPIC_BASE_URL`: `https://api.guijiapi.net`

### Q: 如何更换模型？

修改配置文件：
```bash
# Linux/Mac
~/.claude-code-router/config.json

# Windows
%USERPROFILE%\.claude-code-router\config.json
```

修改 `Router.default` 和 `Providers[].models` 字段。

## 四、支持的模型

硅基API 支持以下 Claude 模型：

| 模型名称 | 特点 |
|---------|------|
| claude-sonnet-4-6-20260218 | 推荐，速度快 |
| claude-opus-4-6-20260205 | 最强，较慢 |
| claude-sonnet-4-5-20250514 | 稳定版本 |
| claude-3-5-sonnet-20241022 | 经典版本 |

---

**硅基API** - 提供高质量的AI接口服务，安全稳定、低延迟、高并发的企业级解决方案。

官网：https://api.guijiapi.net