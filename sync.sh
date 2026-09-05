#!/usr/bin/env bash
# Installs the metaskills harness into all three agent harnesses:
#   Claude Code  -> ~/.claude          (skills, agents)
#   opencode     -> ~/.config/opencode (skill, agent, command)
#   Codex        -> ~/.codex           (skills, prompts)
#
# Only items managed by this repo are touched; other skills/agents/commands
# in the target directories are left alone.
#
# Usage:  ./sync.sh              # install/update everywhere
#         ./sync.sh --dry-run    # show what would change

set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

dry_run=false
if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]]; then
    dry_run=true
fi

claude_skills="$HOME/.claude/skills"
claude_agents="$HOME/.claude/agents"
opencode_skills="$HOME/.config/opencode/skill"
opencode_agents="$HOME/.config/opencode/agent"
opencode_command="$HOME/.config/opencode/command"
codex_skills="$HOME/.codex/skills"
codex_prompts="$HOME/.codex/prompts"
codex_agents="$HOME/.codex/agents"

for dir in "$claude_skills" "$claude_agents" "$opencode_skills" "$opencode_agents" \
           "$opencode_command" "$codex_skills" "$codex_prompts" "$codex_agents"; do
    $dry_run || mkdir -p "$dir"
done

join_list() {
    local out="" item
    for item in "$@"; do out+="${out:+, }$item"; done
    printf '%s' "$out"
}

install_skill_dir() {
    local source="$1" target_root="$2"
    local name dest
    name="$(basename "$source")"
    dest="$target_root/$name"
    if $dry_run; then
        echo "would install skill '$name' -> $dest"
    else
        rm -rf "$dest"
        cp -R "$source" "$dest"
    fi
}

install_file() {
    local source="$1" target_root="$2"
    local name dest
    name="$(basename "$source")"
    dest="$target_root/$name"
    if $dry_run; then
        echo "would install file '$name' -> $dest"
    else
        cp -f "$source" "$dest"
    fi
}

remove_legacy_path() {
    local path="$1"
    if [[ -e "$path" ]]; then
        if $dry_run; then
            echo "would remove legacy managed file -> $path"
        else
            rm -rf "$path"
        fi
    fi
}

# Remove legacy managed installs that were renamed in this repository.
remove_legacy_path "$claude_skills/plan"
remove_legacy_path "$opencode_skills/plan"
remove_legacy_path "$codex_skills/plan"
remove_legacy_path "$opencode_command/plan.md"
remove_legacy_path "$codex_prompts/plan.md"
# agent-login was removed from the shared harness; auth now lives in
# each project's AGENTS.md (AGENTS.template.md § Agent Login).
remove_legacy_path "$claude_skills/agent-login"
remove_legacy_path "$opencode_skills/agent-login"
remove_legacy_path "$codex_skills/agent-login"

# --- Skills: identical SKILL.md trees for all three harnesses ---------------
skill_names=()
for skill in "$repo"/skills/*/; do
    skill="${skill%/}"
    install_skill_dir "$skill" "$claude_skills"
    install_skill_dir "$skill" "$opencode_skills"
    install_skill_dir "$skill" "$codex_skills"
    skill_names+=("$(basename "$skill")")
done
echo "Skills installed: $(join_list "${skill_names[@]}")"

# --- Commands: opencode command/ and Codex prompts/ -------------------------
# Claude Code is skipped deliberately: skills are directly invocable as
# /<name> slash commands there, and a same-named command would collide.
command_names=()
for cmd in "$repo"/commands/*.md; do
    install_file "$cmd" "$opencode_command"
    install_file "$cmd" "$codex_prompts"
    command_names+=("$(basename "$cmd" .md)")
done
echo "Commands installed: $(join_list "${command_names[@]}")"

# --- Agents: per-harness dialects --------------------------------------------
opencode_names=()
for agent in "$repo"/agents/opencode/*.md; do
    install_file "$agent" "$opencode_agents"
    opencode_names+=("$(basename "$agent" .md)")
done
claude_names=()
for agent in "$repo"/agents/claude/*.md; do
    install_file "$agent" "$claude_agents"
    claude_names+=("$(basename "$agent" .md)")
done
codex_names=()
for agent in "$repo"/agents/codex/*.toml; do
    install_file "$agent" "$codex_agents"
    codex_names+=("$(basename "$agent" .toml)")
done
echo "Agents installed: opencode($(join_list "${opencode_names[@]}")) claude($(join_list "${claude_names[@]}")) codex($(join_list "${codex_names[@]}"))"

echo 'Done. Remember: each project needs an AGENTS.md that satisfies AGENTS.template.md,'
echo 'and (for Claude Code) a CLAUDE.md whose first line is @AGENTS.md.'
