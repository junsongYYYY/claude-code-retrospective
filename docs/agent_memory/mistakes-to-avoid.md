# Mistakes To Avoid

记录已经确认会导致重复绕路、误写记忆或污染经验库的做法。

## Active

- **[触发: 经验库写入, 复盘]** 不要把一次性路径错误、偶发网络问题或临时文件名错误写入长期经验。
- **[触发: Skill 修改]** 不要自动修改全局 Skill；先输出修改建议或补丁，除非用户明确要求应用。
- **[触发: gitignore, runtime 文件, 版本控制]** 创建文件前先确认 `.gitignore` 规则。runtime 状态文件（如 `fitness_tracker.json`、`session_state.json`）不进入版本控制，但对应的**模板文件**（如 `archive/INDEX.md`）需要 git add。不要写完了才想起来检查是否被忽略。
- **[触发: init 脚本, -CheckOnly, 先检查后修改]** 改动前必须先跑 `init_agent_retro.ps1 -CheckOnly` 查看缺失项，不要凭感觉直接创建文件。脚本的 `-CheckOnly` 是权威信息源，避免重复劳动和遗漏。
- **[触发: git commit, 遗漏文件]** `git add` 后必须用 `git status --short` 或 `git diff --cached` 确认暂存区内容完整，再 commit。不要以为写了文件就自动进了提交。
