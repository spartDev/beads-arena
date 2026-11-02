---
name: patrol
description: Run the arena referee's rounds. Closes satisfied gates, reclaims dead claims, chases open PRs, flags stale and orphaned work, and ranks everything waiting on the human. Designed to run on a schedule or under /loop.
argument-hint: "[--quiet]"
---

# Patrol

Goal: nothing in the arena waits silently. A gate that could close closes, a dead claim returns to
the frontier, a red PR gets a referee, and the human sees the few decisions only they can make.

## Run

```bash
bd mol wisp arena-patrol --json
```

The five sweeps (gates and landing, reclaim, prs, stale, pit) are independent: run them in
parallel, cheaply. The gates sweep is the one that lands merged rounds and closes finished build
steps, so the season moves on to integrate without anyone remembering to do it.
Each step's description holds its exact commands. Delegate a red PR to `arena:referee` rather than
fixing it inline, so the patrol stays short.

Ranking the pit: for each item waiting on the human, count what it unblocks
(`bd show <id> --json`, field `dependent_count`, plus the open tickets below its season's build
step when it is a season gate). Highest first. A deploy approval or a merge that unblocks a wave
outranks a spike question.

## Report

Pit first, three lines maximum per item: what, why it waits, the exact command or click that moves
it. Then one line each for gates closed, claims reclaimed, PR status, stale work. With `--quiet`,
print nothing when the pit is empty and nothing changed.

Close the report step, then `bd mol burn <wisp>` when the patrol found nothing worth keeping, or
`bd mol squash <wisp>` when it changed something.

## Scheduling

- In a live session: `/loop 30m /arena:patrol --quiet`.
- Unattended: a scheduled task (Claude app) or a CI cron that runs `claude -p "/arena:patrol --quiet"`
  in the repository. `bd gate check` alone is enough to keep timer and GitHub gates moving.
