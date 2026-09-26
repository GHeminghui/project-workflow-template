#!/usr/bin/env bash
# 校验模板完整性。改动模板后必须运行本脚本。
#
# 用法:
#   bash scripts/validate.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$REPO_ROOT/template"

PASS=0
FAIL=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
section() { echo; echo "== $1 =="; }

section "1. 必需文件存在性"
required=(
  "template/AGENTS.md"
  "template/PROJECT_STATE.json"
  "template/README.md"
  "template/.gitignore"
  "template/.trae/hooks.json"
  "template/.trae/template-manifest.json"
  "template/.trae/scripts/inject_status.py"
  "template/.trae/commands/init-project.md"
  "template/.trae/commands/status.md"
  "template/.trae/commands/advance.md"
  "template/docs/README.md"
  "template/docs/adr/000-template.md"
  "template/00-discovery/README.md"
  "template/01-design/README.md"
  "template/02-development/README.md"
  "template/03-operations/README.md"
  "scripts/install.sh"
  "scripts/setup-global.sh"
  "scripts/upgrade.sh"
  "scripts/gen-manifest.sh"
  "AGENTS.md"
  "README.md"
  "CHANGELOG.md"
  "CONTRIBUTING.md"
  "LICENSE"
  "VERSION"
  "docs/design.md"
  "docs/architecture.md"
  "docs/specs/template-manifest.md"
  "docs/specs/upgrade-tool.md"
)
for f in "${required[@]}"; do
  [[ -e "$REPO_ROOT/$f" ]] && ok "$f" || bad "缺失: $f"
done

section "2. JSON 合法性"
if command -v python3 >/dev/null 2>&1; then
  for j in "template/PROJECT_STATE.json" "template/.trae/hooks.json"; do
    if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$REPO_ROOT/$j" 2>/dev/null; then
      ok "$j 合法"
    else
      bad "$j 非法 JSON"
    fi
  done
else
  bad "未找到 python3，跳过 JSON 校验"
fi

section "3. PROJECT_STATE.json 结构"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$REPO_ROOT/template/PROJECT_STATE.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
errs = []
for key in ("project_name", "current_stage", "stage_order", "stages", "next_action", "last_updated"):
    if key not in data:
        errs.append(f"缺少字段: {key}")
order = data.get("stage_order", [])
stages = data.get("stages", {})
if order != ["discovery", "design", "development", "operations"]:
    errs.append(f"stage_order 不符合预期: {order}")
for s in order:
    if s not in stages:
        errs.append(f"stages 缺少阶段: {s}")
        continue
    st = stages[s]
    for k in ("name", "status", "checklist"):
        if k not in st:
            errs.append(f"阶段 {s} 缺少字段: {k}")
    for item in st.get("checklist", []):
        if "item" not in item or "done" not in item:
            errs.append(f"阶段 {s} 的 checklist 项缺少 item/done")
if data.get("current_stage") not in order:
    errs.append("current_stage 不在 stage_order 中")
if errs:
    print("  ❌ " + "；".join(errs))
    sys.exit(1)
print("  ✅ 状态结构与四阶段定义一致")
PY
  [[ $? -eq 0 ]] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
fi

section "4. 载荷中不得含开发层内容"
leak_tokens=(
  "scripts/install.sh"
  "scripts/setup-global.sh"
  "scripts/validate.sh"
  "tests/test_install.sh"
  "CHANGELOG.md"
  "CONTRIBUTING.md"
  "docs/design.md"
  "docs/architecture.md"
)
leaked=0
for tok in "${leak_tokens[@]}"; do
  if grep -rqF "$tok" "$TEMPLATE" 2>/dev/null; then
    bad "载荷中出现了开发层引用: $tok"
    leaked=1
  fi
done
[[ $leaked -eq 0 ]] && ok "载荷未泄漏开发层内容"

section "5. 脚本语法与可执行性"
for s in "scripts/install.sh" "scripts/setup-global.sh" "scripts/upgrade.sh" "scripts/build-dist.sh" "scripts/gen-manifest.sh" "scripts/validate.sh" "tests/test_install.sh"; do
  if [[ -f "$REPO_ROOT/$s" ]]; then
    bash -n "$REPO_ROOT/$s" 2>/dev/null && ok "$s 语法正确" || bad "$s 语法错误"
  fi
done

section "6. 安装路径一致性（命令引用 vs 全局安装目标）"
REF=$(grep -oE '\$HOME/\.(trae|trae-cn)/templates/project-workflow/install\.sh' "$TEMPLATE/.trae/commands/init-project.md" | head -1 || true)
if [[ -n "$REF" ]]; then
  ok "init-project 引用了安装器: $REF"
else
  bad "init-project.md 未引用全局安装器路径"
fi
if grep -q "templates/project-workflow" "$REPO_ROOT/scripts/setup-global.sh"; then
  ok "setup-global 安装目标包含 templates/project-workflow"
else
  bad "setup-global 安装目标与命令引用不一致"
fi
if grep -qE '\$HOME/\.(trae|trae-cn)/templates/project-workflow/upgrade\.sh' "$TEMPLATE/.trae/commands/upgrade.md"; then
  ok "upgrade 引用了全局升级脚本"
else
  bad "upgrade.md 未引用全局升级脚本路径"
fi
if grep -q "upgrade\.sh\|upgrade.sh" "$REPO_ROOT/scripts/setup-global.sh"; then
  ok "setup-global 一并安装 upgrade.sh"
else
  bad "setup-global 未安装 upgrade.sh，/upgrade 将失效"
fi

section "7. 状态注入脚本可运行"
if command -v python3 >/dev/null 2>&1; then
  OUT=$(TRAE_PROJECT_DIR="$TEMPLATE" python3 "$TEMPLATE/.trae/scripts/inject_status.py" 2>&1 || true)
  if echo "$OUT" | grep -q "当前阶段"; then
    ok "inject_status.py 输出正常"
  else
    bad "inject_status.py 输出异常: $OUT"
  fi
fi

section "8. 模板清单一致性（清单 ↔ 载荷 ↔ 版本号）"
if [[ ! -f "$REPO_ROOT/scripts/gen-manifest.sh" ]]; then
  bad "缺少 scripts/gen-manifest.sh"
else
  if OUT=$(bash "$REPO_ROOT/scripts/gen-manifest.sh" --check 2>&1); then
    ok "清单与载荷、版本号一致"
  else
    bad "模板清单与载荷不一致（会导致升级时误判文件改动）"
    echo "$OUT" | sed 's/^/     /'
  fi
fi

echo
echo "========================================"
echo "  校验结果: 通过 $PASS 项，失败 $FAIL 项"
echo "========================================"
if [[ $FAIL -gt 0 ]]; then
  echo "❌ 校验未通过，请修复后重试。"
  exit 1
fi
echo "✅ 全部通过。"
