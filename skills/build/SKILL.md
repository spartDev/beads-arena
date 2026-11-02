---
name: build
description: Work the ready frontier of an arena season. Each ticket gets an arena-round wisp, an implementer subagent in its own worktree, TDD, proof against CONSTRAINTS.md, three parallel review lenses (Standards, Spec, Doubt) and exactly one PR. "auto" keeps feeding the frontier until nothing is ready.
argument-hint: "[season root | ticket id | auto] [--max N]"
---

# Build

Goal: every ready ticket becomes one green, reviewed PR, while the orchestrator (you) stays light
enough to keep feeding the frontier.

Target: $ARGUMENTS

## 0. Pick the work

- A ticket id: that ticket only.
- A season root: its build step's frontier, `bd ready --parent <build-step> --label triage:ready-for-agent --json`.
- `auto`: same frontier, refilled every time a ticket lands, until it is empty. `--max N` caps
  concurrent implementers (default 3, never more than the swarm's max parallelism).
- Nothing given: `bd ready --label triage:ready-for-agent --json`, highest priority first.

Skip tickets labelled `bout`: run `/arena:bout <id>` first. Skip `triage:ready-for-human`.
Confirm the breakdown approval gate of the season is resolved; if not, stop.

## 1. Per ticket: pour the round

```bash
bd mol wisp arena-round --var ticket=<id> --var slug=<kebab-slug> [--var base=main] [--var ci_workflow=ci.yml] --json
```

The wisp's steps are the checklist; do not invent another one. Read the steps once
(`bd list --all --include-ephemeral --json | jq '.[] | select(.parent=="<wisp>")'`).

## 2. Delegate brief, red, green, prove to an implementer

Spawn `arena:implementer` (background, isolated worktree) with pointers, not pasted context:

> Ticket <id>, round wisp <wisp>, branch arena/<id>-<slug>, base <base>.
> Goal (restated): <one sentence>. Run your bd commands as BEADS_ACTOR=arena/implementer-<id>.
> Work the brief, red, green and prove steps of the wisp in order and close each with evidence.
> Report: branch, commits, gate output, anything filed as discovered work, anything you could not do.

Launch independent tickets in the same message so they run concurrently. Two ready tickets that
clearly change the same module (read their descriptions and the code they name) run one after the
other: never two writers on one module.

## 3. When an implementer returns: verify, then the lenses

1. Read its diff yourself (`git -C <worktree> diff <base>...HEAD`). Run the CONSTRAINTS.md gates
   once yourself. A green report is a claim, the gate output is the proof.
2. Spawn the three lenses in one message, each fresh, each pointed at the worktree and the ticket:
   - `arena:reviewer` with lens **standards** (CODING_STANDARDS.md, CONTRIBUTING.md, smell baseline)
   - `arena:reviewer` with lens **spec** (acceptance criteria and the linked spec)
   - `arena:adversary` (break it, keep only findings a run proves). Mandatory for `risk:high`,
     with a second adversary on a different model tier. For trivial mechanical diffs, close the
     doubt step with a one-line skip reason instead.
   If `mattpocock-skills:code-review` or `pstack:interrogate` is installed, the lenses may call them.
3. Verified findings go back to a **fresh** implementer with consolidated scope (original brief,
   the findings, the branch). Never resume a finished agent: directives get lost. First remove the
   finished implementer's worktree (`git worktree remove <path>`; its commits stay on the branch),
   because a branch can be checked out in only one worktree.
4. Close the standards, spec and doubt steps with the report summary in the reason.

## 4. Open the PR (one per ticket)

From the ticket worktree, using `.github/pull_request_template.md` (written by `/arena:setup`, or
`mattpocock-skills:pr` when installed): Why (the goal), the smallest visual that explains the
change, before and after evidence, merge danger (one-way or two-way door, blast radius),
`Refs: <id>`. Then:

```bash
gh pr create --base <base> --head arena/<id>-<slug> --title "<type>(<scope>): <title>" --body-file <file>
bd update <id> --status in_review --external-ref gh-<n>
bd gate create --type=gh:pr --await-id <n> --blocks <land-step> --title "PR #<n> merged"
bd close <pr-step> --reason "PR #<n> opened"
```

Hand the PR to `/arena:referee <id>` (or an `arena:referee` subagent in auto mode).

## 5. Land what merged

The human merges. Then:

```bash
bd gate check                                                    # closes gh:pr gates of merged PRs
bd ready --include-ephemeral --label round:land --json           # merged rounds (plain bd ready hides them)
```

For each land step: `bd close <ticket> --reason "merged PR #<n>" --suggest-next`, close the land
step, `bd mol squash <wisp>`, `git worktree remove <path>`. When the last ticket of a season has
landed, close its build step (`bd close <build-step> --reason "all tickets merged"`; bd refuses
while a child is open), which makes the integrate step ready. `/arena:patrol` does the same sweep
on a schedule.

## 6. Auto mode loop

After each landing or each referee hand-off, re-read the frontier and fill free slots up to `--max`.
Stop when the frontier is empty and no implementer is running, then report: PRs opened, tickets
waiting in the pit, discovered work filed, and what the human must do next (merges first).

## Never

- Two tickets in one PR, or one ticket across two PRs.
- A commit without `Refs: <id>`.
- Closing a ticket before its PR merged (the land step does it, after the gh:pr gate).
- Merging. The human merges; the referee prepares.
