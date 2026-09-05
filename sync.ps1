# Installs the metaskills harness into all three agent harnesses:
#   Claude Code  -> ~/.claude          (skills, agents)
#   opencode     -> ~/.config/opencode (skill, agent, command)
#   Codex        -> ~/.codex           (skills, prompts, agents)
#
# Only items managed by this repo are touched. Each target directory gets a
# .metaskills-manifest listing what this repo installed there; on the next run
# anything in the old manifest that the repo no longer ships is removed, so
# renames and deletions clean up after themselves.
#
# Usage:  .\sync.ps1            # install/update everywhere
#         .\sync.ps1 -WhatIf    # show what would change
#         .\sync.ps1 -Check     # lint the repo; no install

[CmdletBinding(SupportsShouldProcess = $true)]
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$manifestName = '.metaskills-manifest'

# --- Lint ----------------------------------------------------------------------
function Invoke-Check {
    function Fail([string]$Message) { Write-Host "FAIL: $Message"; $script:failures++ }

    foreach ($dir in Get-ChildItem (Join-Path $repo 'skills') -Directory) {
        $name = $dir.Name
        $skill = Join-Path $dir.FullName 'SKILL.md'
        if (-not (Test-Path $skill)) { Fail "skills/$name has no SKILL.md"; continue }
        $text = Get-Content $skill -Raw
        if ($text -notmatch "(?m)^name: $([regex]::Escape($name))`$") { Fail "skills/$name/SKILL.md frontmatter name != '$name'" }
        if ($text -notmatch '(?m)^description: .') { Fail "skills/$name/SKILL.md has no description" }
        foreach ($md in Get-ChildItem $dir.FullName -Filter '*.md') {
            $rel = "skills/$name/$($md.Name)"
            $lines = Get-Content $md.FullName
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match '^```powershell') { Fail "powershell fence in ${rel}:$($i + 1)" }
                if ($lines[$i] -match '^\s*(Set-Location|Set-Content|Remove-Item|Out-File)\b|gh --%') { Fail "PowerShell-only command in ${rel}:$($i + 1)" }
            }
        }
    }

    # No em/en dashes anywhere in the repo (U+2014, U+2013).
    $tracked = & git -C $repo ls-files --cached --others --exclude-standard
    foreach ($rel in $tracked) {
        $path = Join-Path $repo $rel
        if (-not (Test-Path $path -PathType Leaf)) { continue }
        $lines = Get-Content $path
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '[\u2014\u2013]') { Fail "em/en dash in ${rel}:$($i + 1)" }
        }
    }

    foreach ($cmd in Get-ChildItem (Join-Path $repo 'commands') -Filter '*.md') {
        $name = $cmd.BaseName
        if (-not (Test-Path (Join-Path $repo "skills\$name"))) { Fail "commands/$name.md has no skills/$name" }
        if ((Get-Content $cmd.FullName -Raw) -notmatch '\$ARGUMENTS') { Fail "commands/$name.md does not pass `$ARGUMENTS" }
    }

    $roles = @(
        Get-ChildItem (Join-Path $repo 'agents\claude') -Filter '*.md'
        Get-ChildItem (Join-Path $repo 'agents\opencode') -Filter '*.md'
        Get-ChildItem (Join-Path $repo 'agents\codex') -Filter '*.toml'
    ) | ForEach-Object BaseName | Sort-Object -Unique
    function Get-MdBody([string]$Path) {
        $lines = Get-Content $Path; $n = 0; $out = @()
        foreach ($l in $lines) { if ($l -eq '---') { $n++; continue }; if ($n -ge 2) { $out += $l } }
        ($out -join "`n").TrimStart("`n")
    }
    function Get-TomlBody([string]$Path) {
        $lines = Get-Content $Path; $in = $false; $out = @()
        foreach ($l in $lines) {
            if ($l -eq "'''") { $in = $false; continue }
            if ($in) { $out += $l }
            if ($l -eq "developer_instructions = '''") { $in = $true }
        }
        $out -join "`n"
    }
    foreach ($role in $roles) {
        $c = Join-Path $repo "agents\claude\$role.md"; $o = Join-Path $repo "agents\opencode\$role.md"; $x = Join-Path $repo "agents\codex\$role.toml"
        $missing = $false
        if (-not (Test-Path $c)) { Fail "agents/claude/$role.md missing"; $missing = $true }
        if (-not (Test-Path $o)) { Fail "agents/opencode/$role.md missing"; $missing = $true }
        if (-not (Test-Path $x)) { Fail "agents/codex/$role.toml missing"; $missing = $true }
        if ($missing) { continue }
        $cb = Get-MdBody $c
        if ($cb -ne (Get-MdBody $o))   { Fail "agents/${role}: claude and opencode bodies differ" }
        if ($cb -ne (Get-TomlBody $x)) { Fail "agents/${role}: claude and codex bodies differ" }
    }

    if ($script:failures -eq 0) { Write-Host 'check: OK'; return 0 }
    Write-Host "check: $($script:failures) failure(s)"; return 1
}

if ($Check) {
    $script:failures = 0
    exit (Invoke-Check)
}

# --- Install -------------------------------------------------------------------
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
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
}

# Install-Set <root> <sources...>: dirs copied recursively, files copied.
# Writes the manifest and removes anything the previous manifest listed that
# is no longer in the set.
function Install-Set {
    param([string]$Root, [System.IO.FileSystemInfo[]]$Sources)
    $entries = @()
    foreach ($src in $Sources) {
        $name = $src.Name
        $entries += $name
        $dest = Join-Path $Root $name
        if ($PSCmdlet.ShouldProcess($dest, "install '$name'")) {
            if ($src.PSIsContainer) {
                if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
                Copy-Item -Recurse -Path $src.FullName -Destination $dest
            } else {
                Copy-Item -Force -Path $src.FullName -Destination $dest
            }
        }
    }
    $manifest = Join-Path $Root $manifestName
    if (Test-Path $manifest) {
        foreach ($old in Get-Content $manifest) {
            if ([string]::IsNullOrWhiteSpace($old) -or $entries -contains $old) { continue }
            $stale = Join-Path $Root $old
            if ((Test-Path $stale) -and $PSCmdlet.ShouldProcess($stale, "remove stale '$old'")) {
                Remove-Item -Recurse -Force $stale
            }
        }
    }
    if ($PSCmdlet.ShouldProcess($manifest, 'write manifest')) {
        [System.IO.File]::WriteAllLines($manifest, [string[]]$entries)
    }
}

# Legacy installs that predate the manifest. Safe to delete once every
# machine has synced at least once with manifests in place.
$legacy = @(
    (Join-Path $targets.ClaudeSkills 'plan'), (Join-Path $targets.OpencodeSkills 'plan'), (Join-Path $targets.CodexSkills 'plan'),
    (Join-Path $targets.OpencodeCommand 'plan.md'), (Join-Path $targets.CodexPrompts 'plan.md'),
    (Join-Path $targets.ClaudeSkills 'agent-login'), (Join-Path $targets.OpencodeSkills 'agent-login'), (Join-Path $targets.CodexSkills 'agent-login'),
    (Join-Path $targets.ClaudeSkills 'deploy'), (Join-Path $targets.OpencodeSkills 'deploy'), (Join-Path $targets.CodexSkills 'deploy'),
    (Join-Path $targets.OpencodeCommand 'deploy.md'), (Join-Path $targets.CodexPrompts 'deploy.md'),
    (Join-Path $targets.ClaudeAgents 'deploy.md'), (Join-Path $targets.OpencodeAgents 'deploy.md'), (Join-Path $targets.CodexAgents 'deploy.toml')
)
foreach ($path in $legacy) {
    if ((Test-Path $path) -and $PSCmdlet.ShouldProcess($path, 'remove legacy')) { Remove-Item -Recurse -Force $path }
}

# --- Skills: identical trees for all three harnesses ---------------------------
$skills = Get-ChildItem (Join-Path $repo 'skills') -Directory
Install-Set $targets.ClaudeSkills   $skills
Install-Set $targets.OpencodeSkills $skills
Install-Set $targets.CodexSkills    $skills
Write-Host ("Skills: " + (($skills | ForEach-Object Name) -join ', '))

# --- Commands: opencode command/ and Codex prompts/ ----------------------------
# Claude Code is skipped deliberately: skills are directly invocable as
# /<name> slash commands there, and a same-named command would collide.
$commands = Get-ChildItem (Join-Path $repo 'commands') -Filter '*.md'
Install-Set $targets.OpencodeCommand $commands
Install-Set $targets.CodexPrompts    $commands
Write-Host ("Commands: " + (($commands | ForEach-Object BaseName) -join ', '))

# --- Agents: per-harness dialects ----------------------------------------------
Install-Set $targets.OpencodeAgents (Get-ChildItem (Join-Path $repo 'agents\opencode') -Filter '*.md')
Install-Set $targets.ClaudeAgents   (Get-ChildItem (Join-Path $repo 'agents\claude') -Filter '*.md')
Install-Set $targets.CodexAgents    (Get-ChildItem (Join-Path $repo 'agents\codex') -Filter '*.toml')
Write-Host ("Agents: " + ((Get-ChildItem (Join-Path $repo 'agents\claude') -Filter '*.md' | ForEach-Object BaseName) -join ', '))

Write-Host 'Done. Each project needs an AGENTS.md that satisfies AGENTS.template.md'
Write-Host '(and, for Claude Code, a CLAUDE.md whose first line is @AGENTS.md).'
