# 更新日志

本文件记录模板仓库的每次优化。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased]

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
