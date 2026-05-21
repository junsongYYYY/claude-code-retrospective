[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

$beginMarker = "<!-- retro:begin -->"
$endMarker = "<!-- retro:end -->"
$globalClaudePath = Join-Path $env:USERPROFILE ".claude\CLAUDE.md"

$created = New-Object System.Collections.Generic.List[string]
$updated = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-ItemStatus {
    param(
        [System.Collections.Generic.List[string]]$List,
        [string]$Value
    )
    $List.Add($Value) | Out-Null
}

function Read-Utf8Text {
    param([string]$Path)
    $utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
    try {
        return [System.IO.File]::ReadAllText($Path, $utf8Strict)
    } catch {
        $utf8Lenient = [System.Text.UTF8Encoding]::new($false, $false)
        return [System.IO.File]::ReadAllText($Path, $utf8Lenient)
    }
}

function Write-Utf8BomText {
    param(
        [string]$Path,
        [string]$Text
    )
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $utf8Bom = [System.Text.UTF8Encoding]::new($true)
    [System.IO.File]::WriteAllText($Path, $Text, $utf8Bom)
}

function Ensure-Directory {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Add-ItemStatus $skipped $Path
        return
    }
    if ($CheckOnly) {
        Add-ItemStatus $warnings "Missing directory: $Path"
        return
    }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    Add-ItemStatus $created $Path
}

function Ensure-File {
    param(
        [string]$Path,
        [string]$Content
    )
    if (Test-Path -LiteralPath $Path) {
        Add-ItemStatus $skipped $Path
        return
    }
    if ($CheckOnly) {
        Add-ItemStatus $warnings "Missing file: $Path"
        return
    }
    Write-Utf8BomText -Path $Path -Text $Content
    Add-ItemStatus $created $Path
}

function Ensure-ControlledBlock {
    param(
        [string]$Path,
        [string]$Block
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        if ($CheckOnly) {
            Add-ItemStatus $warnings "Missing file: $Path"
            return
        }
        Write-Utf8BomText -Path $Path -Text "# Project Rules`r`n`r`n$Block`r`n"
        Add-ItemStatus $created $Path
        return
    }
    $current = Read-Utf8Text -Path $Path
    $escapedBegin = [regex]::Escape($beginMarker)
    $escapedEnd = [regex]::Escape($endMarker)
    $pattern = "(?s)$escapedBegin.*?$escapedEnd"
    if ($current -match $pattern) {
        $newContent = [regex]::Replace($current, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $Block })
        if ($newContent -eq $current) {
            Add-ItemStatus $skipped $Path
            return
        }
        if ($CheckOnly) {
            Add-ItemStatus $warnings "Controlled block differs: $Path"
            return
        }
        Write-Utf8BomText -Path $Path -Text $newContent
        Add-ItemStatus $updated $Path
        return
    }
    if ($CheckOnly) {
        Add-ItemStatus $warnings "Missing retro controlled block: $Path"
        return
    }
    $separator = if ($current.EndsWith("`n")) { "`r`n" } else { "`r`n`r`n" }
    Write-Utf8BomText -Path $Path -Text ($current + $separator + $Block + "`r`n")
    Add-ItemStatus $updated $Path
}

function Write-Section {
    param(
        [string]$Title,
        [System.Collections.Generic.List[string]]$Items
    )
    Write-Host ""
    Write-Host "[$Title]"
    if ($Items.Count -eq 0) {
        Write-Host "- none"
        return
    }
    foreach ($item in $Items) {
        Write-Host "- $item"
    }
}

function Join-Lines {
    param([string[]]$Lines)
    return (($Lines -join [Environment]::NewLine) + [Environment]::NewLine)
}

# --- Resolve project root ---
$resolvedProjectRoot = $ProjectRoot
if (Test-Path -LiteralPath $ProjectRoot) {
    $resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
} elseif (-not $CheckOnly) {
    New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null
    $resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    Add-ItemStatus $created $resolvedProjectRoot
} else {
    Add-ItemStatus $warnings "Project root does not exist: $ProjectRoot"
}

# --- Check global skill ---
$globalSkillPath = Join-Path $env:USERPROFILE ".claude\skills\agent-retrospective\SKILL.md"
if (-not (Test-Path -LiteralPath $globalSkillPath)) {
    Add-ItemStatus $warnings "Global skill missing: $globalSkillPath"
}

# --- Check global CLAUDE.md ---
if (-not (Test-Path -LiteralPath $globalClaudePath)) {
    Add-ItemStatus $warnings "Global CLAUDE.md missing: $globalClaudePath"
} else {
    $globalClaude = Read-Utf8Text -Path $globalClaudePath
    if ($globalClaude -notmatch "Agent Retrospective") {
        Add-ItemStatus $warnings "Global CLAUDE.md does not contain Agent Retrospective rules."
    }
}

# --- Directory structure ---
$agentMemoryDir = Join-Path $resolvedProjectRoot "docs\agent_memory"
$archiveDir = Join-Path $agentMemoryDir "archive"
$retroDir = Join-Path $resolvedProjectRoot ".claude\retro"
$retrosDir = Join-Path $retroDir "retros"

Ensure-Directory $agentMemoryDir
Ensure-Directory $archiveDir
Ensure-Directory $retroDir
Ensure-Directory $retrosDir

# --- File templates ---
$controlledBlock = Join-Lines @(
    '<!-- retro:begin -->',
    '## Agent Retrospective 自进化复盘',
    '',
    '- 复杂任务开始前，先快速查看 `AGENT_LESSONS.md`；如果任务命中特定类别，再查看 `docs/agent_memory/` 下对应分类文件。',
    '- 复杂任务结束前，如果出现失败命令、测试失败后成功、重复尝试、用户纠偏、配置/依赖绕路或多次切换方案，使用 `agent-retrospective` Skill 做复盘。',
    '- 项目经验可自动写入 `docs/agent_memory/inbox.md` 或分类文件；正式分类文件的 bullet 必须以 `[触发: ...]` 开头，候选复盘必须填写 `触发关键词`；只有稳定、高频、可复用的经验才进入 `AGENT_LESSONS.md`。',
    '- 不记录 API Key、token、cookie、完整 `.env` 或完整 stdout/stderr。',
    '',
    '### 与 Auto Memory 的分工',
    '',
    '当用户说"记住"时判断内容类型：',
    '- 项目信息/用户偏好 -> 仅 Auto Memory',
    '- 排障经验/避坑指南 -> Retro 写入结构化版本（含"下次优先/避免路径"），Auto Memory 写入背景说明版，不写相同内容。',
    '<!-- retro:end -->'
)
$controlledBlock = $controlledBlock.TrimEnd([char[]]"`r`n")

$agentLessons = Join-Lines @(
    '# Agent Lessons',
    '',
    '本文件只保存本项目最高频、最稳定、最可复用的经验索引。详细复盘和候选经验放在 `docs/agent_memory/`。',
    '',
    '## 使用规则',
    '',
    '- 复杂任务开始前先读本文件。',
    '- 命中具体类别时，再读对应分类文件。',
    '- 本文件控制在 10-20 条核心经验；普通候选先进入 `docs/agent_memory/inbox.md`。',
    '',
    '## Active Lessons',
    '',
    '暂无。首批经验应来自真实任务复盘，而不是预设猜测。'
)

$readme = Join-Lines @(
    '# Agent Memory',
    '',
    '本目录保存 Agent 在本项目中的任务复盘、候选经验和分类经验。',
    '',
    '## 文件职责',
    '',
    '- `testing.md`：测试、构建、验证相关正式经验。',
    '- `dependencies.md`：依赖、解释器、环境配置相关正式经验。',
    '- `project-conventions.md`：项目结构、工作流、命名和维护约定。',
    '- `mistakes-to-avoid.md`：已经确认应避免的操作习惯或排障路径。',
    '- `inbox.md`：不确定、边界模糊或暂时无法判断的候选复盘。',
    '- `archive/`：过期或低频复盘归档。',
    '',
    '## 任务开始',
    '',
    '- 直接读取 `AGENT_LESSONS.md` 和分类文件的 `## Active`。',
    '- 默认不读取 `inbox.md`；只有整理候选经验时才读取。',
    '',
    '## 写入规则',
    '',
    '- 明确可复用且能写出"下次优先路径"和"下次避免"的内容，直接写入分类文件 `## Active`，并以 `[触发: keyword1, keyword2, ...]` 开头。',
    '- 不确定、边界模糊或暂时无法判断的问题才放 `inbox.md`，候选模板必须填写 `触发关键词`。',
    '- 高频或跨任务通用经验才提升到 `AGENT_LESSONS.md`。',
    '- 定期使用 `lesson-curator` 清理 `inbox.md`。',
    '- 不保存密钥、完整 `.env`、cookie、token 或大段 stdout/stderr。'
)

$inbox = Join-Lines @(
    '# Retrospective Inbox',
    '',
    '候选复盘先写入这里。定期使用 `lesson-curator` 判断：有价值的升级到分类文件，一次性或过时的删除，仍不确定的继续保留。',
    '',
    '## Template',
    '',
    '```markdown',
    '## YYYY-MM-DD｜标题',
    '',
    '状态：candidate',
    '分类：testing / dependencies / project-conventions / mistakes-to-avoid / other',
    '来源任务：',
    '触发关键词：keyword1, keyword2, keyword3 （2-5个场景关键词，用于后续检索和分类）',
    '',
    '### 任务结果',
    '- 是否完成：',
    '- 验证方式：',
    '',
    '### 绕路信号',
    '- 失败命令：',
    '- 重复尝试：',
    '- 用户纠偏：',
    '- 测试失败后成功：',
    '',
    '### 根因',
    '',
    '### 下次优先路径',
    '',
    '### 下次避免',
    '',
    '### 建议处理',
    '- Keep / Promote / Delete',
    '```'
)

$testing = Join-Lines @(
    '# Testing Lessons',
    '',
    '记录测试、构建、验证链路中的可复用经验。',
    '',
    '## Active',
    '',
    '暂无。'
)

$dependencies = Join-Lines @(
    '# Dependency Lessons',
    '',
    '记录解释器、依赖安装、版本冲突、配置路径等可复用经验。',
    '',
    '## Active',
    '',
    '暂无。'
)

$projectConventions = Join-Lines @(
    '# Project Conventions',
    '',
    '记录本项目稳定的结构、命名、流程和维护约定。',
    '',
    '## Active',
    '',
    '- **[触发: 自进化系统, 项目接入]** 本项目已接入 Agent Retrospective 自进化复盘机制：复杂任务开始前直接读取 `AGENT_LESSONS.md` 和分类经验文件；明确可复用经验进入分类文件并以 `[触发: ...]` 开头，不确定经验进入 `inbox.md` 并填写 `触发关键词`；定期使用 `lesson-curator` 清理候选。'
)

$mistakesToAvoid = Join-Lines @(
    '# Mistakes To Avoid',
    '',
    '记录已经确认会导致重复绕路、误写记忆或污染经验库的做法。',
    '',
    '## Active',
    '',
    '- **[触发: 经验库写入, 复盘]** 不要把一次性路径错误、偶发网络问题或临时文件名错误写入长期经验。',
    '- **[触发: Skill 修改]** 不要自动修改全局 Skill；先输出修改建议或补丁，除非用户明确要求应用。'
)

$sessionStateContent = '{"turn_id":"","task_started_at":"","dirty":false,"files_changed":[],"config_changed":false,"dependency_changed":false,"test_run":false,"test_failed_once":false,"test_passed_later":false,"failed_commands":0,"repeated_failures":0,"tool_calls":0,"error_signals":[],"score":0,"retro_triggered":false,"retro_level":"none"}'

$taskEventsContent = ''

# --- Ensure files ---
Ensure-ControlledBlock -Path (Join-Path $resolvedProjectRoot "CLAUDE.md") -Block $controlledBlock
Ensure-File -Path (Join-Path $resolvedProjectRoot "AGENT_LESSONS.md") -Content $agentLessons
Ensure-File -Path (Join-Path $agentMemoryDir "README.md") -Content $readme
Ensure-File -Path (Join-Path $agentMemoryDir "inbox.md") -Content $inbox
Ensure-File -Path (Join-Path $agentMemoryDir "testing.md") -Content $testing
Ensure-File -Path (Join-Path $agentMemoryDir "dependencies.md") -Content $dependencies
Ensure-File -Path (Join-Path $agentMemoryDir "project-conventions.md") -Content $projectConventions
Ensure-File -Path (Join-Path $agentMemoryDir "mistakes-to-avoid.md") -Content $mistakesToAvoid

if (-not (Test-Path (Join-Path $retroDir "session_state.json"))) {
    if (-not $CheckOnly) {
        Set-Content -LiteralPath (Join-Path $retroDir "session_state.json") -Value $sessionStateContent -Encoding utf8
        Add-ItemStatus $created (Join-Path $retroDir "session_state.json")
    } else {
        Add-ItemStatus $warnings "Missing session_state.json"
    }
} else {
    Add-ItemStatus $skipped (Join-Path $retroDir "session_state.json")
}

if (-not (Test-Path (Join-Path $retroDir "task_events.jsonl"))) {
    if (-not $CheckOnly) {
        Set-Content -LiteralPath (Join-Path $retroDir "task_events.jsonl") -Value $taskEventsContent -Encoding utf8
        Add-ItemStatus $created (Join-Path $retroDir "task_events.jsonl")
    } else {
        Add-ItemStatus $warnings "Missing task_events.jsonl"
    }
} else {
    Add-ItemStatus $skipped (Join-Path $retroDir "task_events.jsonl")
}

# --- Summary ---
Write-Host "Agent retrospective project initialization"
Write-Host "ProjectRoot: $resolvedProjectRoot"
Write-Host "Script: $PSCommandPath"
if ($CheckOnly) {
    Write-Host "Mode: check only"
} else {
    Write-Host "Mode: initialize"
}

Write-Section -Title "created" -Items $created
Write-Section -Title "updated" -Items $updated
Write-Section -Title "skipped" -Items $skipped
Write-Section -Title "warnings" -Items $warnings

if ($warnings.Count -gt 0) {
    exit 2
}

exit 0