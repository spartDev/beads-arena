## Arena

This repository runs the arena SDLC on Beads. Read the `arena:protocol` skill before touching a ticket.

- Tracker: Beads (`bd`) only. Task list target for every planning skill: Beads, one bead per task, edges with `bd dep add`. Never TodoWrite, TaskCreate or `tasks/todo.md`.
- Tracker operations for skills that "publish to the issue tracker": docs/agents/issue-tracker.md.
- One ticket, one worktree, one branch `arena/<ticket>-<slug>`, one PR. Commit trailer `Refs: <ticket>`.
- Git authority: this repository opts into the Beads team-maintainer profile, scoped to arena work. Agents commit on their own `arena/<ticket>-<slug>` branch, push that branch, open its PR, close beads and run `bd dolt push`. They never push the default branch, never merge, never force-push without `--force-with-lease`. A current user instruction still wins.
- Quality bar: CONSTRAINTS.md. Vocabulary: GLOSSARY.md. Decisions: docs/adr/. Specs: docs/specs/.
- Blocked on a human: `bd set-state <id> triage=ready-for-human --reason "..."`, then keep working.
- Unsure what to do: `/arena:next`.
