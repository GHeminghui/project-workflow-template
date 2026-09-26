---
description: 将项目推进到下一阶段（要求当前阶段 checklist 全部完成）
---

请执行以下步骤推进阶段：

1. 读取 `PROJECT_STATE.json`
2. 检查当前阶段的 `checklist` 是否全部 `done`
   - **若有未完成项**：列出未完成项，拒绝推进，并提示用户先完成这些项
   - **若全部完成**：继续第 3 步
3. 逐项核对已勾选内容的产物是否真实存在（`artifact` 可指向文件或目录，两者皆可）
   - 若有缺失：列出「已勾选但产物不存在」的项，**请用户确认**——是补齐产物，还是确认该项可视为完成
   - 用户确认后继续；用户选择补齐则停止推进，等产物就位后重新运行 `/advance`
4. 更新状态：
   - 当前阶段：`status` 设为 `done`，填写 `completed_at` 为当前日期
   - 下一阶段：`status` 设为 `in_progress`，填写 `started_at` 为当前日期
   - `current_stage` 更新为下一阶段
   - `last_updated` 更新为当前日期
5. 保存 `PROJECT_STATE.json`
6. 用 `git add PROJECT_STATE.json && git commit -m "chore: advance to <下一阶段>"` 提交阶段推进（若在 git 仓库中）

若当前已是最后一个阶段（operations）且 checklist 全部完成，则提示用户项目已全部完成，并询问是否需要归档。
完成后，向用户说明已推进到哪个阶段、该阶段的目标和下一步要做什么。
