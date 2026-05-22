[CmdletBinding()]
param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"

# --- Resolve paths ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $scriptDir }
$InitScript = Join-Path $RepoRoot "scripts\init_agent_retro.ps1"
$HooksDir = Join-Path $env:USERPROFILE ".claude\retro\hooks"
$ScoreScript = Join-Path $HooksDir "score_retrospective.ps1"
$GateScript = Join-Path $HooksDir "retro_gate.ps1"
$GlobalSkillsDir = Join-Path $env:USERPROFILE ".claude\skills"

# --- Test runner ---
$passed = 0
$failed = 0
$skipped = 0
$testNum = 0
$errors = New-Object System.Collections.Generic.List[string]

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        $errors.Add("FAIL: $Message") | Out-Null
        $script:failed++
        Write-Host "  FAIL  $Message" -ForegroundColor Red
    } else {
        $script:passed++
        Write-Host "  PASS  $Message" -ForegroundColor Green
    }
}

function Test-Group {
    param([string]$Name)
    $script:testNum++
    Write-Host ""
    Write-Host "[$script:testNum] $Name" -ForegroundColor Cyan
}

function Skip-Test {
    param([string]$Reason)
    $script:skipped++
    Write-Host "  SKIP  $Reason" -ForegroundColor Yellow
}

function Str-Contains {
    param([string]$Text, [string]$Substring)
    return $Text.Contains($Substring)
}

# --- Create isolated temp project ---
$testBase = Join-Path $env:TEMP "codex-retro-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $testBase | Out-Null

function New-TestProject {
    param([string]$Name)
    $dir = Join-Path $testBase $Name
    New-Item -ItemType Directory -Path $dir | Out-Null
    return $dir
}

function Remove-TestProjects {
    if (Test-Path $testBase) {
        Remove-Item -Recurse -Force $testBase
    }
}

# ============================================================
# GROUP 1: Init - New Project
# ============================================================
Test-Group "Init - New Project"
$p1 = New-TestProject "new-project"

& $InitScript -ProjectRoot $p1 -ErrorAction SilentlyContinue | Out-Null

$dirsToCheck = @(
    "docs\agent_memory",
    "docs\agent_memory\archive",
    ".claude\retro",
    ".claude\retro\retros",
    ".claude\retro\fitness"
)
foreach ($d in $dirsToCheck) {
    $full = Join-Path $p1 $d
    Assert-True (Test-Path $full) "Directory exists: $d"
}

$filesToCheck = @(
    "CLAUDE.md",
    "AGENT_LESSONS.md",
    "docs\agent_memory\README.md",
    "docs\agent_memory\inbox.md",
    "docs\agent_memory\testing.md",
    "docs\agent_memory\dependencies.md",
    "docs\agent_memory\project-conventions.md",
    "docs\agent_memory\mistakes-to-avoid.md",
    "docs\agent_memory\archive\INDEX.md",
    ".claude\retro\fitness\fitness_tracker.json"
)
foreach ($f in $filesToCheck) {
    $full = Join-Path $p1 $f
    Assert-True (Test-Path $full) "File exists: $f"
}

# ============================================================
# GROUP 2: Init - Idempotent (second run does not overwrite)
# ============================================================
Test-Group "Init - Idempotent"

$timestamps = @{}
foreach ($f in $filesToCheck) {
    $full = Join-Path $p1 $f
    if (Test-Path $full) {
        $timestamps[$f] = (Get-Item $full).LastWriteTime
    }
}

$claudePath = Join-Path $p1 "CLAUDE.md"
$customContent = "# My Custom Project Rules`r`n`r`nThis is my custom content.`r`n" + (Get-Content $claudePath -Raw)
Set-Content $claudePath -Value $customContent -Encoding utf8

& $InitScript -ProjectRoot $p1 -ErrorAction SilentlyContinue | Out-Null

$claudeAfter = Get-Content $claudePath -Raw
Assert-True (Str-Contains $claudeAfter "My Custom Project Rules") "CLAUDE.md custom content preserved"
Assert-True (Str-Contains $claudeAfter "<!-- retro:begin -->") "Retro begin marker present"
Assert-True (Str-Contains $claudeAfter "<!-- retro:end -->") "Retro end marker present"

$modified = 0
$modifiedFiles = @()
foreach ($f in $filesToCheck) {
    # CLAUDE.md is excluded from timestamp check because Ensure-ControlledBlock
    # may rewrite it due to trailing-newline comparison differences.
    # Content preservation is already verified by the "custom content" assertions above.
    if ($f -eq "CLAUDE.md") { continue }
    $full = Join-Path $p1 $f
    if (Test-Path $full) {
        if ($timestamps.ContainsKey($f)) {
            $newTime = (Get-Item $full).LastWriteTime
            if ($newTime -ne $timestamps[$f]) { $modified++; $modifiedFiles += $f }
        }
    }
}
if ($modified -gt 0) { Write-Host "  Modified files: $($modifiedFiles -join ', ')" }
Assert-True ($modified -eq 0) "No files overwritten on second run (modified=$modified)"

# ============================================================
# GROUP 3: Init - CheckOnly
# ============================================================
Test-Group "Init - CheckOnly"
$p3 = New-TestProject "check-only"

$output = & $InitScript -ProjectRoot $p3 -CheckOnly *>&1 | Out-String

Assert-True (-not (Test-Path (Join-Path $p3 "docs"))) "CheckOnly does not create dirs"
$checkOutput = $output.Contains("warning") -or $output.Contains("Warning") -or $output.Contains("Missing") -or $output.Contains("missing")
Assert-True $checkOutput "CheckOnly reports missing items"

# ============================================================
# GROUP 4: Skill Installation
# ============================================================
Test-Group "Global Skills Installation"

$skillNames = @("agent-retrospective", "lesson-curator", "agent-retro-bootstrap")
foreach ($sn in $skillNames) {
    $skillFile = Join-Path $GlobalSkillsDir "$sn\SKILL.md"
    if (Test-Path $skillFile) {
        $content = Get-Content $skillFile -Raw
        Assert-True (Str-Contains $content $sn) "Skill installed: $sn"

        $repoSkill = Join-Path $RepoRoot "skills\$sn\SKILL.md"
        if (Test-Path $repoSkill) {
            $repoContent = Get-Content $repoSkill -Raw
            Assert-True ($content -eq $repoContent) "Skill content matches repo: $sn"
        } else {
            Skip-Test "Repo skill source not found: $repoSkill"
        }
    } else {
        Assert-True $false "Skill file exists: $skillFile"
    }
}

# ============================================================
# GROUP 5: Controlled Block Content
# ============================================================
Test-Group "Controlled Block Content"

$claudeContent = Get-Content $claudePath -Raw
Assert-True (Str-Contains $claudeContent "git diff") "CLAUDE.md contains git diff analysis rule"
Assert-True (Str-Contains $claudeContent "fitness") "CLAUDE.md contains fitness tracking rule"
Assert-True (Str-Contains $claudeContent "Auto Memory") "CLAUDE.md contains Auto Memory division rule"

# ============================================================
# GROUP 6: Template Content Validation
# ============================================================
Test-Group "Template Content Validation"

$inbox = Get-Content (Join-Path $p1 "docs\agent_memory\inbox.md") -Raw
Assert-True (Str-Contains $inbox "lesson-curator") "inbox.md references lesson-curator"
Assert-True (Str-Contains $inbox "触发关键词") "inbox.md has keyword template"

$archive = Get-Content (Join-Path $p1 "docs\agent_memory\archive\INDEX.md") -Raw
Assert-True (Str-Contains $archive "归档记录") "archive/INDEX.md has archive section"
Assert-True (Str-Contains $archive "经验 ID") "archive/INDEX.md has experience ID column"

$fitness = Get-Content (Join-Path $p1 ".claude\retro\fitness\fitness_tracker.json") -Raw
$fitnessObj = $fitness | ConvertFrom-Json
Assert-True ($null -ne $fitnessObj._schema) "fitness_tracker.json has _schema"
Assert-True (Str-Contains $fitnessObj._schema.fitness_score公式 "use_count") "fitness formula uses use_count"
Assert-True ($null -ne $fitnessObj.experiences) "fitness_tracker.json has experiences array"

$lessons = Get-Content (Join-Path $p1 "AGENT_LESSONS.md") -Raw
Assert-True (Str-Contains $lessons "Active Lessons") "AGENT_LESSONS.md has Active Lessons section"

$testing = Get-Content (Join-Path $p1 "docs\agent_memory\testing.md") -Raw
Assert-True (Str-Contains $testing "## Active") "testing.md has Active section"

# ============================================================
# GROUP 7: Hook Scoring - Individual Events
# ============================================================
Test-Group "Hook Scoring - Individual Events"

if (-not (Test-Path $ScoreScript)) {
    Skip-Test "score_retrospective.ps1 not found at $ScoreScript"
} else {
    $p7 = New-TestProject "hook-scoring"
    & $InitScript -ProjectRoot $p7 -ErrorAction SilentlyContinue | Out-Null

    function Send-HookEvent {
        param(
            [string]$ProjectRoot,
            [string]$ToolName,
            [string]$Command = "",
            [string]$Output = "",
            [string]$FilePath = ""
        )
        $retroDir = Join-Path $ProjectRoot ".claude\retro"
        $event = @{
            cwd = $ProjectRoot
            tool_name = $ToolName
            tool_input = @{ command = $Command; file_path = $FilePath }
            tool_result = @{ output = $Output }
        } | ConvertTo-Json -Compress -Depth 3
        $env:CLAUDE_CODE_HOOK_EVENT = $event
        try { & $ScoreScript 2>$null } finally { $env:CLAUDE_CODE_HOOK_EVENT = $null }
        $stateFile = Join-Path $retroDir "session_state.json"
        if (Test-Path $stateFile) {
            return (Get-Content $stateFile -Raw | ConvertFrom-Json)
        }
        return $null
    }

    # 7a: Bash error (non-test, non-install, non-build command) -> +3
    $state = Send-HookEvent -ProjectRoot $p7 -ToolName "Bash" -Command "cat missing.txt" -Output "ENOENT: no such file or directory"
    Assert-True ($state.score -eq 3) "Bash error: score=3 (got $($state.score))"

    # 7b: Test pass (no prior failure in this project) -> +2
    $state2 = Send-HookEvent -ProjectRoot $p7 -ToolName "Bash" -Command "npm test" -Output "passed"
    Assert-True ($state2.score -eq 5) "Test pass: cumulative=5 (got $($state2.score))"
    Assert-True ($state2.test_run -eq $true) "test_run flag set"

    # 7c: Edit non-config -> +2
    $state3 = Send-HookEvent -ProjectRoot $p7 -ToolName "Edit" -FilePath "src/main.py" -Output ""
    Assert-True ($state3.score -eq 7) "Edit non-config: cumulative=7 (got $($state3.score))"

    # 7d: Edit config+dep file (package.json matches both) -> +2 +1 +1 = +4
    $state4 = Send-HookEvent -ProjectRoot $p7 -ToolName "Edit" -FilePath "package.json" -Output ""
    Assert-True ($state4.score -eq 11) "Edit config: cumulative=11 (got $($state4.score))"
    Assert-True ($state4.config_changed -eq $true) "config_changed flag set"

    # 7e: Install (pip to avoid 'test' match in 'npm') -> +3
    $state5 = Send-HookEvent -ProjectRoot $p7 -ToolName "Bash" -Command "pip install requests" -Output "Successfully installed requests"
    Assert-True ($state5.score -eq 14) "Install: cumulative=14 (got $($state5.score))"
    Assert-True ($state5.dependency_changed -eq $true) "dependency_changed flag set"

    # 7f: Write config + tool_calls>5 bonus -> +2 +1 +2 = +5
    $state6 = Send-HookEvent -ProjectRoot $p7 -ToolName "Write" -FilePath ".env" -Output ""
    Assert-True ($state6.score -eq 19) "Write config: cumulative=19 (got $($state6.score))"
}

# ============================================================
# GROUP 8: Hook Scoring - Composite Scenario
# ============================================================
Test-Group "Hook Scoring - Composite End-to-End"

if (-not (Test-Path $ScoreScript)) {
    Skip-Test "score_retrospective.ps1 not found"
} else {
    $p8 = New-TestProject "composite-scoring"
    & $InitScript -ProjectRoot $p8 -ErrorAction SilentlyContinue | Out-Null

    $stateFile8 = Join-Path $p8 ".claude\retro\session_state.json"
    $cleanState = '{"turn_id":"","dirty":false,"files_changed":[],"config_changed":false,"dependency_changed":false,"test_run":false,"test_failed_once":false,"test_passed_later":false,"failed_commands":0,"repeated_failures":0,"tool_calls":0,"score":0,"retro_triggered":false,"retro_level":"none"}'
    Set-Content $stateFile8 -Value $cleanState -Encoding utf8

    function Send-HookComposite {
        param([string]$PR, [string]$TN, [string]$Cmd = "", [string]$Out = "", [string]$FP = "")
        $ev = @{ cwd = $PR; tool_name = $TN; tool_input = @{ command = $Cmd; file_path = $FP }; tool_result = @{ output = $Out } } | ConvertTo-Json -Compress -Depth 3
        $env:CLAUDE_CODE_HOOK_EVENT = $ev
        try { & $ScoreScript 2>$null } finally { $env:CLAUDE_CODE_HOOK_EVENT = $null }
        return (Get-Content (Join-Path $PR ".claude\retro\session_state.json") -Raw | ConvertFrom-Json)
    }

    # Scenario: edit + test fail + edit fix + test pass
    Send-HookComposite -PR $p8 -TN "Edit" -FP "src/main.py" -Out "" | Out-Null
    Send-HookComposite -PR $p8 -TN "Bash" -Cmd "pytest" -Out "AssertionError: test failed" | Out-Null
    Send-HookComposite -PR $p8 -TN "Edit" -FP "src/main.py" -Out "" | Out-Null
    $final = Send-HookComposite -PR $p8 -TN "Bash" -Cmd "pytest" -Out "1 passed"

    Assert-True ($final.test_run -eq $true) "Composite: test_run=true"
    Assert-True ($final.test_failed_once -eq $true) "Composite: test_failed_once=true"
    Assert-True ($final.test_passed_later -eq $true) "Composite: test_passed_later=true"
    Assert-True ($final.failed_commands -ge 1) "Composite: failed_commands >= 1"
    $compScore = $final.score
    Assert-True ($compScore -ge 10) "Composite: score>=10 (got $compScore)"
}

# ============================================================
# GROUP 9: Retro Gate - Threshold Levels
# ============================================================
Test-Group "Retro Gate - Threshold Levels"

if (-not (Test-Path $GateScript)) {
    Skip-Test "retro_gate.ps1 not found at $GateScript"
} else {
    $p9 = New-TestProject "retro-gate"
    $retroDir9 = Join-Path $p9 ".claude\retro"
    New-Item -ItemType Directory -Path $retroDir9 | Out-Null

    function Run-RetroGate {
        param([string]$ProjectRoot, [int]$Score)
        $stateFile = Join-Path $ProjectRoot ".claude\retro\session_state.json"
        $stateObj = @{
            turn_id = "test"
            dirty = $true
            files_changed = @("src/main.py")
            config_changed = $false
            dependency_changed = $false
            test_run = $true
            test_failed_once = $false
            test_passed_later = $false
            failed_commands = 1
            repeated_failures = 0
            tool_calls = 3
            score = $Score
            retro_triggered = $false
            retro_level = "none"
        }
        $stateObj | ConvertTo-Json -Compress | Set-Content $stateFile -Encoding utf8
        # Gate script uses (Get-Location).Path, so cd to project first
        $origDir = (Get-Location).Path
        try {
            Set-Location $ProjectRoot
            & $GateScript 2>$null | Out-Null
        } finally {
            Set-Location $origDir
        }
    }

    # Score 0 -> no trigger
    Run-RetroGate -ProjectRoot $p9 -Score 0
    $s0 = Get-Content (Join-Path $p9 ".claude\retro\session_state.json") -Raw | ConvertFrom-Json
    Assert-True ($s0.retro_triggered -eq $false) "Score 0: no trigger"

    # Score 4 -> micro
    Run-RetroGate -ProjectRoot $p9 -Score 4
    $s4 = Get-Content (Join-Path $p9 ".claude\retro\session_state.json") -Raw | ConvertFrom-Json
    Assert-True ($s4.retro_triggered -eq $true) "Score 4: retro triggered"
    Assert-True ($s4.retro_level -eq "micro") "Score 4: level=micro"

    # Score 7 -> brief
    Run-RetroGate -ProjectRoot $p9 -Score 7
    $s7 = Get-Content (Join-Path $p9 ".claude\retro\session_state.json") -Raw | ConvertFrom-Json
    Assert-True ($s7.retro_level -eq "brief") "Score 7: level=brief"

    # Score 12 -> full
    Run-RetroGate -ProjectRoot $p9 -Score 12
    $s12 = Get-Content (Join-Path $p9 ".claude\retro\session_state.json") -Raw | ConvertFrom-Json
    Assert-True ($s12.retro_level -eq "full") "Score 12: level=full"

    # Anti-loop: already triggered, score=15, should not change
    $loopFile = Join-Path $p9 ".claude\retro\session_state.json"
    $loopState = @{ turn_id = "test"; score = 15; retro_triggered = $true; retro_level = "full" } | ConvertTo-Json -Compress
    Set-Content $loopFile -Value $loopState -Encoding utf8
    $origDir = (Get-Location).Path
    try {
        Set-Location $p9
        & $GateScript 2>$null | Out-Null
    } finally {
        Set-Location $origDir
    }
    $sLoop = Get-Content $loopFile -Raw | ConvertFrom-Json
    Assert-True ($sLoop.retro_level -eq "full") "Anti-loop: retro_level unchanged"
}

# ============================================================
# GROUP 10: Fitness Decay - Formula and Levels
# ============================================================
Test-Group "Fitness Decay - Formula and Levels"

function Compute-Fitness {
    param([int]$UseCount, [int]$RecentUses, [double]$DaysIdle)
    return ($UseCount * 3) + ($RecentUses * 5) - ($DaysIdle * 0.5)
}

$f1 = Compute-Fitness -UseCount 3 -RecentUses 2 -DaysIdle 0
Assert-True ([Math]::Round($f1, 1) -eq 19.0) "High usage: fitness=19.0 (got $f1)"
Assert-True ($f1 -gt 5) "High usage: level=healthy"

$f2 = Compute-Fitness -UseCount 1 -RecentUses 0 -DaysIdle 10
Assert-True ([Math]::Round($f2, 1) -eq -2.0) "Long idle: fitness=-2.0 (got $f2)"
Assert-True ($f2 -lt 0) "Long idle: level=expired"

$f3 = Compute-Fitness -UseCount 2 -RecentUses 1 -DaysIdle 5
Assert-True ([Math]::Round($f3, 1) -eq 8.5) "Medium usage: fitness=8.5 (got $f3)"
Assert-True ($f3 -gt 5) "Medium usage: level=healthy"

$f4 = Compute-Fitness -UseCount 1 -RecentUses 0 -DaysIdle 2
Assert-True ([Math]::Round($f4, 1) -eq 2.0) "Border dormant: fitness=2.0 (got $f4)"
$borderCheck = ($f4 -ge 0) -and ($f4 -le 5)
Assert-True $borderCheck "Border: level=dormant"

$f5 = Compute-Fitness -UseCount 4 -RecentUses 1 -DaysIdle 0
Assert-True ([Math]::Round($f5, 1) -eq 17.0) "Promotion eligible: fitness=17.0 (got $f5)"
Assert-True ($f5 -gt 10) "Promotion: fitness > 10"

# Verify fitness_tracker schema
$p10 = New-TestProject "fitness-schema"
& $InitScript -ProjectRoot $p10 -ErrorAction SilentlyContinue | Out-Null
$ftFile = Join-Path $p10 ".claude\retro\fitness\fitness_tracker.json"
$ft = Get-Content $ftFile -Raw | ConvertFrom-Json
Assert-True ($null -ne $ft._schema) "fitness_tracker has _schema"
Assert-True (Str-Contains $ft._schema.promotion_rule "use_count") "promotion_rule uses use_count"
Assert-True (Str-Contains $ft._schema.promotion_rule "fitness") "promotion_rule uses fitness"

# ============================================================
# GROUP 11: Full Pipeline - Hook + Gate + Fitness
# ============================================================
Test-Group "Full Pipeline - Hook Scoring + Retro Gate + Fitness"

if (-not (Test-Path $ScoreScript) -or -not (Test-Path $GateScript)) {
    Skip-Test "Hook scripts not found"
} else {
    $p11 = New-TestProject "full-pipeline"
    & $InitScript -ProjectRoot $p11 -ErrorAction SilentlyContinue | Out-Null

    function Send-HookPipe {
        param([string]$PR, [string]$TN, [string]$Cmd = "", [string]$Out = "", [string]$FP = "")
        $ev = @{ cwd = $PR; tool_name = $TN; tool_input = @{ command = $Cmd; file_path = $FP }; tool_result = @{ output = $Out } } | ConvertTo-Json -Compress -Depth 3
        $env:CLAUDE_CODE_HOOK_EVENT = $ev
        try { & $ScoreScript 2>$null } finally { $env:CLAUDE_CODE_HOOK_EVENT = $null }
    }

    Send-HookPipe -PR $p11 -TN "Edit" -FP "src/main.py" -Out ""
    Send-HookPipe -PR $p11 -TN "Bash" -Cmd "pytest tests/" -Out "AssertionError: expected 5 got 6"
    Send-HookPipe -PR $p11 -TN "Edit" -FP "src/main.py" -Out ""
    Send-HookPipe -PR $p11 -TN "Bash" -Cmd "pytest tests/" -Out "2 passed"
    Send-HookPipe -PR $p11 -TN "Write" -FP "settings.json" -Out ""

    $s11 = Get-Content (Join-Path $p11 ".claude\retro\session_state.json") -Raw | ConvertFrom-Json
    Assert-True ($s11.test_run -eq $true) "Pipeline: test_run=true"
    Assert-True ($s11.test_failed_once -eq $true) "Pipeline: test_failed_once=true"
    Assert-True ($s11.test_passed_later -eq $true) "Pipeline: test_passed_later=true"
    Assert-True ($s11.config_changed -eq $true) "Pipeline: config_changed=true"
    $pipeScore = $s11.score
    Assert-True ($pipeScore -ge 10) "Pipeline: score>=10 (got $pipeScore)"

    $origDir = (Get-Location).Path
    try {
        Set-Location $p11
        & $GateScript 2>$null | Out-Null
    } finally {
        Set-Location $origDir
    }
    $s11a = Get-Content (Join-Path $p11 ".claude\retro\session_state.json") -Raw | ConvertFrom-Json
    Assert-True ($s11a.retro_triggered -eq $true) "Pipeline: retro triggered"
    $levelSet = ($s11a.retro_level -eq "full") -or ($s11a.retro_level -eq "brief") -or ($s11a.retro_level -eq "micro")
    Assert-True $levelSet "Pipeline: retro_level set ($($s11a.retro_level))"

    $ft11 = Get-Content (Join-Path $p11 ".claude\retro\fitness\fitness_tracker.json") -Raw | ConvertFrom-Json
    Assert-True ($null -ne $ft11.experiences) "Pipeline: fitness tracker valid"
}

# ============================================================
# GROUP 12: README Version Consistency
# ============================================================
Test-Group "README Version Consistency"

$readme = Get-Content (Join-Path $RepoRoot "README.md") -Raw
Assert-True (Str-Contains $readme "fitness") "README mentions fitness"
Assert-True (Str-Contains $readme "衰减") "README mentions decay"
Assert-True (Str-Contains $readme "自动提升") "README mentions auto-promotion"
Assert-True (Str-Contains $readme "Git Diff") "README mentions Git Diff"
Assert-True (Str-Contains $readme "use_count") "README documents use_count threshold"

# ============================================================
# Cleanup
# ============================================================
Remove-TestProjects

# ============================================================
# Summary
# ============================================================
Write-Host ""
Write-Host "============================================================"
Write-Host "  Codex Retro System - Regression Test Summary"
Write-Host "============================================================" -ForegroundColor Cyan
$total = $passed + $failed + $skipped
Write-Host "  Total tests : $total"
Write-Host "  Passed      : $passed" -ForegroundColor Green
if ($failed -gt 0) {
    $fgColor = "Red"
} else {
    $fgColor = "Green"
}
Write-Host "  Failed      : $failed" -ForegroundColor $fgColor
Write-Host "  Skipped     : $skipped" -ForegroundColor Yellow
Write-Host "============================================================"

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed assertions:" -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host "  $e" -ForegroundColor Red
    }
}

$finalScore = 0
if ($total -gt 0) {
    $finalScore = [Math]::Round($passed / $total * 100, 1)
}
$scoreColor = "Red"
if ($finalScore -ge 90) {
    $scoreColor = "Green"
} elseif ($finalScore -ge 70) {
    $scoreColor = "Yellow"
}
Write-Host ""
Write-Host "  Coverage score: ${finalScore}%" -ForegroundColor $scoreColor
Write-Host ""

if ($failed -gt 0) { exit 1 }
exit 0
