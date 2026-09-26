#!/usr/bin/env bash
# 构建分发产物到 dist/：
#   - bootstrap.sh                       自包含安装脚本（内嵌 template/ 载荷）
#   - project-workflow-template.tar.gz   整仓库压缩包
#   - project-workflow-template.zip      整仓库压缩包
#
# 产物内容以 git 跟踪文件为唯一来源（git ls-files）：未跟踪文件（如 .DS_Store、
# __pycache__）不会被打进产物，本地构建与 CI 构建结果一致。
#
# 注意：新增文件需先 git add 才会进入产物。
#
# 用法:
#   bash scripts/build-dist.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$REPO_ROOT/template"
DIST="$REPO_ROOT/dist"

if ! git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "[错误] $REPO_ROOT 不是 git 仓库，无法确定应打包的跟踪文件。" >&2
  exit 1
fi

rm -rf "$DIST"
mkdir -p "$DIST"

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

TRACKED_NUL="$WORK/tracked.nul"
TRACKED_TXT="$WORK/tracked.txt"
git -C "$REPO_ROOT" ls-files -z > "$TRACKED_NUL"
git -C "$REPO_ROOT" ls-files | LC_ALL=C sort > "$TRACKED_TXT"

# ---------- 1. bootstrap.sh（内嵌载荷） ----------
python3 - "$REPO_ROOT" "$TEMPLATE" "$DIST/bootstrap.sh" "$TRACKED_NUL" <<'PY'
import base64, os, sys

repo_root, template, out, tracked = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
prefix = os.path.relpath(template, repo_root).replace(os.sep, "/") + "/"

with open(tracked, "rb") as fh:
    names = [n for n in fh.read().decode("utf-8").split("\0") if n]

files = sorted(n[len(prefix):] for n in names if n.startswith(prefix))

lines = [
    "#!/usr/bin/env bash",
    "# 四阶段项目工作流模板 - 自包含安装脚本（内嵌 template/ 载荷）",
    "# 用法: bash bootstrap.sh [目标目录]   (默认当前目录)",
    "set -euo pipefail",
    'TARGET_DIR="${1:-.}"',
    'mkdir -p "$TARGET_DIR"',
    'cd "$TARGET_DIR"',
    'echo "==> 安装到: $(pwd)"',
    "",
]
for rel in files:
    with open(os.path.join(template, rel), "rb") as fh:
        b64 = base64.b64encode(fh.read()).decode()
    lines.append(f'echo "    写入 {rel}"')
    lines.append(f'mkdir -p "$(dirname \'{rel}\')"')
    lines.append(f"base64 -d > '{rel}' <<'B64EOF'")
    for i in range(0, len(b64), 76):
        lines.append(b64[i:i+76])
    lines.append("B64EOF")
    lines.append("")
lines.append('chmod +x .trae/scripts/inject_status.py 2>/dev/null || true')
lines.append('echo "==> 完成！可用命令: /init-project  /status  /advance"')

with open(out, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
os.chmod(out, 0o755)
print(f"bootstrap.sh 生成完成，内嵌 {len(files)} 个载荷文件")
PY

# ---------- 2. 压缩包（仅跟踪文件） ----------
echo "打包 tar.gz ..."
tar -czf "$DIST/project-workflow-template.tar.gz" -C "$REPO_ROOT" --null -T "$TRACKED_NUL"

HAVE_ZIP=0
if command -v zip >/dev/null 2>&1; then
  echo "打包 zip ..."
  (cd "$REPO_ROOT" && zip -q "$DIST/project-workflow-template.zip" -@) < "$TRACKED_TXT"
  HAVE_ZIP=1
else
  echo "[提示] 未找到 zip 命令，仅生成 tar.gz"
fi

# ---------- 3. 自检：产物条目必须与 git 跟踪文件完全一致 ----------
check_entries() {
  local label="$1" actual="$2"
  if diff -q "$TRACKED_TXT" "$actual" >/dev/null; then
    echo "  ✅ $label 与跟踪文件一致（$(wc -l < "$TRACKED_TXT" | tr -d ' ') 个文件）"
  else
    echo "[错误] $label 内容与 git 跟踪文件不一致：" >&2
    diff "$TRACKED_TXT" "$actual" >&2 || true
    exit 1
  fi
}

tar -tzf "$DIST/project-workflow-template.tar.gz" | LC_ALL=C sort > "$WORK/tar.actual"
check_entries "tar.gz" "$WORK/tar.actual"
if [[ $HAVE_ZIP -eq 1 ]] && command -v unzip >/dev/null 2>&1; then
  unzip -Z1 "$DIST/project-workflow-template.zip" | LC_ALL=C sort > "$WORK/zip.actual"
  check_entries "zip" "$WORK/zip.actual"
fi

echo
echo "==> 分发产物:"
ls -lh "$DIST" | awk 'NR>1 {print "    " $5, $NF}'
