# 项目状态文件规格（`PROJECT_STATE.json`）

> **状态**：已实现，主要不变量由 `scripts/validate.sh` 第 3 节强制校验。
> 本文是该文件的**数据契约**：字段、取值、不变量、写入规则与向后兼容。
> 相邻契约见 [template-manifest.md](template-manifest.md)（模板清单）与 [upgrade-tool.md](upgrade-tool.md)（升级行为）。

## 1. 地位：唯一状态数据源

`PROJECT_STATE.json` 是项目状态的**单一数据源**。阶段推进、checklist 勾选、生命周期变更都必须写入它；
`AGENTS.md`、阶段 README、两张汇总表只描述**规范**，不承载**现状**。

**不再存在的字段（改为按需派生）**：

| 旧字段 | 现状 |
|--------|------|
| `next_action` | 已删除。取当前阶段第一个未完成的 checklist 项，由 `inject_status.py` / `/status` 现场派生 |
| 各阶段 `deliverables` | 已删除。由已勾选 checklist 项的 `artifact` 现场汇总 |

理由：二者与 `checklist` 构成双重真相，必然陈旧。

## 2. 双重身份与写入规则

该文件**既是载荷的一部分，又承载项目侧数据**（进度），因此各写入方权限不同：

| 场景 | 行为 |
|------|------|
| `install.sh` 首次安装 | 写入 `project_name` / `created_at` / 当前阶段 `started_at` / `last_updated` |
| `install.sh --force` | **不整体覆盖**（清单标 `create-only`）；仅在 `-n` 指定名字时做单字段更新 |
| `upgrade.sh` | **永不整体覆盖**；只做 `template_version` 的字段级更新 |
| `/advance` | 改写阶段状态、`current_stage`、`last_updated`（由 AI 按命令文档执行） |
| checklist 勾选 | 由 AI 就地更新对应项的 `done` |

## 3. 顶层字段

| 字段 | 类型 | 取值 | §3 强制 |
|------|------|------|:------:|
| `project_name` | string | 任意 | ✅ |
| `project_status` | enum | `active` / `rejected` / `archived` | ✅ |
| `created_at` | date | `YYYY-MM-DD` | — |
| `current_stage` | string | ∈ `stage_order` | ✅ |
| `stage_order` | string[] | 恰为四阶段、顺序固定 | ✅ |
| `stages` | object | key = 阶段标识 | ✅ |
| `last_updated` | date | `YYYY-MM-DD`，每次更新同步刷新 | ✅ |
| `template_version` | string | 与仓库根 `VERSION` 一致（见 §7） | 由 §8 间接约束 |

> 「§3 强制」列为 `—` 表示该字段属于约定，`validate.sh` 第 3 节未纳入必需字段列表。

## 4. 阶段对象（`stages.<key>`）

`key` 为 `discovery` / `design` / `development` / `operations`。

| 字段 | 类型 | 取值 | §3 强制 |
|------|------|------|:------:|
| `name` | string | `调研` / `设计` / `开发` / `运营` | ✅（存在性） |
| `dir` | string | 如 `00-discovery` | — |
| `status` | enum | `pending` / `in_progress` / `done` | ✅（存在性，值不校验） |
| `started_at` | date \| null | | — |
| `completed_at` | date \| null | | — |
| `checklist` | object[] | 见 §4.1 | ✅ |
| `decision` | enum | `pending` / `go` / `no-go`，**仅 discovery** | ✅（含取值，见 §5） |

> `name` 是阶段显示名的**权威来源**：`AGENTS.md` 标题、阶段 README 标题、两张汇总表都必须与它一致（由 `validate.sh` 第 9 节校验）。
> `dir` 仅供人读——**脚本不读取该字段**（`validate.sh` 用内置的阶段↔目录映射）。

### 4.1 checklist 项

| 字段 | 类型 | 说明 |
|------|------|------|
| `item` | string | 面向人的描述；Hook 与 `/status` 原文展示，故措辞会被用户看到 |
| `done` | bool | 是否完成 |
| `artifact` | string | 产物路径，相对项目根，**可为文件或目录** |

## 5. 不变量

`validate.sh` 第 3 节强制：

| # | 不变量 |
|---|--------|
| 1 | §3 所列必需字段齐备 |
| 2 | `project_status ∈ {active, rejected, archived}` |
| 3 | `stage_order` 恰为 `["discovery","design","development","operations"]` |
| 4 | 每个阶段含 `name` / `status` / `checklist`；每个 checklist 项含 `item` / `done` |
| 5 | `current_stage ∈ stage_order` |
| 6 | `discovery.decision ∈ {pending, go, no-go}` |
| 7 | `project_status == rejected` ⟹ `discovery.decision == no-go` |

`validate.sh` 第 8 节另行保证：`template_version` ↔ `VERSION` ↔ 模板清单三者一致。

**约定但未机器强制**（由 `/advance` 与 AI 遵守）：

- 勾选某项前，其 `artifact` 应已真实产出——`/advance` 第 4 步逐项核对存在性
- `artifact` 存在**只能证明产物已落地，不能证明其声称的结果成立**（例如 `tests/` 目录存在 ≠ 测试通过）
- 非 `active` 时不得继续推进阶段

## 6. 生命周期（`project_status`）

| 值 | 含义 | 由谁设置 |
|----|------|---------|
| `active` | 进行中 | 初始值 |
| `rejected` | 调研阶段判定 No-Go，流程终止 | `/advance` 在 `discovery.decision == no-go` 时 |
| `archived` | 四阶段完成并归档 | `/advance` 在 operations 完成后经用户同意 |

生命周期与阶段链**正交**：它表达端点，而不给阶段链加回路。决策见 [ADR-003](../adr/003-discovery-decision-field.md)。

## 7. 版本字段与升级

`template_version` 是**版本锚点**，权威来源是仓库根的 `VERSION`：`gen-manifest.sh` 把它同步进模板清单与本文件。
`upgrade.sh` 在「项目版本 == 模板版本」时直接短路报「已是最新」（见 [upgrade-tool.md §5](upgrade-tool.md)），
因此该字段一旦陈旧，用户就会被误判为无需升级——这正是「载荷一改就必须推进 `VERSION`」这条硬约束的由来。

## 8. 向后兼容

状态结构随版本演进（`project_status`、`discovery.decision` 都是后加字段）。约定：

- **新增字段必须容忍缺失**：读取方（`inject_status.py`、`/advance`）遇到缺失字段按「未设置」处理，不得报错
- **老项目不自动补齐**：本文件是 `create-only`，升级只改 `template_version`；缺失字段由工作流在需要时写入
  （例如 `/advance` 在用户确认 Go/No-Go 后写入 `decision`）

## 9. 校验位置

| 节 | 内容 |
|----|------|
| `validate.sh` §2 | JSON 合法性 |
| `validate.sh` §3 | 结构、枚举与 §5 的不变量 |
| `validate.sh` §7 | `inject_status.py` 能读取并渲染 |
| `validate.sh` §8 | `template_version` ↔ `VERSION` ↔ 清单一致 |
| `validate.sh` §9 | checklist 的 `artifact` 与各文档描述一致（准出对齐） |

## 10. 相关

- [template-manifest.md](template-manifest.md)——模板清单的数据契约
- [upgrade-tool.md](upgrade-tool.md)——升级工具的行为契约
- [ADR-002](../adr/002-upgrade-strategy.md)、[ADR-003](../adr/003-discovery-decision-field.md)
- [docs/design.md](../design.md)——设计原理
