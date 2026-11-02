# Issue tracker: Beads

Issues, specs' tickets, decisions and gates for this repo live in Beads, a dependency-aware tracker
stored in Dolt under `.beads/`. Use the `bd` CLI for every operation and add `--json` when parsing.
This file is read by any skill that says "the issue tracker" (to-tickets, triage, wayfinder,
implement-spec, code-review, planning skills).

## Conventions

- **Create an issue**: `bd create "Title" -t <task|bug|feature|chore|spike|decision> -p <0-4> -d "<why>" --acceptance "- <criterion>" --json`. Creation is refused without the sections the type requires: `## Acceptance Criteria` (or `--acceptance`) for tasks and features, plus `## Steps to Reproduce` for bugs, `## Goal` and `## Findings` for spikes, `## Decision`, `## Rationale` and `## Alternatives Considered` for decisions. Multi-line bodies: `--body-file -` with a heredoc.
- **Create many issues with blocking edges**: write a graph plan and run `bd create --graph plan.json --json` (one transaction). Node `deps: [{"type": "blocks", "target": "<key or id>"}]` means "this node waits for target".
- **Read an issue**: `bd show <id> --json` (body, acceptance criteria, notes, labels, dependencies, comments count), comments with `bd comments <id> --json`.
- **List issues**: `bd list --json` with `--status <open|in_progress|in_review|blocked|closed>`, `--label <l>` (AND), `--label-any <a,b>` (OR), `--type <t>`, `--all` for closed too.
- **Make an issue a sub-issue of a parent**: `--parent <parent-id> --no-inherit-labels` on create (without the flag the child copies the parent's labels), or `bd update <child> --parent <parent-id>`.
- **Blocking**: native dependencies. `bd dep add <blocked> <blocker>` means blocked waits for blocker. A ticket is unblocked when every blocker is closed.
- **Count open blockers / startable work**: `bd ready --json` is the frontier (open, unblocked, not deferred). `bd blocked --json` lists what waits and on what.
- **Comment on an issue**: `bd comment <id> "<text>"`. Notes for the next session: `bd note <id> "<text>"`.
- **Apply / remove labels**: `bd update <id> --add-label <l>` / `--remove-label <l>`. Triage roles are set with `bd set-state <id> triage=<role> --reason "..."`, never as raw labels (see docs/agents/triage-labels.md).
- **Close**: `bd close <id> --reason "<explanation>"`. Rejected work is closed with the reason; there is no wontfix label.

The issue prefix is this repo's; ids look like `<prefix>-a1b`, children `<prefix>-a1b.1`.

## Pull requests as a triage surface

**PRs as a request surface: no.** External PRs are handled by `/arena:referee`, not by triage.

## When a skill says "publish to the issue tracker"

Create Beads issues as above. A spec is a file in docs/specs/ linked on its epic with
`bd update <epic> --spec-id docs/specs/<name>.md`; its tickets are children of the season's build
step (see `/arena:slice`).

## When a skill says "fetch the relevant ticket"

`bd show <id> --json`, then `bd comments <id> --json`.

## Wayfinding operations

Used by `/wayfinder` and `/arena:frame --fog`. The **map** is one bead with child beads as tickets.

- **Map**: a bead labelled `wayfinder:map` (in the arena: the season root). Its description holds Destination, Notes, Decisions so far, Not yet specified, Out of scope. Edit it with `bd update <map> --description "..."`.
- **Child ticket**: `bd create "<question>" -t spike|decision --parent <map> --no-inherit-labels -l wayfinder:<research|prototype|grilling|task> --acceptance "- answer recorded"` plus the description sections its type requires (spike: `## Goal`, `## Findings`; decision: `## Decision`, `## Rationale`, `## Alternatives Considered`).
- **Blocking**: `bd dep add <ticket> <blocker>`.
- **Frontier query**: `bd ready --parent <map> --unassigned --json`; first by priority wins.
- **Claim**: `bd update <id> --claim`, the session's first write.
- **Resolve**: `bd comment <id> "<answer>"`, `bd close <id> --reason "<one-line gist>"`, then append the gist and the id to the map's Decisions so far.
