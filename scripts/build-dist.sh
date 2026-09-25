#!/usr/bin/env bash
# 构建分发产物到 dist/：
#   - bootstrap.sh                       自包含安装脚本（内嵌 template/ 载荷）
#   - project-workflow-template.tar.gz   整仓库压缩包
#   - project-workflow-template.zip      整仓库压缩包
#
# 用法:
#   bash scripts/build-dist.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$REPO_ROOT/template"
DIST="$REPO_ROOT/dist"

rm -rf "$DIST"
mkdir -p "$DIST"

# ---------- 1. bootstrap.sh（内嵌载荷） ----------
python3 - "$TEMPLATE" "$DIST/bootstrap.sh" <<'PY'
import base64, os, sys

template, out = sys.argv[1], sys.argv[2]
files = []
for dirpath, dirnames, filenames in os.walk(template):
    dirnames[:] = [d for d in dirnames if d not in (".git",)]
    for fn in filenames:
        rel = os.path.relpath(os.path.join(dirpath, fn), template)
        files.append(rel)
files.sort()

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
    with open(os.path.join(template, rel), "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    lines.append(f'echo "    写入 {rel}"')
    lines.append(f'mkdir -p "$(dirname \'{rel}\')"')
    lines.append(f"base64 -d > '{rel}' <<'B64EOF'")
    for i in range(0, len(b64), 76):
        lines.append(b64[i:i+76])
    lines.append("B64EOF")
    lines.append("")
lines.append('chmod +x .trae/scripts/inject_status.py 2>/dev/null || true')
lines.append('echo "==> 完成！可用命令: /init-project  /status  /advance"')

with open(out, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
os.chmod(out, 0o755)
print(f"bootstrap.sh 生成完成，内嵌 {len(files)} 个载荷文件")
PY

# ---------- 2. 压缩包 ----------
echo "打包 tar.gz ..."
tar -czf "$DIST/project-workflow-template.tar.gz" \
    --exclude='./.git' --exclude='./dist' \
    -C "$REPO_ROOT" .

if command -v zip >/dev/null 2>&1; then
  echo "打包 zip ..."
  (cd "$REPO_ROOT" && zip -qr "$DIST/project-workflow-template.zip" . -x '.git/*' 'dist/*')
else
  echo "[提示] 未找到 zip 命令，仅生成 tar.gz"
fi

echo
echo "==> 分发产物:"
ls -lh "$DIST" | awk 'NR>1 {print "    " $5, $NF}'
