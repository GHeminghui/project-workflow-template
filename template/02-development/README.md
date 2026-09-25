# 阶段 3：执行 / 开发（Development）

## 目标
把设计变成可运行、可测试的代码。

## 准入条件
- 设计阶段已完成并通过 `/advance` 推进
- 已有验收标准

## 推荐能力
- `writing-plans`：把设计拆成多步执行计划
- `test-driven-development` / `Praxis:tdd`：先写测试再实现
- `browser_use`：前端页面验证
- `RunCommand`：构建、测试、lint
- `TodoWrite`：子任务进度跟踪

## 准出产物
- [ ] `plan.md`：任务拆分与进度
- [ ] `src/`：代码
- [ ] `tests/`：测试（需全部通过）
- [ ] `changelog.md`：开发日志

## 交付给下一阶段
通过测试的可部署产物 + 部署说明。

## 完成标准
全量测试通过后，`PROJECT_STATE.json` 中 `development` 阶段的 checklist 全部勾选，再运行 `/advance`。
