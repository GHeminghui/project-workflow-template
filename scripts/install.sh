#!/usr/bin/env bash
# 将四阶段工作流模板（template/ 载荷）安装到指定项目目录。
#
# 用法:
#   bash install.sh [目标目录] [选项]
#
# 选项:
#   -n, --name <名称>   指定项目名（默认取目标目录名）
#   -f, --force         覆盖已存在的模板文件（不含 PROJECT_STATE.json，它属用户数据）
#   -h, --help          显示帮助
#
# 示例:
#   bash scripts/install.sh ~/code/my-app
#   bash scripts/install.sh ~/code/my-app -n "我的应用" -f
#
# 载荷定位（自动）:
#   仓库内运行      -> ../template
#   全局模板目录内  -> 脚本同级目录（含 PROJECT_STATE.json）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -d "$SCRIPT_DIR/../template" ]]; then
  PAYLOAD="$(cd "$SCRIPT_DIR/../template" && pwd)"
elif [[ -f "$SCRIPT_DIR/PROJECT_STATE.json" ]]; then
  PAYLOAD="$SCRIPT_DIR"
else
  echo "错误: 未找到模板载荷（template/ 或同级 PROJECT_STATE.json）。" >&2
  exit 1
fi

TARGET_DIR=""
PROJECT_NAME=""
NAME_GIVEN=0
FORCE=0

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name) PROJECT_NAME="$2"; NAME_GIVEN=1; shift 2 ;;
    -f|--force) FORCE=1; shift ;;
    -h|--help) usage ;;
    -*) echo "未知选项: $1" >&2; usage ;;
    *) TARGET_DIR="$1"; shift ;;
  esac
done

if [[ -z "$TARGET_DIR" ]]; then
  echo "错误: 请指定目标目录。用法: bash install.sh <目标目录> [-n 项目名] [-f]" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

if [[ -z "$PROJECT_NAME" ]]; then
  PROJECT_NAME="$(basename "$TARGET_DIR")"
fi

echo "==> 载荷来源: $PAYLOAD"
echo "==> 安装目标: $TARGET_DIR"
echo "==> 项目名称: $PROJECT_NAME"

copy_file() {
  local rel="$1"
  local src="$PAYLOAD/$rel"
  local dst="$TARGET_DIR/$rel"
  [[ -e "$src" ]] || return 0
  if [[ -e "$dst" && "$FORCE" -ne 1 ]]; then
    echo "    [跳过] 已存在: $rel"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "    [写入] $rel"
}

echo "==> 创建目录结构"
for d in 00-discovery 01-design 02-development 03-operations docs/adr .trae/scripts .trae/commands; do
  mkdir -p "$TARGET_DIR/$d"
done

echo "==> 复制载荷文件"
copy_file "AGENTS.md"

# PROJECT_STATE.json 属用户数据（承载项目进度），仅在不存在时写入初始模板；
# 即使指定 --force 也不整体覆盖，否则会清空 current_stage / checklist / deliverables。
if [[ -e "$TARGET_DIR/PROJECT_STATE.json" ]]; then
  STATE_PREEXISTING=1
  echo "    [保留] 已存在: PROJECT_STATE.json（用户数据，不覆盖）"
else
  STATE_PREEXISTING=0
  cp "$PAYLOAD/PROJECT_STATE.json" "$TARGET_DIR/PROJECT_STATE.json"
  echo "    [写入] PROJECT_STATE.json"
fi

copy_file "README.md"
copy_file ".gitignore"
copy_file "docs/README.md"
copy_file "docs/adr/000-template.md"
copy_file ".trae/hooks.json"
copy_file ".trae/scripts/inject_status.py"

for cmd in "$PAYLOAD"/.trae/commands/*.md; do
  [[ -e "$cmd" ]] && copy_file ".trae/commands/$(basename "$cmd")"
done

for stage in 00-discovery 01-design 02-development 03-operations; do
  copy_file "$stage/README.md"
done

echo "==> 处理 PROJECT_STATE.json"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$TARGET_DIR/PROJECT_STATE.json" "$PROJECT_NAME" "$STATE_PREEXISTING" "$NAME_GIVEN" <<'PY'
import json, sys, datetime

path, name = sys.argv[1], sys.argv[2]
preexisting = sys.argv[3] == "1"
name_given = sys.argv[4] == "1"

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

today = datetime.date.today().isoformat()
changed = False

if not preexisting:
    # 全新安装：写入初始状态的元信息
    data["project_name"] = name
    data["created_at"] = today
    if data.get("current_stage") in data.get("stages", {}):
        data["stages"][data["current_stage"]]["started_at"] = today
    data["last_updated"] = today
    changed = True
    print(f"    已初始化 project_name = {name}")
elif name_given and data.get("project_name") != name:
    # 已存在的项目：仅在用户显式传 -n 时做单字段更新，绝不触碰进度字段
    old = data.get("project_name")
    data["project_name"] = name
    data["last_updated"] = today
    changed = True
    print(f"    已更新 project_name: {old} -> {name}（进度字段未改动）")
else:
    print("    保留原有状态：current_stage / checklist / deliverables 均未改动")

if changed:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
PY
else
  echo "    [警告] 未找到 python3，跳过状态处理"
fi

chmod +x "$TARGET_DIR/.trae/scripts/inject_status.py" 2>/dev/null || true

echo "==> 初始化 git（若尚未初始化）"
if [[ ! -d "$TARGET_DIR/.git" ]]; then
  git -C "$TARGET_DIR" init -q 2>/dev/null && echo "    已执行 git init" || echo "    [警告] git init 失败或未安装 git"
else
  echo "    已是 git 仓库，跳过"
fi

cat <<EOF

==> 安装完成！

后续手动步骤（在 TRAE 中一次性设置）:
  1. 设置 → 规则 → 导入设置
     开启「将 AGENTS.md 包含在上下文中」
  2. 设置 → Hooks → 运行方式
     选择「本地自动运行」或「沙箱运行」
  3. 开启一个全新会话，验证状态注入是否生效

可用命令:
  /init-project   重新生成/补齐模板
  /status         查看当前阶段与进度
  /advance        推进到下一阶段
EOF
