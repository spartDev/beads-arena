# Architecture and design decisions

## Three layers

1. **State: Beads.** Tickets, edges, claims, gates, decisions, learning. Formulas encode the process
   as dependency graphs, so "what can happen next" is a query (`bd ready`), not a memory.
2. **Roles: Claude Code.** The main session orchestrates; subagents (implementer, reviewer,
   adversary, judge, referee, scout) each get a fresh context and a pointer to their bead.
3. **Techniques: skills.** The arena's own skills carry the process; upstream skill packs are called
   by name when installed and supply depth (grilling, TDD, interrogation, retro).

## The fractal

| Level | Question | Beads object | Human checkpoint |
|---|---|---|---|
| Hypothesis | is this worth building? | `arena-season` root, frame and spec steps | spec sign-off |
| Shippable increment | what is the smallest valuable slice? | build epic and its tickets | breakdown approval, deploy approval |
| Atomic execution | does this ticket work? | `arena-round` wisp | merge |
| Value validation | did it move the signal? | bake, validate, retro steps | value verdict |

## Decisions, with the evidence behind them

All behaviours below were observed on bd 1.3.2 while building the arena (`tests/formulas.test.sh`
reproduces them).

| Decision | Why |
|---|---|
| Human checkpoints are standalone gate steps (`type = "gate"`, no `[steps.gate]`) | they stay blocked until the work before them closes and are hidden from `bd ready`; a gate step with a `[steps.gate]` block became a gate-type bead hiding the work itself from the ready queue |
| GitHub and timer gates are created at the moment they start (`bd gate create`) | a timer counts from creation, `{{var}}` is not substituted in a poured gate's timeout, and a gh:pr gate needs the PR number |
| Fan-out uses spawner steps (type epic, children created with `--parent`) | formula loops chain iterations sequentially and cannot read `--var`; a parent refuses to close while a child is open, so `needs` on the spawner waits for every child; `bd swarm validate` works on an epic |
| Rounds, bouts and patrols are wisps; seasons are persistent | operational steps would bloat history; `bd mol squash` keeps a digest when it matters |
| Routing state uses `bd set-state triage=...` | one label per dimension, plus an event bead per transition, which feeds time-to-ready |
| The frontier is `bd ready`, never `bd mol current` | `bd mol current` ignores gates created outside the molecule |
| Acceptance criteria live in step descriptions under `## Acceptance Criteria` | formula steps have no acceptance field (unknown keys are dropped silently); `validation.on-create=error` and `bd lint` accept the heading |
| The arena hook adds `bd prime` only when Beads' own hook is absent | `bd init` installs a SessionStart hook running `bd prime`; duplicating it costs about 1,500 tokens per session |
| The CLAUDE.md section opts into a scoped team-maintainer git profile | the Beads managed block defaults to "no commits, no pushes", which would stall every round |
| Merges, deploys and infra applies are permission prompts, not denials | a human is usually present to approve; a denial would push agents toward workarounds |
| Floor exceptions require `arena-allow: <reason>` on the line | the exception is visible in the diff and greppable, instead of a silent bypass |
| Implementers heartbeat at every step; patrol reclaims only with `--older-than 2h` | a claim's lease lasts 5 minutes and is not configurable; bare `bd reclaim` would hand live work to a second implementer |
| Merged rounds are found with `bd ready --include-ephemeral --label round:land` | plain `bd ready` hides wisp steps and `bd ready --gated` only sees persistent molecules |
| Patrol closes spawner epics by attempting `bd close` | bd never closes an epic by itself, and refuses while a child is open, so the attempt is safe and moves the season to integrate |
| Children created with `--parent` use `--no-inherit-labels` | a ticket under the build step would otherwise carry `arena:spawner` and `phase:build` |
| `bd gate resolve` is a permission prompt | otherwise any agent could approve its own spec, breakdown or deploy gate |
| Untrusted text never enters a command line | PR comments, CI logs and `Refs:` trailers go through files (`--file`, `--body-file`) and id patterns |
| Metrics are proxies printed with their definitions | Intent-to-Merge, Time-to-Ready and learning velocity are computed from bd timestamps only; nobody self-reports |

## Known limits

- Model diversity is limited to Claude tiers. pstack's cross-family judging (Claude against Grok)
  is replaced by lens and model-tier diversity; judges see candidates by label only.
- `bd gate check` must run for gh:pr and timer gates to close: schedule `/arena:patrol` or a cron.
- Plugin agents ignore `permissionMode` and `hooks` frontmatter; the arena relies on the plugin
  hooks and on the main session's permission mode instead.
- Beads federation and multi-repo routing are out of scope for this version: one repository, one
  Beads workspace, linked worktrees sharing it.
