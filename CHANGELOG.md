# 更新日志

本文件记录模板仓库的每次优化。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased]

### Changed
- `CONTRIBUTING.md` 的「分支保护」由「待设置」改为**已生效**，并把核对到的实际配置写进文档（Ruleset `protect-main` / active；规则 `deletion` + `non_fast_forward` + `pull_request`（0 审批）+ 两条必需检查；Bypass = `Repository admin` / `always`；目标 = 默认分支）
- 更正原先「token 无法读写分支保护配置」的说法：**读** ruleset 用集成 token 即可，只有**写**（改规则）才需要 `administration` 权限；并提醒不要误用已废弃的 `/branches/main/protection` 端点

## [0.7.2] - 2026-09-26

### Changed
- **收尾 dogfooding 记录项 F7**（Hook 依赖 cwd 为项目根）：
  - `docs/architecture.md` §2.1 记明该**已知约束**、静默失效时的表现（新会话看不到「[项目状态自动加载]」），以及为何不在仓库侧加固（写绝对路径会破坏项目可移动性、并让 `hooks.json` 变成"被用户改过"从而干扰升级判定）
  - `template/README.md` 的「一次性配置」补一条自查提示，让使用者能自己定位「状态注入没生效」
- `VERSION` 推进至 `0.7.2`（本段改动触及载荷）

## [0.7.1] - 2026-09-26

### Added
- **`PROJECT_STATE.json` 新增 `stages.discovery.decision` 字段**（`pending` / `go` / `no-go`）：把 Go/No-Go 结论从「AI 解读 `decision.md` 措辞」改为**确定性字段判定**——此前它是整套「状态单一数据源」之外唯一的软肋（dogfooding 发现项 F4，决策见 `docs/adr/003-discovery-decision-field.md`）
- `scripts/validate.sh` 第 3 节新增校验：`discovery.decision` 必须存在且取值合法，且 `project_status: rejected` 必然对应 `decision: no-go`
- `tests/test_install.sh` 新增第 16 节：判定字段初值、Hook 展示、No-Go 渲染、缺字段的向后兼容
- `docs/specs/project-state.md`（新增）：`PROJECT_STATE.json` 的**数据契约**——顶层与阶段字段、取值、不变量（并区分「第 3 节强制」与「约定」）、写入规则与向后兼容；已登记进 `validate.sh` 第 1 节与 `architecture.md` 职责表
- `scripts/validate.sh` 新增第 14 节：`AGENTS.md` 的 ADR 规则必须**指向** `docs/adr/000-template.md`，且其中提到的小节必须在该模板中真实存在

### Changed
- `template/.trae/commands/advance.md` 第 5 步改为依 `decision` 字段分支；`pending` 或字段缺失（老项目）时读 `decision.md` 并请用户确认，**先把结论写入字段**再推进——不再替用户判定
- `inject_status.py` 在会话开始即展示 Go/No-Go 判定；`/status` 同步展示；`AGENTS.md` 的「状态维护」补充该字段说明
- `docs/design.md`、`docs/architecture.md` 补充设计理由与数据流说明
- `AGENTS.md` 规则 6 由「轻量 ADR 格式（背景 / 决策 / 后果）」改为**指向** `docs/adr/000-template.md`——原描述漏了模板实际要求的「备选方案」等小节，照它写出的 ADR 与模板不符（dogfooding 发现项 F5；仓库自己的 ADR 其实都按模板写）
- 开发阶段准出与门控文案澄清「测试通过」的验证边界（dogfooding 发现项 F3）：`tests/` 目录存在 ≠ 测试通过，门控不代运行
- `VERSION` 推进至 `0.7.1`（本段多次触及载荷，逐次推进）

### Fixed
- `AGENTS.md` 规则 7 补充约束：产物存在只证明「已落地」，不证明某项声称的**结果**成立；结果性项须**实际运行/验证取得结果**后再勾选

## [0.6.1] - 2026-09-26

### Added
- `scripts/validate.sh` 新增第 13 节：校验 `/advance` 的提交步骤必须包含阶段产物（不能只提交状态文件），可识别单行 `&&` 写法
- `tests/test_install.sh` 新增第 15 节：覆盖升级工具的准入检查（拒绝 / 不写入 / `--apply` 同样拒绝 / `--force` 放行 / 不误伤正常项目）

### Changed
- `VERSION` 推进至 `0.6.1`（本段改动触及载荷）

### Fixed
- **`/advance` 不再只提交状态文件**：此前第 8 步只 `git add PROJECT_STATE.json`，跑完四阶段后 13 个阶段产物与 ADR 全部留在版本库外——状态宣告阶段「完成」，git 里却查不到实物（dogfooding 实测发现）。现改为连同阶段目录与 `docs/` 一并提交，末阶段归档同样处理
- `AGENTS.md` 新增规则 8「阶段产物必须入库」；`docs/architecture.md` 的 `/advance` 数据流说明同步更新
- **`upgrade.sh` 新增目标目录准入检查**：目标目录既无 `PROJECT_STATE.json` 也无 `.trae/template-manifest.json` 时默认**拒绝执行**（退出码 2，不写任何文件），`--force` 可越过——此前会把整套载荷写进任意目录（dogfooding 中实测发生：误传空目标使 cwd 落到仓库根，仓库根被写入 11 个载荷文件）。行为契约同步更新至 `docs/specs/upgrade-tool.md` §3.1
- **`upgrade.sh --force` 预览模式的退出码修正**：此前 `--force` 预览即使发现差异也返回 `0`——落盘期概念 `remaining_merge` 被误用于退出码，与规格 §6「预览模式下发现差异 → 1」相矛盾。由 F2 新增的第 15 节测试发现

## [0.6.0] - 2026-09-26

### Added
- `scripts/validate.sh` 新增第 11 节「推荐能力一致性」：校验 `AGENTS.md` 的「推荐技能 / 推荐工具」与四个阶段 README 的「## 推荐能力」完全一致
- `scripts/validate.sh` 新增第 12 节「阶段 README 结构齐备」：每个阶段 README 必须含非空的「准入条件 / 推荐能力 / 准出产物」三节
- `CONTRIBUTING.md` 新增「扩展阶段数」章节：列出增减、重命名或调序阶段时必须同步的全部位置（并说明 `inject_status.py` 无需改动）

### Changed
- `CONTRIBUTING.md` 新增「分支保护」章节，固化 `main` 的 Rulesets 保护策略：要求 PR（`Required approvals` 填 0）+ CI 通过（两条矩阵检查名已列明）+ 禁强推/禁删除，Admin bypass 设为 **Always**；并写明「发布提交直推 `main`」是唯一例外；「发布」第 5 步同步写明该直推流程
- **推荐能力清单统一为「技能 / 工具」两类**，并让 `AGENTS.md` 与四个阶段 README 一致——此前两处互有出入（`AGENTS.md` 少了 `industry-panorama-research`、`web-app-development`、`TodoWrite`、`RunCommand`、`lark`/`wecom`），且工具与技能混列
- `plan.md` 的职责收敛为「任务拆分」，去掉「进度」：进度统一以 `PROJECT_STATE.json` 为准，不再出现第二个进度的落脚点
- `AGENTS.md` 规则 3 由「阶段准入准出以 `checklist` 为准」更正为「**准出**以 `checklist` 为准、**准入**见各阶段 README」——原表述与实际门控不符（checklist 只编码准出）
- `docs/design.md` 的「阶段门控的设计」补充「准入为静态约定、不做机器校验」的说明；`docs/architecture.md` 更新 `validate.sh` 职责并新增「扩展阶段数」小节
- `VERSION` 推进至 `0.6.0`（本段改动触及载荷，按约定推进版本号）

### Fixed
- 修正 `template/AGENTS.md` 与 `02-development/README.md` 中不存在的技能名 `browser_use` → `agent-browser`

## [0.5.0] - 2026-09-26

### Added
- `scripts/validate.sh` 新增第 9 节「阶段准出一致性」：强制校验门控（`PROJECT_STATE.json` 的 checklist）与 `AGENTS.md`、四个阶段 README、两张阶段产物汇总表五处描述一致

### Changed
- 对齐阶段准出的五处描述与实际门控（此前同一组产物在各处的成分互不相同）：
  - 调研：`PROJECT_STATE.json` 中两项同指 `research.md` 的重复清单项合并为一项
  - 设计：两张汇总表补上 `architecture.html`
  - 开发：门控补上独立的 `tests/` 项；`AGENTS.md` 准出补上 `plan.md`、`src/`
  - 运营：门控与两张汇总表补上 `monitoring.md`；`AGENTS.md` 准出改为 `deploy.md` + `runbook.md` + `release-notes.md` + `monitoring.md`
- `template/README.md` 标题「三个命令」更正为「四个命令」（上一版加入 `/upgrade` 时漏改）
- **状态文件只保留不可派生的字段**：删除 `next_action` 与各阶段 `deliverables`，改为现场派生
  - Hook 注入的「下一步动作」现取当前阶段第一个未完成的 checklist 项，不再可能陈旧
  - `/status` 的「下一步动作」与「已完成交付物」均现场派生
  - 原因：二者与 checklist 构成双重真相；而 `deliverables` 从未被任何代码写入过（`/status` 展示它却永远是空）
- 统一阶段显示名，以 `PROJECT_STATE.json` 的 `stages[].name` 为权威来源：开发（原为「执行(开发)」/「执行」/「开发」三种写法）、运营（原「上线运营」）
- `/advance` 新增产物存在性核对：已勾选项的 `artifact` 不存在时列出并请用户确认，而非直接放行
- `AGENTS.md` 新增约束：勾选某项前先确认其 `artifact` 已真实产出
- 修正「交付给下一阶段」的产物归属：调研的需求清单明确落在 `research.md`；开发阶段不再承诺「部署说明」（该文件归运营阶段）
- `scripts/validate.sh` 第 9 节扩展为同时校验阶段显示名（AGENTS.md 标题、阶段 README 标题、两张汇总表共 4 处比对 `stages[].name`）
- **给项目加生命周期终态 `project_status`**（与阶段链正交，不引入回路）：`active` / `rejected`（调研 No-Go 终止）/ `archived`（四阶段完成归档）
  - `/advance` 在 discovery 阶段确认 No-Go 后置为 `rejected` 并停止推进；在 operations 完成后经用户同意置为 `archived`
  - Hook 在非 `active` 时只提示状态、不再推动阶段；`/status` 展示项目状态
  - 此前「归档」与「No-Go」两处承诺都没有可表示的终态——`/advance` 说「询问是否需要归档」，却没有任何可写入的字段
- **把「迭代」从阶段目标降级为明确的非目标**：运营阶段目标改为「部署上线并持续监控运行」；`AGENTS.md` 新增「关于迭代」（迭代请新建项目周期，不在流程内回退阶段）；`docs/design.md` 的**非目标**补充「不做阶段回退与迭代循环」与「不做需求裁剪（N/A）机制」
  - 原因：原目标写着「持续监控、迭代」，而 `/advance` 只能向前，两处说法矛盾
- `docs/design.md` 的「阶段门控的设计」补记产物存在性核对（上一版实现后漏更）
- `VERSION` 推进至 `0.5.0`：本段改动多次触及载荷，每次都必须推进版本号以避开升级工具的「版本相同」短路（该约束见 `CONTRIBUTING.md` 与升级工具规格 §5）

### Fixed
- `scripts/validate.sh` 修复一处 **bash 3.2 专属**语法错误：`$()` 内嵌 heredoc 正文中的字面反引号被误解析（改用 `chr(96)`）。该写法在 Linux 的 bash 5 下不报错，只在 macOS 的 bash 3.2 下必现；相应约定已记入 `CONTRIBUTING.md`
- 修复两处既有的「变量后紧接全角字符」写法——同属 bash 3.2 陷阱，且**都在报错/警告分支**，正常路径永远看不到，一旦触发就崩在诊断代码上：
  - `scripts/gen-manifest.sh` 的未知选项提示（`$1（`）
  - `scripts/setup-global.sh` 的缺失文件警告（`$s，`）——缺文件时文件名会被静默丢失
- `scripts/validate.sh` 新增第 10 节：扫描全部 Shell 脚本，禁止「变量后紧接全角字符」写法
- `tests/test_install.sh` 修正一条**过弱断言**：原用 `grep` 匹配产物文字，而该文字在「本阶段清单」中也会出现，导致派生逻辑坏掉也照样通过；现改为精确比对「下一步动作:」整行

## [0.2.0] - 2026-09-26

### Added
- 新增 `.github/release.yml`：Release notes 分类配置，按 PR 标签归类
- 新增 `.github/PULL_REQUEST_TEMPLATE.md`：PR 模板
- 新增 `scripts/setup-labels.sh`：一键创建/同步 8 个 PR 标签（幂等，可重复执行）
- 新增 `docs/adr/002-upgrade-strategy.md`（状态：已采纳）：模板升级策略，含版本锚点、文件边界声明化与默认只读的升级流程
- 新增 `docs/specs/template-manifest.md`：冻结模板清单（`.trae/template-manifest.json`）的路径与格式，作为后续实现的接口契约
- 新增 `docs/specs/` 目录与规格文档约定，`AGENTS.md` 改动工作流同步补充第 6 条
- 新增 `VERSION`（模板版本单一数据源）与 `scripts/gen-manifest.sh`（生成/校验模板清单）
- 生成并提交 `template/.trae/template-manifest.json`（文件边界 + 基线哈希 + 版本号）
- 新增 `docs/specs/upgrade-tool.md`：冻结升级工具的入口、CLI、文件状态→动作矩阵、报告格式与退出码
- 新增 `scripts/upgrade.sh` 与 `/upgrade` 命令（`template/.trae/commands/upgrade.md`）：把项目内模板文件升级到新版本，默认只读预览，`--apply` 落盘，`--force` 才覆盖被改过的文件（先备份 `.bak`）

### Changed
- `CONTRIBUTING.md` 新增「PR 与标签」标签约定，流程补充 PR 步骤，并说明两个 `release.yml` 的区别
- `docs/architecture.md`、`AGENTS.md`、`README.md` 同步登记新增文件与脚本
- CI 与发布工作流升级 action 版本以适配 Node 24：`actions/checkout` v4→v5、`actions/setup-python` v5→v6
- `README.md` 仓库结构树补充 `.github/` 目录
- `scripts/install.sh` 改为按模板清单驱动复制，据 `mode` 处理覆盖策略（移除硬编码文件列表）
- `template/PROJECT_STATE.json` 增加 `template_version` 字段，由清单派生
- `scripts/validate.sh` 新增第 8 节「清单 ↔ 载荷 ↔ 版本号」一致性校验，脚本语法检查补入 `build-dist.sh`、`gen-manifest.sh`
- `CONTRIBUTING.md` 发布流程补充版本对齐步骤（改 `VERSION` → 重生成清单 → 验证），并新增 Shell 约定
- `docs/design.md` 补充「升级策略」一节，补齐此前的设计空白
- `docs/specs/template-manifest.md` §8 的动作策略移入升级工具规格（消除重复）；其中「文件缺失」的默认动作由「不恢复」改为「恢复」——恢复不构成数据丢失

### Fixed
- `scripts/install.sh` 的 `--force` 不再整体覆盖 `PROJECT_STATE.json`：该文件承载项目进度、属用户数据，改为仅在不存在时写入初始模板，已存在时仅在显式传 `-n` 时更新 `project_name` 单个字段。修复 `--force` 清空 `current_stage`／清单勾选／`deliverables` 的数据丢失问题（见 `docs/adr/002-upgrade-strategy.md`）
- `tests/test_install.sh` 第 5 节新增断言，防止上述数据丢失问题回归
- 修复 `scripts/install.sh --help` 会多打印一行 `set -euo pipefail`：`usage()` 原按固定行号截取注释块，越界包含了 `set -e` 行

## [0.1.2] - 2026-09-26

### Changed
- `CONTRIBUTING.md` 发布小节补充注意事项：tag 所指提交必须已包含 `.github/workflows/release.yml`，否则不会触发发布工作流

### Fixed
- `scripts/build-dist.sh` 改为以 git 跟踪文件（`git ls-files`）为唯一来源，修复未跟踪文件（如 `template/.DS_Store`）被内嵌进 `bootstrap.sh` 与压缩包、进而污染用户项目的问题；并新增产物自检，条目与跟踪文件不一致时直接失败

## [0.1.1] - 2026-09-26

### Added
- 仓库重构为「开发层 + `template/` 载荷层」双层结构，隔离模板开发上下文与用户项目上下文
- 新增 `AGENTS.md` 开发指引，便于 AI 理解并持续优化本模板
- 新增 `docs/design.md`、`docs/architecture.md` 说明设计原理与数据流
- 新增 `scripts/validate.sh` 模板完整性校验
- 新增 `tests/test_install.sh` 安装端到端测试
- 新增 `CHANGELOG.md`、`CONTRIBUTING.md`
- 新增 `.github/workflows/ci.yml`：push / PR 时在 ubuntu 与 macOS 上自动运行 `validate.sh` 与 `test_install.sh`
- 新增 `.github/workflows/release.yml`：打 `v*` tag 时自动完成发布前门控、`build-dist.sh` 打包、产物自检并创建 GitHub Release

### Changed
- `install.sh`、`setup-global.sh` 迁移至 `scripts/` 并适配新结构
- 安装载荷统一收敛到 `template/`

## [0.1.0] - 2026-09-26

### Added
- 初始版本：四阶段流程模板
- `AGENTS.md` 流程规范、`PROJECT_STATE.json` 状态文件
- `.trae/hooks.json` + `inject_status.py` 会话状态注入
- 斜杠命令 `/init-project`、`/status`、`/advance`
- 四阶段目录与说明、`docs/adr/` 决策模板
- `install.sh`、`setup-global.sh`、`bootstrap.sh` 分发脚本
