# Upstream skills the arena routes to

The arena is the conductor, not the orchestra. Each phase names the technique it needs; when the
upstream plugin is installed, call its skill by name through the Skill tool. When it is not, the
arena skill carries a compact version of the technique so the phase still runs.

Install all three once, then run `/arena:setup` in each repo:

```
claude plugin install mattpocock-skills@claude-plugins-official
claude plugin marketplace add addyosmani/agent-skills
claude plugin install agent-skills@addy-agent-skills
claude plugin marketplace add cursor/plugins
claude plugin install pstack@cursor-plugins
```

(Inside a session, the same commands work as `/plugin marketplace add ...` and `/plugin install ...`.)

`/arena:setup` writes `docs/agents/issue-tracker.md` describing Beads, so the mattpocock skills
(`to-tickets`, `triage`, `wayfinder`, `implement-spec`, `code-review`) read and write Beads natively,
and declares Beads as the task list target so addyosmani's `planning-and-task-breakdown` files one
bead per task instead of `tasks/todo.md`.

| Phase | Primary | Also useful | What it brings |
|---|---|---|---|
| Frame | `mattpocock-skills:grill-with-docs` | `agent-skills:interview-me`, `agent-skills:idea-refine` | one question at a time, GLOSSARY.md and ADRs updated inline |
| Foggy, multi-session effort | `mattpocock-skills:wayfinder` | | decision tickets resolved one per session, fog of war |
| Spec | `mattpocock-skills:to-spec` | `agent-skills:spec-driven-development` | PRD published to the tracker |
| Quality bar | `agent-skills:constraint-driven-development` | | CONSTRAINTS.md with numbers, floor guard against a lowered bar |
| Slice | `mattpocock-skills:to-tickets` | `agent-skills:planning-and-task-breakdown` | tracer bullets, expand then contract for wide refactors, task sizing XS to XL |
| Build | `mattpocock-skills:tdd` | `agent-skills:test-driven-development`, `agent-skills:incremental-implementation` | red, green, refactor per vertical slice |
| Design before code | `pstack:architect` | `mattpocock-skills:codebase-design` | caller usage, types and module shape settled first |
| Doubt | `pstack:interrogate` | `agent-skills:doubt-driven-development` | adversaries, only findings a run proves |
| Review | `mattpocock-skills:code-review` | `agent-skills:code-review-and-quality` | Standards and Spec axes in parallel, Fowler smell baseline |
| PR body | `mattpocock-skills:pr` | | smallest visual, before and after evidence, one-way or two-way door |
| Contest | `pstack:arena` | `pstack:swarm` | N candidates, cross-judge, base and graft |
| Referee | pstack Babysit playbook (`pstack:poteto-mode`) | `agent-skills:ci-cd-and-automation` | classify CI before retrying, skeptical bot triage, never churn code to quiet a bot |
| Ship | `agent-skills:shipping-and-launch` | `pstack:poteto-mode` Shipping playbook | rollback path, independent verdict before landing |
| Learn | `mattpocock-skills:retro` | `pstack:reflect`, `pstack:correct` | environment fixes ranked by severity, lessons encoded in structure |
| Principles | pstack `principle-*` skills | | laziness protocol, prove it works, fix root causes, encode lessons in structure |

## Notes on combining them

- pstack was written for Cursor. Its multi-model steps name Grok and Opus; in Claude Code use
  different Claude model tiers for diversity (the arena agents already do), and skip steps that need
  Cursor-only features (Bugbot, automations).
- mattpocock skills expect `/setup-matt-pocock-skills` to have run. `/arena:setup` writes the same
  files with Beads as the tracker, so do not rerun the upstream setup afterwards (it would offer
  GitHub Issues again).
- addyosmani's `/build auto` writes `tasks/plan.md`; keep the plan document, but the task list is
  Beads (the CLAUDE.md arena section says so).
- The upstream skills each assume they own the process. The arena owns it: when an upstream skill
  says "publish to the issue tracker", that means Beads; when it says "open a todo list", that means
  the round's wisp steps.
