# 阶段 1：调研（Discovery）

## 目标
搞清楚「做什么、为什么做、现状如何」，为是否进入设计阶段提供依据。

## 准入条件
- 项目已通过 `/init-project` 初始化
- `PROJECT_STATE.json` 中本阶段状态为 `in_progress`

## 推荐能力

### 技能
- `whiteboard`：思维导图、用户旅程图、竞品对比图
- `report-page`：结构化调研报告
- `industry-researcher` / `industry-panorama-research`：行业与赛道研究

### 工具
- `WebSearch` / `WebFetch`：资料收集、竞品分析

## 准出产物
- [ ] `research.md`：背景、目标用户、竞品、技术可行性，以及需求清单与约束条件
- [ ] `decision.md`：Go / No-Go 决策记录

## 交付给下一阶段
明确的需求清单与约束条件（见 `research.md` 的研究结论）。

## 完成标准
`PROJECT_STATE.json` 中 `discovery` 阶段的 checklist 全部勾选后，运行 `/advance`。
