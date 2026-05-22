# Agent Lessons

本文件只保存本项目最高频、最稳定、最可复用的经验索引。详细复盘和候选经验放在 `docs/agent_memory/`。

## 使用规则

- 复杂任务开始前先读本文件。
- 命中具体类别时，再读对应分类文件。
- 本文件控制在 10-20 条核心经验；普通候选先进入 `docs/agent_memory/inbox.md`。

## Active Lessons

- **[触发: gitignore, runtime 文件]** 区分 runtime 文件（被 gitignore 排除，由脚本创建）和模板文件（需要版本控制）。创建文件前先检查 `.gitignore`。
- **[触发: -CheckOnly, 先检查后修改]** 任何变更前先跑 `init_agent_retro.ps1 -CheckOnly`，以脚本输出为准，不要凭感觉创建文件。
- **[触发: git commit, 遗漏文件]** `git add` 后用 `git status --short` 确认暂存区完整再 commit。
