# Installs the metaskills harness into all three agent harnesses:
#   Claude Code  -> ~/.claude        (skills, agents)
#   opencode     -> ~/.config/opencode (skill, agent, command)
#   Codex        -> ~/.codex         (skills, prompts)
#
# Only items managed by this repo are touched; other skills/agents/commands
# in the target directories are left alone.
#
# Usage:  .\sync.ps1            # install/update everywhere
#         .\sync.ps1 -WhatIf    # show what would change

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot

$targets = @{
    ClaudeSkills    = Join-Path $env:USERPROFILE '.claude\skills'
    ClaudeAgents    = Join-Path $env:USERPROFILE '.claude\agents'
    OpencodeSkills  = Join-Path $env:USERPROFILE '.config\opencode\skill'
    OpencodeAgents  = Join-Path $env:USERPROFILE '.config\opencode\agent'
    OpencodeCommand = Join-Path $env:USERPROFILE '.config\opencode\command'
    CodexSkills     = Join-Path $env:USERPROFILE '.codex\skills'
    CodexPrompts    = Join-Path $env:USERPROFILE '.codex\prompts'
    CodexAgents     = Join-Path $env:USERPROFILE '.codex\agents'
}

foreach ($dir in $targets.Values) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}

function Install-SkillDir {
    param([string]$Source, [string]$TargetRoot)
    $name = Split-Path $Source -Leaf
    $dest = Join-Path $TargetRoot $name
    if ($PSCmdlet.ShouldProcess($dest, "install skill '$name'")) {
        if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
        Copy-Item -Recurse -Path $Source -Destination $dest
    }
}

function Install-File {
    param([string]$Source, [string]$TargetRoot)
    $name = Split-Path $Source -Leaf
    $dest = Join-Path $TargetRoot $name
    if ($PSCmdlet.ShouldProcess($dest, "install file '$name'")) {
        Copy-Item -Force -Path $Source -Destination $dest
    }
}

# --- Skills: identical SKILL.md trees for all three harnesses ---------------
$skills = Get-ChildItem (Join-Path $repo 'skills') -Directory
foreach ($skill in $skills) {
    Install-SkillDir $skill.FullName $targets.ClaudeSkills
    Install-SkillDir $skill.FullName $targets.OpencodeSkills
    Install-SkillDir $skill.FullName $targets.CodexSkills
}
Write-Host ("Skills installed: " + (($skills | ForEach-Object Name) -join ', '))

# --- Commands: opencode command/ and Codex prompts/ -------------------------
# Claude Code is skipped deliberately: skills are directly invocable as
# /<name> slash commands there, and a same-named command would collide.
$commands = Get-ChildItem (Join-Path $repo 'commands') -Filter '*.md'
foreach ($cmd in $commands) {
    Install-File $cmd.FullName $targets.OpencodeCommand
    Install-File $cmd.FullName $targets.CodexPrompts
}
Write-Host ("Commands installed: " + (($commands | ForEach-Object BaseName) -join ', '))

# --- Agents: per-harness dialects --------------------------------------------
$opencodeAgents = Get-ChildItem (Join-Path $repo 'agents\opencode') -Filter '*.md'
foreach ($agent in $opencodeAgents) {
    Install-File $agent.FullName $targets.OpencodeAgents
}
$claudeAgents = Get-ChildItem (Join-Path $repo 'agents\claude') -Filter '*.md'
foreach ($agent in $claudeAgents) {
    Install-File $agent.FullName $targets.ClaudeAgents
}
$codexAgents = Get-ChildItem (Join-Path $repo 'agents\codex') -Filter '*.toml'
foreach ($agent in $codexAgents) {
    Install-File $agent.FullName $targets.CodexAgents
}
Write-Host ("Agents installed: opencode(" + (($opencodeAgents | ForEach-Object BaseName) -join ', ') + ") claude(" + (($claudeAgents | ForEach-Object BaseName) -join ', ') + ") codex(" + (($codexAgents | ForEach-Object BaseName) -join ', ') + ")")

Write-Host 'Done. Remember: each project needs an AGENTS.md that satisfies AGENTS.template.md,'
Write-Host 'and (for Claude Code) a CLAUDE.md whose first line is @AGENTS.md.'
