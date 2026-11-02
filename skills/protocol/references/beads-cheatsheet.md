# Beads cheatsheet for the arena

Every command below was run against bd 1.3.2 while the arena was built. Add `--json` whenever
you parse output.

## Finding work

| Need | Command |
|---|---|
| The frontier (unblocked, not deferred) | `bd ready --json` |
| Frontier of one season's tickets | `bd ready --parent <build-step-id> --json` |
| Frontier including wisp steps | `bd ready --include-ephemeral --json` |
| Claim the first matching ready ticket | `bd ready --label triage:ready-for-agent --claim --json` |
| Why something is blocked | `bd blocked --json`, `bd ready --explain` |
| Where a molecule stands | `bd mol current <mol-id>` (display only, see gotchas) |
| Gates waiting | `bd gate list --json` (`--all` includes closed) |

## Writing work

| Need | Command |
|---|---|
| One ticket | `bd create "Title" -t task -p 2 -d "why" --acceptance "- criterion" --json` |
| Many tickets with edges, one transaction | `bd create --graph plan.json --json` (schema below) |
| Child of a step or epic | `--parent <id> --no-inherit-labels` on create (children inherit the parent's labels otherwise), or `"parent_id"` in a graph node (no inheritance) |
| Dependency (B needs A) | `bd dep add <B> <A>` |
| Discovered work | `bd create "..." --deps discovered-from:<current> ...` |
| Claim | `bd update <id> --claim` (atomic, non-zero exit if someone else holds it) |
| Keep a claim alive (5-minute lease) | `bd heartbeat <id>` |
| Release a claim | `bd unclaim <id>` |
| Routing state with audit event | `bd set-state <id> triage=<value> --reason "..."` |
| PR open | `bd update <id> --status in_review --external-ref gh-<n>` |
| Note for the next session | `bd note <id> "..."`, or `--file f` for anything copied from outside |
| Evidence or discussion | `bd comment <id> "..."`, or `--file f` for logs and quoted comments |
| Close | `bd close <id> --reason "merged PR #<n>" --suggest-next` |
| Durable project fact | `bd remember "insight" --key <slug>`, search with `bd memories <word>` |

Never `bd edit`: it opens `$EDITOR` and hangs an agent. Use `bd update --description/--notes/--design`.

## Sections strict mode requires at creation

With `validation.on-create=error` (the arena default), `bd create` refuses a bead whose description
lacks these headings. `--acceptance` counts as `## Acceptance Criteria`.

| Type | Required in the description |
|---|---|
| task, feature | `## Acceptance Criteria` |
| bug | `## Steps to Reproduce`, `## Acceptance Criteria` |
| epic | `## Success Criteria` or `## Acceptance Criteria` |
| decision | `## Decision`, `## Rationale`, `## Alternatives Considered` |
| spike | `## Goal`, `## Findings` (write "pending" until the spike is done) |
| chore | none, but a description is required |

Multi-line bodies: `bd create "..." -t decision --body-file - <<'EOF' ... EOF`.

## Graph plan schema (`bd create --graph`)

```json
{
  "commit_message": "arena: slice dark-mode",
  "nodes": [
    {"key": "t1", "title": "Theme tokens end to end", "type": "task", "parent_id": "<build-step-id>",
     "description": "...", "acceptance_criteria": "- ...", "labels": ["triage:ready-for-agent"]},
    {"key": "t2", "title": "Theme toggle persists", "type": "task", "parent_id": "<build-step-id>",
     "description": "...", "acceptance_criteria": "- ...", "deps": [{"type": "blocks", "target": "t1"}]}
  ]
}
```

A node dep `{"type": "blocks", "target": "t1"}` means this node waits for `t1`. `target` resolves
as a plan key first, then as an existing bead id. Output: `{"ids": {"t1": "ar-7dd", ...}}`.

## Molecules, wisps, gates

| Need | Command |
|---|---|
| Start a season (persistent) | `bd mol pour arena-season --var name=<slug> --var hypothesis="..."` |
| Start a round, bout or patrol (ephemeral) | `bd mol wisp arena-round --var ticket=<id> --var slug=<slug>` |
| Keep a wisp as a digest | `bd mol squash <wisp-id>` |
| Drop a wisp | `bd mol burn <wisp-id>` |
| Human resolves a checkpoint | `bd gate resolve <gate-id> --reason "..."` |
| Arm a merge gate | `bd gate create --type=gh:pr --await-id <n> --blocks <step-id> --title "PR #<n> merged"` |
| Arm a timer | `bd gate create --type=timer --timeout 72h --blocks <step-id>` |
| Close satisfied gates | `bd gate check` (`--dry-run` to preview) |
| Validate a breakdown | `bd swarm validate <epic-id>`, then `bd swarm status <epic-id>` |
| Reclaim dead claims | `bd reclaim --older-than 2h` (bare `bd reclaim` steals from live workers between heartbeats) |
| Rounds whose PR merged | `bd ready --include-ephemeral --label round:land --json` |
| Close a finished spawner epic | `bd close <epic> --reason "all children closed"` (refused while a child is open) |

## Gotchas found while building the arena (bd 1.3.2)

1. A formula step with `type = "gate"` plus a `[steps.gate]` block does not behave as the docs'
   exit gate: the step itself becomes a gate-type bead, hidden from `bd ready`. The arena only uses
   standalone gate steps (no `[steps.gate]`) for human checkpoints.
2. A timer gate poured with a formula counts from pour time, and `{{var}}` is not substituted in a
   gate's `timeout`. Arm timers with `bd gate create` when they must start.
3. `bd mol current` shows a step as ready even when a gate created outside the molecule blocks it.
   `bd ready` and `bd blocked` are authoritative.
4. Gate-type beads do not appear in `bd list` or `bd children`. Use `bd gate list --all`.
5. `bd children` returns nothing for wisp roots. Use
   `bd list --all --include-ephemeral --json | jq '.[] | select(.parent=="<wisp-id>")'`.
6. Formula loops chain their iterations sequentially, and a loop range cannot read a `--var`.
   Parallel fan-out is a spawner step: create the children with `--parent <step-id>`; the step
   cannot close while a child is open, so whatever needs it waits for all of them.
7. A parent refuses to close while a child is open ("close children first or use --force").
   This is what makes spawner steps work. Never `--force` it.
8. `bd set-state` on a label that is already set does nothing and writes no event.
9. Formula steps have no `acceptance` field (unknown TOML keys are dropped silently). Acceptance
   criteria go in the description under `## Acceptance Criteria`, which `bd lint` accepts.
10. A claim's lease expires 5 minutes after the last claim or heartbeat, and the TTL is not
    configurable. `bd reclaim` without a grace window can take a ticket from a worker that is
    simply busy.
11. `bd ready` hides wisp steps and `bd ready --gated` only reports persistent molecules: a merged
    round's land step is found with `--include-ephemeral --label round:land`.
12. bd never closes an epic by itself. `bd close` on a spawner epic succeeds once its last child
    closed, which is how patrol closes the season's build step.
13. A conflicting claim exits 1 (not 13; 13 is for `--if-assignee`/`--if-status` mismatches).
14. `bd create --parent <id>` copies the parent's labels onto the child (a ticket under the build
    step would carry `arena:spawner` and `phase:build`). Pass `--no-inherit-labels`; graph plans
    with `parent_id` do not inherit.
