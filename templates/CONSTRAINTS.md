# Constraints

The quality bar for this repository, decided once and enforced on every change. Agents never lower
it; a change to this file is a decision with an ADR.

## Gates (every PR, run locally before opening it and in CI)

Fill the commands this repo actually uses. `/arena:setup` pre-fills what it detects.

| Gate | Command | Blocks merge |
|---|---|---|
| Types | `npx tsc --noEmit` | yes |
| Lint | `npx eslint . --max-warnings 0` | yes |
| Unit and integration tests | `npm test` | yes |
| Build | `npm run build` | yes |
| Terraform format | `terraform fmt -check -recursive` | yes, when *.tf changed |
| Terraform validate | `terraform validate` (per root module) | yes, when *.tf changed |
| Terraform plan | `terraform plan` output attached to the PR | human review, never `apply` from an agent |

## Thresholds

| Dimension | Floor | Default when undecided |
|---|---|---|
| Coverage | no decrease on touched files | same |
| Performance | none until a baseline exists | same |
| Accessibility | no new axe violations on touched pages | same |
| Bundle size | none until a baseline exists | same |

## The floor (never lowered by an agent)

- No new `@ts-ignore`, `@ts-nocheck`, `eslint-disable`, `# type: ignore`, `# noqa`, `//nolint`.
- No `.skip`, `.only`, `xit`, `xdescribe`, deleted tests or weakened assertions.
- No threshold edited down in this file, in CI or in tool configs.
- No stub that throws "not implemented" in a merged PR.
- An exception exists only on the line that needs it, with `arena-allow: <reason>` in a comment.
  Reviewers see it in the diff; the Edit/Write guard refuses anything else.

## Definition of Done

A ticket is done when its acceptance criteria are met and:

- New behaviour is covered by tests that fail without the change.
- Every gate above passes and the behaviour was exercised at runtime, not only type-checked.
- No unrelated change rides along. Public interfaces and ADR-worthy decisions are documented.
- Security reviewed for untrusted input, auth and data handling; observability on new critical paths.
- Rollback path exists for anything risky. The human merged it.
