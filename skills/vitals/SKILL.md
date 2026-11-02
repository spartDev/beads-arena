---
name: vitals
description: Show the arena scoreboard computed from Beads: flow, the pit, Time-to-Ready, Intent-to-Merge, build time, review latency, human wait, learning velocity and the share of hidden scope. Read-only.
argument-hint: "[--since 30d] [--json | --oneline]"
---

# Vitals

Measure how fast the organisation learns, not how fast people type. Every number comes from
timestamps Beads already records; nothing is self-reported.

```bash
arena-vitals $ARGUMENTS
```

If `arena-vitals` is not on PATH, run `<this skill's base directory>/../../bin/arena-vitals`.
It needs `bd` and Node 22.6 or newer.

## Reading the numbers

| Metric | Proxy | Healthy direction | First lever when it degrades |
|---|---|---|---|
| Time-to-Ready (season) | season poured until breakdown approved | down | grill sooner, smaller seasons, fog mode for unclear ones |
| Time-to-Ready (ticket) | created until first ready-for-agent event | down | answer needs-info faster (the pit) |
| Intent-to-Merge | claim until merged | down | smaller tickets, fewer lens findings (encode them as checks) |
| Build time | claim until PR opened | down | better prefactoring, sharper acceptance criteria |
| Review latency | PR opened until merged | down | the pit: merges wait on the human more than on CI |
| Human wait | human gate unblocked until resolved | down | patrol cadence, fewer gates where trust is earned |
| Learning velocity | lesson filed until its check is proven | down | encode lessons as automated checks first |
| Hidden scope | share of new tickets discovered during other work | stable or down | longer grilling, spikes before slicing |

Report the table, then the single metric that moved the most and the lever you recommend. Separate
what the numbers show (fact) from why they moved (inference), and label the inference.
A metric with n below 5 is an anecdote: say so instead of drawing a conclusion.
