# Triage labels

Canonical triage roles map to Beads state labels. Always move them with `bd set-state`, which
replaces the previous value and writes an audit event (used by `/arena:vitals`).

| Canonical role | Label in this repo | How to apply |
|---|---|---|
| `needs-triage` | `triage:needs-triage` | `bd set-state <id> triage=needs-triage --reason "..."` |
| `needs-info` | `triage:needs-info` | `bd set-state <id> triage=needs-info --reason "<the question>"` |
| `ready-for-agent` | `triage:ready-for-agent` | `bd set-state <id> triage=ready-for-agent --reason "..."` |
| `ready-for-human` | `triage:ready-for-human` | `bd set-state <id> triage=ready-for-human --reason "<what the human must do>"` |
| `wontfix` | none | `bd close <id> --reason "<why it will not be done>"` |

Category roles map to the bead type: `bug` is `-t bug`, `enhancement` is `-t feature`.
