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

## 发布

发布由 `.github/workflows/release.yml` 自动完成，只需打 tag 并推送：

```bash
git tag v0.2.0
git push origin v0.2.0
```

工作流会自动执行：发布前校验与测试 → 构建 `dist/` 产物 → 产物自检 → 创建 GitHub Release，
并附上 `bootstrap.sh`、`project-workflow-template.tar.gz`、`project-workflow-template.zip` 三个产物。

- tag 使用 `v<major>.<minor>.<patch>` 形式，与 `CHANGELOG.md` 的版本号对应
- 发布前请确认 `CHANGELOG.md` 的 `[Unreleased]` 已归入对应版本段
- 需要重跑时，可在 Actions 页面手动触发 `Release` 工作流并填入已存在的 tag（步骤幂等，会覆盖同名资产）

## 决策记录

涉及架构级选择（例如改变状态文件格式、增减阶段）时，请在 `docs/adr/` 新增一条记录，说明背景、备选方案与后果。

## 禁止

- 提交密钥、令牌、绝对路径、机器相关信息
- 在 `template/` 中引入开发层依赖
- 未经测试直接提交
