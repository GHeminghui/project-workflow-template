---
description: 初始化项目为四阶段流程（调研→设计→执行→上线运营）
---

请将当前项目初始化为四阶段流程项目。

## 首选方式：调用全局模板安装脚本

若全局模板存在，直接执行（最可靠，结果与模板完全一致）：

```bash
bash "$HOME/.trae/templates/project-workflow/install.sh" "$(pwd)" -n "$(basename "$(pwd)")"
```

（若全局目录为 `~/.trae-cn/`，则用 `"$HOME/.trae-cn/templates/project-workflow/install.sh"`）

执行完成后跳到「收尾」步骤。若脚本不存在，则使用下面的「备用方式」。

## 备用方式：手动生成

1. 创建目录：`00-discovery/`、`01-design/`、`02-development/`、`03-operations/`、`docs/adr/`、`.trae/scripts/`、`.trae/commands/`
2. 生成 `PROJECT_STATE.json`（四阶段标准模板，`current_stage` 为 `discovery`，所有 checklist 的 `done` 为 false）
3. 生成 `AGENTS.md`（四阶段流程规范，含核心规则与阶段说明）
4. 生成 `.trae/hooks.json`（配置 SessionStart 事件调用注入脚本）
5. 生成 `.trae/scripts/inject_status.py`（读取状态并注入上下文）
6. 为四个阶段目录各生成 `README.md`（写明准入条件、推荐工具、准出产物）
7. 将项目名写入 `PROJECT_STATE.json` 的 `project_name` 字段（用户提供则用其值，否则用目录名）

## 收尾

- 若不在 git 仓库中，执行 `git init` 并提交初始版本
- 向用户简要说明：项目已就绪、当前处于「调研」阶段、下一步该做什么
