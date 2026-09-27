#!/usr/bin/env bash
# 全局安装：让四阶段工作流模板与斜杠命令对所有项目可用。
#
# 安装内容:
#   1. 载荷 + 安装器 -> ~/.trae/templates/project-workflow/
#   2. 全局命令      -> ~/.trae/commands/  (载荷 .trae/commands/ 下的全部命令)
#
# 用法:
#   bash scripts/setup-global.sh               # 安装
#   bash scripts/setup-global.sh --uninstall   # 卸载全局命令（保留载荷）
#
# 自定义 TRAE 配置目录（例如 ~/.trae-cn）:
#   TRAE_HOME="$HOME/.trae-cn" bash scripts/setup-global.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -d "$SCRIPT_DIR/../template" ]]; then
  PAYLOAD="$REPO_ROOT/template"
elif [[ -f "$SCRIPT_DIR/PROJECT_STATE.json" ]]; then
  PAYLOAD="$SCRIPT_DIR"
else
  echo "错误: 未找到模板载荷。" >&2
  exit 1
fi

TRAE_HOME="${TRAE_HOME:-$HOME/.trae}"
TEMPLATE_DEST="$TRAE_HOME/templates/project-workflow"
COMMANDS_DEST="$TRAE_HOME/commands"

if [[ "${1:-}" == "--uninstall" ]]; then
  echo "==> 卸载全局命令"
  for cmd in "$PAYLOAD"/.trae/commands/*.md; do
    [[ -e "$cmd" ]] || continue
    base="$(basename "$cmd")"
    if [[ -f "$COMMANDS_DEST/$base" ]]; then
      rm -f "$COMMANDS_DEST/$base"
      echo "    已删除 $COMMANDS_DEST/$base"
    fi
  done
  echo "==> 载荷保留在: $TEMPLATE_DEST"
  echo "==> 卸载完成"
  exit 0
fi

echo "==> TRAE 配置目录: $TRAE_HOME"
echo "==> 载荷来源: $PAYLOAD"
mkdir -p "$TEMPLATE_DEST" "$COMMANDS_DEST"

echo "==> 安装载荷到: $TEMPLATE_DEST"
rm -rf "$TEMPLATE_DEST"
mkdir -p "$TEMPLATE_DEST"
for item in AGENTS.md PROJECT_STATE.json README.md .gitignore .trae \
             00-discovery 01-design 02-development 03-operations docs; do
  if [[ -e "$PAYLOAD/$item" ]]; then
    cp -R "$PAYLOAD/$item" "$TEMPLATE_DEST/"
    echo "    复制 $item"
  fi
done

echo "==> 安装器随载荷放置（供 /init-project 与 /upgrade 调用）"
for s in install.sh upgrade.sh; do
  if [[ -f "$REPO_ROOT/scripts/$s" ]]; then
    cp "$REPO_ROOT/scripts/$s" "$TEMPLATE_DEST/$s"
    echo "    复制 $s"
  else
    echo "    [警告] 未找到 scripts/${s}，跳过"
  fi
done

echo "==> 安装全局斜杠命令到: $COMMANDS_DEST"
for cmd in "$PAYLOAD"/.trae/commands/*.md; do
  [[ -e "$cmd" ]] || continue
  cp "$cmd" "$COMMANDS_DEST/$(basename "$cmd")"
  echo "    复制 $(basename "$cmd")"
done

cat <<EOF

==> 全局安装完成！

现在任意项目中都可以使用:
  /init-project   在当前项目初始化四阶段流程
  /status         查看当前阶段与进度
  /advance        推进到下一阶段
  /upgrade        把项目的模板文件升级到新版本

注意:
  - /init-project 调用:$TEMPLATE_DEST/install.sh
  - /upgrade      调用:$TEMPLATE_DEST/upgrade.sh
  - 若命令未生效，请重启 TRAE 或开启新会话
  - 仍需在 设置 → 规则 中开启「将 AGENTS.md 包含在上下文中」
  - 仍需在 设置 → Hooks 中启用 Hook 运行
EOF
