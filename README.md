# arena

A Claude Code plugin that runs the whole SDLC as an arena, with [Beads](https://beads.gascity.com/)
(`bd`) as the single source of truth for every ticket, dependency, gate and decision.

Ideas get grilled into a spec, specs get sliced into tracer-bullet tickets, every ticket becomes
exactly one PR through TDD and three parallel review lenses, a referee drives CI and every review
thread, humans decide only what is theirs to decide, shipped work is validated against its value
hypothesis, and every season ends by encoding its lessons into the factory itself.

![Arena factory map: frame, slice, build, ship, validate and learn, with Beads holding every step](docs/factory.svg)

Read it left to right. Dashed pink arrows wait for a human; the dashed gold line is the learning loop that feeds the next season. Open the SVG for full size.

## Why Beads

Agents lose context; Beads does not. The ready queue (`bd ready`) is computed from real dependency
edges, so a swarm of agents always knows what is startable. Claims are atomic, gates hold work until
a human, a PR merge or a timer releases it, formulas turn a process into a dependency graph, and
every state change is timestamped, which is what makes the vitals possible without self-reporting.

## Install

Prerequisites: `bd` 1.3+, `git`, `jq`, `gh` (authenticated), Node 22.6+. In CI, install bd with
`env -u CI npm install -g @beads/bd`: the npm package skips its binary download when `CI` is set.

```
claude plugin marketplace add SpartDev/beads-arena
claude plugin install arena@spartdev
```

Recommended companions (the arena calls them when installed, and carries a compact fallback when not):

```
claude plugin install mattpocock-skills@claude-plugins-official
claude plugin marketplace add addyosmani/agent-skills && claude plugin install agent-skills@addy-agent-skills
claude plugin marketplace add cursor/plugins && claude plugin install pstack@cursor-plugins
```

Then, in each repository: `/arena:setup`.

## Commands

| Command | What it does |
|---|---|
| `/arena:setup [prefix] [--strict\|--lenient]` | `bd init`, arena formulas, Beads tracker doc for the upstream skills, CLAUDE.md section, CONSTRAINTS.md |
| `/arena:frame <idea> [--fog]` | pours a season, grills with docs, spikes and decisions as beads, writes the spec |
| `/arena:slice <season>` | tracer-bullet tickets in one `bd create --graph` transaction, `bd swarm validate` |
| `/arena:build [season\|ticket\|auto]` | one round per ticket: implementer in a worktree, TDD, proof, three lenses, one PR |
| `/arena:bout <ticket> [n]` | N candidates contest a ticket's shape, a judge scores them, base and graft |
| `/arena:referee <ticket\|PR>` | CI classified before retrying, every comment answered, escalations to the pit |
| `/arena:patrol` | gates checked, dead claims reclaimed, PRs chased, the pit ranked (schedule it) |
| `/arena:pit` | everything waiting on you, ranked by what it unblocks, resolved inline |
| `/arena:retro [scope]` | lessons become learning beads, fixed at the highest level that works |
| `/arena:vitals [--since 30d]` | Time-to-Ready, Intent-to-Merge, review latency, human wait, learning velocity |
| `/arena:next` | reads the state and makes the single most valuable move |

## What is in the box

| Path | Content |
|---|---|
| `formulas/` | `arena-season`, `arena-round`, `arena-bout`, `arena-patrol` Beads formulas |
| `skills/` | the commands above, plus `protocol` (the arena rules, model-invoked) |
| `agents/` | implementer, reviewer, adversary, judge, referee, scout |
| `hooks/` | SessionStart brief, Bash guard, floor guard, Stop landing check |
| `bin/` | `arena-setup`, `arena-vitals` (on PATH inside Claude Code) |
| `templates/` | CLAUDE.md section, Beads tracker doc, triage labels, CONSTRAINTS.md, glossary, ADR, PR template |
| `tests/` | `formulas.test.sh` (end-to-end walk against a real bd), `hooks.test.sh` (every guard decision) |

## Guardrails (hooks, active only in repositories with `.beads/`)

| Hook | Effect |
|---|---|
| SessionStart | arena brief (seasons, claims, PRs, frontier, the pit), plus `bd prime` when Beads' own hook is absent |
| Bash guard | denies commits without `Refs: <ticket>`, `bd edit`, forced claims, plain and `+refspec` force pushes; asks before `bd gate resolve` (the prompt is your signature), merges (including through `gh api`), pushes to the default branch, deploys, `terraform apply/destroy`, destructive AWS, kubectl and git commands |
| Floor guard | denies edits that add `@ts-ignore`, `eslint-disable`, `.skip`, `.only`, not-implemented stubs and similar, unless the line says `arena-allow: <reason>` |
| Stop | one line for you when the pit is not empty or work is left claimed or uncommitted |

## Tests

```
tests/formulas.test.sh   # 34 checks: season, slice, round to merge and land, bout, strict-mode commands, build closing, patrol, vitals
tests/hooks.test.sh      # 44 checks: every guard decision on real payloads
```

## Credits

The techniques come from three MIT-licensed skill packs, re-expressed for Beads:
[mattpocock/skills](https://github.com/mattpocock/skills) (grill with docs, tracer-bullet tickets,
wayfinder, two-axis review, retro), [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)
(lifecycle phases, constraint-driven development, definition of done, doubt-driven development),
[cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) (arena bake-offs,
interrogate, babysit, reflect, principles). Beads by Steve Yegge and the Gas Town contributors.

MIT license.
