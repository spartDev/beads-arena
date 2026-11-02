---
name: next
description: Read the arena's state in Beads and do the single most valuable next move, or tell the human which decision of theirs unblocks the most work. Use when you are unsure what to run.
argument-hint: "[season root]"
---

# Next

Read, decide, act. One move, not a menu.

```bash
bd list --type molecule --json          # seasons in flight
bd gate list --json                     # human checkpoints open
bd list --label triage:ready-for-human --json
bd list --status in_review --json       # PRs out
bd ready --json                         # agent frontier
bd list --status in_progress --json     # claims in flight
```

Decide with the first rule that matches:

1. A human checkpoint or a merge unblocks a wave: say which one, why, and the exact command. Stop.
2. A merged round waits to land (`bd gate check`, then `bd ready --include-ephemeral --label round:land`):
   land it, per `/arena:build` section 5.
3. An `in_review` ticket has red CI or unanswered threads: run `/arena:referee <id>`.
4. A season's frame step is ready: `/arena:frame <root>`.
5. A slice step is ready: `/arena:slice <root>`.
6. Tickets labelled `bout` are ready: `/arena:bout <id>`.
7. The build frontier has `triage:ready-for-agent` tickets: `/arena:build <root>` (or `auto` when
   more than two are ready).
8. Integrate, release, ship, validate or retro steps are ready: do that step, per its description.
9. Learning beads labelled `triage:ready-for-agent` are ready: build them like any ticket (those
   labelled `arena` wait in the pit for the human).
10. Nothing in flight: say so, show the last vitals line (`arena-vitals --oneline`), and ask what
    to frame next.

Say which rule fired in one sentence, then act.
