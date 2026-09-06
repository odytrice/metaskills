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

    if (-not @(Get-ChildItem (Join-Path $repo 'skills') -Directory).Count) { Fail 'no skills found' }
    if (-not @(Get-ChildItem (Join-Path $repo 'commands') -Filter '*.md').Count) { Fail 'no commands found' }
    foreach ($dialect in 'claude', 'opencode', 'codex') {
        $extension = if ($dialect -eq 'codex') { '*.toml' } else { '*.md' }
        if (-not @(Get-ChildItem (Join-Path $repo "agents/$dialect") -Filter $extension).Count) { Fail "no $dialect agents found" }
    }

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
        if (-not (Test-Path (Join-Path $repo "commands\$name.md"))) { Fail "skills/$name has no commands/$name.md" }
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

function Assert-Name([string]$Name) {
    if ($Name -cnotmatch '^[a-zA-Z0-9_][a-zA-Z0-9_.-]*\z' -or $Name.EndsWith('.') -or
        ($Name.Split('.')[0] -match '^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])$')) {
        throw "unsafe name: $Name"
    }
}

# Reject links, including junctions, rather than resolving them. This preflight
# assumes no concurrent writers; it is not an atomic installer or a lock.
function Assert-Path([string]$Path) {
    if (-not [IO.Path]::IsPathRooted($Path) -or $Path -match '^[A-Za-z]:[^\\/]|^[A-Za-z]:$' -or
        $Path -match '(^|[\\/])\.{1,2}([\\/]|$)') {
        throw "unsafe path: $Path"
    }
    $current = $Path
    while ($current) {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($item) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "linked path: $current" }
            if ($current -cne $Path -and -not $item.PSIsContainer) { throw "non-directory ancestor: $current" }
        }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }
}
function Assert-Tree([string]$Path) {
    Assert-Path $Path
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) {
        $names = @()
        foreach ($child in Get-ChildItem -LiteralPath $Path -Force) {
            Assert-Name $child.Name
            if ($names -contains $child.Name) { throw "case-colliding name: $($child.FullName)" }
            $names += $child.Name
            Assert-Tree $child.FullName
        }
    } elseif ($item -isnot [IO.FileInfo] -or ($item.UnixMode -match '^[bcps]')) {
        throw "not a regular file: $Path"
    }
}
foreach ($source in 'skills', 'commands', 'agents') { Assert-Tree (Join-Path $repo $source) }
$script:failures = 0
$result = Invoke-Check
if ($result -ne 0) { exit 1 }
if ($Check) { exit 0 }

# --- Install -------------------------------------------------------------------
Assert-Path $env:USERPROFILE
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

function Test-Set([string]$Root, [System.IO.FileSystemInfo[]]$Sources) {
    Assert-Path $Root
    if ((Test-Path -LiteralPath $Root) -and -not (Test-Path -LiteralPath $Root -PathType Container)) {
        throw "not a directory: $Root"
    }
    $manifest = Join-Path $Root $manifestName
    Assert-Path $manifest
    $owned = @()
    if (Test-Path -LiteralPath $manifest) {
        if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { throw "not a regular manifest: $manifest" }
        Assert-Tree $manifest
        $bytes = [IO.File]::ReadAllBytes($manifest)
        foreach ($byte in $bytes) {
            if ($byte -gt 127 -or [char]$byte -cnotmatch '[A-Za-z0-9_.\r\n-]') { throw "invalid manifest bytes: $manifest" }
        }
        if ([Text.Encoding]::ASCII.GetString($bytes) -match '\r(?!\n|\z)') { throw "invalid manifest line ending: $manifest" }
        foreach ($old in [IO.File]::ReadAllLines($manifest)) {
            Assert-Name $old
            if ($owned -contains $old) { throw "duplicate manifest name: $old" }
            $owned += $old
            $path = Join-Path $Root $old
            Assert-Path $path
            if (Test-Path -LiteralPath $path) { Assert-Tree $path }
        }
    }
    foreach ($src in $Sources) {
        Assert-Name $src.Name
        $dest = Join-Path $Root $src.Name
        Assert-Path $dest
        if ((Test-Path -LiteralPath $dest) -and $owned -cnotcontains $src.Name) { throw "unmanaged collision: $dest" }
    }
    foreach ($name in (@($Sources | ForEach-Object Name) + $owned)) {
        if (Test-Path -LiteralPath $Root) {
            foreach ($child in Get-ChildItem -LiteralPath $Root -Force) {
                if ($child.Name -eq $name -and $child.Name -cne $name) { throw "case collision: $($child.FullName)" }
            }
        }
    }
}
$skills = @(Get-ChildItem (Join-Path $repo 'skills') -Directory)
$commands = @(Get-ChildItem (Join-Path $repo 'commands') -Filter '*.md')
Test-Set $targets.ClaudeSkills $skills
Test-Set $targets.OpencodeSkills $skills
Test-Set $targets.CodexSkills $skills
Test-Set $targets.OpencodeCommand $commands
Test-Set $targets.CodexPrompts $commands
Test-Set $targets.OpencodeAgents (Get-ChildItem (Join-Path $repo 'agents/opencode') -Filter '*.md')
Test-Set $targets.ClaudeAgents (Get-ChildItem (Join-Path $repo 'agents/claude') -Filter '*.md')
Test-Set $targets.CodexAgents (Get-ChildItem (Join-Path $repo 'agents/codex') -Filter '*.toml')

# Install-Set <root> <sources...>: dirs copied recursively, files copied.
# Writes the manifest and removes anything the previous manifest listed that
# is no longer in the set.
function Install-Set {
    param([string]$Root, [System.IO.FileSystemInfo[]]$Sources)
    if (-not (Test-Path -LiteralPath $Root) -and $PSCmdlet.ShouldProcess($Root, 'create directory')) {
        New-Item -ItemType Directory -Force -Path $Root | Out-Null
    }
    $entries = @()
    foreach ($src in $Sources) {
        $name = $src.Name
        $entries += $name
        $dest = Join-Path $Root $name
        if ($PSCmdlet.ShouldProcess($dest, "install '$name'")) {
            if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
            Copy-Item -Recurse -LiteralPath $src.FullName -Destination $dest
        }
    }
    $manifest = Join-Path $Root $manifestName
    if (Test-Path -LiteralPath $manifest) {
        foreach ($old in Get-Content -LiteralPath $manifest) {
            if ($entries -ccontains $old) { continue }
            $stale = Join-Path $Root $old
            if ((Test-Path -LiteralPath $stale) -and $PSCmdlet.ShouldProcess($stale, "remove stale '$old'")) {
                Remove-Item -Recurse -Force -LiteralPath $stale
            }
        }
    }
    if ($PSCmdlet.ShouldProcess($manifest, 'write manifest')) {
        # Replace the entry, not the inode: a manifest may have external hard links.
        [System.IO.File]::Delete($manifest)
        [System.IO.File]::WriteAllLines($manifest, [string[]]$entries)
    }
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
