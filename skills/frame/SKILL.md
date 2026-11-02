---
name: frame
description: Start an arena season from a raw idea. Pours the arena-season molecule, grills the human with docs (glossary and ADRs updated inline), turns open questions into spike and decision beads, and writes the spec that the human signs off. Use --fog for efforts too big or too unclear for one session.
argument-hint: "<idea, or an existing bead id> [--fog]"
---

# Frame

Goal: a value hypothesis worth building, a shared vocabulary, and a spec the human signed off.
Nothing gets built in this phase. The output is decisions.

Idea or bead: $ARGUMENTS

## 1. Pour the season

1. Restate the idea in your own words in two sentences: who has the problem, what changes for them.
2. Draft the value hypothesis with the human in one exchange:
   "We believe <change> will cause <outcome> for <who>, measured by <signal> reaching <target>."
   No signal, no season: if nobody can name one, the first spike is "find the signal".
3. Pick a kebab-case name and pour:

```bash
bd mol pour arena-season --var name=<name> --var hypothesis="<hypothesis>" --json
```

Find the season root and its steps (`bd list --type molecule --json`, then `bd mol show <root>`).
Claim the frame step: `bd update <frame-step> --claim`.

## 2. Grill with docs

If `mattpocock-skills:grill-with-docs` is installed, run it now and come back for step 3.
Otherwise, run this loop until no branch of the design tree is left open:

- One question per message, with your recommended answer, so the human can say "yes" in one word.
- If the codebase can answer a question, read the code instead of asking.
- Challenge fuzzy terms against GLOSSARY.md the moment they appear. Write the agreed definition
  to GLOSSARY.md immediately (term, definition, terms to avoid).
- A decision that is hard to reverse, surprising without context, and a real trade-off gets an ADR
  in docs/adr/NNNN-<slug>.md and a `decision` bead under the season root. Strict mode requires the
  three sections:
  ```bash
  bd create "ADR: <title>" -t decision --parent <root> --no-inherit-labels --acceptance "- ADR file merged" --body-file - <<'EOF'
  ## Decision
  <what we decided>
  ## Rationale
  <why, in glossary terms>
  ## Alternatives Considered
  <each option and why it lost>
  EOF
  ```
- A question nobody can answer yet becomes a spike, not a guess:
  `bd create "Spike: <question>" -t spike --parent <root> --no-inherit-labels --acceptance "- answer recorded" -d $'## Goal\n<what would settle it>\n## Findings\npending'`.
- Stress-test with concrete scenarios: edge cases, failure paths, the second user, the tenth.

## 3. Fog mode (`--fog`)

When the effort clearly exceeds one session or the route is unclear, do not force a spec.
Chart a map instead (the `mattpocock-skills:wayfinder` pattern, on Beads):

- The season root is the map. Write its body with `bd update <root> --description`:
  Destination, Notes, Decisions so far (one line and a bead id per closed decision),
  Not yet specified (the fog), Out of scope.
- Each sharp question becomes a child bead labelled `wayfinder:<research|prototype|grilling|task>`,
  type `spike` or `decision`, with blocking edges between them.
- Resolve exactly one decision bead per session (research beads may run in parallel through
  `arena:scout`). Close it with the answer in the reason, then add its line to Decisions so far.
- The spec step starts once the fog no longer hides anything needed to build.

## 4. Write the spec

Close the frame step, claim the spec step. If `mattpocock-skills:to-spec` is installed, use it with
Beads as the tracker. Otherwise write docs/specs/<name>.md with: problem, users, user stories
("As a <who>, I want <what>, so that <why>"), out of scope, success signal and target, risks,
open spikes. Use GLOSSARY.md vocabulary only. Then:

```bash
bd update <root> --spec-id docs/specs/<name>.md
bd close <spec-step> --reason "spec written: docs/specs/<name>.md"
```

## 5. Hand over to the human

The spec sign-off gate is now listed in `bd gate list`. Tell the human, in three lines: the
hypothesis, the spec path, the decisions that were hardest. They resolve it with
`bd gate resolve <gate-id> --reason "..."` or ask for changes. Next phase: `/arena:slice <root>`.
