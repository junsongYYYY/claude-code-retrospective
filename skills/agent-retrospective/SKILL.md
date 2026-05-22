---
name: agent-retrospective
description: 复杂任务后的结构化复盘。当任务出现报错、重复尝试、测试先失败后成功、依赖/配置变更时触发。支持 git diff 语义分析和经验适应度追踪。
when_to_use: 复盘, retrospective, agent-retrospective, 任务总结, 经验沉淀
---

# Agent Retrospective

## 触发条件

- Bash 命令失败（非 0 退出码）
- 同类命令重复尝试
- 测试先失败后成功
- 修改代码文件超过 5 个
- 修改配置文件或依赖文件
- 安装/升级/删除依赖
- 用户明确要求"记住"或"下次别这样"

## 不触发场景

- 普通问答、概念解释
- 简单查文件
- 单文件小改且无报错
- 纯文本润色

## 工作流程

1. 读取 `.claude/retro/session_state.json`（如有）获取任务信号
2. 执行 git diff 语义分析（见下方专节）
3. 回顾本次任务执行过程，识别：
   - 失败命令及原因
   - 重复尝试的无效路径
   - 用户纠偏点
   - 测试失败后成功的关键转折
4. 按以下模板生成复盘
5. 判断是否需要更新经验适应度（见下方专节）

## Git Diff 语义分析

在生成复盘之前，执行以下检查：

1. 运行 `git diff --stat` 查看变更文件概览
2. 运行 `git diff --unified=3` 查看具体变更内容
3. 分析以下维度：
   - **意图匹配**：代码变更是否真正解决了任务目标？有无偏离需求的变更？
   - **变更集中度**：是否集中在少数几个文件？还是散落在大量文件中？（集中 = 好，分散 = 可能过度修改）
   - **删除/新增比**：大量删除可能意味着破坏性变更，大量新增可能意味着过度设计
   - **隐藏约束**：是否有被忽略的边界条件或依赖关系？
4. 将分析结论写入复盘的"原因分析"和"下次优化路径"中

如果当前项目不在 git 仓库中，跳过本环节。

## 复盘输出模板

### 任务复盘

**任务结果：**
- 是否完成：
- 验证方式：

**执行过程中的问题：**
- 报错：
- 走弯路：
- 重复尝试：
- 无效路径：

**Git Diff 分析：**
- 变更概览（文件数、增减行数）：
- 意图匹配度：
- 变更集中度评价：
- 风险点（如有）：

**原因分析：**
- 根本原因：
- 为什么一开始没有直接定位：

**下次优化路径：**
- 下次优先做：
- 下次避免做：
- 可复用命令：
- 需要提前检查的文件：

**是否写入经验库：**
- 建议：是 / 否
- 理由：
- 建议写入位置：`docs/agent_memory/inbox.md` / `dependencies.md` / `testing.md` / `mistakes-to-avoid.md` / `config.md`

## 经验适应度追踪

当复盘结果建议写入经验库时，同时更新 `.claude/retro/fitness/fitness_tracker.json`：

1. 为新经验生成唯一 ID：`exp-YYYYMMDD-NNN`
2. 在 `fitness_tracker.json` 的 `experiences` 数组中追加记录：
   ```json
   {
     "id": "exp-20260522-001",
     "title": "经验简短标题",
     "source_file": "docs/agent_memory/inbox.md",
     "category": "inbox",
     "created_at": "2026-05-22",
     "last_used_at": "2026-05-22",
     "use_count": 0,
     "recent_uses": 0,
     "fitness": 0.0,
     "status": "active"
   }
   ```
3. 如果本次任务引用了已有经验（在复盘过程中参考了某条旧经验），则：
   - 在 `fitness_tracker.json` 中找到对应经验的 `id`
   - `use_count += 1`
   - `recent_uses += 1`（由 lesson-curator 在 14 天后重置此字段）
   - `last_used_at = 今天日期`
   - 重新计算 `fitness = use_count * 3 + recent_uses * 5 - days_idle * 0.5`

## 经验自动提升检查

每次写入新经验或更新已有经验的 use_count 后，检查是否满足自动提升条件：

- `use_count >= 3` 且 `fitness > 10` 时，在复盘结尾附加提示：
  > **自动提升触发**：经验 "{title}" 已被引用 {use_count} 次，适应度 {fitness}。
  > 建议在下一次 lesson-curator 整理时将其从 inbox 提升为分类经验。

## 经验写入规则

能写出"下次优先路径"和"下次避免路径"的内容才写入经验库。
一次性问题先放 `docs/agent_memory/inbox.md`，不直接进入 `AGENT_LESSONS.md`。
