---
name: pit
description: Show the human everything in the arena that only they can move, ranked by how much work each decision unblocks, and let them resolve it right here: sign-offs, merges, deploy approvals, questions agents parked as needs-info, escalated review threads.
argument-hint: "[season root]"
---

# The pit

The pit is where agents park what they must not decide. This skill turns it into a short decision
session.

## 1. Collect

```bash
bd gate list --json                                         # human checkpoints and ad hoc decision gates
bd list --label triage:ready-for-human --json               # merges, judgment calls, escalations
bd list --label triage:needs-info --json                    # parked questions
bd blocked --json                                           # to compute what each item unblocks
```

Keep only items whose predecessors are closed (a gate still blocked by unfinished work is not the
human's yet). Scope to one season when an id is given.

## 2. Rank

Score = number of open beads that become ready when this item resolves (use `dependent_count`, and
for a season gate the open tickets below its build step). Ties: older first.

## 3. Present, then resolve inline

For each item, highest score first: one line of what, one line of why it waits, one line of what you
recommend, and the evidence link (spec path, PR URL, the parked question). Then ask the human,
one item at a time, with your recommendation first. On their answer:

| Item | Human says yes | Human says no or changes |
|---|---|---|
| sign-off or approval gate | `bd gate resolve <gate> --reason "<their words>"` (the guard asks them to confirm) | `bd comment <step> "<requested change>"`, gate stays open |
| PR ready to merge | they merge in GitHub (never merge for them); patrol closes the gh:pr gate | referee gets the change request |
| needs-info question | `bd comment <id> "<answer>"`, `bd set-state <id> triage=ready-for-agent --reason "answered"` | ticket closed with reason, or reshaped |
| escalated review thread | answer posted on the PR thread, ticket back to the referee | same |

Stop when the human says so. Report what moved and what is now ready for agents.
