---
name: retro
description: Close the arena's learning loop. Mines a season, a ticket or the current session for what slowed the agents or let defects through, and turns each lesson into a learning bead fixed at the highest level that works (architecture, types, lint and CI, tests, then docs last), so the factory learns faster than failures repeat.
argument-hint: "[season root | ticket id | session]"
---

# Retro

Goal: the next run is better than this one because the environment changed, not because someone
promised to remember. Learning velocity is the time from a lesson to a verified change in how
future work gets done; `/arena:vitals` measures it from the beads this skill creates.

Scope: $ARGUMENTS (default: the current session)

## 1. Gather primary sources, in parallel

Delegate to `arena:scout` subagents, each returning cited findings:
- Beads history of the scope: reopened tickets, `needs-info` events, tickets that waited longest in
  each state, discovered-from beads (hidden scope), bout verdicts (`bd list --all --json`,
  `bd history <id> --json`).
- PR threads of the scope: every comment, which were fixed, which were dismissed and why.
- CI: failures by class (flake, stale base, real) from the ticket notes.
- The session transcript, when the scope is a session.

If `mattpocock-skills:retro` or `pstack:reflect` is installed, run it on the same sources and merge
its candidates into step 2.

## 2. Classify each candidate lesson

| Category | Signal | Preferred fix |
|---|---|---|
| Automated check | a mistake a lint, type or test could catch; a repo with no guardrail | new lint rule, stricter type, pre-commit hook, CI job |
| Reviewer standard | a judgment call the reviewer lens missed | CODING_STANDARDS.md rule (read by the reviewer, not the implementer) |
| Navigation | agents searched long for something | a pointer in CLAUDE.md or a doc index |
| Information access | a crucial fact was out of reach | tee logs, read-only access, a script |
| Tool economy | an expensive or repeated tool call | a script in the repo, a narrower command |
| Process | a phase skipped or misordered, a gate in the wrong place | edit the arena formula or skill |
| No-op | a steering line that changes nothing | delete it |

Fix at the highest level that works: architecture, then types, then lint and CI, then tests, docs
last. A lesson written twice in prose is a lesson that wanted to be a check.

## 3. File and approve

Present the candidates by severity. On the human's approval, one bead per accepted lesson:

```bash
bd create "Learning: <imperative fix>" -t chore -l learning \
  --deps discovered-from:<scope-id> \
  -d "Evidence: <links>. Failure it prevents: <...>." \
  --acceptance "- <the check or edit exists> - <it fails on the original mistake>"
```

Add `learning:structural` when the fix is an automated check. Durable facts about this codebase
that are not fixes go to `bd remember "<fact>" --key <slug>` (bd prime injects them every session).
Edits to the arena's own skills or formulas are learning beads too, labelled `arena`, and are set
to `triage:ready-for-human` instead of `ready-for-agent`: they change every future run, so they wait
in the pit for explicit approval.

## 4. Close the loop

Learning beads enter the frontier like any ticket (`triage:ready-for-agent` when an agent can do
it). A learning bead is closed only when its acceptance criteria are proven: the check exists and
fails on the original mistake. Close the season's retro step with the list of beads filed.
