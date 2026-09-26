# 阶段 4：运营（Operations）

## 目标
部署上线，并持续监控、迭代。

## 准入条件
- 开发阶段已完成并通过 `/advance` 推进
- 已通过全量测试

## 推荐能力
- `Praxis:ship` / `Praxis:release`：发布与版本打 tag
- `verification-before-completion`：上线前验证清单
- `RunCommand`：部署脚本、监控命令
- `lark` / `wecom`：上线通知与团队同步（如需要）

## 准出产物
- [ ] `deploy.md`：部署步骤、回滚方案
- [ ] `runbook.md`：运维手册（常见问题、监控指标）
- [ ] `release-notes.md`：版本发布说明
- [ ] `monitoring.md`：监控方案与告警阈值

## 完成标准
上线验证通过，`PROJECT_STATE.json` 中 `operations` 阶段的 checklist 全部勾选。
至此整个流程完成，可运行 `/status` 回顾，或归档项目。
