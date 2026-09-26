# project-workflow-template

一套基于 TRAE 的项目全流程管理模板：把 **调研 → 设计 → 执行 → 上线运营** 四阶段流程，固化为一组可安装的文件、状态机制与斜杠命令。

本仓库是**模板的源码仓库**（用于持续优化模板），不是某个业务项目。使用它请见下方「使用」。

## 解决的问题

| 痛点 | 本模板的方案 |
|------|------------|
| 新项目不知道按什么流程走 | `template/AGENTS.md` 固化四阶段规范，会话自动加载 |
| 每次开会话忘了做到哪了 | `SessionStart` Hook 自动注入 `PROJECT_STATE.json` 状态 |
| 阶段之间没有门控，容易跳步 | `/advance` 校验 checklist，未完成拒绝推进 |
| 决策无留痕 | `docs/adr/` 决策记录模板 |

## 仓库结构

```
.
├── AGENTS.md           开发指引（给 AI/协作者）
├── README.md           本文件
├── CHANGELOG.md        优化记录
├── CONTRIBUTING.md     贡献约定
├── VERSION             模板版本（单一数据源）
├── docs/
│   ├── design.md       设计原理
│   ├── architecture.md 架构与数据流
│   ├── specs/          接口与格式规格
│   └── adr/            模板自身的决策记录
├── .github/            仓库级配置
│   ├── workflows/      ci.yml 校验与测试、release.yml 打包发布
│   ├── release.yml     Release notes 分类配置
│   └── PULL_REQUEST_TEMPLATE.md   PR 模板
├── template/           【载荷】被安装到用户项目的内容
├── scripts/
│   ├── install.sh      安装到单个项目
│   ├── setup-global.sh 全局安装
│   ├── upgrade.sh      把项目升级到新版本
│   ├── build-dist.sh   构建发布产物
│   ├── gen-manifest.sh 生成/校验模板清单
│   ├── validate.sh     校验模板完整性
│   └── setup-labels.sh 同步 GitHub PR 标签
└── tests/
    └── test_install.sh 安装端到端测试
```

## 使用

### 全局安装（推荐，一次配置，所有项目可用）

```bash
bash scripts/setup-global.sh
```

安装后模板置于 `~/.trae/templates/project-workflow/`，`/init-project`、`/status`、`/advance` 在**所有项目**可用。

### 安装到单个项目

```bash
bash scripts/install.sh /path/to/your/project
```

### TRAE 侧一次性设置

1. 设置 → 规则 → 开启「将 AGENTS.md 包含在上下文中」
2. 设置 → Hooks → 运行方式选「本地自动运行」或「沙箱运行」
3. 开新会话验证

安装后用户项目的完整使用说明见 `template/README.md`。

## 参与优化

见 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [AGENTS.md](AGENTS.md)。

改动后请运行：

```bash
bash scripts/validate.sh && bash tests/test_install.sh
```

## 许可证

见 [LICENSE](LICENSE)。
