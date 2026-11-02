# Domain docs

Single context layout.

- `GLOSSARY.md` at the repo root: the project's vocabulary. Read it before naming anything; use its
  terms in tickets, code and PRs; add a term the moment a discussion settles it.
- `docs/adr/NNNN-<slug>.md`: architecture decision records. Write one when a decision is hard to
  reverse, surprising without its context, and a real trade-off. Each ADR has a matching
  `decision` bead in Beads.
- `docs/specs/<name>.md`: one spec per arena season, linked on the season with `--spec-id`.

Consumers: read GLOSSARY.md and the ADRs touching the area before exploring code, and respect them.
A change that contradicts an ADR needs a new ADR that supersedes it.
