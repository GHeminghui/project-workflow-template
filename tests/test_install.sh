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
         .trae/hooks.json .trae/template-manifest.json .trae/scripts/inject_status.py \
         .trae/commands/init-project.md .trae/commands/status.md .trae/commands/advance.md \
         docs/README.md docs/adr/000-template.md \
         00-discovery/README.md 01-design/README.md 02-development/README.md 03-operations/README.md; do
  assert_file "已安装 $f" "$TARGET/$f"
done
[[ -d "$TARGET/.git" ]] && ok "已初始化 git" || bad "未初始化 git"

section "2. 状态文件与模板清单被正确写入"
if command -v python3 >/dev/null 2>&1; then
  OUT=$(python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print(d["project_name"])
PY
)
  [[ "$OUT" == "my-app" ]] && ok "project_name = my-app" || bad "project_name 异常: $OUT"

  OUT=$(python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8")).get("project_status", "<缺失>"))
PY
)
  [[ "$OUT" == "active" ]] && ok "project_status = active" || bad "project_status 异常: $OUT"

  EXPECTED_VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")"
  OUT=$(python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8")).get("template_version", "<缺失>"))
PY
)
  [[ "$OUT" == "$EXPECTED_VERSION" ]] && ok "template_version = $EXPECTED_VERSION" || bad "template_version 异常: ${OUT}（期望 ${EXPECTED_VERSION}）"
else
  bad "未找到 python3，跳过"
fi

assert_file "已安装模板清单" "$TARGET/.trae/template-manifest.json"
if cmp -s "$TARGET/.trae/template-manifest.json" "$REPO_ROOT/template/.trae/template-manifest.json"; then
  ok "安装的清单与载荷逐字节一致（基线可用）"
else
  bad "安装的清单与载荷不一致"
fi

section "3. 状态注入脚本可运行（下一步动作由 checklist 派生）"
OUT=$(TRAE_PROJECT_DIR="$TARGET" python3 "$TARGET/.trae/scripts/inject_status.py" 2>&1 || true)
echo "$OUT" | grep -q "当前阶段" && ok "输出包含当前阶段" || bad "输出异常: $OUT"
echo "$OUT" | grep -q "调研" && ok "当前阶段为调研" || bad "阶段渲染异常"
FIRST_ITEM=$(python3 -c "
import json
d = json.load(open('$TARGET/PROJECT_STATE.json', encoding='utf-8'))
print(d['stages'][d['current_stage']]['checklist'][0]['item'])")
NEXT_LINE=$(echo "$OUT" | grep "^下一步动作:" | sed 's/^下一步动作: //')
if [[ "$NEXT_LINE" == "$FIRST_ITEM" ]]; then
  ok "下一步动作派生自第一个未完成项"
else
  bad "下一步动作未正确派生: 得到「${NEXT_LINE}」，期望「${FIRST_ITEM}」"
fi
python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["stages"]["discovery"]["checklist"][0]["done"] = True
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
SECOND_ITEM=$(python3 -c "
import json
d = json.load(open('$TARGET/PROJECT_STATE.json', encoding='utf-8'))
print(d['stages']['discovery']['checklist'][1]['item'])")
OUT2=$(TRAE_PROJECT_DIR="$TARGET" python3 "$TARGET/.trae/scripts/inject_status.py" 2>&1 || true)
NEXT_LINE2=$(echo "$OUT2" | grep "^下一步动作:" | sed 's/^下一步动作: //')
if [[ "$NEXT_LINE2" == "$SECOND_ITEM" ]]; then
  ok "勾选后下一步动作自动前移（派生生效）"
else
  bad "下一步动作未随勾选前移: 得到「${NEXT_LINE2}」，期望「${SECOND_ITEM}」"
fi
python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["stages"]["discovery"]["checklist"][0]["done"] = False
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
# 归档状态：Hook 只提示状态，不再推动阶段
python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["project_status"] = "archived"
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
OUT3=$(TRAE_PROJECT_DIR="$TARGET" python3 "$TARGET/.trae/scripts/inject_status.py" 2>&1 || true)
echo "$OUT3" | grep -q "已归档" && ok "归档状态被渲染" || bad "归档状态未渲染: ${OUT3}"
echo "$OUT3" | grep -q "^下一步动作:" && bad "归档后仍推动阶段" || ok "归档后不再推动阶段"
python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["project_status"] = "active"
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY

section "4. 默认跳过已存在文件（不覆盖）"
echo "CUSTOM" > "$TARGET/AGENTS.md"
bash "$REPO_ROOT/scripts/install.sh" "$TARGET" >/dev/null 2>&1
grep -q "CUSTOM" "$TARGET/AGENTS.md" && ok "已存在文件未被覆盖" || bad "已存在文件被误覆盖"

section "5. --force 覆盖模板文件，但不得破坏 PROJECT_STATE.json"
# 先在状态文件里写入一份"用户进度"，再执行 -f，验证状态文件逐字节不变
python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
p = sys.argv[1]
with open(p, encoding="utf-8") as f:
    d = json.load(f)
d["current_stage"] = "design"
d["stages"]["discovery"]["status"] = "done"
d["stages"]["discovery"]["completed_at"] = "2026-01-01"
for it in d["stages"]["discovery"]["checklist"]:
    it["done"] = True
with open(p, "w", encoding="utf-8") as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
PY
cp "$TARGET/PROJECT_STATE.json" "$WORK/state-with-progress.json"
bash "$REPO_ROOT/scripts/install.sh" "$TARGET" -f >/dev/null 2>&1
grep -q "CUSTOM" "$TARGET/AGENTS.md" && bad "--force 未生效" || ok "--force 成功覆盖模板文件 AGENTS.md"
if cmp -s "$WORK/state-with-progress.json" "$TARGET/PROJECT_STATE.json"; then
  ok "--force 未改动 PROJECT_STATE.json（逐字节一致，进度完整保留）"
else
  bad "--force 改动了 PROJECT_STATE.json"
  diff "$WORK/state-with-progress.json" "$TARGET/PROJECT_STATE.json" | head -n 10
fi

section "6. 全局安装（模拟 HOME）"
FAKE_HOME="$WORK/home"
mkdir -p "$FAKE_HOME"
HOME="$FAKE_HOME" bash "$REPO_ROOT/scripts/setup-global.sh" >/dev/null 2>&1
GDEST="$FAKE_HOME/.trae/templates/project-workflow"
assert_file "全局载荷 AGENTS.md" "$GDEST/AGENTS.md"
assert_file "全局安装器 install.sh" "$GDEST/install.sh"
assert_file "全局升级脚本 upgrade.sh" "$GDEST/upgrade.sh"
assert_file "全局命令 init-project.md" "$FAKE_HOME/.trae/commands/init-project.md"
assert_file "全局命令 status.md" "$FAKE_HOME/.trae/commands/status.md"
assert_file "全局命令 advance.md" "$FAKE_HOME/.trae/commands/advance.md"
assert_file "全局命令 upgrade.md" "$FAKE_HOME/.trae/commands/upgrade.md"

section "7. 全局安装器可独立工作（路径自适应）"
TARGET2="$WORK/from-global"
bash "$GDEST/install.sh" "$TARGET2" >/dev/null 2>&1
assert_file "从全局安装器安装成功" "$TARGET2/PROJECT_STATE.json"
assert_file "从全局安装器安装命令" "$TARGET2/.trae/commands/advance.md"

section "8. 全局命令引用的路径真实存在"
REF_PATH="$FAKE_HOME/.trae/templates/project-workflow/install.sh"
[[ -f "$REF_PATH" ]] && ok "命令引用的安装器存在: $REF_PATH" || bad "命令引用的安装器不存在"
REF_UP="$FAKE_HOME/.trae/templates/project-workflow/upgrade.sh"
[[ -f "$REF_UP" ]] && ok "命令引用的升级脚本存在: $REF_UP" || bad "命令引用的升级脚本不存在"

section "9. 全局卸载"
HOME="$FAKE_HOME" bash "$REPO_ROOT/scripts/setup-global.sh" --uninstall >/dev/null 2>&1
[[ ! -f "$FAKE_HOME/.trae/commands/init-project.md" ]] && ok "全局命令已卸载" || bad "全局命令未卸载"
[[ -d "$GDEST" ]] && ok "全局载荷保留" || bad "全局载荷被误删"

# ---------- 升级工具测试夹具 ----------
# 造一个"新版载荷"：版本 0.9.9，且 AGENTS.md 内容相对当前载荷发生变化
UP_PAYLOAD="$WORK/upgrade-payload"
UP_PROJ="$WORK/upgrade-proj"
cp -R "$REPO_ROOT/template" "$UP_PAYLOAD"
cp "$REPO_ROOT/scripts/upgrade.sh" "$UP_PAYLOAD/upgrade.sh"
python3 - "$UP_PAYLOAD" <<'PY'
import hashlib, json, os, sys
payload = sys.argv[1]
with open(os.path.join(payload, "AGENTS.md"), "a", encoding="utf-8") as f:
    f.write("\n<!-- added in 0.9.9 -->\n")
mp = os.path.join(payload, ".trae", "template-manifest.json")
with open(mp, encoding="utf-8") as f:
    m = json.load(f)
m["template_version"] = "0.9.9"
for item in m["files"]:
    with open(os.path.join(payload, item["path"]), "rb") as f:
        item["sha256"] = hashlib.sha256(f.read()).hexdigest()
with open(mp, "w", encoding="utf-8") as f:
    json.dump(m, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
bash "$REPO_ROOT/scripts/install.sh" "$UP_PROJ" -n up-test >/dev/null 2>&1
# 在项目侧制造三种状态：被用户改过 / 缺失 / 未改动
printf '\n<!-- 用户自定义 -->\n' >> "$UP_PROJ/.trae/hooks.json"
rm -f "$UP_PROJ/00-discovery/README.md"

section "10. 升级工具：预览只读且判定准确"
UP_OUT="$(bash "$UP_PAYLOAD/upgrade.sh" "$UP_PROJ" 2>&1)"; UP_RC=$?
echo "$UP_OUT" | grep -q "~ AGENTS.md" && ok "未改动的 AGENTS.md 判为「覆盖」" || bad "AGENTS.md 未判为覆盖"
echo "$UP_OUT" | grep -q "! .trae/hooks.json" && ok "被改过的 hooks.json 判为「待合并」" || bad "hooks.json 未判为待合并"
echo "$UP_OUT" | grep -q "+ 00-discovery/README.md" && ok "缺失文件判为「恢复」" || bad "缺失文件未判为恢复"
echo "$UP_OUT" | grep -q "= PROJECT_STATE.json" && ok "状态文件判为「不动」（用户数据）" || bad "状态文件未判为不动"
[[ "$UP_RC" -eq 1 ]] && ok "预览发现差异时退出码为 1" || bad "退出码异常: $UP_RC"
grep -q "added in 0.9.9" "$UP_PROJ/AGENTS.md" && bad "预览竟写入了文件" || ok "预览未写入任何文件"
[[ -f "$UP_PROJ/00-discovery/README.md" ]] && bad "预览竟恢复了文件" || ok "预览未恢复文件"

section "11. 升级工具：--apply 落盘、推进基线、保留进度与用户数据"
python3 - "$UP_PROJ/PROJECT_STATE.json" <<'PY'
import json, sys
p = sys.argv[1]
with open(p, encoding="utf-8") as f:
    d = json.load(f)
d["current_stage"] = "development"
for it in d["stages"]["discovery"]["checklist"]:
    it["done"] = True
with open(p, "w", encoding="utf-8") as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
PY
bash "$UP_PAYLOAD/upgrade.sh" "$UP_PROJ" --apply >/dev/null 2>&1; UP_RC=$?
grep -q "added in 0.9.9" "$UP_PROJ/AGENTS.md" && ok "未改动的文件已更新为新版" || bad "文件未更新"
[[ -f "$UP_PROJ/00-discovery/README.md" ]] && ok "缺失文件已恢复" || bad "缺失文件未恢复"
grep -q "用户自定义" "$UP_PROJ/.trae/hooks.json" && ok "用户改过的文件未被覆盖" || bad "用户改动被覆盖了"
[[ "$UP_RC" -eq 1 ]] && ok "仍有待合并项时退出码为 1" || bad "退出码异常: $UP_RC"
if python3 - "$UP_PROJ/.trae/template-manifest.json" "$UP_PROJ/PROJECT_STATE.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    m = json.load(f)
with open(sys.argv[2], encoding="utf-8") as f:
    s = json.load(f)
dis = s["stages"]["discovery"]
ok = (m["template_version"] == "0.9.9"
      and s.get("template_version") == "0.9.9"
      and s.get("current_stage") == "development"
      and all(i["done"] for i in dis["checklist"]))
if not ok:
    print(f"基线={m['template_version']} 状态版本={s.get('template_version')} "
          f"阶段={s.get('current_stage')} 勾选={[i['done'] for i in dis['checklist']]}")
sys.exit(0 if ok else 1)
PY
then
  ok "基线推进至 0.9.9，且 PROJECT_STATE.json 进度完好（仅字段级更新）"
else
  bad "基线或进度异常"
fi

section "12. 升级工具：版本相同时短路，不重复提示用户改动"
UP_OUT="$(bash "$UP_PAYLOAD/upgrade.sh" "$UP_PROJ" 2>&1)"; UP_RC=$?
echo "$UP_OUT" | grep -q "已是最新（0.9.9）" && ok "报「已是最新」并短路" || bad "未短路"
[[ "$UP_RC" -eq 0 ]] && ok "退出码 0" || bad "退出码异常: $UP_RC"
echo "$UP_OUT" | grep -q "待合并" && bad "不应再重复提示用户改动" || ok "不再重复提示用户改动（符合规格 §5）"

section "13. 升级工具：--force 在版本跃迁中备份后覆盖"
# --force 只在版本跃迁期间有意义：版本一致时会被 §5 短路，故这里再升一版
UP_PAYLOAD2="$WORK/upgrade-payload2"
cp -R "$UP_PAYLOAD" "$UP_PAYLOAD2"
python3 - "$UP_PAYLOAD2" <<'PY'
import json, os, sys
mp = os.path.join(sys.argv[1], ".trae", "template-manifest.json")
with open(mp, encoding="utf-8") as f:
    m = json.load(f)
m["template_version"] = "0.9.10"
with open(mp, "w", encoding="utf-8") as f:
    json.dump(m, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
bash "$UP_PAYLOAD2/upgrade.sh" "$UP_PROJ" --apply --force >/dev/null 2>&1; UP_RC=$?
[[ "$UP_RC" -eq 0 ]] && ok "--force 处理后无待合并项，退出码 0" || bad "退出码异常: $UP_RC"
cmp -s "$UP_PROJ/.trae/hooks.json" "$UP_PAYLOAD2/.trae/hooks.json" && ok "被改过的文件已覆盖为载荷版本" || bad "未被覆盖"
grep -q "用户自定义" "$UP_PROJ/.trae/hooks.json.bak" && ok "覆盖前已备份 .bak 且保留用户改动" || bad ".bak 缺失或内容不对"
python3 -c "
import json,sys
d=json.load(open('$UP_PROJ/PROJECT_STATE.json',encoding='utf-8'))
sys.exit(0 if d.get('template_version')=='0.9.10' else 1)" \
  && ok "项目版本推进至 0.9.10" || bad "项目版本未推进"

section "14. 升级工具：缺少基线清单的老项目"
OLD_PROJ="$WORK/old-proj"
bash "$REPO_ROOT/scripts/install.sh" "$OLD_PROJ" -n old >/dev/null 2>&1
rm -f "$OLD_PROJ/.trae/template-manifest.json"
UP_OUT="$(bash "$UP_PAYLOAD/upgrade.sh" "$OLD_PROJ" 2>&1)"; UP_RC=$?
echo "$UP_OUT" | grep -q "缺少基线清单" && ok "报告说明了缺少基线的原因" || bad "未提示缺少基线"
echo "$UP_OUT" | grep -q "! AGENTS.md" && ok "已存在文件一律判为「待合并」" || bad "未按待合并处理"
[[ "$UP_RC" -eq 1 ]] && ok "退出码为 1" || bad "退出码异常: $UP_RC"
bash "$UP_PAYLOAD/upgrade.sh" "$OLD_PROJ" --apply --force >/dev/null 2>&1
[[ -f "$OLD_PROJ/.trae/template-manifest.json" ]] && ok "首次 --force 升级后已建立基线" || bad "基线未建立"
bash "$UP_PAYLOAD/upgrade.sh" "$OLD_PROJ" >/dev/null 2>&1 && ok "建立基线后恢复精确判定（已是最新）" || bad "基线建立后仍无法判定"

section "15. 升级工具：目标目录不像模板项目时拒绝（F2）"
NOT_PROJ="$WORK/not-a-project"
mkdir -p "$NOT_PROJ"
UP_OUT="$(bash "$UP_PAYLOAD/upgrade.sh" "$NOT_PROJ" 2>&1)"; UP_RC=$?
[[ "$UP_RC" -eq 2 ]] && ok "非项目目录退出码为 2" || bad "退出码异常: $UP_RC"
echo "$UP_OUT" | grep -q "不像模板项目" && ok "报告说明该目录不像模板项目" || bad "未给出拒绝原因"
[[ -z "$(ls -A "$NOT_PROJ")" ]] && ok "被拒绝时未向该目录写入任何文件" || bad "被拒绝却写入了文件"
bash "$UP_PAYLOAD/upgrade.sh" "$NOT_PROJ" --apply >/dev/null 2>&1; UP_RC=$?
[[ "$UP_RC" -eq 2 && -z "$(ls -A "$NOT_PROJ")" ]] && ok "--apply 同样被拒绝且未落盘" || bad "--apply 未被拒绝: rc=$UP_RC"
bash "$UP_PAYLOAD/upgrade.sh" "$NOT_PROJ" --force >/dev/null 2>&1; UP_RC=$?
[[ "$UP_RC" -eq 1 ]] && ok "显式加 --force 可放行（不再报错 2）" || bad "--force 未放行: rc=$UP_RC"
UP_OUT="$(bash "$UP_PAYLOAD/upgrade.sh" "$UP_PROJ" 2>&1)"
echo "$UP_OUT" | grep -q "不像模板项目" && bad "正常项目被误判为非项目" || ok "正常项目不受影响（门禁无误伤）"

section "16. Go/No-Go 判定字段（discovery.decision）"
# 判定字段属于调研阶段；前面的用例把 current_stage 改到了别的阶段，这里先归位
python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["current_stage"] = "discovery"
d["project_status"] = "active"
d["stages"]["discovery"]["decision"] = "pending"
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
DEC=$(python3 -c "import json;print(json.load(open('$TARGET/PROJECT_STATE.json',encoding='utf-8'))['stages']['discovery'].get('decision'))")
[[ "$DEC" == "pending" ]] && ok "新装项目 discovery.decision 初始为 pending" || bad "初始值异常: $DEC"
OUT_D=$(TRAE_PROJECT_DIR="$TARGET" python3 "$TARGET/.trae/scripts/inject_status.py" 2>&1 || true)
echo "$OUT_D" | grep -q "Go/No-Go 判定: 未判定" && ok "Hook 展示「未判定」" || bad "Hook 未展示判定: ${OUT_D}"
python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["stages"]["discovery"]["decision"] = "no-go"
d["project_status"] = "rejected"
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
OUT_D2=$(TRAE_PROJECT_DIR="$TARGET" python3 "$TARGET/.trae/scripts/inject_status.py" 2>&1 || true)
echo "$OUT_D2" | grep -q "Go/No-Go 判定: No-Go" && ok "Hook 展示「No-Go」" || bad "Hook 未展示 No-Go: ${OUT_D2}"
echo "$OUT_D2" | grep -q "已否决" && ok "No-Go 时项目状态渲染为已否决" || bad "No-Go 状态未渲染"
python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["stages"]["discovery"].pop("decision", None)
d["project_status"] = "active"
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
OUT_D3=$(TRAE_PROJECT_DIR="$TARGET" python3 "$TARGET/.trae/scripts/inject_status.py" 2>&1 || true)
echo "$OUT_D3" | grep -q "当前阶段" && ok "缺 decision 字段时 Hook 仍正常（向后兼容）" || bad "缺字段导致 Hook 异常: ${OUT_D3}"
echo "$OUT_D3" | grep -q "Go/No-Go 判定" && bad "缺字段时仍输出判定行" || ok "缺字段时不输出判定行"
python3 - "$TARGET/PROJECT_STATE.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["stages"]["discovery"]["decision"] = "pending"
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY

echo
echo "========================================"
echo "  测试结果: 通过 $PASS 项，失败 $FAIL 项"
echo "========================================"
if [[ $FAIL -gt 0 ]]; then
  echo "❌ 测试未通过。"
  exit 1
fi
echo "✅ 全部通过。"
