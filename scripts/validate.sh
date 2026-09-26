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
for key in ("project_name", "current_stage", "stage_order", "stages", "last_updated"):
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

section "9. 阶段准出一致性（门控 ↔ AGENTS.md ↔ 阶段 README ↔ 汇总表）"
if command -v python3 >/dev/null 2>&1; then
  OUT=$(python3 - "$TEMPLATE" <<'PY'
import json
import os
import re
import sys

template = sys.argv[1]
STAGES = [("discovery", "00-discovery"), ("design", "01-design"),
          ("development", "02-development"), ("operations", "03-operations")]


def norm(tokens):
    out = set()
    for t in tokens:
        t = t.strip().strip("`").strip().rstrip("/")
        if t:
            out.add(t)
    return out


def backticks(text):
    return re.findall(r"`([^`]+)`", text)


# 基准：门控（PROJECT_STATE.json 的 checklist artifact）
with open(os.path.join(template, "PROJECT_STATE.json"), encoding="utf-8") as f:
    state = json.load(f)
gates = {
    key: norm([os.path.basename(i["artifact"]) for i in state["stages"][key]["checklist"]])
    for key, _ in STAGES
}
stage_names = {key: state["stages"][key].get("name", "") for key, _ in STAGES}

sources = {}

# 阶段 README 的「准出产物」
readme = {}
title_names = {}
for key, d in STAGES:
    items = []
    title = ""
    with open(os.path.join(template, d, "README.md"), encoding="utf-8") as f:
        for line in f:
            stripped = line.strip()
            m = re.match(r"^- \[ \] `([^`]+)`", stripped)
            if m:
                items.append(m.group(1))
            tm = re.match(r"^# 阶段 \d+：(.+?)（", stripped)
            if tm:
                title = tm.group(1)
    readme[key] = norm(items)
    title_names[key] = title
sources["阶段 README"] = readme

# AGENTS.md 阶段说明里的「准出」行
with open(os.path.join(template, "AGENTS.md"), encoding="utf-8") as f:
    agents_text = f.read()
agents = {}
head_names = {}
for key, d in STAGES:
    sec = re.search(r"^###[^\n]*" + re.escape(d) + r"[^\n]*\n(.*?)(?=\n###|\n##|\Z)",
                    agents_text, re.S | re.M)
    items = []
    if sec:
        m = re.search(r"^- 准出：(.*)$", sec.group(1), re.M)
        if m:
            items = backticks(m.group(1))
    agents[key] = norm(items)
    hm = re.search(r"^### (\S+)[^\n]*" + re.escape(d), agents_text, re.M)
    head_names[key] = hm.group(1) if hm else ""
sources["AGENTS.md"] = agents

# 两张「阶段产物」汇总表，按目录列定位阶段
table_names = {}
for rel in ["README.md", "docs/README.md"]:
    table = {}
    label = {}
    with open(os.path.join(template, rel), encoding="utf-8") as f:
        for line in f:
            if not line.strip().startswith("|"):
                continue
            cols = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cols) < 3:
                continue
            d = cols[1].strip().strip("`").rstrip("/")
            for key, dd in STAGES:
                if d == dd:
                    table[key] = norm(cols[2].replace("、", " ").split())
                    label[key] = cols[0].strip().strip(chr(96))
    sources[rel] = table
    table_names[rel] = label

errors = []
for name, src in sources.items():
    for key, d in STAGES:
        got = src.get(key, set())
        if got != gates[key]:
            detail = []
            if gates[key] - got:
                detail.append("缺 " + "、".join(sorted(gates[key] - got)))
            if got - gates[key]:
                detail.append("多 " + "、".join(sorted(got - gates[key])))
            errors.append(f"{name} 的 {key}（{d}/）: " + "；".join(detail))

# 阶段显示名：以 PROJECT_STATE.json 的 stages[].name 为权威来源
for name, src in {**{"AGENTS.md 标题": head_names, "阶段 README 标题": title_names},
                  **table_names}.items():
    for key, d in STAGES:
        got = src.get(key, "")
        if got != stage_names[key]:
            errors.append(f"{name} 的 {key}（{d}/）显示名不一致: "
                          f"「{got}」≠ 状态文件「{stage_names[key]}」")

if errors:
    for e in errors:
        print("  ❌ " + e)
    print("  门控以 PROJECT_STATE.json 的 checklist 为准；请让四处描述与它一致")
    sys.exit(1)
sys.exit(0)
PY
)
  if [[ $? -eq 0 ]]; then
    ok "门控与 AGENTS.md、阶段 README、两张汇总表描述一致"
  else
    bad "阶段准出在文档间不一致（门控才是真正生效的那层）"
    echo "$OUT" | sed 's/^/     /'
  fi
else
  bad "未找到 python3，跳过"
fi

section "10. Shell 变量引用后不接全角字符（bash 3.2 陷阱）"
if command -v python3 >/dev/null 2>&1; then
  OUT=$(python3 - "$REPO_ROOT" <<'PY'
import glob
import os
import re
import sys

root = sys.argv[1]
pat = re.compile(r"\$([A-Za-z_][A-Za-z0-9_]*)([^\x00-\x7F])")
files = (sorted(glob.glob(os.path.join(root, "scripts", "*.sh")))
         + sorted(glob.glob(os.path.join(root, "tests", "*.sh")))
         + sorted(glob.glob(os.path.join(root, "template", "**", "*.sh"), recursive=True)))
found = []
for f in files:
    for i, line in enumerate(open(f, encoding="utf-8"), 1):
        for m in pat.finditer(line):
            found.append(f"{os.path.relpath(f, root)}:{i}: ${m.group(1)} 后紧跟 {m.group(2)}")
if found:
    for item in found:
        print("  ❌ " + item)
    print("  macOS 的 bash 3.2 会把高位字节并入变量名，导致变量未定义或静默丢失；请写成 ${VAR}")
    sys.exit(1)
sys.exit(0)
PY
)
  if [[ $? -eq 0 ]]; then
    ok "Shell 脚本中无「变量后紧接全角字符」写法"
  else
    bad "存在会触发 bash 3.2 误解析的变量写法"
    echo "$OUT" | sed 's/^/     /'
  fi
else
  bad "未找到 python3，跳过"
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
