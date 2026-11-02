#!/usr/bin/env bash
# PreToolUse(Bash): the arena's referee on shell commands. Active only inside an arena (.beads/).
#   deny: bd edit (hangs agents), forcing a live claim, commits without "Refs: <ticket>", plain force push
#   ask:  human gate resolution, merges, pushes to the default branch, deploys, infra apply/destroy,
#         destructive cloud and cluster commands. The permission prompt is the human's signature.
set -uo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
[ -n "$cmd" ] || exit 0
cd "${cwd:-.}" 2>/dev/null || exit 0
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[ -d "$root/.beads" ] || exit 0

decide() { # decide <deny|ask> <reason>
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

has() { grep -Eq -- "$1" <<<"$cmd"; }

# --- Beads hygiene -------------------------------------------------------------
if has '(^|[;&|[:space:]])bd[[:space:]]+edit([[:space:]]|$)'; then
  decide deny "arena: 'bd edit' opens \$EDITOR and hangs the agent. Use bd update <id> --description/--notes/--design/--acceptance."
fi
if has '(^|[;&|[:space:]])bd[[:space:]]+(update|close)[[:space:]].*--force'; then
  decide deny "arena: --force would take over a live claim or close past open children or blockers. Pick other work, or ask the human."
fi
if has '(^|[;&|[:space:]])bd[[:space:]]+gate[[:space:]]+resolve'; then
  decide ask "arena: resolving a gate is a human decision (sign-off, approval, merge). Approve only if the human just said yes."
fi

# --- Commits carry their ticket --------------------------------------------------
if has '(^|[;&|[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+commit([[:space:]]|$)'; then
  if has '--no-edit' || has 'Refs:[[:space:]]*[A-Za-z0-9]'; then
    :
  else
    msgfile="$(grep -Eo -- '(-F|--file)[= ]+[^[:space:];&|]+' <<<"$cmd" | head -1 | sed -E 's/^(-F|--file)[= ]+//')"
    if [ -n "$msgfile" ] && [ -f "$msgfile" ] && grep -Eq 'Refs:[[:space:]]*[A-Za-z0-9]' "$msgfile"; then
      :
    else
      decide deny "arena: every commit carries the trailer 'Refs: <ticket-id>' (find yours: bd list --status in_progress --json). No ticket yet? Create and claim one first."
    fi
  fi
fi

# --- Pushes -----------------------------------------------------------------------
if has '(^|[;&|[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]]|$)'; then
  if has '[[:space:]](-f|--force)([[:space:]]|$)' && ! has '--force-with-lease'; then
    decide deny "arena: plain force push is refused. Use --force-with-lease on your own arena/* branch."
  fi
  if has '[[:space:]]\+[^[:space:]]+'; then
    decide deny "arena: a +refspec is a force push. Use --force-with-lease on your own arena/* branch."
  fi
  if has '[[:space:]](origin[[:space:]]+)?([^[:space:]]*:)?(refs/heads/)?(main|master)([[:space:]]|$)'; then
    decide ask "arena: direct push to the main branch. Arena work lands through one PR per ticket. Allow only if the human asked for it."
  fi
fi

# --- Irreversible: the human decides --------------------------------------------------
if has '(^|[;&|[:space:]])gh[[:space:]]+pr[[:space:]]+merge' || has '(^|[;&|[:space:]])gh[[:space:]]+api[[:space:]].*pulls/[0-9]+/merge'; then
  decide ask "arena: merging is the human's call. The referee prepares, the human merges."
fi
if has '(^|[;&|[:space:]])gh[[:space:]]+workflow[[:space:]]+run'; then
  decide ask "arena: triggering a workflow may deploy or publish. Confirm with the human."
fi
if has '(^|[;&|[:space:]])(npm|pnpm|yarn|bun)[[:space:]]+(run[[:space:]]+)?(deploy|release|publish)([:[:space:]]|$)' \
  || has '(^|[;&|[:space:]])(vercel|netlify)[[:space:]].*--prod' \
  || has '(^|[;&|[:space:]])(fly|flyctl|firebase|amplify)[[:space:]]+(deploy|publish)' \
  || has '(^|[;&|[:space:]])helm[[:space:]]+(upgrade|install|uninstall|rollback)'; then
  decide ask "arena: deploys go through the season's ship step after the human approval gate."
fi
if has '(^|[;&|[:space:]])(terraform|tofu|terragrunt)[[:space:]]+([^;&|]*[[:space:]])?(apply|destroy)([[:space:]]|$)'; then
  decide ask "arena: infrastructure apply/destroy is irreversible. Attach the plan to the PR; the human applies."
fi
if has '(^|[;&|[:space:]])(cdk|pulumi|sst|serverless|sls)[[:space:]]+([^;&|]*[[:space:]])?(deploy|destroy|up|remove)([[:space:]]|$)'; then
  decide ask "arena: deploys go through the season's ship step after the human approval gate."
fi
if has '(^|[;&|[:space:]])aws[[:space:]].*[[:space:]](delete-|terminate-|remove-|deregister-|rb[[:space:]]|rm[[:space:]].*--recursive)'; then
  decide ask "arena: destructive AWS command. Confirm with the human."
fi
if has '(^|[;&|[:space:]])kubectl[[:space:]]+(apply|delete|drain|replace|rollout[[:space:]]+(restart|undo))'; then
  decide ask "arena: cluster change. Confirm with the human."
fi
if has '(^|[;&|[:space:]])git[[:space:]]+(reset[[:space:]]+--hard|clean[[:space:]]+-[a-zA-Z]*f)'; then
  decide ask "arena: this discards uncommitted work. Confirm it is yours to discard."
fi

exit 0
