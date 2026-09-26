#!/usr/bin/env bash
# 把已建项目里的模板文件升级到新版本。
#
# 判定依据是两份模板清单的逐文件 sha256：项目内的基线清单（判断「是否被用户改过」）
# 与载荷清单（判断「是否已是最新」）。接口契约见 docs/specs/upgrade-tool.md。
#
# 用法:
#   bash upgrade.sh [目标目录] [选项]      # 目标目录默认当前目录
#
# 选项:
#   --apply    按预览结果落盘（默认只读，不写任何文件）
#   --force    连「被改过」的模板文件也覆盖；覆盖前备份为 <文件>.bak
#   -h, --help 显示帮助
#
# 设计要点:
#   - 默认只读，且永不交互（同时供人与 AI 通过 /upgrade 调用）
#   - 默认行为永远不会丢失用户内容
#   - 路径自适应载荷：仓库内 -> ../template；全局模板目录内 -> 同级目录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -d "$SCRIPT_DIR/../template" ]]; then
  PAYLOAD="$(cd "$SCRIPT_DIR/../template" && pwd)"
elif [[ -f "$SCRIPT_DIR/PROJECT_STATE.json" ]]; then
  PAYLOAD="$SCRIPT_DIR"
else
  echo "错误: 未找到模板载荷（template/ 或同级 PROJECT_STATE.json）。" >&2
  exit 2
fi

TARGET_DIR=""
APPLY=0
FORCE=0

if ! command -v python3 >/dev/null 2>&1; then
  echo "错误: 需要 python3 以解析模板清单。" >&2
  exit 2
fi

usage() {
  sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage ;;
    -*) echo "未知选项: $1" >&2; exit 2 ;;
    *) TARGET_DIR="$1"; shift ;;
  esac
done

if [[ -z "$TARGET_DIR" ]]; then
  TARGET_DIR="."
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "错误: 目标目录不存在: $TARGET_DIR" >&2
  exit 2
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

rc=0
python3 - "$PAYLOAD" "$TARGET_DIR" "$APPLY" "$FORCE" <<'PY' || rc=$?
import hashlib
import json
import os
import shutil
import sys

payload, project, apply_flag, force_flag = sys.argv[1:5]
do_apply = apply_flag == "1"
force = force_flag == "1"

MANIFEST_REL = ".trae/template-manifest.json"
STATE_REL = "PROJECT_STATE.json"
SCHEMA_VERSION = 1


def die(msg):
    print("[错误] " + msg, file=sys.stderr)
    sys.exit(2)


payload_manifest_path = os.path.join(payload, MANIFEST_REL)
if not os.path.isfile(payload_manifest_path):
    die("载荷缺少模板清单 " + MANIFEST_REL)
try:
    with open(payload_manifest_path, encoding="utf-8") as f:
        new = json.load(f)
except Exception as exc:  # noqa: BLE001
    die("载荷清单解析失败: " + str(exc))

if new.get("schema_version") != SCHEMA_VERSION:
    die(
        "不支持的清单 schema_version: "
        + repr(new.get("schema_version"))
        + "（本工具仅支持 "
        + str(SCHEMA_VERSION)
        + "）"
    )

new_version = new.get("template_version", "") or "未知"
new_files = {item["path"]: item for item in new.get("files", [])}

# 项目内基线清单：用于判断「是否被用户改过」。缺失时为 None（老项目）
project_manifest_path = os.path.join(project, MANIFEST_REL)
base = None
if os.path.isfile(project_manifest_path):
    try:
        with open(project_manifest_path, encoding="utf-8") as f:
            base = json.load(f)
    except Exception:  # noqa: BLE001
        base = None
base_files = (
    {item["path"]: item.get("sha256") for item in base.get("files", [])}
    if base is not None
    else {}
)
base_version = base.get("template_version") if base is not None else None

state_path = os.path.join(project, STATE_REL)
project_version = None
if os.path.isfile(state_path):
    try:
        with open(state_path, encoding="utf-8") as f:
            project_version = json.load(f).get("template_version")
    except Exception:  # noqa: BLE001
        project_version = None


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def advance_baseline():
    """推进基线：替换项目内清单，并字段级更新 PROJECT_STATE.json 的版本号。"""
    os.makedirs(os.path.join(project, os.path.dirname(MANIFEST_REL)), exist_ok=True)
    shutil.copy2(payload_manifest_path, project_manifest_path)
    if not os.path.isfile(state_path):
        return
    try:
        with open(state_path, encoding="utf-8") as fh:
            state = json.load(fh)
        if state.get("template_version") != new_version:
            state["template_version"] = new_version
            with open(state_path, "w", encoding="utf-8") as fh:
                json.dump(state, fh, ensure_ascii=False, indent=2)
                fh.write("\n")
    except Exception:  # noqa: BLE001
        print("  [警告] PROJECT_STATE.json 解析失败，未更新 template_version")


# 版本相同即视为已是最新，不再逐文件扫描（规格 §5）。
# 若无此短路，用户改过的文件会被每次报成「待合并」，退出码恒为 1 而失去意义。
if base is not None and base_version == new_version:
    print("==> 项目: " + project)
    print("==> 项目模板版本: " + (project_version or base_version or "未知"))
    print("==> 模板版本:     " + new_version)
    print()
    print("  已是最新（" + new_version + "），无需升级。")
    sys.exit(0)


overwrite, restore, merge, keep, unchanged = [], [], [], [], []

for rel in sorted(new_files):
    item = new_files[rel]
    if item.get("mode", "manage") == "create-only":
        keep.append(rel)
        continue
    dst = os.path.join(project, rel)
    if not os.path.isfile(dst):
        restore.append(rel)
        continue
    actual = sha256_file(dst)
    if actual == item.get("sha256"):
        unchanged.append(rel)
        continue
    if base is not None and base_files.get(rel) == actual:
        overwrite.append(rel)
        continue
    merge.append(rel)

# ---------- 报告 ----------
print("==> 项目: " + project)
print("==> 项目模板版本: " + (project_version or base_version or "未知"))
print("==> 模板版本:     " + new_version)
print("==> 模式: " + ("落盘（--apply" + (" --force）" if force else "）") if do_apply else "只读预览（未写入任何文件）"))
print()

if base is None:
    print("  注意: 项目内缺少基线清单（" + MANIFEST_REL + "），无法判定文件是否被改动，")
    print("        故已存在的模板文件一律视为「被改过」。如需覆盖请显式使用 --force；")
    print("        首次升级成功后即建立基线，后续判定恢复精确。")
    print()


def section(label, desc, items, mark, count_only=False):
    if not items:
        return
    suffix = "（" + desc + "）" if desc else ""
    print("  " + label + " " + str(len(items)) + " 个" + suffix)
    if not count_only:
        for rel in items:
            print("    " + mark + " " + rel)


section("覆盖", "模板文件未被改动", overwrite, "~")
section("恢复", "模板文件缺失", restore, "+")
section("待合并", "你改过，默认不覆盖", merge, "!")
section("不动", "用户数据", keep, "=")
section("未变更", "", unchanged, "", count_only=True)

pending = overwrite + restore + merge

# ---------- 落盘 ----------
if do_apply and pending:
    print()
    for rel in overwrite + restore:
        src, dst = os.path.join(payload, rel), os.path.join(project, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
    backed_up = []
    if force:
        for rel in merge:
            src, dst = os.path.join(payload, rel), os.path.join(project, rel)
            shutil.copy2(dst, dst + ".bak")
            shutil.copy2(src, dst)
            backed_up.append(rel + ".bak")
    # 推进基线：替换项目内清单并做字段级版本更新
    advance_baseline()

    print("  已落盘: 覆盖 " + str(len(overwrite)) + " 个，恢复 " + str(len(restore)) + " 个"
          + ("，备份并覆盖 " + str(len(backed_up)) + " 个（.bak）" if backed_up else ""))
    print("  基线已推进至 " + new_version)

remaining_merge = merge if not force else []
if do_apply and remaining_merge:
    print()
    print("  " + str(len(remaining_merge)) + " 个文件仍需人工处理（默认不改动）:")
    for rel in remaining_merge:
        print("    ! " + rel)
    print("  可对照全局模板目录手工合并；或改用 --apply --force（会先备份为 .bak）。")

if not pending:
    # 版本不同但文件已全部一致（例如用户手工同步过）：落盘时让基线收敛
    if do_apply:
        advance_baseline()
    print()
    print("  无需升级：项目已与模板 " + new_version + " 一致。")
    sys.exit(0)

if not do_apply:
    print()
    print("  下一步: bash upgrade.sh --apply")
    if merge:
        print("  需要连「待合并」的文件一起覆盖时: bash upgrade.sh --apply --force")

sys.exit(1 if remaining_merge else 0)
PY

exit $rc
