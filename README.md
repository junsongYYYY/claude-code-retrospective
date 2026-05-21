# Agent Retrospective 自进化复盘系统

把 AI Agent 在本地项目中踩过的坑，沉淀成后续任务会直接读取的项目经验。核心闭环：

```text
任务开始：直接读取正式经验文件
任务结束：复盘产生经验
明确可复用：写入分类经验文件
不确定：写入 inbox.md
定期维护：用 lesson-curator 清理 inbox
```

## 核心结构

- `AGENT_LESSONS.md`：最高频、最稳定、跨任务通用的经验索引。
- `docs/agent_memory/testing.md`、`dependencies.md`、`mistakes-to-avoid.md`、`project-conventions.md`：正式分类经验库。
- `docs/agent_memory/inbox.md`：不确定、边界模糊、暂时无法判断的候选复盘。
- `docs/agent_memory/archive/`：过期或低频复盘归档。
- Agent 全局 `agent-retrospective` skill：任务结束时生成复盘并写回项目经验。
- Agent 全局 `lesson-curator` skill：定期人工整理 `inbox.md`。

## 目录结构

```text
<project-root>
├── CLAUDE.md              # 项目规则（含 retro 受控区块）
├── AGENT_LESSONS.md       # 高频通用经验索引
├── README.md              # 本文件
├── scripts
│   └── init_agent_retro.ps1   # 新项目一键接入脚本
├── .claude/retro/         # session 状态文件（已加入 .gitignore）
│   ├── session_state.json # 当前对话的信号采集与评分
│   └── task_events.jsonl  # 工具调用事件日志
└── docs
    ── agent_memory
        ├── README.md
        ├── inbox.md
        ├── testing.md
        ├── dependencies.md
        ├── project-conventions.md
        ├── mistakes-to-avoid.md
        └── archive/
```

## 日常使用

### 任务开始前

复杂任务开始前直接读取：

```
AGENT_LESSONS.md
docs/agent_memory/testing.md
docs/agent_memory/dependencies.md
docs/agent_memory/mistakes-to-avoid.md
docs/agent_memory/project-conventions.md
```

默认不读取 `inbox.md`。`inbox.md` 只在整理候选经验时读取。

### 任务结束前

如果本轮出现以下任一情况，需要使用 `agent-retrospective` 做复盘：

- 命令失败。
- 测试失败后修复成功。
- 重复搜索、重复编辑或多次切换方案。
- 用户纠正了范围、事实来源、措辞或验收标准。
- 修改了依赖、环境配置、工具设置、记忆规则或项目约定。
- 因为漏看入口、命令或 source of truth 而绕路。

复盘写回规则：

```
明确可复用、有下次优先路径和下次避免
  -> 写入分类文件 ## Active，并以 [触发: keyword1, keyword2, ...] 开头

不确定、边界模糊、暂时无法判断
  -> 写入 docs/agent_memory/inbox.md，并填写 触发关键词

高频/跨任务通用
  -> 写入 AGENT_LESSONS.md 作为索引
```

## Hook 机制（自动评分触发）

系统通过全局 hooks 实现**自动评分与复盘门控**，无需手动触发：

| Hook | 触发时机 | 脚本 | 作用 |
|---|---|---|---|
| `PostToolUse` | 每次 `Bash` / `Edit` / `Write` 工具调用后 | `score_retrospective.ps1` | 采集执行信号，累加评分，写入 `session_state.json` |
| `Stop` | 对话结束时 | `retro_gate.ps1` | 读取评分，按阈值决定是否触发复盘 |

评分信号采集规则：

- **命令失败**：+3 分
- **测试运行**：+2 分；先失败后成功：额外 +4 分
- **依赖变更**（install 命令或依赖文件修改）：+3 分
- **配置文件修改**（JSON/YAML/.env/CLAUDE.md 等）：+2+1 分
- **普通文件编辑/写入**：+2 分
- **修改超过 5 个文件**：额外 +2 分
- **工具调用超过 8 次且有问题**：额外 +2 分

复盘门控阈值：

- **0-3 分**：不复盘
- **4-6 分**：微日志（不打扰用户）
- **7-10 分**：简短复盘
- **11-14 分**：完整复盘
- **15+ 分**：强制复盘

## 给新项目接入

初始化或补齐一个项目：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <project-root>\scripts\init_agent_retro.ps1 -ProjectRoot D:\path\to\project
```

只检查不修改：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <project-root>\scripts\init_agent_retro.ps1 -ProjectRoot D:\path\to\project -CheckOnly
```

初始化脚本会创建或补齐：

- `CLAUDE.md`（含 `retro` 受控区块）
- `AGENT_LESSONS.md`
- `docs/agent_memory/` 下的所有分类文件
- `.claude/retro/` 目录及 session 状态文件

已有文件不会被覆盖。已有 `CLAUDE.md` 只更新 `<!-- retro:begin -->` 到 `<!-- retro:end -->` 之间的受控区块。

## Lesson Curator

`lesson-curator` 是定期人工清理 `inbox.md` 的技能。

使用场景：

- 用户说"整理 inbox"、"清理经验库候选"。
- `inbox.md` 中候选太多，需要判断哪些应升级或删除。

判断结果：

- `Promote`：候选已确认有价值，移动到分类文件。
- `Delete`：候选是一次性、过时或无复用价值，删除。
- `Keep`：证据不足，继续留在 `inbox.md`。

## 多线程工作方式

多个任务并行时，各任务直接读取同一组稳定经验文件。系统不生成共享的任务前快照文件，因此不会出现多个对话同时刷新同一个文件、互相覆盖的问题。

## 维护原则

- 经验必须可执行，不能只写"本次踩了坑"。
- 明确可复用的经验直接进入分类文件，并以 `[触发: ...]` 开头。
- `inbox.md` 只保存不确定候选，并填写 `触发关键词`。
- `AGENT_LESSONS.md` 只保存高频/跨任务通用索引。
- 定期用 `lesson-curator` 清理 `inbox.md`。
- 不记录 API Key、token、cookie、完整 `.env` 或完整 stdout/stderr。

## 最短操作路径

当前项目检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\init_agent_retro.ps1 -ProjectRoot . -CheckOnly
```

新项目接入：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <project-root>\scripts\init_agent_retro.ps1 -ProjectRoot D:\path\to\project
```
