# 仓库开发指引（AGENTS.md）

> **本文件是给「开发/维护本模板仓库」的 AI 与协作者看的，不是给使用本模板的最终用户看的。**
> 用户项目里被安装的那份规范在 `template/AGENTS.md`，两者用途不同，请勿混淆。

## 这个仓库是什么

`project-workflow-template` 是一套基于 TRAE 的**项目全流程管理模板**，把「调研 → 设计 → 执行 → 上线运营」四阶段流程固化为一组可安装的文件与脚本。

仓库分为两层：

| 层 | 路径 | 用途 |
|----|------|------|
| **开发层** | 仓库根（`AGENTS.md`、`README.md`、`docs/`、`scripts/`、`tests/`） | 维护模板本身 |
| **载荷层** | `template/` | 真正被安装到用户项目里的内容 |

**核心约束：`template/` 下的内容会原样交付给用户，改动它等于改动用户的使用体验。**

## 关键设计（改动前必读）

1. **状态单一数据源**：用户项目状态全部存在 `template/PROJECT_STATE.json`，不允许把状态散落到其他文件。
2. **两种 AGENTS.md 严格隔离**：
   - 仓库根 `AGENTS.md`（本文件）= 开发指引
   - `template/AGENTS.md` = 用户项目的流程规范
   - **绝不可把开发内容写进 `template/AGENTS.md`**，否则会污染用户项目。
3. **路径自适应**：`scripts/install.sh` 需同时支持两种运行位置：
   - 仓库内：`scripts/install.sh`，载荷在 `../template`
   - 全局模板目录内：`install.sh`，载荷在同级 `.`
4. **命令引用**：`template/.trae/commands/init-project.md` 中引用的安装脚本路径，必须与 `scripts/setup-global.sh` 实际安装的路径一致。

## 目录职责

```
AGENTS.md            本文件：开发指引
README.md            仓库说明（面向人类）
CHANGELOG.md         优化记录，每次改动都要追加
CONTRIBUTING.md      贡献流程与约定
VERSION              模板版本单一数据源（清单与 PROJECT_STATE 的版本由此派生）
docs/design.md       设计原理：为什么这么设计
docs/architecture.md 各文件职责与数据流
docs/specs/          接口与格式规格（如模板清单）
docs/adr/            模板自身的架构决策记录（不是用户项目的）
template/            【载荷】被安装到用户项目的内容
scripts/install.sh   把 template/ 安装到目标项目
scripts/setup-global.sh 全局安装（模板 + 斜杠命令）
scripts/upgrade.sh   把项目升级到新版本（默认只读，--apply 落盘）
scripts/build-dist.sh 构建发布产物（仅打包 git 跟踪文件）
scripts/gen-manifest.sh 生成/校验模板清单（版本取自 VERSION）
scripts/validate.sh  校验模板完整性
scripts/setup-labels.sh 同步 GitHub PR 标签
tests/               端到端测试
.github/release.yml  Release notes 分类配置（按 PR 标签）
.github/workflows/   持续集成（校验 + 测试）与发布（打 tag 自动打包）
```

## 改动工作流（必须遵守）

1. **先读** `docs/design.md` 与 `docs/architecture.md`，理解设计意图
2. **改动**时同步更新受影响的其他文件（例如改了状态结构，要同步 `template/AGENTS.md`、命令文档、`validate.sh`）
3. **改完必须运行**校验与测试，全部通过才算完成：
   ```bash
   bash scripts/validate.sh
   bash tests/test_install.sh
   ```
4. **记录**变更到 `CHANGELOG.md`
5. **涉及架构级决策**时，新增一条 `docs/adr/NNN-*.md`
6. **涉及接口或格式契约**（如模板清单、状态结构）时，同步更新 `docs/specs/` 下的对应规格，并确保其 CI 校验通过

## 禁止事项

- 禁止把仓库开发相关的内容写入 `template/` 下的任何文件
- 禁止在 `template/` 中引入对仓库根或 `scripts/` 的绝对路径依赖
- 禁止在模板中硬编码用户名、绝对路径、机器相关信息
- 禁止提交密钥、令牌等敏感信息

## 自检清单

改动后自问：

- [ ] `bash scripts/validate.sh` 通过
- [ ] `bash tests/test_install.sh` 通过
- [ ] `template/` 中没有出现开发层内容
- [ ] `CHANGELOG.md` 已更新
- [ ] 安装到空目录后 `/init-project`、`/status`、`/advance` 逻辑仍自洽
