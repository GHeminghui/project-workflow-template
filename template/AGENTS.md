# 项目工作流规范

本项目遵循四阶段流程：**调研 → 设计 → 开发 → 运营**。
所有工作必须在当前阶段内进行，按顺序推进，不得跳阶段。

## 核心规则（必须遵守）

1. **开始任何工作前**，先读取项目根目录的 `PROJECT_STATE.json`，确认当前阶段与下一步动作。
2. **每次回复开头**，用一句话说明：「当前处于 X 阶段，本次目标是 Y」。
3. **严格按阶段顺序执行**：阶段**准出**以 `PROJECT_STATE.json` 中对应阶段的 `checklist` 为准；阶段**准入**条件见各阶段目录的 `README.md`（属模板的静态约定，不随项目状态变化）。
4. **不得越阶段操作**：例如设计阶段不得写生产代码，开发阶段不得擅自部署上线。
5. **完成当前阶段全部 checklist 后**，提示用户运行 `/advance` 推进到下一阶段，不要自行推进。
6. **关键决策**记录到 `docs/adr/`，使用轻量 ADR 格式（背景 / 决策 / 后果）。
7. **产物落地到对应阶段目录**，路径以 `PROJECT_STATE.json` 中的 `artifact` 字段为准；**勾选某项前，先确认该 `artifact` 已真实产出**。

## 阶段说明

### 调研 (discovery) — 目录 `00-discovery/`
- 目标：搞清楚「做什么、为什么做、现状如何」
- 推荐技能：`whiteboard`、`report-page`、`industry-researcher`、`industry-panorama-research`
- 推荐工具：`WebSearch`、`WebFetch`
- 准出：`research.md` + `decision.md` 完成

### 设计 (design) — 目录 `01-design/`
- 目标：把需求转化为可执行方案（产品设计 + 技术设计）
- 推荐技能：`brainstorming`、`Praxis:design`、`whiteboard`、`visualize-code`、`Frontend Design`、`web-app-development`
- 推荐工具：（无，以技能为主）
- 准出：`product-spec.md` + `tech-design.md` + `architecture.html`

### 开发 (development) — 目录 `02-development/`
- 目标：把设计变成可运行、可测试的代码
- 推荐技能：`writing-plans`、`test-driven-development` / `Praxis:tdd`、`agent-browser`
- 推荐工具：`RunCommand`、`TodoWrite`
- 准出：`plan.md` + `src/` + `tests/`（全量通过）+ `changelog.md`

### 运营 (operations) — 目录 `03-operations/`
- 目标：部署上线并持续监控运行
- 推荐技能：`Praxis:ship`、`Praxis:release`、`verification-before-completion`、`lark`、`wecom`
- 推荐工具：`RunCommand`
- 准出：`deploy.md` + `runbook.md` + `release-notes.md` + `monitoring.md`

## 目录结构

```
00-discovery/     调研阶段产物
01-design/        设计阶段产物
02-development/   执行阶段产物（代码、测试）
03-operations/    上线运营产物
docs/             跨阶段文档（README、ADR、决策记录）
.trae/            TRAE 配置（hooks、commands、scripts）
PROJECT_STATE.json 项目状态（单一数据源）
```

## 状态维护

- `PROJECT_STATE.json` 是**唯一状态数据源**，任何阶段推进、checklist 勾选都必须更新它。
- 每次更新后同步刷新 `last_updated` 字段；「下一步动作」由当前阶段第一个未完成的 checklist 项派生，无需手写。
- `project_status` 表示项目生命周期：`active`（进行中）、`rejected`（调研阶段 No-Go，流程终止）、`archived`（四阶段完成并归档）。**非 `active` 时不得继续推进阶段。**

## 关于迭代

本流程**刻意保持线性**：不做阶段回退，也不做迭代循环。运营阶段的目标是「部署上线并持续监控运行」，不含回到设计或开发的通路。

上线后如需迭代，请按以下方式处理，而不是在流程内回退阶段：

- **新一轮迭代** → 为本轮变更**新建一个项目周期**，让它独立走完四阶段
- **同一项目内的紧急修补** → 人工把 `project_status` 改回 `active`，并按需要把 `current_stage` 调回对应阶段，同时自行核对状态与产物是否一致

这样取舍的理由：线性流程「简单、可预测、不跳步」是这套模板的核心价值；引入回路会让门控与状态判断显著复杂化。
