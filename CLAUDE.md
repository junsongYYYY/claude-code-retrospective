# Project Rules

<!-- retro:begin -->
## Agent Retrospective 自进化复盘

- 复杂任务开始前，先快速查看 `AGENT_LESSONS.md`；如果任务命中特定类别，再查看 `docs/agent_memory/` 下对应分类文件。
- 复杂任务结束前，如果出现失败命令、测试失败后成功、重复尝试、用户纠偏、配置/依赖绕路或多次切换方案，使用 `agent-retrospective` Skill 做复盘。
- 项目经验可自动写入 `docs/agent_memory/inbox.md` 或分类文件；正式分类文件的 bullet 必须以 `[触发: ...]` 开头，候选复盘必须填写 `触发关键词`；只有稳定、高频、可复用的经验才进入 `AGENT_LESSONS.md`。
- 不记录 API Key、token、cookie、完整 `.env` 或完整 stdout/stderr。

### 与 Auto Memory 的分工

当用户说"记住"时判断内容类型：
- 项目信息/用户偏好 → 仅 Auto Memory
- 排障经验/避坑指南 → Retro 写入结构化版本（含"下次优先/避免路径"），Auto Memory 写入背景说明版，不写相同内容。
<!-- retro:end -->
