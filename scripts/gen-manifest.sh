#!/usr/bin/env bash
# 生成模板清单 template/.trae/template-manifest.json。
#
# 清单是「哪些文件属于模板」的唯一边界声明源，也是升级时判断「文件是否被用户
# 改过」的基线。规格见 docs/specs/template-manifest.md。
#
# 版本号来源: 仓库根的 VERSION 文件（单一数据源）。
#
# 用法:
#   bash scripts/gen-manifest.sh           # 刷新版本并重新生成清单
#   bash scripts/gen-manifest.sh --check   # 仅校验清单与载荷是否一致，不写任何文件

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CHECK=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK=1
elif [[ -n "${1:-}" ]]; then
  echo "未知选项: $1（仅支持 --check）" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "[错误] 需要 python3。" >&2
  exit 1
fi

python3 - "$REPO_ROOT" "$CHECK" <<'PY'
import hashlib
import json
import os
import subprocess
import sys

repo_root = sys.argv[1]
check = sys.argv[2] == "1"

TEMPLATE = os.path.join(repo_root, "template")
MANIFEST_REL = ".trae/template-manifest.json"
MANIFEST = os.path.join(TEMPLATE, MANIFEST_REL)
STATE_REL = "PROJECT_STATE.json"
VERSION_FILE = os.path.join(repo_root, "VERSION")
TEMPLATE_NAME = "project-workflow-template"
SCHEMA_VERSION = 1

# 承载用户数据的文件：永不覆盖，仅首次写入
CREATE_ONLY = {STATE_REL}


def fail(messages):
    for m in messages:
        print("  ❌ " + m)
    sys.exit(1)


if not os.path.isfile(VERSION_FILE):
    fail([f"缺少版本文件: {os.path.relpath(VERSION_FILE, repo_root)}"])

with open(VERSION_FILE, encoding="utf-8") as f:
    version = f.read().strip()

if not version:
    fail(["VERSION 文件为空"])


def tracked_template_files():
    """以 git 跟踪文件为准（与 build-dist.sh 的技术选择一致），排除清单自身。"""
    raw = subprocess.check_output(
        ["git", "-C", repo_root, "ls-files", "-z", "--", "template"]
    )
    out = []
    for p in raw.decode("utf-8").split("\0"):
        if not p:
            continue
        rel = p[len("template/"):]
        if rel == MANIFEST_REL:
            continue  # 清单不记录自身
        out.append(rel)
    return sorted(out)


def sha256_of(rel):
    with open(os.path.join(TEMPLATE, rel), "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


# ---------- 校验模式 ----------
if check:
    errors = []
    manifest = None
    if not os.path.isfile(MANIFEST):
        errors.append(f"清单不存在: {MANIFEST_REL}（请运行 bash scripts/gen-manifest.sh）")
    else:
        with open(MANIFEST, encoding="utf-8") as f:
            manifest = json.load(f)

    state_path = os.path.join(TEMPLATE, STATE_REL)
    if not os.path.isfile(state_path):
        errors.append(f"缺少 {STATE_REL}")
    else:
        with open(state_path, encoding="utf-8") as f:
            state = json.load(f)
        if state.get("template_version") != version:
            errors.append(
                f"template/{STATE_REL} 的 template_version="
                f"{state.get('template_version')!r} 与 VERSION={version!r} 不一致"
            )

    if manifest is not None:
        if manifest.get("template_version") != version:
            errors.append(
                f"清单 template_version={manifest.get('template_version')!r} "
                f"与 VERSION={version!r} 不一致"
            )
        if manifest.get("schema_version") != SCHEMA_VERSION:
            errors.append(
                f"清单 schema_version={manifest.get('schema_version')!r} "
                f"与预期 {SCHEMA_VERSION} 不一致"
            )
        want = tracked_template_files()
        got = sorted(item.get("path", "") for item in manifest.get("files", []))
        missing = sorted(set(want) - set(got))
        extra = sorted(set(got) - set(want))
        if missing:
            errors.append(f"清单缺少文件: {missing}")
        if extra:
            errors.append(f"清单含多余文件: {extra}")
        for item in manifest.get("files", []):
            rel = item.get("path", "")
            if not os.path.isfile(os.path.join(TEMPLATE, rel)):
                errors.append(f"清单所列文件不存在: {rel}")
                continue
            if sha256_of(rel) != item.get("sha256"):
                errors.append(f"sha256 与载荷不一致: {rel}")

    if errors:
        fail(errors)
    print(f"  ✅ 清单与载荷一致（{len(manifest.get('files', []))} 个文件，版本 {version}）")
    sys.exit(0)

# ---------- 生成模式 ----------
state_path = os.path.join(TEMPLATE, STATE_REL)
with open(state_path, encoding="utf-8") as f:
    state = json.load(f)
if state.get("template_version") != version:
    state["template_version"] = version
    with open(state_path, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"已同步 template/{STATE_REL} 的 template_version = {version}")

files = []
for rel in tracked_template_files():
    item = {"path": rel, "sha256": sha256_of(rel)}
    if rel in CREATE_ONLY:
        item["mode"] = "create-only"
    files.append(item)

manifest = {
    "schema_version": SCHEMA_VERSION,
    "template_name": TEMPLATE_NAME,
    "template_version": version,
    "files": files,
}

os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
with open(MANIFEST, "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(f"清单已生成: {MANIFEST_REL}（{len(files)} 个文件，版本 {version}）")
PY
