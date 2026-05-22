# Project Rules

<!-- retro:begin -->
## Agent Retrospective 自进化复盘

- 复杂任务开始前，先快速查看 `AGENT_LESSONS.md`；如果任务命中特定类别，再查看 `docs/agent_memory/` 下对应分类文件。
- **任务结束触发条件**：在说"完成"或报告最终结果之前，快速回顾本次 session 是否存在以下任一情况：
  - 有命令/脚本执行失败后重试并成功
  - 尝试了多种方案/多次切换思路
  - 用户纠正了你的做法
  - 绕路排查了依赖、配置或环境问题
  - 测试先失败后通过
  → 满足任一条件时，在最终报告**之后**主动调用 `agent-retrospective` Skill 做复盘，不要等用户提醒
  → **如果全程一次通过、没有任何反复，则跳过复盘**
- 复盘时执行 git diff 语义分析（`git diff --stat` + `git diff --unified=3`），分析意图匹配、变更集中度、删除/新增比、隐藏约束，写入复盘报告独立区块。
- 项目经验可自动写入 `docs/agent_memory/inbox.md` 或分类文件；正式分类文件的 bullet 必须以 `[触发: ...]` 开头，候选复盘必须填写 `触发关键词`；只有稳定、高频、可复用的经验才进入 `AGENT_LESSONS.md`。
- 写入经验时同步更新 `.claude/retro/fitness/fitness_tracker.json`：记录 use_count、last_used_at、fitness 评分。
- 不记录 API Key、token、cookie、完整 `.env` 或完整 stdout/stderr。

### 与 Auto Memory 的分工

当用户说"记住"时判断内容类型：
- 项目信息/用户偏好 → 仅 Auto Memory
- 排障经验/避坑指南 → Retro 写入结构化版本（含"下次优先/避免路径"），Auto Memory 写入背景说明版，不写相同内容。
<!-- retro:end -->
