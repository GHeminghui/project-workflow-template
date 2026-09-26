#!/usr/bin/env bash
# 创建/同步本仓库用于 Release notes 归类的 PR 标签。
#
# 标签清单与 .github/release.yml 的分类一一对应，约定见 CONTRIBUTING.md「PR 与标签」。
# 可重复执行：已存在的标签会被更新为这里的颜色与描述，误删后可一键恢复。
#
# 依赖 GitHub CLI（gh，https://cli.github.com/），需先完成 gh auth login。
#
# 用法:
#   bash scripts/setup-labels.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v gh >/dev/null 2>&1; then
  echo "[错误] 未找到 gh（GitHub CLI）。请先安装并执行 gh auth login。" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "[错误] gh 尚未登录，请先执行 gh auth login。" >&2
  exit 1
fi

# 名称|颜色|描述
labels=(
  "feat|0e8a16|新增能力"
  "fix|d73a4a|修复问题"
  "refactor|fbca04|结构调整"
  "test|5319e7|测试相关"
  "docs|0075ca|文档改动"
  "chore|cfd3d7|杂项"
  "breaking|b60205|存在破坏性变更"
  "skip-changelog|ffffff|不纳入 release notes"
)

echo "同步 PR 标签到：$(git remote get-url origin 2>/dev/null || echo '当前仓库')"
echo

ok=0
fail=0
for entry in "${labels[@]}"; do
  IFS='|' read -r name color desc <<< "$entry"
  if err=$(gh label create "$name" --color "$color" --description "$desc" --force 2>&1); then
    echo "  ✅ $name"
    ok=$((ok + 1))
  else
    echo "  ❌ $name" >&2
    echo "     $err" >&2
    fail=$((fail + 1))
  fi
done

echo
echo "标签同步完成：成功 $ok 个，失败 $fail 个"
if [[ $fail -gt 0 ]]; then
  echo "❌ 存在失败项，请检查 gh 登录状态与仓库权限。" >&2
  exit 1
fi
echo "✅ 全部就绪，Release notes 归类已可用。"
