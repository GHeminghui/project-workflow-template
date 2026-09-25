# 架构与数据流

本文说明各文件职责与运行时的数据流，便于定位改动点。

## 1. 静态结构

```
project-workflow-template/          仓库根 = 开发层
├── AGENTS.md                       开发指引（TRAE 打开本仓库时自动加载）
├── README.md / CHANGELOG.md / CONTRIBUTING.md / LICENSE
├── docs/                           设计原理、架构、ADR
├── scripts/                        维护与安装脚本
│   ├── install.sh                  安装载荷到目标项目（路径自适应）
│   ├── setup-global.sh             全局安装（载荷 + 命令）
│   └── validate.sh                 校验模板完整性
├── tests/test_install.sh           安装端到端测试
├── .github/workflows/ci.yml        持续集成（校验 + 测试）
└── template/                       载荷层 = 交付给用户的内容
    ├── AGENTS.md                   用户项目流程规范（会话自动加载）
    ├── PROJECT_STATE.json          用户项目状态（唯一数据源）
    ├── README.md                   面向用户的使用说明
    ├── .gitignore
    ├── .trae/
    │   ├── hooks.json              SessionStart 事件配置
    │   ├── scripts/inject_status.py 状态渲染脚本
    │   └── commands/               /init-project /status /advance
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
              · 刷新 next_action / last_updated
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

## 3. 文件职责速查

| 文件 | 职责 | 改动时需同步 |
|------|------|-------------|
| `template/PROJECT_STATE.json` | 状态结构与初始值 | `template/AGENTS.md`、`commands/*`、`validate.sh` |
| `template/AGENTS.md` | 流程规范 | `template/PROJECT_STATE.json`、阶段 README |
| `template/.trae/hooks.json` | 事件绑定 | `template/.trae/scripts/*` |
| `inject_status.py` | 状态渲染 | `PROJECT_STATE.json` 结构 |
| `commands/init-project.md` | 安装入口 | `scripts/setup-global.sh` 的安装路径 |
| `scripts/install.sh` | 载荷分发 | `template/` 文件清单 |
| `scripts/setup-global.sh` | 全局安装 | `commands/init-project.md` 引用路径 |
| `scripts/validate.sh` | 完整性校验 | `template/` 结构与状态字段 |
| `.github/workflows/ci.yml` | 持续集成 | `scripts/validate.sh`、`tests/test_install.sh` |

## 4. 路径自适应约定

`install.sh` 必须同时支持两种运行位置，这是分发正确性的关键：

| 运行位置 | 脚本路径 | 载荷位置 |
|---------|---------|---------|
| 仓库内 | `scripts/install.sh` | `../template` |
| 全局模板目录 | `~/.trae/templates/project-workflow/install.sh` | 同级 `.` |

判断方式（见脚本实现）：
- 若 `脚本目录/../template` 存在 → 载荷为 `../template`
- 否则若 `脚本目录/PROJECT_STATE.json` 存在 → 载荷为脚本目录自身
