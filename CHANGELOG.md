# 更新日志

本文件记录模板仓库的每次优化。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased]

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
