# 阶段 3：开发（Development）

## 目标
把设计变成可运行、可测试的代码。

## 准入条件
- 设计阶段已完成并通过 `/advance` 推进
- 已有验收标准

## 推荐能力

### 技能
- `writing-plans`：把设计拆成多步执行计划
- `test-driven-development` / `Praxis:tdd`：先写测试再实现（二者择一）
- `agent-browser`：前端页面验证

### 工具
- `RunCommand`：构建、测试、lint
- `TodoWrite`：子任务进度跟踪

## 准出产物
- [ ] `plan.md`：任务拆分（进度以 `PROJECT_STATE.json` 为准，不在此重复维护）
- [ ] `src/`：代码
- [ ] `tests/`：测试用例，**须真实运行且全部通过**（门控只核对目录存在，不代你运行）
- [ ] `changelog.md`：开发日志

## 交付给下一阶段
通过测试的可部署产物；部署说明由下一阶段产出为 `03-operations/deploy.md`。

## 完成标准
全量测试通过后，`PROJECT_STATE.json` 中 `development` 阶段的 checklist 全部勾选，再运行 `/advance`。
