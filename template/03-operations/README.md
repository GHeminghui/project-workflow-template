# 阶段 4：运营（Operations）

## 目标
部署上线，并持续监控运行。

## 准入条件
- 开发阶段已完成并通过 `/advance` 推进
- 已通过全量测试

## 推荐能力

### 技能
- `Praxis:ship` / `Praxis:release`：发布与版本打 tag
- `verification-before-completion`：上线前验证清单
- `lark` / `wecom`：上线通知与团队同步（如需要）

### 工具
- `RunCommand`：部署脚本、监控命令

## 准出产物
- [ ] `deploy.md`：部署步骤、回滚方案
- [ ] `runbook.md`：运维手册（常见问题、监控指标）
- [ ] `release-notes.md`：版本发布说明
- [ ] `monitoring.md`：监控方案与告警阈值

## 完成标准
上线验证通过，`PROJECT_STATE.json` 中 `operations` 阶段的 checklist 全部勾选。
至此整个流程完成，可运行 `/status` 回顾；归档由 `/advance` 完成——它会询问是否把 `project_status` 置为 `archived`。

## 关于迭代

本流程不做阶段回退。上线后如需迭代，见 `AGENTS.md` 的「关于迭代」。
