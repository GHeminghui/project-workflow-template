# 本项目使用四阶段工作流

本项目按 **调研 → 设计 → 执行(开发) → 上线运营** 四阶段推进，流程规范见 [AGENTS.md](AGENTS.md)，当前进度见 [PROJECT_STATE.json](PROJECT_STATE.json)。

## 三个命令

| 命令 | 用途 |
|------|------|
| `/status` | 查看当前阶段、进度与下一步动作 |
| `/advance` | 当前阶段完成后，推进到下一阶段（有门控校验） |
| `/init-project` | 补齐缺失的模板文件（不覆盖已存在的文件） |
| `/upgrade` | 把本项目的模板文件升级到模板的新版本（默认只读预览，需确认后落盘） |

## 怎么用

- **开新会话时**：若已启用状态注入，AI 会自动知道当前阶段与下一步，直接说「继续」即可。
- **想知道做到哪了**：`/status`
- **完成一个阶段后**：勾选完清单，敲 `/advance`

## 阶段与产物

| 阶段 | 目录 | 关键产物 |
|------|------|----------|
| 调研 | `00-discovery/` | `research.md`、`decision.md` |
| 设计 | `01-design/` | `product-spec.md`、`tech-design.md` |
| 执行 | `02-development/` | `plan.md`、代码、测试、`changelog.md` |
| 运营 | `03-operations/` | `deploy.md`、`runbook.md`、`release-notes.md` |

各阶段的准入条件、推荐工具与准出产物，见对应目录下的 `README.md`。

## 决策留痕

关键决策记录到 `docs/adr/`，按 `docs/adr/000-template.md` 格式新增。

## 一次性配置（TRAE 侧）

1. 设置 → 规则 → 开启「将 AGENTS.md 包含在上下文中」
2. 设置 → Hooks → 运行方式选「本地自动运行」或「沙箱运行」
3. 开启一个全新会话验证状态注入
