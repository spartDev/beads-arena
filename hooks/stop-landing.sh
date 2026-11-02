#!/usr/bin/env bash
# Stop: landing-the-plane check. Never blocks; prints one line for the human when something
# needs attention: the pit, open claims, uncommitted work.
set -uo pipefail

input="$(cat || true)"
[ "$(jq -r '.stop_hook_active // false' <<<"$input" 2>/dev/null)" = "true" ] && exit 0
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
cd "${cwd:-${CLAUDE_PROJECT_DIR:-.}}" 2>/dev/null || exit 0
command -v bd >/dev/null 2>&1 || exit 0
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[ -d "$root/.beads" ] || exit 0
cd "$root"

len() { jq 'length' 2>/dev/null || echo 0; }

claimed="$(bd list --status in_progress --json 2>/dev/null | len)"
dirty="$(git status --porcelain 2>/dev/null | grep -vc '^?? \.arena/' || true)"
blocked_ids="$(bd blocked --json 2>/dev/null | jq -c '[.[]?.id]' 2>/dev/null || echo '[]')"
pit_gates="$(bd gate list --json 2>/dev/null | jq --argjson b "$blocked_ids" \
  '[.[]? | select((.await_type == null or .await_type == "human") and (.id as $i | $b | index($i) | not))] | length' 2>/dev/null || echo 0)"
for_human="$(bd list --label triage:ready-for-human --json 2>/dev/null | len)"
needs_info="$(bd list --label triage:needs-info --json 2>/dev/null | len)"
pit=$(( pit_gates + for_human + needs_info ))

parts=()
[ "$pit" -gt 0 ] && parts+=("pit: $pit waiting on you (/arena:pit)")
[ "$claimed" -gt 0 ] && parts+=("$claimed ticket(s) in progress")
[ "${dirty:-0}" -gt 0 ] && parts+=("${dirty} uncommitted change(s)")

[ "${#parts[@]}" -eq 0 ] && exit 0
msg="arena: $(printf '%s; ' "${parts[@]}" | sed 's/; $//')"
jq -n --arg m "$msg" '{systemMessage: $m}'
exit 0
