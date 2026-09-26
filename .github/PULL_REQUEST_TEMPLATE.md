## 变更说明

<!-- 这个 PR 做了什么、为什么这么做 -->

## 验证

- [ ] `bash scripts/validate.sh` 通过
- [ ] `bash tests/test_install.sh` 通过
- [ ] `CHANGELOG.md` 的 `[Unreleased]` 段已更新

## 自检清单

- [ ] `template/` 中未混入开发层内容（载荷纯净）
- [ ] 新增文件已 `git add`（未跟踪文件不会进入发布产物）
- [ ] 涉及架构级决策时，已新增 `docs/adr/NNN-*.md`

## 发布标签

<!-- 请为本 PR 打上用于生成 release notes 的标签，约定见 CONTRIBUTING.md「PR 与标签」 -->

- [ ] 已打上 `feat` / `fix` / `docs` / `refactor` / `test` / `chore` 之一
- [ ] 存在破坏性变更时已打上 `breaking`
- [ ] 不希望出现在 release notes 中时已打上 `skip-changelog`

## 关联 Issue

<!-- 例如：Closes #123 -->
