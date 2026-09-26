# 贡献指南

感谢参与优化本模板。请遵循以下约定，确保模板长期可维护。

## 核心原则

1. **载荷纯净**：`template/` 下的文件会原样交付给用户，只放用户需要的内容。
2. **上下文隔离**：模板开发相关的内容一律放仓库根或 `docs/`，不得进入 `template/`。
3. **改动闭环**：每次改动都要让校验与测试通过，并更新 `CHANGELOG.md`。

## 流程

1. 阅读 [AGENTS.md](AGENTS.md)（开发指引）与 [docs/design.md](docs/design.md)（设计原理）
2. 新建分支进行改动
3. 同步更新受影响的关联文件（状态结构、文档、脚本、校验）
4. 本地验证：
   ```bash
   bash scripts/validate.sh
   bash tests/test_install.sh
   ```
5. 更新 `CHANGELOG.md` 的 `[Unreleased]` 段
6. 提交并说明改动原因
7. 发起 Pull Request 并打上标签（见「PR 与标签」），`ci.yml` 会自动运行校验与测试

## 提交信息

采用简洁的语义化前缀：

| 前缀 | 含义 |
|------|------|
| `feat:` | 新增能力 |
| `fix:` | 修复问题 |
| `docs:` | 文档改动 |
| `refactor:` | 结构调整 |
| `test:` | 测试相关 |
| `chore:` | 杂项 |

例如：`feat: 为 /advance 增加阶段回退能力`

## PR 与标签

改动通过 Pull Request 合入 `main`，并打上标签——Release notes 就是按这些标签自动归类的
（配置见 `.github/release.yml`）。标签名与提交前缀保持一致，不必额外记一套词汇：

| 标签 | 含义 | 归入的分类 |
|------|------|-----------|
| `feat` | 新增能力 | 🚀 新增能力 |
| `fix` | 修复问题 | 🐛 修复 |
| `refactor` | 结构调整 | ♻️ 结构调整 |
| `test` | 测试相关 | ✅ 测试 |
| `docs` | 文档改动 | 📝 文档 |
| `chore` | 杂项 | 🔧 其他变更 |
| `breaking` | 存在破坏性变更 | ⚠️ 破坏性变更（优先展示） |
| `skip-changelog` | 不纳入 release notes | 不出现 |

- 每个 PR 至少打上前 6 个标签中的一个；`breaking` 与 `skip-changelog` 按需叠加
- 分类按 `.github/release.yml` 中的顺序匹配，PR 归入第一个命中的分类，`*` 为兜底
- 标签尚未创建或误删时，执行 `bash scripts/setup-labels.sh` 一键同步（需安装 `gh` 并完成 `gh auth login`，可重复执行）
- PR 模板见 `.github/PULL_REQUEST_TEMPLATE.md`

## 分支保护

`main` 是受保护分支（在仓库 **Settings → Rules → Rulesets → New branch ruleset** 中配置，
GitHub 现在以 Rulesets 承载此类规则）。约定如下，目的是「对贡献者严格、对维护者保留发布后门」：

| 规则 | 设置 | 理由 |
|------|------|------|
| Require a pull request before merging | 开，`Required approvals` 填 **0** | 所有改动走 PR，但不强制他人审批（单人仓库无法自审） |
| Require status checks to pass | 开，必需检查见下 | 校验与测试必须先通过 |
| Block force pushes | 开 | 防止改写已发布历史 |
| Restrict deletions | 开 | 防止误删 `main` |
| Require linear history | 不开 | 保留 merge/squash 的灵活性 |
| Bypass list | `Repository admin`，权限 **Always** | 让发布提交仍可直推（见下） |

**必需状态检查**（`Require status checks to pass` 里 `Add checks` 勾选，两个都要）：

```
校验与测试 (ubuntu-latest)
校验与测试 (macos-latest)
```

> 这两个名字来自 `.github/workflows/ci.yml` 中 `check` 任务的 `name: 校验与测试 (${{ matrix.os }})`
> ——矩阵会展开为两条独立检查。注意候选列表**只列出已跑过至少一次的检查**；若搜不到，先开个 PR
> 让 CI 跑一次再回来添加。

**唯一例外——发布提交直推 `main`**：发版时的版本对齐提交（见「发布」第 5 步）由仓库管理员经
bypass 直推 `main`，**不走 PR**。原因是这条提交本身就是为生成 release notes 而生，若走 PR 会
被归类进它自己的 release notes 里，不干净。除它之外的所有改动一律走 PR。

> 维护者注意：本仓库集成所用的 token 没有 `administration` 权限，无法用命令读写分支保护配置，
> 上述规则需在 GitHub 网页端设置。

## 发布

`VERSION` 是模板版本的**单一数据源**，`template/.trae/template-manifest.json` 与
`template/PROJECT_STATE.json` 里的版本号都由它派生。

> **硬约束：载荷（`template/`）一有改动，就必须把 `VERSION` 推进到一个尚未发布过的版本号。**
> 因为升级工具在「项目版本 == 模板版本」时会直接短路报「已是最新」（见
> [docs/specs/upgrade-tool.md §5](docs/specs/upgrade-tool.md)）。若载荷变了而版本号没变，
> 使用者执行 `/upgrade` 会被短路，**改动静默地升不上去**。

发布前先对齐版本：

1. 把 `CHANGELOG.md` 的 `[Unreleased]` 归入新版本段，如 `## [0.3.0] - YYYY-MM-DD`
2. 确认根目录 `VERSION` 与要发布的版本号一致（如 `0.3.0`）
3. 重新生成模板清单（会一并同步 `template/PROJECT_STATE.json` 的版本号）：

   ```bash
   bash scripts/gen-manifest.sh
   ```

4. 本地验证 —— `validate.sh` 第 8 节会强制校验「`VERSION` ↔ 清单 ↔ 载荷哈希」三者一致，
   漏做第 2、3 步会在这里被拦下：

   ```bash
   bash scripts/validate.sh && bash tests/test_install.sh
   ```

5. 提交版本对齐改动并**直推 `main`**（维护者经分支保护 bypass，见「分支保护」），随后打 tag 推送：

   ```bash
   git commit -am "chore: 发布 v0.3.0（CHANGELOG 版本对齐）"
   git push origin main
   git tag v0.3.0
   git push origin v0.3.0
   ```

工作流会自动执行：发布前校验与测试 → 构建 `dist/` 产物 → 产物自检 → 创建 GitHub Release，
并附上 `bootstrap.sh`、`project-workflow-template.tar.gz`、`project-workflow-template.zip` 三个产物。

- tag 使用 `v<major>.<minor>.<patch>` 形式，与 `CHANGELOG.md` 的版本号对应
- 发布前请确认 `CHANGELOG.md` 的 `[Unreleased]` 已归入对应版本段
- 产物资内容以 **git 跟踪文件**为准（`scripts/build-dist.sh` 基于 `git ls-files`）：新增文件需先 `git add` 才会进入产物，未跟踪文件（如 `.DS_Store`）不会被打包
- Release notes 由 GitHub 自动生成，并按 PR 标签归类（配置 `.github/release.yml`，约定见「PR 与标签」）；直接推送到 `main` 的提交不会出现在分类明细里
- 需要重跑时，可在 Actions 页面手动触发 `Release` 工作流并填入已存在的 tag（步骤幂等，会覆盖同名资产）

> ⚠️ **tag 所指的提交必须已包含 `.github/workflows/release.yml`**，否则 GitHub 不会触发发布工作流，也就不会创建 Release。
> GitHub Actions 对 push 事件只读取触发该事件的 ref 中实际存在的工作流文件，因此给工作流引入之前的历史提交补 tag 时，
> 不会自动发布，需改用 Actions 页面的手动触发（填入该已存在的 tag）。

> 📌 两个 `release.yml` 不要混淆：`.github/release.yml` 是 **Release notes 分类配置**（GitHub 官方约定文件名），
> `.github/workflows/release.yml` 是**发布工作流本体**。前者被 GitHub 读取用于归类 notes，不参与任何构建。

## Shell 约定

- 脚本中变量名后**紧接全角字符**时，必须写成 `${VAR}`，不能用 `$VAR`。
  原因：macOS 自带的 bash 3.2 会把高位字节（≥ `0x80`）并入变量名，导致
  `$rel（用户数据…）` 被解析为变量 `rel<0xEF>` 并触发 `set -u` 报错。CI 的
  macOS runner 正是 bash 3.2，因此这个错误必现。**该约定已由 `scripts/validate.sh` 第 10 节强制检查。**
- 新增脚本需同时登记到 `scripts/validate.sh` 第 1 节（必需文件）与第 5 节（语法检查）。
- **不要在 `$()` 内嵌的 heredoc 正文里写字面反引号。** 原因同上：bash 3.2 会把反引号误判为
  未闭合的引号，报 `unexpected EOF while looking for matching`，且**报错行号指向 heredoc 内部**，
  极难定位。需要剥离反引号时用 `chr(96)` 代替字面反引号。已实测：同一脚本在 Linux 的 bash 5 下
  不报错，只在 macOS 的 bash 3.2 下必现——这类错误只能靠 CI 的 macOS job 拦下。

## 扩展阶段数

模板固定四阶段（调研 → 设计 → 开发 → 运营），且 `validate.sh` 对阶段序、准出、推荐能力、阶段 README 结构都有硬校验。
**增减、重命名或调序阶段时，下列位置必须同步改动**，否则校验会失败：

| 改动位置 | 需要同步的内容 |
|---------|---------------|
| `template/PROJECT_STATE.json` | `stage_order` 与 `stages`（含 `name` / `dir` / `checklist`） |
| `template/<dir>/README.md` | 阶段目录与说明，须齐备「准入条件 / 推荐能力 / 准出产物」三节（第 12 节） |
| `template/AGENTS.md` | 首行「四阶段」表述、目录结构、「阶段说明」的标题（显示名）与「推荐技能 / 推荐工具」行（第 11 节） |
| `template/README.md`、`template/docs/README.md` | 首行表述与两张「阶段产物」汇总表 |
| `scripts/validate.sh` | 第 3 节的 `stage_order` 断言；第 9 / 11 / 12 节的 `STAGES` 列表 |
| `template/.trae/commands/advance.md` | 首阶段（discovery 的 Go/No-Go）与末阶段（operations 的归档）分支 |
| `template/.trae/commands/init-project.md` | 目录创建清单与四阶段状态模板 |
| `template/.trae/commands/status.md` | 「序号」示例（如 `2/4`） |

`template/.trae/scripts/inject_status.py` **无需改动**——它按 `stage_order` 与 `len(stage_order)` 通用计算，不硬编码阶段数。

改完执行：

```bash
bash scripts/gen-manifest.sh   # 载荷已变更，重新生成清单并同步版本号
bash scripts/validate.sh       # 第 3 / 9 / 11 / 12 节会逐项核对上述一致性
```

> 阶段集合是模板的**结构约定**，不是运行时可选项。若只是想调整某阶段的产物或推荐能力，改对应 README 与状态文件即可，无需动阶段序。

## 决策记录

涉及架构级选择（例如改变状态文件格式、增减阶段）时，请在 `docs/adr/` 新增一条记录，说明背景、备选方案与后果。

## 禁止

- 提交密钥、令牌、绝对路径、机器相关信息
- 在 `template/` 中引入开发层依赖
- 未经测试直接提交
