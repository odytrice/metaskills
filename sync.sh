#!/usr/bin/env bash
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
# Usage:  ./sync.sh              # install/update everywhere
#         ./sync.sh --dry-run    # show what would change
#         ./sync.sh --check      # lint the repo; no install

set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mode=install
case "${1:-}" in
    --dry-run|-n) mode=dry-run ;;
    --check)      mode=check ;;
    "")           ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
esac

# --- Lint ----------------------------------------------------------------------
check() {
    local failures=0
    fail() { echo "FAIL: $*"; failures=$((failures + 1)); }

    local dir name
    for dir in "$repo"/skills/*/; do
        dir="${dir%/}"; name="$(basename "$dir")"
        [[ -f "$dir/SKILL.md" ]] || { fail "skills/$name has no SKILL.md"; continue; }
        grep -q "^name: $name\$" "$dir/SKILL.md" || fail "skills/$name/SKILL.md frontmatter name != '$name'"
        grep -q '^description: .' "$dir/SKILL.md" || fail "skills/$name/SKILL.md has no description"
        grep -nH '^```powershell' "$dir"/*.md 2>/dev/null | sed "s|^$repo/|FAIL: powershell fence in |" && failures=$((failures + 1))
        grep -nHE '^\s*(Set-Location|Set-Content|Remove-Item|Out-File)\b|gh --%' "$dir"/*.md 2>/dev/null \
            | sed "s|^$repo/|FAIL: PowerShell-only command in |" && failures=$((failures + 1))
        [[ -f "$repo/commands/$name.md" ]] || fail "skills/$name has no commands/$name.md"
    done

    # No em/en dashes anywhere in the repo (U+2014, U+2013).
    local dash; dash="$(printf '\xe2\x80\x94\xe2\x80\x93')"
    (cd "$repo" && git ls-files --cached --others --exclude-standard | xargs grep -nH "[$dash]" 2>/dev/null) \
        | sed 's|^|FAIL: em/en dash in |' && failures=$((failures + 1))

    local cmd
    for cmd in "$repo"/commands/*.md; do
        name="$(basename "$cmd" .md)"
        [[ -d "$repo/skills/$name" ]] || fail "commands/$name.md has no skills/$name"
        grep -q '\$ARGUMENTS' "$cmd" || fail "commands/$name.md does not pass \$ARGUMENTS"
    done

    local role roles=()
    for role in "$repo"/agents/claude/*.md "$repo"/agents/opencode/*.md "$repo"/agents/codex/*.toml; do
        role="$(basename "$role")"; role="${role%.*}"
        roles+=("$role")
    done
    md_body()   { awk 'f{print} /^---$/{n++; if(n==2) f=1}' "$1" | sed '/./,$!d'; }
    toml_body() { awk "/^'''\$/{f=0} f{print} /^developer_instructions = '''\$/{f=1}" "$1"; }
    for role in $(printf '%s\n' "${roles[@]}" | sort -u); do
        [[ -f "$repo/agents/claude/$role.md" ]]     || { fail "agents/claude/$role.md missing"; continue; }
        [[ -f "$repo/agents/opencode/$role.md" ]]   || { fail "agents/opencode/$role.md missing"; continue; }
        [[ -f "$repo/agents/codex/$role.toml" ]]    || { fail "agents/codex/$role.toml missing"; continue; }
        local c o x
        c="$(md_body "$repo/agents/claude/$role.md")"
        o="$(md_body "$repo/agents/opencode/$role.md")"
        x="$(toml_body "$repo/agents/codex/$role.toml")"
        [[ "$c" == "$o" ]] || fail "agents/$role: claude and opencode bodies differ"
        [[ "$c" == "$x" ]] || fail "agents/$role: claude and codex bodies differ"
    done

    if (( failures == 0 )); then
        echo "check: OK"
    else
        echo "check: $failures failure(s)"; return 1
    fi
}

# Reject links rather than resolving them: even an internal link can redirect
# a later recursive copy/removal. Preflight is not a concurrent-writer lock.
die() { echo "FAIL: $*" >&2; exit 1; }
safe_name() {
    local upper
    [[ "$1" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ && "$1" != *. ]] || die "unsafe name: $1"
    upper="$(printf '%s' "${1%%.*}" | tr '[:lower:]' '[:upper:]')"
    case "$upper" in CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9]) die "reserved name: $1" ;; esac
}
safe_path() {
    local path="$1"
    [[ "$path" == /* && "$path" != *'/../'* && "$path" != */.. && "$path" != *'/./'* && "$path" != */. ]] || die "unsafe path: $path"
    while [[ "$path" != / ]]; do
        [[ ! -L "$path" ]] || die "linked path: $path"
        if [[ "$path" != "$1" && -e "$path" && ! -d "$path" ]]; then die "non-directory ancestor: $path"; fi
        path="$(dirname "$path")"
    done
}
safe_tree() {
    local path="$1" child names='|' lower
    safe_path "$path"
    [[ -e "$path" ]] || die "missing source/path: $path"
    if [[ -d "$path" ]]; then
        for child in "$path"/* "$path"/.[!.]* "$path"/..?*; do
            [[ -e "$child" || -L "$child" ]] || continue
            safe_name "${child##*/}"
            lower="$(printf '%s' "${child##*/}" | tr '[:upper:]' '[:lower:]')"
            [[ "$names" != *"|$lower|"* ]] || die "case-colliding name: $child"
            names+="$lower|"
            safe_tree "$child"
        done
    elif [[ ! -f "$path" ]]; then die "not a regular file: $path"; fi
}
for source in "$repo/skills" "$repo/commands" "$repo/agents"; do safe_tree "$source"; done
check
[[ $mode != check ]] || exit 0

# --- Install -------------------------------------------------------------------
dry_run=false; [[ $mode == dry-run ]] && dry_run=true
[[ -n "$HOME" ]] || die 'HOME must be an absolute directory'
safe_path "$HOME"

claude_skills="$HOME/.claude/skills"
claude_agents="$HOME/.claude/agents"
opencode_skills="$HOME/.config/opencode/skill"
opencode_agents="$HOME/.config/opencode/agent"
opencode_command="$HOME/.config/opencode/command"
codex_skills="$HOME/.codex/skills"
codex_prompts="$HOME/.codex/prompts"
codex_agents="$HOME/.codex/agents"
manifest_name=".metaskills-manifest"

preflight_set() {
    local root="$1" old src name owned='|' seen='|' lower child
    local -a names=()
    shift
    safe_path "$root"
    [[ ! -e "$root" || -d "$root" ]] || die "not a directory: $root"
    safe_path "$root/$manifest_name"
    if [[ -e "$root/$manifest_name" ]]; then
        [[ -f "$root/$manifest_name" ]] || die "not a regular manifest: $root"
        # Detect NUL and other bytes that shell read would otherwise discard.
        LC_ALL=C tr -d 'A-Za-z0-9_.\r\n-' < "$root/$manifest_name" | cmp -s - /dev/null || die "invalid manifest bytes: $root"
        while IFS= read -r old || [[ -n "$old" ]]; do
            old="${old%$'\r'}"
            safe_name "$old"
            lower="$(printf '%s' "$old" | tr '[:upper:]' '[:lower:]')"
            [[ "$seen" != *"|$lower|"* ]] || die "duplicate manifest name: $old"
            seen+="$lower|"; owned+="$old|"
            names+=("$old")
            safe_path "$root/$old"
            if [[ -e "$root/$old" ]]; then safe_tree "$root/$old"; fi
        done < "$root/$manifest_name"
    fi
    for src in "$@"; do
        name="${src##*/}"; safe_name "$name"
        safe_path "$root/$name"
        if [[ -e "$root/$name" && "$owned" != *"|$name|"* ]]; then die "unmanaged collision: $root/$name"; fi
        names+=("$name")
    done
    for name in "${names[@]}"; do
        # Reject case aliases even on case-sensitive filesystems.
        for child in "$root"/* "$root"/.[!.]* "$root"/..?*; do
            [[ -e "$child" || -L "$child" ]] || continue
            lower="$(printf '%s' "${child##*/}" | tr '[:upper:]' '[:lower:]')"
            if [[ "$lower" == "$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')" && "${child##*/}" != "$name" ]]; then die "case collision: $child"; fi
        done
    done
}
skill_dirs=(); for s in "$repo"/skills/*/; do skill_dirs+=("${s%/}"); done
preflight_set "$claude_skills" "${skill_dirs[@]}"
preflight_set "$opencode_skills" "${skill_dirs[@]}"
preflight_set "$codex_skills" "${skill_dirs[@]}"
preflight_set "$opencode_command" "$repo"/commands/*.md
preflight_set "$codex_prompts" "$repo"/commands/*.md
preflight_set "$opencode_agents" "$repo"/agents/opencode/*.md
preflight_set "$claude_agents" "$repo"/agents/claude/*.md
preflight_set "$codex_agents" "$repo"/agents/codex/*.toml

join_list() {
    local out="" item
    for item in "$@"; do out+="${out:+, }$item"; done
    printf '%s' "$out"
}

# install_set <target_root> <source>...   (dirs are copied recursively, files copied)
# Writes the manifest and removes anything the previous manifest listed that
# is no longer in the set.
install_set() {
    local root="$1"; shift
    $dry_run || mkdir -p "$root"
    local -a entries=()
    local src name
    for src in "$@"; do
        name="$(basename "$src")"
        entries+=("$name")
        if $dry_run; then
            echo "would install '$name' -> $root/$name"
        else
            rm -rf "$root/$name"; cp -R "$src" "$root/$name"
        fi
    done
    local old
    if [[ -f "$root/$manifest_name" ]]; then
        while IFS= read -r old || [[ -n "$old" ]]; do
            old="${old%$'\r'}"
            if ! printf '%s\n' "${entries[@]}" | grep -Fqx -- "$old"; then
                if $dry_run; then echo "would remove stale '$old' from $root"; else rm -rf "${root:?}/$old"; fi
            fi
        done < "$root/$manifest_name"
    fi
    if ! $dry_run; then
        # Replace the entry, not the inode: a manifest may have external hard links.
        rm -f "$root/$manifest_name"
        printf '%s\n' "${entries[@]}" > "$root/$manifest_name"
    fi
}

# --- Skills: identical trees for all three harnesses ---------------------------
install_set "$claude_skills"   "${skill_dirs[@]}"
install_set "$opencode_skills" "${skill_dirs[@]}"
install_set "$codex_skills"    "${skill_dirs[@]}"
skill_names=(); for s in "${skill_dirs[@]}"; do skill_names+=("$(basename "$s")"); done
echo "Skills: $(join_list "${skill_names[@]}")"

# --- Commands: opencode command/ and Codex prompts/ ----------------------------
# Claude Code is skipped deliberately: skills are directly invocable as
# /<name> slash commands there, and a same-named command would collide.
install_set "$opencode_command" "$repo"/commands/*.md
install_set "$codex_prompts"    "$repo"/commands/*.md
command_names=(); for c in "$repo"/commands/*.md; do command_names+=("$(basename "$c" .md)"); done
echo "Commands: $(join_list "${command_names[@]}")"

# --- Agents: per-harness dialects ----------------------------------------------
install_set "$opencode_agents" "$repo"/agents/opencode/*.md
install_set "$claude_agents"   "$repo"/agents/claude/*.md
install_set "$codex_agents"    "$repo"/agents/codex/*.toml
agent_names=(); for a in "$repo"/agents/claude/*.md; do agent_names+=("$(basename "$a" .md)"); done
echo "Agents: $(join_list "${agent_names[@]}")"

echo 'Done. Each project needs an AGENTS.md that satisfies AGENTS.template.md'
echo '(and, for Claude Code, a CLAUDE.md whose first line is @AGENTS.md).'
