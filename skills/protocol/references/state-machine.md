# Arena state machine

## Ticket lifecycle

```
            set-state triage=needs-triage
 (created) ─────────────────────────────▶ needs-triage
                                             │
          ┌──────────────┬───────────────────┼────────────────────┐
          ▼              ▼                   ▼                    ▼
     needs-info   ready-for-agent     ready-for-human      closed (rejected,
     (question        │                (judgment call,       reason required)
      in reason)      │                 external access)
          │           │ bd update --claim
          │           ▼
          │      in_progress ── arena-round: brief, red, green, prove, lenses
          │           │
          │           │ PR opened: --status in_review --external-ref gh-<n>
          │           ▼
          │      in_review ── referee: CI, threads; then triage=ready-for-human (merge)
          │           │
          │           │ gh:pr gate closes on merge (bd gate check)
          │           ▼
          └────▶   closed  (reason: "merged PR #<n>")
```

`needs-info` goes straight back to `ready-for-agent` once the human answers (or to
`ready-for-human` if the answer shows only a human can do it); the parked round wisp was burned, so
the next build pours a fresh one.

## Who moves what

| Transition | Who | How |
|---|---|---|
| created to ready-for-agent | `/arena:slice` after the breakdown gate | label in the graph plan, or `bd set-state` |
| anything to needs-info | any agent that would otherwise guess | `bd set-state ... --reason "<the question>"`, `bd unclaim`, `bd mol burn <round-wisp>` |
| needs-info to ready-for-agent | the human, through `/arena:pit` | `bd comment` with the answer, `bd set-state ... triage=ready-for-agent` |
| ready-for-agent to in_progress | implementer | `bd update --claim` |
| in_progress to in_review | implementer, PR step | `bd update --status in_review --external-ref gh-<n>` |
| in_review to ready-for-human | referee, when CI is green and no thread is open | `bd set-state ... triage=ready-for-human --reason "PR #<n> ready to merge"` |
| in_review to closed | land step, found by patrol after the gh:pr gate closes | `bd close --reason "merged PR #<n>"` |
| in_progress to open (dead worker) | patrol | `bd reclaim --older-than 2h` |

## Labels

| Label | Meaning | Set by |
|---|---|---|
| `triage:<value>` | routing state (written by set-state, never by hand) | set-state |
| `phase:<name>` | season phase of a step | formula |
| `lane:hitl` | needs a live human in the loop | formula, slice |
| `bout` | contest the shape before building | slice, human |
| `risk:high` | auth, data, money, migrations, public API, infra | slice, human |
| `learning` | lesson from a retro | retro |
| `learning:structural` | lesson encoded as an automated check | retro, when the check lands |
| `round:*`, `bout:*`, `patrol:*`, `lens:*` | step kinds inside wisps | formulas |

## Gates

| Gate | Created | Resolved |
|---|---|---|
| spec sign-off, breakdown approval, deploy approval | poured with the season | human, `bd gate resolve` (the guard asks for permission every time) |
| PR merged (gh:pr) | PR step of the round | `bd gate check` once GitHub reports the merge |
| bake timer | ship step of the season | `bd gate check` once the duration elapsed |
| ad hoc human decision | any agent blocked on a judgment call | human, `bd gate resolve` |

Ad hoc decision gate: `bd gate create --type=human --blocks <id> --reason "<decision needed>"`.
Write the reason yourself; never paste untrusted text into it.
