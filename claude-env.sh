#!/usr/bin/env bash
# ============================================================
#  Claude 环境切换器 - 多服务商一键切换（CLI 版）
#  支持: DeepSeek / 智谱清言 / Kimi / 硅基API / OpenAI / 其他
#  仅切换 CLI 版配置 (~/.claude/settings.json)，不影响桌面版
#
#  用法:
#    bash claude-env.sh              # 交互式菜单
#    bash claude-env.sh list         # 列出所有环境
#    bash claude-env.sh switch <名称> # 直接切换
#    bash claude-env.sh add <名称>    # 保存当前配置为新环境
# ============================================================

ENV_DIR="$HOME/.claude/environments"
SETTINGS="$HOME/.claude/settings.json"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── 工具函数 ─────────────────────────────────────────────────
get_current_base_url() {
  [ -f "$SETTINGS" ] || return 0
  python3 -c "
import json, sys
try:
    with open('$SETTINGS') as f:
        d = json.load(f)
    print(d.get('env', {}).get('ANTHROPIC_BASE_URL', ''))
except Exception:
    print('')
" 2>/dev/null
}

get_env_list() {
  [ -d "$ENV_DIR" ] || return 0
  for d in "$ENV_DIR"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    url=""
    if [ -f "$d/settings.json" ]; then
      url=$(python3 -c "
import json
try:
    with open('$d/settings.json') as f:
        data = json.load(f)
    print(data.get('env', {}).get('ANTHROPIC_BASE_URL', ''))
except Exception:
    print('')
" 2>/dev/null)
    fi
    echo "$name|$url"
  done
}

save_current_env() {
  local name="$1"
  [ -f "$SETTINGS" ] || { echo -e "${YELLOW}[WARN]${NC} 当前没有 ~/.claude/settings.json，无法保存"; return 1; }
  case "$name" in
    *' '*|*'/'*|*'\'*|*':'*|*'*'*|*'?'*|*'"'*|*'<'*|*'>'*|*'|'*) echo -e "${RED}[ERROR]${NC} 环境名称不能包含空格或特殊字符"; return 1 ;;
  esac
  mkdir -p "$ENV_DIR/$name"
  cp "$SETTINGS" "$ENV_DIR/$name/settings.json"
  echo -e "${GREEN}[OK]${NC} 已保存当前环境: $name"
  local url
  url=$(get_current_base_url)
  [ -n "$url" ] && echo "     API: $url"
  return 0
}

switch_env() {
  local name="$1"
  local target="$ENV_DIR/$name/settings.json"
  if [ ! -f "$target" ]; then
    echo -e "${RED}[ERROR]${NC} 环境不存在: $name"
    echo "  可用环境: $(get_env_list | cut -d'|' -f1 | tr '\n' ' ')"
    return 1
  fi

  # 先把当前 settings 存回它所属的环境（避免丢失未保存的修改）
  local current
  current=$(get_current_base_url)
  if [ -n "$current" ]; then
    local match
    match=$(get_env_list | awk -F'|' -v url="$current" -v n="$name" '$2 == url && $1 != n { print $1; exit }')
    if [ -n "$match" ]; then
      save_current_env "$match" >/dev/null
      echo -e "${CYAN}[INFO]${NC} 已同步更新环境快照: $match"
    fi
  fi

  # 复制目标配置（无 BOM，UTF-8）
  python3 -c "
import shutil, sys
src = '$target'
dst = '$SETTINGS'
with open(src, 'r', encoding='utf-8-sig') as f:
    content = f.read()
with open(dst, 'w', encoding='utf-8', newline='') as f:
    f.write(content)
"
  echo -e "${GREEN}[OK]${NC} 已切换到环境: $name"
  local target_url
  target_url=$(get_env_list | awk -F'|' -v n="$name" '$1 == n { print $2; exit }')
  [ -n "$target_url" ] && echo "     API: $target_url"
  echo ""
  echo -e "${YELLOW}请重启 claude 会话使配置生效${NC}"
  return 0
}

# ── 命令行模式 ───────────────────────────────────────────────
case "${1:-}" in
  add)
    [ -n "$2" ] && { save_current_env "$2"; exit $?; }
    echo -e "${RED}[ERROR]${NC} 用法: bash claude-env.sh add <名称>"
    exit 1
    ;;
  list)
    echo -e "${CYAN}=== 已保存的环境 ===${NC}"
    local_count=$(get_env_list | wc -l | tr -d ' ')
    if [ "$local_count" = "0" ]; then
      echo "  （无，可通过交互模式或 add 保存当前环境）"
    else
      current=$(get_current_base_url)
      get_env_list | while IFS='|' read -r name url; do
        mark=""
        [ -n "$url" ] && [ "$url" = "$current" ] && mark="  <- 当前"
        echo "  $name  -  $url$mark"
      done
    fi
    exit 0
    ;;
  switch)
    [ -n "$2" ] && { switch_env "$2"; exit $?; }
    echo -e "${RED}[ERROR]${NC} 用法: bash claude-env.sh switch <名称>"
    exit 1
    ;;
esac

# ── 交互模式 ─────────────────────────────────────────────────
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Claude 环境切换器（CLI 版）                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""

current=$(get_current_base_url)
echo -e "${CYAN}当前环境:${NC} ${current:-（未配置）}"
echo ""

mapfile -t ENVS < <(get_env_list)
COUNT=${#ENVS[@]}
i=0
for entry in "${ENVS[@]}"; do
  i=$((i+1))
  name="${entry%%|*}"
  url="${entry#*|}"
  echo "  $i) $name  -  $url"
done
i=$((i+1))
SAVE_OPT=$i
echo "  $i) 保存当前环境为新环境"
i=$((i+1))
EXIT_OPT=$i
echo "  $i) 退出"

echo ""
read -r -p "请选择 (1-$i): " choice

if [ "$choice" = "$EXIT_OPT" ]; then echo "再见！"; exit 0; fi
if [ "$choice" = "$SAVE_OPT" ]; then
  read -r -p "请输入新环境名称（如 deepseek/zhipu/kimi）: " name
  if [ -n "$name" ]; then
    save_current_env "$name"
  else
    echo -e "${YELLOW}[WARN]${NC} 名称不能为空"
  fi
  echo ""
  read -r -p "按 Enter 键退出..."
  exit 0
fi

idx=$((choice - 1))
if [ "$idx" -lt 0 ] || [ "$idx" -ge "$COUNT" ]; then
  echo -e "${RED}[ERROR]${NC} 无效选择"
else
  entry="${ENVS[$idx]}"
  name="${entry%%|*}"
  switch_env "$name"
fi

echo ""
read -r -p "按 Enter 键退出..."
