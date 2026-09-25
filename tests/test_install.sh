#!/usr/bin/env bash
# 安装端到端测试：验证 install.sh 与 setup-global.sh 的正确行为。
#
# 用法:
#   bash tests/test_install.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
section() { echo; echo "== $1 =="; }

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

assert_file() { [[ -f "$2" ]] && ok "$1" || bad "$1 (缺失: $2)"; }

section "1. 安装到空目录"
TARGET="$WORK/my-app"
bash "$REPO_ROOT/scripts/install.sh" "$TARGET" >/dev/null 2>&1
[[ -d "$TARGET" ]] && ok "目标目录已创建" || bad "目标目录未创建"
for f in AGENTS.md PROJECT_STATE.json .gitignore \
         .trae/hooks.json .trae/scripts/inject_status.py \
         .trae/commands/init-project.md .trae/commands/status.md .trae/commands/advance.md \
         docs/README.md docs/adr/000-template.md \
         00-discovery/README.md 01-design/README.md 02-development/README.md 03-operations/README.md; do
  assert_file "已安装 $f" "$TARGET/$f"
done
[[ -d "$TARGET/.git" ]] && ok "已初始化 git" || bad "未初始化 git"

section "2. 状态文件被正确写入"
if command -v python3 >/dev/null 2>&1; then
  OUT=$(python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print(d["project_name"])
PY
)
  [[ "$OUT" == "my-app" ]] && ok "project_name = my-app" || bad "project_name 异常: $OUT"
else
  bad "未找到 python3，跳过"
fi

section "3. 状态注入脚本可运行"
OUT=$(TRAE_PROJECT_DIR="$TARGET" python3 "$TARGET/.trae/scripts/inject_status.py" 2>&1 || true)
echo "$OUT" | grep -q "当前阶段" && ok "输出包含当前阶段" || bad "输出异常: $OUT"
echo "$OUT" | grep -q "调研" && ok "当前阶段为调研" || bad "阶段渲染异常"

section "4. 默认跳过已存在文件（不覆盖）"
echo "CUSTOM" > "$TARGET/AGENTS.md"
bash "$REPO_ROOT/scripts/install.sh" "$TARGET" >/dev/null 2>&1
grep -q "CUSTOM" "$TARGET/AGENTS.md" && ok "已存在文件未被覆盖" || bad "已存在文件被误覆盖"

section "5. --force 覆盖已存在文件"
bash "$REPO_ROOT/scripts/install.sh" "$TARGET" -f >/dev/null 2>&1
grep -q "CUSTOM" "$TARGET/AGENTS.md" && bad "--force 未生效" || ok "--force 成功覆盖"

section "6. 全局安装（模拟 HOME）"
FAKE_HOME="$WORK/home"
mkdir -p "$FAKE_HOME"
HOME="$FAKE_HOME" bash "$REPO_ROOT/scripts/setup-global.sh" >/dev/null 2>&1
GDEST="$FAKE_HOME/.trae/templates/project-workflow"
assert_file "全局载荷 AGENTS.md" "$GDEST/AGENTS.md"
assert_file "全局安装器 install.sh" "$GDEST/install.sh"
assert_file "全局命令 init-project.md" "$FAKE_HOME/.trae/commands/init-project.md"
assert_file "全局命令 status.md" "$FAKE_HOME/.trae/commands/status.md"
assert_file "全局命令 advance.md" "$FAKE_HOME/.trae/commands/advance.md"

section "7. 全局安装器可独立工作（路径自适应）"
TARGET2="$WORK/from-global"
bash "$GDEST/install.sh" "$TARGET2" >/dev/null 2>&1
assert_file "从全局安装器安装成功" "$TARGET2/PROJECT_STATE.json"
assert_file "从全局安装器安装命令" "$TARGET2/.trae/commands/advance.md"

section "8. 全局命令引用的路径真实存在"
REF_PATH="$FAKE_HOME/.trae/templates/project-workflow/install.sh"
[[ -f "$REF_PATH" ]] && ok "命令引用的安装器存在: $REF_PATH" || bad "命令引用的安装器不存在"

section "9. 全局卸载"
HOME="$FAKE_HOME" bash "$REPO_ROOT/scripts/setup-global.sh" --uninstall >/dev/null 2>&1
[[ ! -f "$FAKE_HOME/.trae/commands/init-project.md" ]] && ok "全局命令已卸载" || bad "全局命令未卸载"
[[ -d "$GDEST" ]] && ok "全局载荷保留" || bad "全局载荷被误删"

echo
echo "========================================"
echo "  测试结果: 通过 $PASS 项，失败 $FAIL 项"
echo "========================================"
if [[ $FAIL -gt 0 ]]; then
  echo "❌ 测试未通过。"
  exit 1
fi
echo "✅ 全部通过。"
