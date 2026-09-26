---
description: 把本项目的模板文件升级到模板的新版本
---

请把当前项目的模板文件升级到新版本。

## 步骤 1：只读预览

先执行（默认只读，不会写入任何文件）：

```bash
bash "$HOME/.trae/templates/project-workflow/upgrade.sh" "$(pwd)"
```

（若全局目录为 `~/.trae-cn/`，则用 `"$HOME/.trae-cn/templates/project-workflow/upgrade.sh"`）

## 步骤 2：展示报告并征求用户确认

- 把脚本输出的报告**原样**展示给用户
- 逐条说明将要发生什么：哪些文件会被覆盖、哪些会被恢复、哪些因「被改过」而**不会**被覆盖
- **必须获得用户明确同意后才能落盘**

## 步骤 3：落盘

用户确认后执行：

```bash
bash "$HOME/.trae/templates/project-workflow/upgrade.sh" "$(pwd)" --apply
```

仅当用户明确表示「连我改过的文件也覆盖」时，才追加 `--force`（覆盖前会备份为 `.bak`）：

```bash
bash "$HOME/.trae/templates/project-workflow/upgrade.sh" "$(pwd)" --apply --force
```

## 注意

- 升级源是**全局模板目录**。若脚本报告「已是最新」而你预期有新版本，通常是因为全局模板尚未刷新——
  需先在模板仓库中重新运行全局安装脚本，把新版载荷装到全局模板目录，再重试本命令。
- 脚本**永不整体覆盖** `PROJECT_STATE.json`（项目进度），只对其 `template_version` 做字段级更新。
- 判定「文件是否被改过」依赖项目内的基线清单 `.trae/template-manifest.json`。
  若报告提示「缺少基线清单」（老项目），则已存在的模板文件默认都不会被覆盖，需用 `--force` 推进。
