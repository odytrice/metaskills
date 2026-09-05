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

if [[ $mode == check ]]; then
    check
    exit
fi

# --- Install -------------------------------------------------------------------
dry_run=false; [[ $mode == dry-run ]] && dry_run=true

claude_skills="$HOME/.claude/skills"
claude_agents="$HOME/.claude/agents"
opencode_skills="$HOME/.config/opencode/skill"
opencode_agents="$HOME/.config/opencode/agent"
opencode_command="$HOME/.config/opencode/command"
codex_skills="$HOME/.codex/skills"
codex_prompts="$HOME/.codex/prompts"
codex_agents="$HOME/.codex/agents"
manifest_name=".metaskills-manifest"

for dir in "$claude_skills" "$claude_agents" "$opencode_skills" "$opencode_agents" \
           "$opencode_command" "$codex_skills" "$codex_prompts" "$codex_agents"; do
    $dry_run || mkdir -p "$dir"
done

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
    local -a entries=()
    local src name
    for src in "$@"; do
        name="$(basename "$src")"
        entries+=("$name")
        if $dry_run; then
            echo "would install '$name' -> $root/$name"
        elif [[ -d "$src" ]]; then
            rm -rf "$root/$name"; cp -R "$src" "$root/$name"
        else
            cp -f "$src" "$root/$name"
        fi
    done
    local old
    if [[ -f "$root/$manifest_name" ]]; then
        while IFS= read -r old; do
            [[ -z "$old" ]] && continue
            if ! printf '%s\n' "${entries[@]}" | grep -qx -- "$old"; then
                if $dry_run; then echo "would remove stale '$old' from $root"; else rm -rf "${root:?}/$old"; fi
            fi
        done < "$root/$manifest_name"
    fi
    $dry_run || printf '%s\n' "${entries[@]}" > "$root/$manifest_name"
}

# Legacy installs that predate the manifest. Safe to delete once every
# machine has synced at least once with manifests in place.
for legacy in "$claude_skills/plan" "$opencode_skills/plan" "$codex_skills/plan" \
              "$opencode_command/plan.md" "$codex_prompts/plan.md" \
              "$claude_skills/agent-login" "$opencode_skills/agent-login" "$codex_skills/agent-login" \
              "$claude_skills/deploy" "$opencode_skills/deploy" "$codex_skills/deploy" \
              "$opencode_command/deploy.md" "$codex_prompts/deploy.md" \
              "$claude_agents/deploy.md" "$opencode_agents/deploy.md" "$codex_agents/deploy.toml"; do
    if [[ -e "$legacy" ]]; then
        if $dry_run; then echo "would remove legacy '$legacy'"; else rm -rf "$legacy"; fi
    fi
done

# --- Skills: identical trees for all three harnesses ---------------------------
skill_dirs=(); for s in "$repo"/skills/*/; do skill_dirs+=("${s%/}"); done
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
