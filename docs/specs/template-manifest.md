# 模板清单规格（`.trae/template-manifest.json`）

> **状态**：清单的**生成与一致性校验已实现**（`scripts/gen-manifest.sh`、`validate.sh` 第 8 节）；
> 升级工具尚未实现。本文冻结清单文件的路径与格式，作为接口契约。
> 决策背景见 [ADR-002](../adr/002-upgrade-strategy.md)。

## 1. 为什么需要这份清单

`install.sh` 采用复制式分发：把载荷逐字节复制进用户项目，此后项目与上游没有任何链接。要做升级，必须先能回答两个问题：

1. **哪些文件属于模板？** —— 否则无法界定"升级该动什么"
2. **这些文件在安装时是什么内容？** —— 否则无法判断"用户是否改过它"

这份清单同时回答两者：文件列表给出边界，逐文件哈希给出基线。

## 2. 位置

| 环境 | 路径 |
|------|------|
| 载荷侧 | `template/.trae/template-manifest.json` |
| 项目侧 | `<项目根>/.trae/template-manifest.json` |

选择 `.trae/` 的原因：它与 `hooks.json`、`scripts/`、`commands/` 同属项目内的 TRAE 元数据，语义一致；且 `template/.gitignore` 中已有 `!.trae/`，清单会被项目自身的 git 自然追踪，基线随项目版本化。

**因为 `install.sh` 是逐字节复制，两侧内容在安装瞬间完全相同。** 这一点是"一份文件同时充当载荷声明与项目基线"的前提——不需要两份文件。

## 3. 格式

JSON。理由与 `PROJECT_STATE.json` 一致（见 [design.md](../design.md) 主线三）：脚本需可读可写，结构化格式解析不易出错。

### 3.1 顶层字段

| 字段 | 类型 | 必填 | 语义 |
|------|------|------|------|
| `schema_version` | int | ✅ | **清单格式**的版本，用于将来格式演进 |
| `template_name` | string | ✅ | 模板名，用于区分 fork 或改名后的来源 |
| `template_version` | string | ✅ | **模板**的语义化版本，与 `CHANGELOG.md` 版本段及 git tag 对齐 |
| `files` | array | ✅ | 模板文件列表，见 3.2 |

**`schema_version` 与 `template_version` 必须分为两个字段。** 这不是冗余——`.trae/hooks.json` 里的 `{"version": 1}` 是 TRAE 的配置 schema 版本，在 ADR-002 的背景调查中曾被误读为模板版本，导致"项目不知道自己来自哪个版本"。字段名必须自解释，不能留下这种歧义空间。

**不设 `generated_at`。** `template_version` 已能唯一定位版本，加时间戳只会让清单每次重新生成都产生无意义的 diff。

**不设 `directories`。** 现有需创建的目录（`docs/adr`、`.trae/scripts`、`.trae/commands`、四个阶段目录）都已有文件落在 `files` 中，其父目录集合已完整覆盖，复制时自动 `mkdir -p` 即可。若将来需要交付空目录，再借 `schema_version` 演进补充。

### 3.2 `files` 项

| 字段 | 类型 | 必填 | 语义 |
|------|------|------|------|
| `path` | string | ✅ | 相对项目根的路径，正斜杠分隔 |
| `sha256` | string | ✅ | 该文件在此模板版本中的内容哈希，纯小写 hex |
| `mode` | string | ⬜ | 缺省 `manage`；`create-only` 表示**仅在文件不存在时写入** |

`mode` 的取值：

- `manage`（默认）—— 常规模板文件。升级时参与哈希比对，未被改动则可覆盖。
- `create-only` —— 承载用户数据的文件。**永不覆盖**；仅当文件不存在时写入初始内容。当前唯一使用者是 `PROJECT_STATE.json`。

`PROJECT_STATE.json` 的 `sha256` 记录的是**初始模板状态**的哈希。它不用于覆盖判断（`create-only` 永不覆盖），用途是让升级工具能区分"用户从未动过"与"用户已推进过"。

### 3.3 示例

```json
{
  "schema_version": 1,
  "template_name": "project-workflow-template",
  "template_version": "0.2.0",
  "files": [
    { "path": ".gitignore", "sha256": "6b1f3a9c2d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8" },
    { "path": ".trae/commands/advance.md", "sha256": "1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f809" },
    { "path": ".trae/commands/init-project.md", "sha256": "2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a" },
    { "path": ".trae/hooks.json", "sha256": "3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a2b" },
    { "path": "AGENTS.md", "sha256": "4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c" },
    { "path": "PROJECT_STATE.json", "mode": "create-only", "sha256": "5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d" },
    { "path": "00-discovery/README.md", "sha256": "6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e" }
  ]
}
```

`files` 按 `path` 以字节序升序排列，保证 diff 稳定。示例为节选，实际列出全部模板文件。

## 4. 硬约束

清单同时是「载荷的一部分」与「项目侧的基线记录」，属于**双重身份文件**。这与 ADR-002 中确认的 `PROJECT_STATE.json` 属同一类，必须遵守：

1. **清单不记录自身哈希。** `files` 必须排除 `.trae/template-manifest.json` 自身，否则构成自引用。
2. **清单不受常规复制或 `--force` 覆盖。** 若被新版本哈希覆盖，项目侧基线即丢失，"哪些文件被用户改过"将永远无法判断。
3. **清单只能由升级工具在升级完成后替换**，使基线前进到新版本。这是唯一允许修改它的路径。

> 这三条不是理论风险。ADR-002 的背景中，`PROJECT_STATE.json` 因同类的双重身份被 `--force` 清空，已实测造成进度数据丢失。

## 5. 生成规则

| 项 | 规则 |
|----|------|
| 来源 | 以 **`git ls-files`** 为准（与 `scripts/build-dist.sh` 的技术选择一致），确保只纳入被跟踪文件 |
| 排除 | 清单自身（`.trae/template-manifest.json`） |
| 排序 | `files` 按 `path` 升序，保证 diff 稳定 |
| 哈希 | 对文件原始字节计算 SHA-256，输出小写 hex |
| 时机 | **随版本预生成并提交**，不在安装时计算 |

**为什么必须预生成**：若在安装时现算，则"需要计算哪些文件"本身仍需要一个声明源，绕回原点。预生成让清单成为唯一的边界声明源，`install.sh` 只需照单复制。

## 6. CI 校验（必需）

`validate.sh` 或 CI 必须校验：**清单中每个 `sha256` 与该载荷文件的实际内容一致，且 `files` 与 `git ls-files` 的实际集合一致（排除清单自身）**。

这一项不是锦上添花。一旦清单与载荷漂移，升级时所有文件都会被误判为"被用户改过"，升级功能将**全面失效且静默**。此类错误必须让构建失败，而不能等使用者踩到。

## 7. 生命周期

| 场景 | 对清单的动作 |
|------|-------------|
| 首次安装 | 随载荷复制进项目（此时其内容即基线） |
| `install.sh` 常规运行 | **不覆盖** |
| `install.sh --force` | **不覆盖**（`--force` 只作用于 `mode: manage` 的文件） |
| 升级完成后 | 由升级工具用新载荷的清单替换，基线前进到新版本 |

附带收益：引入 `mode` 后，`install.sh` 中为 `PROJECT_STATE.json` 手写的"存在则跳过"特判代码可退化为按 `mode` 统一处理——**边界从代码移到数据**。

## 8. 升级判定规则（供升级工具实现时遵循）

给定某文件的三种状态：

| 项目内文件相对基线的状态 | 判定 | 处理 |
|------------------------|------|------|
| 哈希一致 | 未被用户改动 | `manage` 可覆盖；`create-only` 不动 |
| 哈希不一致 | 用户改过 | **不覆盖**，输出 diff 供人工决定 |
| 文件缺失 | 视为"用户改过"（可能是有意删除） | **不自动恢复**，输出提示 |

升级默认只报告（dry-run），落盘需显式确认；这一策略由 ADR-002 决策 4 确定。本规格只约束清单的读写，不约束升级工具的交互形态。

## 9. 开放问题

| # | 问题 | 备注 |
|---|------|------|
| 1 | 用户新增的文件，若在某版本被正式收编为模板文件，如何处理？ | 首次纳入时该项目会命中"文件缺失→不自动恢复"或"内容不一致"，需人工介入 |
| 2 | 升级工具是否应支持 `--force` 覆盖被用户改过的文件？ | 倾向支持，但必须显式且带备份 |
| 3 | `template_name` 在 fork/改名后是否需要同步机制？ | 当前仅作标识，无强制约束 |

## 10. 相关

- [ADR-002: 模板升级策略](../adr/002-upgrade-strategy.md)
- [docs/design.md](../design.md)
- [docs/architecture.md](../architecture.md)
