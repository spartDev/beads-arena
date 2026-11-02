---
name: bout
description: Contest a high-uncertainty arena ticket before building it. N isolated candidates attack the same ticket, a read-only judge scores them against a hidden rubric, the orchestrator picks a base and grafts the best ideas of the losers by hand, then records the verdict as a decision bead.
argument-hint: "<ticket id> [candidates 2-5]"
---

# Bout

Use when one attempt would lock in the wrong shape: a new data model, a contested API, an
architecture decision, a spike with competing answers. A bout costs N rounds, so routine tickets
never get one.

Ticket and candidate count: $ARGUMENTS (default 3 candidates)

## 1. Pour and frame

```bash
bd mol wisp arena-bout --var ticket=<id> --var candidates=<n> --json
BEADS_ACTOR=arena/bout-<id> bd update <id> --claim        # the bout holds the ticket until its verdict
```

Frame step:
- Name the artifact every candidate produces (code on a branch, a design doc, a prototype).
- Write the rubric to `.arena/bout-<id>/rubric.md`: 3 to 6 criteria you can grade, specific to this
  ticket (for example "the domain type makes the invalid state unrepresentable", "the migration is
  reversible", "the public API has at most 3 functions"). Never post it on a bead: candidates read
  beads, and only the judge receives the file.
- Vary the candidates on purpose: one per design direction when the space has named directions,
  otherwise vary the model tier (`opus`, `sonnet`) with the same brief. Each direction goes into
  its own candidate bead only.
- Close the frame step.

## 2. Fan out

The candidates step is a spawner epic. Create one child per candidate in one transaction:

```bash
bd create --graph .arena/bout-<id>.json --json   # nodes "Candidate <n> for <id>", parent_id = candidates step, label bout:candidate
```

Spawn every `arena:implementer` candidate in one message, in the background, each in its own
worktree on branch `arena/<id>-c<n>`, each told: the ticket (read-only, the bout holds the claim),
its candidate bead (claim that one), its direction, "produce the artifact and post a rationale on
your candidate bead naming what you rejected; never name your model". A candidate that produces
nothing is closed with reason "dropout"; continue with N-1.

## 3. Cross-judge and pick

Once every candidate bead is closed, close the candidates step, then in parallel:
- Spawn `arena:judge` (read-only, a different model tier from most candidates) with the rubric
  file and the candidates by label only (`c1`: branch and candidate bead, `c2`: ...).
- Read every candidate end to end yourself and score each criterion.

Agreement on the base confirms it. Disagreement means a bias or an ambiguous rubric: read both
rationales before deciding. Pick the base a future maintainer can extend without breaking
invariants; on a tie, the smaller API and the cleaner boundary win.

## 4. Graft and verify

Rename the base branch to `arena/<id>-<slug>` (the branch the round will use), then port one or
two strengths per losing candidate into it, by hand, so the result keeps one mental model. If the candidates converged, ship the consensus and say so. If they diverged wildly,
the frame was under-specified: reframe and rerun, do not average.

Run the CONSTRAINTS.md gates on the result. Record the verdict:

```bash
bd create "Decision: <ticket title>" -t decision --deps discovered-from:<id> --acceptance "- verdict recorded" --body-file - <<'EOF'
## Decision
Base c<k>, grafts: ...
## Rationale
Rubric scores (yours and the judge's), why the base wins, verification result.
## Alternatives Considered
Each losing candidate and why it lost; dropouts.
EOF
BEADS_ACTOR=arena/bout-<id> bd unclaim <id>
bd update <id> --remove-label bout
```

Remove the losing worktrees, squash the wisp (`bd mol squash <wisp>`), and continue with
`/arena:build <id>`: the round's brief step finds the decision bead and the existing
`arena/<id>-<slug>` branch, skips red, green and prove, and goes straight to the review lenses.
