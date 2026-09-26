---
description: 将项目推进到下一阶段（要求当前阶段 checklist 全部完成）
---

请执行以下步骤推进阶段：

1. 读取 `PROJECT_STATE.json`
2. 若 `project_status` 不是 `active`（即为 `rejected` 或 `archived`），拒绝推进并说明原因——已终止的项目不得继续推进阶段
3. 检查当前阶段的 `checklist` 是否全部 `done`
   - **若有未完成项**：列出未完成项，拒绝推进，并提示用户先完成这些项
   - **若全部完成**：继续
4. 逐项核对已勾选内容的产物是否真实存在（`artifact` 可指向文件或目录，两者皆可）
   - 若有缺失：列出「已勾选但产物不存在」的项，**请用户确认**——是补齐产物，还是确认该项可视为完成
   - 用户确认后继续；用户选择补齐则停止推进，等产物就位后重新运行 `/advance`
5. **若当前阶段是 `discovery`**：先确认 Go/No-Go 结论（读 `00-discovery/decision.md`；若无法判断则直接询问用户）
   - **No-Go**：把 `discovery.status` 设为 `done` 并填写 `completed_at`，把 `project_status` 设为 `rejected`，刷新 `last_updated`，保存后**停止推进**，并告知用户项目已按 No-Go 终止
   - **Go**：继续第 6 步
6. 更新状态：
   - 当前阶段：`status` 设为 `done`，填写 `completed_at` 为当前日期
   - 下一阶段：`status` 设为 `in_progress`，填写 `started_at` 为当前日期
   - `current_stage` 更新为下一阶段
   - `last_updated` 更新为当前日期
7. 保存 `PROJECT_STATE.json`
8. **提交本阶段成果**（若在 git 仓库中）——产物与状态一并入库，**不要只提交状态文件**：

   ```bash
   git add "<当前阶段目录>/" docs/ PROJECT_STATE.json
   git commit -m "chore: 完成<当前阶段名>阶段并推进到<下一阶段名>"
   ```

   - `<当前阶段目录>` 即当前阶段对应的目录（如调研阶段为 `00-discovery/`）
   - 一并加入 `docs/` 是为了带上本阶段新增的 ADR（见 `AGENTS.md` 规则 6）
   - **为什么必须连产物一起提交**：状态文件会宣告本阶段「完成」，若产物没入库，版本库里就查不到实物——换机器、回滚或评审时都会丢

**若当前已是最后一个阶段（operations）且 checklist 全部完成**：不要再去寻找下一阶段，改为：

- 把 `operations.status` 设为 `done` 并填写 `completed_at`
- 询问用户是否归档；若用户同意，把 `project_status` 设为 `archived`
- 刷新 `last_updated` 并保存
- 同样把**产物与状态一并提交**（若在 git 仓库中）：

  ```bash
  git add "03-operations/" docs/ PROJECT_STATE.json
  git commit -m "chore: 完成运营阶段并归档"
  ```

- 然后告知用户项目已完成（以及是否已归档）

完成后，向用户说明已推进到哪个阶段、该阶段的目标和下一步要做什么。
