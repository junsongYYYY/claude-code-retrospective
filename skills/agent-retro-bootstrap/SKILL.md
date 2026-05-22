---
name: agent-retro-bootstrap
description: 初始化、检查、升级自进化复盘系统的关键文件。
when_to_use: 接入自进化, init retro, 初始化复盘系统, 接入agent-retro
---

# Agent Retro Bootstrap

## 使用场景

- 新项目接入自进化复盘系统
- 检查关键文件完整性
- 升级模板版本
- 修复 AGENTS.md/CLAUDE.md、Hook、Skill、经验库之间的不一致

## 原则

- 显式调用，不自动覆盖
- 只更新受控区块（`<!-- retro:begin -->` ... `<!-- retro:end -->`）
- 输出变更清单
- 不覆盖用户手动编辑的内容

## 工作流程

1. 检查项目根目录是否有 `CLAUDE.md` 或 `AGENTS.md`
2. 检查 `AGENT_LESSONS.md` 是否存在
3. 检查 `docs/agent_memory/` 目录及子文件是否完整
4. 检查 `.claude/retro/` 目录是否存在
5. 如使用 `-CheckOnly` 模式：输出检查结果，不做修改
6. 否则：创建缺失文件，追加受控区块到 CLAUDE.md

## 需要创建的文件

```
项目根目录/
├── CLAUDE.md                          (含 retro 受控区块)
├── AGENT_LESSONS.md
└── docs/
    └── agent_memory/
        ├── README.md
        ├── inbox.md
        ├── testing.md
        ├── dependencies.md
        ├── project-conventions.md
        ├── mistakes-to-avoid.md
        └── archive/
            └── INDEX.md
.claude/
└── retro/
    ├── session_state.json
    ├── task_events.jsonl
    ├── retros/
    └── fitness/
        └── fitness_tracker.json
```

## 初始化脚本

用户也可运行 `D:\000项目\自进化系统\scripts\init_agent_retro.ps1` 一键初始化。
支持 `-CheckOnly` 参数只做检查不做修改。
