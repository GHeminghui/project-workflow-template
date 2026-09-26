# ADR-003：把 Go/No-Go 结论存为状态字段

- **状态**：已采纳
- **日期**：2026-09-26
- **决策者**：模板维护者

## 背景

调研阶段的 Go/No-Go 决定项目是否继续，是整条流程唯一的分水岭。此前该结论只写在 `00-discovery/decision.md`，
`/advance` 依赖 AI 阅读该文件的**语义**来判定；而流程其余关卡（阶段推进、checklist 勾选、生命周期终态）
全部由 `PROJECT_STATE.json` 的字段驱动。这使 Go/No-Go 成为「状态单一数据源」设计里唯一的例外：
AI 一旦误读措辞，就可能错误终止项目，或让本该否决的项目走完后三个阶段。dogfooding 复跑时确认了这一软肋（发现项 F4）。

## 决策

在 `PROJECT_STATE.json` 的 `stages.discovery` 下新增 `decision` 字段，取值 `pending` / `go` / `no-go`。
`/advance` 依该字段分支；`decision.md` 降为「结论的依据」，不再是「判定的依据」。

## 备选方案

| 方案 | 优点 | 缺点 |
|------|------|------|
| A. 状态字段（本决策） | 全链路可机器校验；Hook 与 `/status` 能直接展示结论；与其余关卡一致 | 状态结构变更，需处理老项目缺字段的向后兼容 |
| B. 在 `decision.md` 里约定一行机器可读标记（如 `决策: Go`） | 不动状态结构，改动最小 | 校验力弱——那是用户产物，可被自由改写；Hook 仍需读文件才知道结论 |

## 后果

- **正面影响**：Go/No-Go 从「AI 语义判断」变为确定性判定；Hook 在会话开始即可告知「本项目已判定 No-Go」，不必再读文件；`validate.sh` 能强制字段合法（含 `rejected` 必然对应 `no-go` 的交叉校验）
- **负面影响**：状态结构变更引入一次向后兼容处理——老项目（早于本版安装）缺 `decision` 字段，`/advance` 按 `pending` 处理（读 `decision.md` 并请用户确认后写入字段）
- **后续动作**：若将来出现其它「阶段级结论」型字段，沿用这一模式（结论入状态、文档作依据）

## 相关链接

- dogfooding 发现项 F4
- [docs/design.md](../design.md) 的「项目生命周期与终态」
- [template/AGENTS.md](../../template/AGENTS.md) 的「状态维护」
