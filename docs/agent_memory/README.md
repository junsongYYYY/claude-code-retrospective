# Agent Memory

本目录保存 Agent 在本项目中的任务复盘、候选经验和分类经验。

## 文件职责

- `testing.md`：测试、构建、验证相关正式经验。
- `dependencies.md`：依赖、解释器、环境配置相关正式经验。
- `project-conventions.md`：项目结构、工作流、命名和维护约定。
- `mistakes-to-avoid.md`：已经确认应避免的操作习惯或排障路径。
- `inbox.md`：不确定、边界模糊或暂时无法判断的候选复盘。
- `archive/`：过期或低频复盘归档。

## 任务开始

- 直接读取 `AGENT_LESSONS.md` 和分类文件的 `## Active`。
- 默认不读取 `inbox.md`；只有整理候选经验时才读取。

## 写入规则

- 明确可复用且能写出"下次优先路径"和"下次避免"的内容，直接写入分类文件 `## Active`，并以 `[触发: keyword1, keyword2, ...]` 开头。
- 不确定、边界模糊或暂时无法判断的问题才放 `inbox.md`，候选模板必须填写 `触发关键词`。
- 高频或跨任务通用经验才提升到 `AGENT_LESSONS.md`。
- 定期使用 `lesson-curator` 清理 `inbox.md`。
- 不保存密钥、完整 `.env`、cookie、token 或大段 stdout/stderr。
