#!/usr/bin/env bash
# SessionStart: inject the arena brief, plus bd prime when Beads' own hook is not installed.
# Silent outside an arena (no .beads directory). Fires again after compaction.
set -uo pipefail

input="$(cat || true)"
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
cd "${cwd:-${CLAUDE_PROJECT_DIR:-.}}" 2>/dev/null || exit 0

command -v bd >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[ -d "$root/.beads" ] || exit 0
cd "$root"

# bd init (1.3.x) installs its own SessionStart hook running bd prime. Inject bd prime here only
# when no such hook exists, so the context is never duplicated.
prime=""
if ! grep -qs 'bd prime' "$root/.claude/settings.json" "$root/.claude/settings.local.json" "$HOME/.claude/settings.json" 2>/dev/null; then
  prime="$(bd prime --max-memory-chars 2000 2>/dev/null || true)"
fi

count() { jq 'length' 2>/dev/null <<<"$1" || echo 0; }
gates="$(bd gate list --json 2>/dev/null || echo '[]')"
human_gates="$(jq '[.[] | select(.await_type == null or .await_type == "human")]' <<<"$gates" 2>/dev/null || echo '[]')"
blocked_ids="$(bd blocked --json 2>/dev/null | jq -c '[.[]?.id]' 2>/dev/null || echo '[]')"
pit_gates="$(jq --argjson b "$blocked_ids" '[.[] | select(.id as $i | $b | index($i) | not)]' <<<"$human_gates" 2>/dev/null || echo '[]')"
for_human="$(bd list --label triage:ready-for-human --json 2>/dev/null || echo '[]')"
needs_info="$(bd list --label triage:needs-info --json 2>/dev/null || echo '[]')"
in_review="$(bd list --status in_review --json 2>/dev/null || echo '[]')"
in_progress="$(bd list --status in_progress --json 2>/dev/null || echo '[]')"
ready="$(bd ready --label triage:ready-for-agent --json 2>/dev/null || echo '[]')"
seasons="$(bd list --type molecule --json 2>/dev/null | jq '[.[]? | select(.title == "arena-season")]' 2>/dev/null || echo '[]')"

pit=$(( $(count "$pit_gates") + $(count "$for_human") + $(count "$needs_info") ))

top_pit="$(jq -r '.[0:3][] | "  - \(.id) \(.title)"' <<<"$pit_gates" 2>/dev/null)
$(jq -r '.[0:3][] | "  - \(.id) \(.title) (ready-for-human)"' <<<"$for_human" 2>/dev/null)"
top_ready="$(jq -r '.[0:5][] | "  - \(.id) P\(.priority) \(.title)"' <<<"$ready" 2>/dev/null)"

brief="# Arena

Seasons in flight: $(count "$seasons"). Claimed: $(count "$in_progress"). PRs in review: $(count "$in_review"). Agent frontier: $(count "$ready").
Pit (waiting on the human): $pit.
$( [ "$pit" -gt 0 ] && printf 'Top of the pit:\n%s\n' "$(sed '/^$/d' <<<"$top_pit")" )
$( [ "$(count "$ready")" -gt 0 ] && printf 'Next in the frontier:\n%s\n' "$top_ready" )
Rules: read the arena:protocol skill before touching a ticket. Beads is the only tracker. One ticket, one worktree, one PR, commits carry Refs: <ticket>. Unsure what to do: /arena:next."

# Brief first: if the host truncates, the arena state survives and bd prime is what gets cut.
context="$brief"
[ -n "$prime" ] && context="$(printf '%s\n\n%s' "$brief" "$prime")"
# Claude Code caps injected context at 10,000 characters.
context="${context:0:9800}"

jq -n --arg c "$context" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
