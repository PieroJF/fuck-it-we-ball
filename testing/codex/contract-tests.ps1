[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$CodexAgentsPath = (Join-Path $env:USERPROFILE '.codex\AGENTS.md'),
    [string]$ClaudeInstructionsPath = (Join-Path $env:USERPROFILE '.claude\CLAUDE.md'),
    [string]$ProjectContextPath = (Join-Path $env:USERPROFILE '.agents\skills\project-context\SKILL.md'),
    [string]$ClaudeProjectContextPath = (Join-Path $env:USERPROFILE '.claude\skills\project-context\SKILL.md'),
    [string]$ClaudeSkillPath = (Join-Path $env:USERPROFILE '.claude\skills\fuck-it-we-ball\SKILL.md'),
    [string]$CodexSkillPath = (Join-Path $env:USERPROFILE '.agents\skills\fuck-it-we-ball\SKILL.md')
)

$ErrorActionPreference = 'Stop'

$skillPath = Join-Path $RepositoryRoot 'SKILL.md'
$readmePath = Join-Path $RepositoryRoot 'README.md'
$skill = Get-Content -Raw -LiteralPath $skillPath
$readme = Get-Content -Raw -LiteralPath $readmePath
$codexAgents = Get-Content -Raw -LiteralPath $CodexAgentsPath
$claudeInstructions = Get-Content -Raw -LiteralPath $ClaudeInstructionsPath
$projectContext = Get-Content -Raw -LiteralPath $ProjectContextPath
$claudeProjectContext = Get-Content -Raw -LiteralPath $ClaudeProjectContextPath
$results = [System.Collections.Generic.List[object]]::new()

function Add-ContractResult {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [bool]$Passed,
        [Parameter(Mandatory)] [string]$Requirement
    )

    $results.Add([pscustomobject]@{
        Name = $Name
        Passed = $Passed
        Requirement = $Requirement
    })
}

function Get-RuntimeContract {
    param([Parameter(Mandatory)] [string]$Text)

    $pattern = '(?s)<!-- fiwb-runtime-contract:start -->\s*```json\s*(?<json>\{.*?\})\s*```\s*<!-- fiwb-runtime-contract:end -->'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        return $null
    }

    try {
        return $match.Groups['json'].Value | ConvertFrom-Json -Depth 20
    }
    catch {
        return $null
    }
}

function Test-ExactString {
    param(
        [AllowNull()] [object]$Actual,
        [Parameter(Mandatory)] [string]$Expected
    )

    return $Actual -is [string] -and $Actual -ceq $Expected
}

function Test-NormalizedAdapter {
    param([AllowNull()] [object]$Contract)

    if ($null -eq $Contract) {
        return $false
    }

    $capture = @($Contract.git.capture)
    return $Contract.schema -is [long] -and $Contract.schema -eq 1 -and
        (Test-ExactString $Contract.invocations.claude '/fuck-it-we-ball') -and
        (Test-ExactString $Contract.invocations.codex '$fuck-it-we-ball') -and
        (Test-ExactString $Contract.tools.selection 'callable-agent-and-models') -and
        (Test-ExactString $Contract.tools.question_selection 'AskUserQuestion-if-callable-else-plain-text') -and
        (Test-ExactString $Contract.tools.question_formats.AskUserQuestion '2-4-options-recommended-first') -and
        (Test-ExactString $Contract.tools.question_formats.'plain-text' 'single-direct-no-option-list') -and
        $Contract.tools.plain_text_terminal -is [bool] -and $Contract.tools.plain_text_terminal -and
        (Test-ExactString $Contract.tools.missing_agent 'park-needs-user') -and
        (Test-ExactString $Contract.tools.claude.agent 'Agent') -and
        (Test-ExactString $Contract.tools.claude.question 'AskUserQuestion') -and
        (Test-ExactString $Contract.tools.claude.workflow 'Workflow') -and
        (Test-ExactString $Contract.tools.claude.workflow_unit 'agent') -and
        $Contract.tools.claude.workflow_model_required -is [bool] -and
        $Contract.tools.claude.workflow_model_required -and
        (Test-ExactString $Contract.tools.claude.agent_effort_field 'only-if-exposed') -and
        $Contract.tools.claude.dispatch_effort_declaration_required -is [bool] -and
        $Contract.tools.claude.dispatch_effort_declaration_required -and
        $Contract.tools.claude.workflow_effort_required -is [bool] -and
        $Contract.tools.claude.workflow_effort_required -and
        (Test-ExactString $Contract.tools.codex.agent 'spawn_agent') -and
        (Test-ExactString $Contract.tools.codex.question 'plain-text') -and
        (Test-ExactString $Contract.tools.codex.task_list 'only-if-exposed') -and
        (Test-ExactString $Contract.tools.codex.fork_turns 'none') -and
        (Test-ExactString $Contract.tools.codex.reasoning_effort 'xhigh') -and
        (Test-ExactString $Contract.models.claude.implementation 'sonnet') -and
        (Test-ExactString $Contract.models.claude.judgment 'opus') -and
        (Test-ExactString $Contract.models.claude.trivial 'haiku') -and
        (Test-ExactString $Contract.models.codex.implementation 'gpt-5.6-terra') -and
        (Test-ExactString $Contract.models.codex.judgment 'gpt-5.6-sol') -and
        (Test-ExactString $Contract.models.codex.trivial 'gpt-5.6-luna') -and
        (Test-ExactString $Contract.models.effort 'xhigh') -and
        (Test-ExactString $Contract.persistence.done_checkbox 'checked') -and
        (Test-ExactString $Contract.persistence.parked_checkbox 'unchecked') -and
        (Test-ExactString $Contract.persistence.resume_state 'latest-run-log') -and
        (Test-ExactString $Contract.persistence.parked_redispatch 'only-after-user-unblocks') -and
        (Test-ExactString $Contract.persistence.bookkeeping_scope 'one-task-per-commit') -and
        (Test-ExactString $Contract.deviations.specified_approach_premise 'implement-tactical-note') -and
        (Test-ExactString $Contract.deviations.new_dependency 'park-arch-deviation') -and
        $Contract.fallbacks.question_max_per_turn -is [long] -and
        $Contract.fallbacks.question_max_per_turn -eq 1 -and
        (Test-ExactString $Contract.fallbacks.workflow_unavailable 'SDD') -and
        (Test-ExactString $Contract.fallbacks.task_list_unavailable 'skip') -and
        (Test-ExactString $Contract.fallbacks.model_unavailable 'park-needs-user') -and
        (Test-ExactString $Contract.fallbacks.reviewer_unavailable 'park-needs-user') -and
        (Test-ExactString $Contract.fallbacks.context_without_telemetry 'persist-and-handoff-never-estimate') -and
        $capture.Count -eq 2 -and
        (Test-ExactString $capture[0] 'BASE_BRANCH') -and
        (Test-ExactString $capture[1] 'BASE_SHA') -and
        $Contract.git.before_branch -is [bool] -and $Contract.git.before_branch -and
        $Contract.git.guard_auto_deploy -is [bool] -and $Contract.git.guard_auto_deploy
}

function Test-GuardProse {
    param([Parameter(Mandatory)] [string]$Text)

    $required = 'Before merge or push, determine whether the action triggers a production deploy; if it does, park it as a hard-stop and ask the queued deploy question before proceeding.'
    return $Text.Contains($required, [System.StringComparison]::Ordinal)
}

function Test-ReadmeInvocation {
    param([Parameter(Mandatory)] [string]$Text)

    $claudeLine = 'Claude Code: invoke `/fuck-it-we-ball [plan-or-work]`.'
    $codexLine = 'Codex: invoke `$fuck-it-we-ball [plan-or-work]`.'
    return $Text.Contains($claudeLine, [System.StringComparison]::Ordinal) -and
        $Text.Contains($codexLine, [System.StringComparison]::Ordinal)
}

function Test-StrictFrontmatter {
    param([Parameter(Mandatory)] [string]$Text)

    $match = [regex]::Match($Text, '(?s)\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n)')
    if (-not $match.Success) {
        return $false
    }

    $lines = @($match.Groups['yaml'].Value -split '\r?\n')
    if ($lines.Count -ne 2) {
        return $false
    }

    $name = [regex]::Match($lines[0], '^name: (?<value>[a-z0-9]+(?:-[a-z0-9]+)*)$')
    $description = [regex]::Match($lines[1], '^description: (?<value>Use when (?!.*(?:\: | #|\t)).{1,491})$')
    return $name.Success -and $name.Groups['value'].Value -ceq 'fuck-it-we-ball' -and
        $description.Success -and $description.Groups['value'].Value.Length -le 500
}

$contract = Get-RuntimeContract $skill
$contractStart = $skill.IndexOf('<!-- fiwb-runtime-contract:start -->', [System.StringComparison]::Ordinal)
$phaseZeroStart = $skill.IndexOf('## Phase 0', [System.StringComparison]::Ordinal)
$adapterBeforePhaseZero = $contractStart -ge 0 -and $phaseZeroStart -ge 0 -and $contractStart -lt $phaseZeroStart

Add-ContractResult 'runtime-contract-valid' (Test-NormalizedAdapter $contract) 'The marked JSON contract has exact supported tools, models, fallbacks, effort, and git guards.'
Add-ContractResult 'runtime-contract-order' $adapterBeforePhaseZero 'The normalized adapter contract appears before Phase 0.'
$adapterInstruction = 'The JSON contract below is normative: use its exact identifiers and fallbacks; never negate or reinterpret them.'
Add-ContractResult 'runtime-adapter-prose' (($skill -match '(?im)^## Runtime adapter') -and $skill.Contains($adapterInstruction, [System.StringComparison]::Ordinal)) 'Human-readable runtime instructions make the structural contract normative.'
Add-ContractResult 'close-auto-deploy-guard' (($null -ne $contract) -and $contract.git.guard_auto_deploy -is [bool] -and $contract.git.guard_auto_deploy -and (Test-GuardProse $skill)) 'Close contains the exact positive production-side-effect guard.'

$goodFixture = @'
{
  "schema": 1,
  "invocations": {"claude": "/fuck-it-we-ball", "codex": "$fuck-it-we-ball"},
  "tools": {
    "selection": "callable-agent-and-models",
    "question_selection": "AskUserQuestion-if-callable-else-plain-text",
    "question_formats": {"AskUserQuestion": "2-4-options-recommended-first", "plain-text": "single-direct-no-option-list"},
    "plain_text_terminal": true,
    "missing_agent": "park-needs-user",
    "claude": {"agent": "Agent", "question": "AskUserQuestion", "workflow": "Workflow", "workflow_unit": "agent", "workflow_model_required": true, "agent_effort_field": "only-if-exposed", "dispatch_effort_declaration_required": true, "workflow_effort_required": true},
    "codex": {"agent": "spawn_agent", "question": "plain-text", "task_list": "only-if-exposed", "fork_turns": "none", "reasoning_effort": "xhigh"}
  },
  "models": {
    "claude": {"implementation": "sonnet", "judgment": "opus", "trivial": "haiku"},
    "codex": {"implementation": "gpt-5.6-terra", "judgment": "gpt-5.6-sol", "trivial": "gpt-5.6-luna"},
    "effort": "xhigh"
  },
  "persistence": {"done_checkbox": "checked", "parked_checkbox": "unchecked", "resume_state": "latest-run-log", "parked_redispatch": "only-after-user-unblocks", "bookkeeping_scope": "one-task-per-commit"},
  "deviations": {"specified_approach_premise": "implement-tactical-note", "new_dependency": "park-arch-deviation"},
  "fallbacks": {
    "question_max_per_turn": 1,
    "workflow_unavailable": "SDD",
    "task_list_unavailable": "skip",
    "model_unavailable": "park-needs-user",
    "reviewer_unavailable": "park-needs-user",
    "context_without_telemetry": "persist-and-handoff-never-estimate"
  },
  "git": {"capture": ["BASE_BRANCH", "BASE_SHA"], "before_branch": true, "guard_auto_deploy": true}
}
'@ | ConvertFrom-Json -Depth 20

$negativeAgent = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativeAgent.tools.codex.agent = 'never spawn_agent'
$negativeWorkflow = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativeWorkflow.fallbacks.workflow_unavailable = 'never SDD'
$negativeOrder = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativeOrder.git.before_branch = $false
$negativeModel = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativeModel.models.codex.implementation = 'gpt-5.6-sol'
$negativeCase = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativeCase.tools.codex.agent = 'SPAWN_AGENT'
$negativeFork = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativeFork.tools.codex.fork_turns = 'all'
$negativeWorkflowUnit = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativeWorkflowUnit.tools.claude.workflow_model_required = $false
$negativeAgentEffort = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativeAgentEffort.tools.claude.agent_effort_field = 'always-pass'
$negativePersistence = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativePersistence.persistence.parked_checkbox = 'checked'
$negativeBookkeeping = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativeBookkeeping.persistence.bookkeeping_scope = 'batch-parked-tasks'
$negativeSpecifiedApproach = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativeSpecifiedApproach.deviations.specified_approach_premise = 'park-arch-deviation'
$negativePlainTextQuestion = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativePlainTextQuestion.tools.question_formats.'plain-text' = '2-4-options'
$negativePlainTextTerminal = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativePlainTextTerminal.tools.plain_text_terminal = $false
$negativeReviewer = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativeReviewer.fallbacks.reviewer_unavailable = 'continue-inline'
$negativeTypes = $goodFixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20
$negativeTypes.schema = '1'
$negativeTypes.git.before_branch = 1
$guardFixture = 'Before merge or push, determine whether the action triggers a production deploy; if it does, park it as a hard-stop and ask the queued deploy question before proceeding.'
$negatedGuardFixture = 'Before merge or push, do not inspect whether it causes a production deploy.'
$fixtureGate = (Test-NormalizedAdapter $goodFixture) -and
    -not (Test-NormalizedAdapter $negativeAgent) -and
    -not (Test-NormalizedAdapter $negativeWorkflow) -and
    -not (Test-NormalizedAdapter $negativeOrder) -and
    -not (Test-NormalizedAdapter $negativeModel) -and
    -not (Test-NormalizedAdapter $negativeCase) -and
    -not (Test-NormalizedAdapter $negativeFork) -and
    -not (Test-NormalizedAdapter $negativeWorkflowUnit) -and
    -not (Test-NormalizedAdapter $negativeAgentEffort) -and
    -not (Test-NormalizedAdapter $negativePersistence) -and
    -not (Test-NormalizedAdapter $negativeBookkeeping) -and
    -not (Test-NormalizedAdapter $negativeSpecifiedApproach) -and
    -not (Test-NormalizedAdapter $negativePlainTextQuestion) -and
    -not (Test-NormalizedAdapter $negativePlainTextTerminal) -and
    -not (Test-NormalizedAdapter $negativeReviewer) -and
    -not (Test-NormalizedAdapter $negativeTypes) -and
    (Test-GuardProse $guardFixture) -and
    -not (Test-GuardProse $negatedGuardFixture)
Add-ContractResult 'contract-negative-fixtures' $fixtureGate 'The validator rejects negated values, wrong order/roles, wrong casing/types, and negated deploy prose.'

$frontmatterFixture = "---`nname: fuck-it-we-ball`ndescription: Use when an approved plan should run autonomously.`n---`n# Body"
$badFrontmatterFixture = "---`nname fuck-it-we-ball`ndescription: Use when broken.`n---`n# Body"
Add-ContractResult 'frontmatter-valid' ((Test-StrictFrontmatter $skill) -and (Test-StrictFrontmatter $frontmatterFixture) -and -not (Test-StrictFrontmatter $badFrontmatterFixture)) 'Frontmatter conforms to the strict supported YAML subset and rejects malformed syntax.'
$readmeFixture = @'
Claude Code: invoke `/fuck-it-we-ball [plan-or-work]`.
Codex: invoke `$fuck-it-we-ball [plan-or-work]`.
'@
$badReadmeFixture = 'Do not use /fuck-it-we-ball or $fuck-it-we-ball; both are unsupported.'
Add-ContractResult 'readme-dual-invocation' ((Test-ReadmeInvocation $readme) -and (Test-ReadmeInvocation $readmeFixture) -and -not (Test-ReadmeInvocation $badReadmeFixture)) 'README contains exact positive invocation instructions for Claude and Codex.'

$precedence = 'Durante una corrida FIWB, el hard-stop de deploy de la skill prevalece sobre esta regla; no ejecutar ni activar producción hasta que se responda su única pregunta de autorización.'
Add-ContractResult 'codex-global-deploy-precedence' $codexAgents.Contains($precedence, [System.StringComparison]::Ordinal) 'Codex global deploy behavior explicitly yields to FIWB.'
Add-ContractResult 'claude-global-deploy-precedence' $claudeInstructions.Contains($precedence, [System.StringComparison]::Ordinal) 'Claude global deploy behavior explicitly yields to FIWB.'

$windowsSnapshotSuffix = '.claude/projects/-home-piero-Desktop-claude/memory/infrastructure_directory.md'
$gitBashCandidate = 'C:\Program Files\Git\bin\bash.exe'
$locatorDeclared = $projectContext -match [regex]::Escape($windowsSnapshotSuffix) -and
    $projectContext -match [regex]::Escape($gitBashCandidate) -and
    $projectContext -match 'bounded fallback'
$locatorCopiesMatch = (Get-FileHash -Algorithm SHA256 -LiteralPath $ProjectContextPath).Hash -eq
    (Get-FileHash -Algorithm SHA256 -LiteralPath $ClaudeProjectContextPath).Hash

$snapshotPath = Join-Path $env:USERPROFILE '.claude\projects\-home-piero-Desktop-claude\memory\infrastructure_directory.md'
$catWorks = $false
if ((Test-Path -LiteralPath $gitBashCandidate) -and (Test-Path -LiteralPath $snapshotPath)) {
    $catOutput = & $gitBashCandidate -lc 'file=$(cygpath -u "$1") && cat -- "$file"' -- $snapshotPath 2>$null
    $catWorks = $LASTEXITCODE -eq 0 -and ($catOutput -join "`n").Length -gt 100
}
Add-ContractResult 'project-context-windows-locator' ($locatorDeclared -and $locatorCopiesMatch -and $catWorks) 'Both project-context copies declare the verified candidate and bounded fallback, and Git Bash cat reads it.'

$copiesMatch = $false
if ((Test-Path -LiteralPath $CodexSkillPath) -and (Test-Path -LiteralPath $ClaudeSkillPath)) {
    $worktreeSkillHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $skillPath).Hash
    $codexSkillHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $CodexSkillPath).Hash
    $claudeSkillHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ClaudeSkillPath).Hash
    $copiesMatch = $worktreeSkillHash -eq $codexSkillHash -and
        $codexSkillHash -eq $claudeSkillHash -and
        $worktreeSkillHash -eq $claudeSkillHash
}
Add-ContractResult 'installed-copy-parity' $copiesMatch 'The worktree, .agents, and .claude skill copies are byte-identical.'

$results | ForEach-Object {
    $status = if ($_.Passed) { 'PASS' } else { 'FAIL' }
    "[$status] $($_.Name) - $($_.Requirement)"
}

$failed = @($results | Where-Object { -not $_.Passed })
"Summary: $($results.Count - $failed.Count) passed, $($failed.Count) failed, $($results.Count) total"

if ($failed.Count -gt 0) {
    exit 1
}
