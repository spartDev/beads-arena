#!/usr/bin/env bash
# PreToolUse(Edit|Write): the floor never drops. Active only inside an arena (.beads/).
# Refuses an edit that ADDS a suppression, a skipped or focused test, or a not-implemented stub,
# unless the added line carries "arena-allow: <reason>" (visible to reviewers in the diff).
set -uo pipefail

input="$(cat)"
tool="$(jq -r '.tool_name // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
cd "${cwd:-.}" 2>/dev/null || exit 0
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[ -d "$root/.beads" ] || exit 0

case "$tool" in
  Edit)
    before="$(jq -r '.tool_input.old_string // ""' <<<"$input")"
    after="$(jq -r '.tool_input.new_string // ""' <<<"$input")"
    ;;
  Write)
    after="$(jq -r '.tool_input.content // ""' <<<"$input")"
    if [ -n "$file" ] && [ -f "$file" ]; then before="$(cat "$file")"; else before=""; fi
    ;;
  *) exit 0 ;;
esac

# Markdown and the arena's own docs may mention these patterns freely.
case "$file" in
  *.md|*.mdx|*.txt|*/CONSTRAINTS*|*/.beads/*) exit 0 ;;
esac

patterns=(
  '@ts-ignore' '@ts-nocheck' 'eslint-disable' 'biome-ignore' 'prettier-ignore'
  '# type: ignore' '# noqa' '# pragma: no cover' '//nolint' '@SuppressWarnings'
  '\b(it|test|describe|context)\.(skip|only|todo)\b' '\bx(it|describe|test)\(' '\bf(it|describe)\('
  'pytest\.mark\.skip' '@Disabled' '@Ignore\b'
  'throw new Error\(["'"'"'`](not implemented|TODO)' 'raise NotImplementedError'
)

# Count matching lines without an arena-allow marker.
offending() { grep -E -- "$1" <<<"$2" 2>/dev/null | grep -vc 'arena-allow:' || true; }

added=()
for p in "${patterns[@]}"; do
  b="$(offending "$p" "$before")"; a="$(offending "$p" "$after")"
  if [ "${a:-0}" -gt "${b:-0}" ]; then added+=("$p"); fi
done

if [ "${#added[@]}" -gt 0 ]; then
  list="$(printf '%s, ' "${added[@]}" | sed 's/, $//')"
  reason="arena floor: this edit adds ${list} in ${file:-the file}. Fix the cause instead. If an exception is truly needed, put it on that line with a comment 'arena-allow: <reason>' so reviewers see it."
  jq -n --arg r "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
fi
exit 0
