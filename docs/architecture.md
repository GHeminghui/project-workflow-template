# 架构与数据流

本文说明各文件职责与运行时的数据流，便于定位改动点。

## 1. 静态结构

```
project-workflow-template/          仓库根 = 开发层
├── AGENTS.md                       开发指引（TRAE 打开本仓库时自动加载）
├── README.md / CHANGELOG.md / CONTRIBUTING.md / LICENSE
├── VERSION                         模板版本单一数据源
├── docs/                           开发层文档
│   ├── design.md                   设计原理
│   ├── architecture.md             架构与数据流（本文件）
│   ├── specs/                      接口与格式规格
│   └── adr/                        架构决策记录
├── scripts/                        维护与安装脚本
│   ├── install.sh                  安装载荷到目标项目（路径自适应）
│   ├── setup-global.sh             全局安装（载荷 + 命令）
│   ├── upgrade.sh                  把项目升级到新版本（默认只读）
│   ├── build-dist.sh               构建发布产物（仅打包 git 跟踪文件）
│   ├── gen-manifest.sh             生成/校验模板清单
│   ├── validate.sh                 校验模板完整性
│   └── setup-labels.sh             同步 GitHub PR 标签
├── tests/test_install.sh           安装端到端测试
├── .github/                        仓库级配置
│   ├── release.yml                 Release notes 分类配置（按 PR 标签）
│   ├── PULL_REQUEST_TEMPLATE.md    PR 模板
│   └── workflows/                  持续集成与发布
│       ├── ci.yml                  push/PR 时校验与测试
│       └── release.yml             tag 触发打包并创建 Release
└── template/                       载荷层 = 交付给用户的内容
    ├── AGENTS.md                   用户项目流程规范（会话自动加载）
    ├── PROJECT_STATE.json          用户项目状态（唯一数据源）
    ├── README.md                   面向用户的使用说明
    ├── .gitignore
    ├── .trae/
    │   ├── hooks.json              SessionStart 事件配置
    │   ├── template-manifest.json  模板清单（文件边界 + 基线哈希 + 版本）
    │   ├── scripts/inject_status.py 状态渲染脚本
    │   └── commands/               /init-project /status /advance /upgrade
    ├── 00-discovery/ ~ 03-operations/  四阶段目录 + 说明
    └── docs/                       用户项目的文档与 ADR 模板
```

## 2. 运行时数据流

### 2.1 会话启动（状态恢复）

```
用户开新会话
   │
   ▼
TRAE 加载 template/AGENTS.md（若已开启该设置）  ──► 注入「流程规范」
   │
   ▼
SessionStart Hook 触发
   │  command: python3 .trae/scripts/inject_status.py
   ▼
inject_status.py 读取 PROJECT_STATE.json
   │  渲染：当前阶段 / 状态 / 下一步 / 本阶段清单
   ▼
stdout 作为 additionalContext 注入  ──► AI 获知「当前进度」
   │
   ▼
AI 具备「规范 + 进度」完整上下文，可继续工作
```

**关键点**：规范来自 `AGENTS.md`（静态），进度来自 Hook（动态）。两者缺一不可。

### 2.2 阶段推进（/advance）

```
用户输入 /advance
   │
   ▼
AI 读取 PROJECT_STATE.json
   │
   ▼
校验当前阶段 checklist 是否全 done
   ├── 否 ──► 列出未完成项，拒绝推进
   └── 是 ──► 更新状态：
              · 当前阶段 status=done, completed_at
              · 下一阶段 status=in_progress, started_at
              · 切换 current_stage
              · 刷新 last_updated
                  │
                  ▼
              写入 PROJECT_STATE.json + git commit
                  │
                  ▼
              告知用户新阶段与下一步
```

### 2.3 安装（install.sh）

```
scripts/install.sh <目标目录>
   │
   ▼
定位载荷：
   · 仓库内运行   → 载荷 = ../template
   · 全局内运行   → 载荷 = 同级目录（含 PROJECT_STATE.json 的目录）
   │
   ▼
按清单复制载荷文件到目标目录（默认跳过已存在文件）
   │
   ▼
用 python3 写入 project_name / 日期到 PROJECT_STATE.json
   │
   ▼
git init（若目标未初始化）
```

### 2.4 发布（release.yml）

```
推送 tag（v*）或手动触发
   │
   ▼
检出该 tag（fetch-depth: 0，供自动生成 release notes）
   │
   ▼
发布前门控：validate.sh + test_install.sh
   │  任一失败 ──► 中止，不产出任何产物
   ▼
构建分发产物：build-dist.sh
   │  dist/bootstrap.sh / *.tar.gz / *.zip
   ▼
产物自检
   │  · bootstrap.sh 装入临时目录并跑 inject_status.py
   │  · 校验压缩包内含 template/PROJECT_STATE.json
   ▼
gh release create（--generate-notes --verify-tag）
   │  若 Release 已存在 ──► gh release upload --clobber
   ▼
Release 页面：按 PR 标签归类的 notes + 三个分发产物
```

**关键点**：门控在打包之前，坏 tag 不会产出产物；Release 步骤幂等，失败重跑不会因「Release 已存在」二次报错。产物内容以 `git ls-files` 跟踪文件为准，未跟踪文件（如 `.DS_Store`）不会进入 `bootstrap.sh` 或压缩包，本地与 CI 构建结果一致。notes 的分类规则来自 `.github/release.yml`，依据 PR 标签归类。

### 2.5 升级（upgrade.sh）

```
在项目内运行 /upgrade 或 upgrade.sh [目标目录]
   │
   ▼
定位载荷（同 install.sh）：仓库内 -> ../template；全局模板目录内 -> 同级
   │
   ▼
读两份清单：项目内基线（判「是否被改过」）+ 载荷清单（判「是否已是最新」）
   │  版本相同 ──► 报「已是最新」并退出，不逐文件扫描
   ▼
逐文件判定 → 覆盖 / 恢复 / 待合并 / 不动 / 未变更，输出报告
   │  默认只读，不写任何文件；退出码 1 表示存在待处理项
   ▼
--apply 落盘
   │  · 覆盖未改动文件、恢复缺失文件
   │  · --force 才覆盖「被改过」的文件（先备份 .bak）
   │  · 替换项目内清单，基线前进到新版本
   │  · 字段级更新 PROJECT_STATE.json 的 template_version（绝不整体覆盖）
   ▼
下次升级即可精确判定
```

**关键点**：默认只读、且永不交互——它同时被人与 AI（经 `/upgrade` 命令）调用，人机确认由命令文档承担。判定**必须用两份清单**：只跟新版比会把用户的正常改动误判为「被改过」。

## 3. 文件职责速查

| 文件 | 职责 | 改动时需同步 |
|------|------|-------------|
| `template/PROJECT_STATE.json` | 状态结构与初始值 | `template/AGENTS.md`、`commands/*`、`validate.sh` |
| `template/AGENTS.md` | 流程规范 | `template/PROJECT_STATE.json`、阶段 README |
| `template/.trae/hooks.json` | 事件绑定 | `template/.trae/scripts/*` |
| `inject_status.py` | 状态渲染 | `PROJECT_STATE.json` 结构 |
| `commands/init-project.md` | 安装入口 | `scripts/setup-global.sh` 的安装路径 |
| `commands/upgrade.md` | 升级入口 | `scripts/setup-global.sh` 的安装路径、`docs/specs/upgrade-tool.md` |
| `scripts/install.sh` | 载荷分发 | `template/` 文件清单 |
| `scripts/setup-global.sh` | 全局安装 | `commands/init-project.md`、`commands/upgrade.md` 的引用路径 |
| `scripts/upgrade.sh` | 升级项目内模板文件 | `docs/specs/upgrade-tool.md`、`VERSION`、模板清单 |
| `scripts/validate.sh` | 完整性校验（含清单一致性、阶段准出一致性） | `template/` 结构、状态字段、模板清单、阶段准出 |
| `scripts/gen-manifest.sh` | 生成/校验模板清单 | `VERSION`、`template/.trae/template-manifest.json`、`validate.sh` |
| `VERSION` | 模板版本单一数据源 | `scripts/gen-manifest.sh`、`CONTRIBUTING.md` 发版流程 |
| `scripts/setup-labels.sh` | 同步 PR 标签（供 release notes 归类） | `.github/release.yml`、`CONTRIBUTING.md` 标签约定 |
| `scripts/build-dist.sh` | 构建分发产物（以 git 跟踪文件为来源） | `.github/workflows/release.yml` |
| `.github/workflows/ci.yml` | 持续集成（push/PR 校验与测试） | `scripts/validate.sh`、`tests/test_install.sh` |
| `.github/workflows/release.yml` | 发布（tag 触发打包与 Release） | `scripts/build-dist.sh`、tag 命名规范 |
| `.github/release.yml` | Release notes 分类配置（按 PR 标签归类） | `CONTRIBUTING.md` 的标签约定 |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR 模板 | `CONTRIBUTING.md` 的流程与标签约定 |
| `docs/specs/template-manifest.md` | 模板清单的数据契约（路径、字段、生成与校验） | `scripts/install.sh`、`scripts/gen-manifest.sh`、清单一致性校验 |
| `docs/specs/upgrade-tool.md` | 升级工具的行为契约（调用方式、动作策略、报告、退出码） | `scripts/upgrade.sh`、`template/.trae/commands/upgrade.md` |

## 4. 路径自适应约定

`install.sh` 必须同时支持两种运行位置，这是分发正确性的关键：

| 运行位置 | 脚本路径 | 载荷位置 |
|---------|---------|---------|
| 仓库内 | `scripts/install.sh` | `../template` |
| 全局模板目录 | `~/.trae/templates/project-workflow/install.sh` | 同级 `.` |

判断方式（见脚本实现）：
- 若 `脚本目录/../template` 存在 → 载荷为 `../template`
- 否则若 `脚本目录/PROJECT_STATE.json` 存在 → 载荷为脚本目录自身
