---
name: lesson-curator
description: 经验库清洗、合并、归档 + 经验适应度衰减。当经验库膨胀或用户要求整理时触发。
when_to_use: 整理经验库, lesson-curator, 经验清理, 经验归档, 衰减, fitness
---

# Lesson Curator

## 触发条件

- `AGENT_LESSONS.md` 超过 150 行或 20 条经验
- `docs/agent_memory/inbox.md` 候选经验超过 10 条
- `.claude/retro/retros/` 数量超过 30 个
- 用户要求整理经验库
- 距离上次整理超过 7 天（检查 `.claude/retro/fitness/fitness_tracker.json` 的 `last_curated`）

## 主要任务

1. **合并重复经验**：检查 `AGENT_LESSONS.md` 和 `docs/agent_memory/*.md`，合并内容重复的条目
2. **删除一次性经验**：移除仅出现一次、无复用价值的经验
3. **提炼高频规则**：从 inbox 中识别重复出现的模式，提升为正式经验
4. **归档低频复盘**：将长期未命中的经验移入 `docs/agent_memory/archive/`
5. **标记过期经验**：对不再适用的经验标记 `状态：expired`

## 经验适应度衰减机制

每次整理时，读取 `.claude/retro/fitness/fitness_tracker.json`，对每条经验计算适应度：

```
fitness = use_count * 3 + recent_uses * 5 - days_idle * 0.5
```

其中：
- `use_count`：经验被引用总次数
- `recent_uses`：最近 14 天内被引用次数
- `days_idle`：距上次被引用的天数（未使用过的经验从创建日算起）

### 衰减分级

| fitness 值 | 级别 | 操作 |
|---|---|---|
| > 5 | healthy | 保留，不做处理 |
| 0 ~ 5 | dormant | 标记 `状态：dormant`，在整理报告中列出让用户确认是否归档 |
| < 0 | expired | 自动移入 `docs/agent_memory/archive/`，在 `archive/INDEX.md` 中记录归档原因和日期 |

### 自动提升规则

当 inbox 中的经验满足以下全部条件时，**自动提升**为分类经验：
1. `use_count >= 3`
2. `fitness > 10`
3. 能写出明确的"下次优先路径"和"下次避免路径"

提升操作：
1. 从 `inbox.md` 中移除该经验
2. 在 `docs/agent_memory/` 下对应的分类文件（如 `testing.md`、`dependencies.md`）中新增该经验条目
3. 如果该经验具有全局适用性（不限于某个具体项目或工具），执行 CLAUDE.md 自动更新：
   - 检查当前工作目录下是否存在 `CLAUDE.md`
   - 如果存在，在 `CLAUDE.md` 的 "Agent Retrospective" 或 "经验规则" 相关章节后追加一条简短引用，格式：
     ```
     - [经验标题](docs/agent_memory/分类文件.md#经验锚点) — 被引用 N 次，适应度 N
     ```
   - 如果 `CLAUDE.md` 中尚无相关章节，在文件末尾追加 `## 自进化经验规则` 章节
4. 更新 `fitness_tracker.json` 中的分类信息（`status` 改为 `promoted`，`source_file` 更新为分类文件路径）

## 经验准入标准

一条经验只有同时满足以下条件，才进入主库：

- 可复用（不是一次性偶然问题）
- 可操作（有具体的行动指南）
- 有明确适用场景
- 能减少下次弯路
- 能够写出"下次优先路径"和"下次避免路径"

## 不进入主库的内容

- 一次性路径错误
- 临时文件名写错
- 偶发网络波动
- 用户临时改标题
- 没有复用价值的修复过程

## 经验记录格式

每条经验在 `fitness_tracker.json` 中的记录格式：

```json
{
  "id": "exp-20260522-001",
  "title": "简短标题",
  "source_file": "docs/agent_memory/inbox.md",
  "category": "inbox | testing | dependencies | mistakes | config",
  "created_at": "2026-05-22",
  "last_used_at": "2026-05-22",
  "use_count": 0,
  "recent_uses": 0,
  "fitness": 0.0,
  "status": "active | dormant | expired | promoted"
}
```

## 整理报告

整理完成后，输出一份简短报告：

```
### 经验库整理报告
- 处理经验总数：N
- 合并重复：N 条
- 自动提升：N 条（inbox → 分类文件）
- 标记休眠：N 条
- 自动归档：N 条（→ archive/）
- 当前活跃经验总数：N
```
