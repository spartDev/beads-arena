---
name: slice
description: Break a signed-off arena spec into tracer-bullet tickets in Beads, each a vertical slice that fits one fresh context window, with explicit blocking edges, created in one transaction under the season's build step and validated with bd swarm validate.
argument-hint: "<season root id>"
---

# Slice

Goal: a ticket graph an agent swarm can execute without asking anyone, and a human who approved it.

Season: $ARGUMENTS

## 1. Load the ground truth

- `bd mol show <root>` for the steps; the spec path is the root's spec-id.
- Confirm the spec sign-off gate is resolved and claim the slice step. If the gate is still open,
  stop and say so: slicing an unsigned spec builds on sand.
- Read the spec, GLOSSARY.md, the ADRs, CONSTRAINTS.md, and the code the spec touches
  (delegate wide exploration to `arena:scout`).

## 2. Draft the slices

If `mattpocock-skills:to-tickets` is installed, use it to draft (its tracker doc points at Beads).
The rules either way:

- **Vertical**: each ticket cuts a narrow but complete path through every layer it needs
  (schema, API, UI, tests) and is demoable on its own.
- **Prefactor first**: "make the change easy, then make the easy change". Prefactoring tickets
  block the feature tickets.
- **Wide refactors** (one mechanical change across many call sites) are expand, then migrate in
  batches sized by blast radius, then contract. Each batch is a ticket blocked by the expand;
  the contract is blocked by every batch.
- **Size**: S or M. A ticket touching more than about 5 files, needing more than 3 acceptance
  criteria, or with "and" in its title is two tickets.
- **Acceptance criteria are observable behaviour**, not implementation steps. No file paths in the
  body (they rot), except a decision-rich snippet from a prototype.
- **Labels**: `triage:ready-for-agent` when an agent can do it alone, `triage:ready-for-human` with
  the reason when it needs judgment or access only a human has, `risk:high` for auth, data, money,
  migrations, public API or infra, `bout` when two competent engineers would build different shapes.

## 3. Quiz the human

Show a numbered list: title, blocked by, what it delivers, labels. Ask: is the granularity right,
are the edges real (does each blocker truly gate the ticket), what to merge or split. Iterate.

## 4. Create the graph in one transaction

Write `.arena/plan-<name>.json` (schema in
[../protocol/references/beads-cheatsheet.md](../protocol/references/beads-cheatsheet.md)), with
`parent_id` set to the season's build step on every node, then:

```bash
bd create --graph .arena/plan-<name>.json --dry-run   # preview
bd create --graph .arena/plan-<name>.json --json      # one commit, ids returned
bd lint                                               # every ticket has its sections
bd swarm validate <build-step>                        # the build step is an epic: cycles, orphans, waves, max parallelism
```

Post the waves and the maximum parallelism as a comment on the root (`bd comment <root> "..."`):
it tells the human how many agents can usefully run at once.

## 5. Hand over

Close the slice step. The breakdown approval gate is now in `bd gate list`. Tell the human the
ticket count, the waves, the tickets that need them (`ready-for-human`) and the bouts. Next phase,
after they resolve the gate: `/arena:build <root>` or `/arena:build auto`.
