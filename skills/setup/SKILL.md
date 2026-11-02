---
name: setup
description: Turn the current repository into an arena. Initialises Beads, installs the arena formulas, wires the Beads tracker for the upstream skills, writes the CLAUDE.md arena section and sets the quality bar in CONSTRAINTS.md. Run once per repository.
disable-model-invocation: true
argument-hint: "[prefix] [--strict|--lenient]"
---

# Arena setup

Goal: after this skill, `/arena:frame` can start a season in this repository and every phase knows
where tickets, specs, decisions and the quality bar live. Idempotent: safe to rerun.

## 1. Detect before asking

Run these and report what you found in three lines. Never ask what you can read.

```bash
git rev-parse --show-toplevel; git remote -v | head -2
command -v bd && bd version; command -v gh && gh auth status 2>&1 | head -2; command -v jq; node --version
ls .beads CLAUDE.md AGENTS.md CONSTRAINTS.md GLOSSARY.md docs/adr docs/agents 2>/dev/null
cat package.json 2>/dev/null | jq '{scripts, devDependencies}' ; ls *.tf terraform infra 2>/dev/null | head
```

Missing `bd`: stop and give the install line (`brew install beads`, or
`npm install -g @beads/bd`, or the script at https://beads.gascity.com/getting-started/installation).
Missing `gh` or not authenticated: continue, but say that the referee and the merge gates need it.

## 2. Run the installer

`arena-setup` is on PATH through the plugin's `bin/`. If it is not, run
`<this skill's base directory>/../../bin/arena-setup`.

```bash
arena-setup $ARGUMENTS
```

Arguments: an optional issue prefix (default: derived from the repo name), and `--strict`
(default: a ticket without `## Acceptance Criteria` is refused at creation) or `--lenient`
(warning only). The script prints a JSON summary of what it created and what it left untouched.
Read it, do not repeat it.

## 3. Set the quality bar (CONSTRAINTS.md)

The installer writes a CONSTRAINTS.md skeleton only when none exists. Fill it with the human:

1. Read what the repo already enforces (package scripts, eslint/biome config, tsconfig strictness,
   CI workflows, Terraform tooling) and pre-fill every command you found.
2. Ask at most four questions, one at a time, each with a default so "I don't know" is a complete
   answer: coverage floor (default: no decrease on touched files), performance budget (default:
   none until a baseline exists), accessibility (default: no new axe violations on touched pages),
   infra (default: `terraform fmt -check`, `terraform validate`, plan reviewed by a human, never
   `apply` from an agent).
3. If `agent-skills:constraint-driven-development` is installed, follow it instead of this step.
   In a non-interactive run, apply the defaults and note it in the summary.

## 4. Check context injection and git authority

`bd init` installs Beads' own SessionStart hook (`bd prime`) and a managed block in CLAUDE.md and
AGENTS.md. Keep both: the arena hook detects the Beads hook and only adds the arena brief, so
nothing is injected twice. The managed block defaults to a conservative git profile (no commits,
no pushes); the arena section the installer wrote opts into a scoped team-maintainer profile
(agents commit and push their own `arena/*` branches and open PRs, never the default branch, never
merge). Show the human that line and confirm they agree; remove it if they do not, and say that
rounds will then stop before each commit.

## 5. Report

End with: the prefix, the formulas visible in `bd formula list`, the files written, the gates in
CONSTRAINTS.md, and the one next step: `/arena:frame <idea>`. Mention the upstream plugins from
[../protocol/references/upstream-skills.md](../protocol/references/upstream-skills.md) only if none
of them is installed.
