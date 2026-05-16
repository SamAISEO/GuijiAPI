# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains installation scripts for deploying Claude Code configured to use 硅基API (GuijiAPI) as the API provider instead of Anthropic directly. The project consists of two platform-specific one-liner installer scripts and a HTML guide.

**API Provider:** `https://api.guijiapi.net`

## Repository Structure

- `install.sh` — Bash installer for Linux/macOS (piped via `curl | bash`)
- `install.ps1` — PowerShell installer for Windows (piped via `irm | iex`)
- `install-guide.html` — Standalone HTML installation guide
- `README.md` — User-facing documentation in Chinese

## What the Scripts Do

Both scripts perform the same steps:
1. Check Node.js version (minimum 16.0.0)
2. Install/update `@anthropic-ai/claude-code` and `claude-code-router` via npm globally
3. Prompt user for their GuijiAPI key (masked input)
4. Let user select a model (or enter custom)
5. Write `ANTHROPIC_API_KEY` and `ANTHROPIC_BASE_URL=https://api.guijiapi.net` to shell profile (`.bashrc`/`.zshrc`) or Windows user environment
6. Configure `claude-code-router` (`~/.claude-code-router/config.json` or `%USERPROFILE%\.claude-code-router\config.json`)

## Supported Models

| Model | Notes | Provider |
|-------|-------|----------|
| `claude-sonnet-4-6` | Recommended, fast | anthropic |
| `claude-opus-4-7` | Latest & most capable, slower | anthropic |
| `claude-opus-4-6` | Flagship | anthropic |
| `claude-opus-4-5-20251101` | Latest version | anthropic |
| `claude-sonnet-4-5-20250929` | Stable | anthropic |
| `deepseek-v4-flash` | High性价比 | anthropic |
| `deepseek-v4-pro` | High性能 | anthropic |
| `deepseek-v3.2` | Stable | anthropic |
| `glm-5.1` | ChatGLM latest | openai |
| `glm-5` | ChatGLM高性能 | openai |
| `glm-4.7` | ChatGLM稳定 | openai |
| `MiniMax-M2.7` | Minimax最新 | openai |
| `MiniMax-M2.5` | Minimax稳定 | openai |
| `kimi-k2.5` | Moonshot最新 | openai |
| `kimi-k2` | Moonshot稳定 | openai |
| `qwen3.6-max-preview` | Bailian最新 | openai |
| `qwen3.6-plus` | Bailian高性能 | openai |
| `qwen3.6` | Bailian标准 | openai |

## Key Implementation Details

**URL normalization:** Both scripts normalize API base URLs by stripping trailing slashes, `/v1`, and `/v1/messages` suffixes before comparison. This prevents duplicate configuration when the user's existing env already points to the same host.

**Idempotency:** Scripts skip re-installing npm packages already at latest version, and skip re-writing environment variables if they already point to an official URL (`api.guijiapi.net` or `api.anthropic.com`).

**Pipe-compatibility:** `install.sh` reads all interactive input from `/dev/tty` (not stdin) so it works when piped from `curl`.

**Router config path:**
- Linux/Mac: `~/.claude-code-router/config.json`
- Windows: `%USERPROFILE%\.claude-code-router\config.json`

## Deployment

Scripts are fetched directly from GitHub raw URLs — changes pushed to `main` are immediately live for new installs:
- `https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/install.sh`
- `https://raw.githubusercontent.com/SamAISEO/GuijiAPI/main/install.ps1`
