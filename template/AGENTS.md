# 项目工作流规范

本项目遵循四阶段流程：**调研 → 设计 → 执行(开发) → 上线运营**。
所有工作必须在当前阶段内进行，按顺序推进，不得跳阶段。

## 核心规则（必须遵守）

1. **开始任何工作前**，先读取项目根目录的 `PROJECT_STATE.json`，确认当前阶段与下一步动作。
2. **每次回复开头**，用一句话说明：「当前处于 X 阶段，本次目标是 Y」。
3. **严格按阶段顺序执行**，阶段准入准出以 `PROJECT_STATE.json` 中对应阶段的 `checklist` 为准。
4. **不得越阶段操作**：例如设计阶段不得写生产代码，开发阶段不得擅自部署上线。
5. **完成当前阶段全部 checklist 后**，提示用户运行 `/advance` 推进到下一阶段，不要自行推进。
6. **关键决策**记录到 `docs/adr/`，使用轻量 ADR 格式（背景 / 决策 / 后果）。
7. **产物落地到对应阶段目录**，路径以 `PROJECT_STATE.json` 中的 `artifact` 字段为准。

## 阶段说明

### 调研 (discovery) — 目录 `00-discovery/`
- 目标：搞清楚「做什么、为什么做、现状如何」
- 推荐能力：WebSearch、WebFetch、whiteboard、report-page、industry-researcher
- 准出：`research.md` + `decision.md` 完成

### 设计 (design) — 目录 `01-design/`
- 目标：把需求转化为可执行方案（产品设计 + 技术设计）
- 推荐能力：brainstorming、Praxis:design、whiteboard、visualize-code、Frontend Design
- 准出：`product-spec.md` + `tech-design.md` + 架构图完成

### 执行(开发) (development) — 目录 `02-development/`
- 目标：把设计变成可运行、可测试的代码
- 推荐能力：writing-plans、test-driven-development、Praxis:tdd、browser_use、RunCommand
- 准出：全量测试通过 + `changelog.md` 更新

### 上线运营 (operations) — 目录 `03-operations/`
- 目标：部署上线并持续监控、迭代
- 推荐能力：Praxis:ship、Praxis:release、verification-before-completion
- 准出：`deploy.md` + `runbook.md` + 上线验证完成

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
- 每次更新后同步刷新 `last_updated` 和 `next_action` 字段。
