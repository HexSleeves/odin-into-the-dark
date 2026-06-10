---
name: execute-work-item
description: Implement a tracked work item by creating a plan, working item by item, running focused proof, and leaving an auditable trail.
---

# Execute Work Item

## Use When

- User asks to implement, build, fix, or carry a tracked issue to completion
- User says "do #N" or "work on issue X"
- Starting implementation on a GitHub Project board item

## Inputs

| Input | Required | Notes |
|---|---|---|
| Issue number | yes | GitHub issue to implement |
| Scope | no | What to include/exclude |
| Required proof | no | Specific tests or checks beyond `just verify` |

## Workflow

1. **Read the issue** — understand the problem, acceptance criteria, and milestone
2. **Inspect code** — find relevant files using `graphify` or `grep`
3. **Update board status** — move to **In Progress** (see AGENTS.md for GraphQL)
4. **Create branch** — `git checkout -b feat/<issue-num>-short-description`
5. **Create execution checklist** — add to issue body or comment:
   ```md
   ## Execution checklist
   - [ ] Investigate relevant code
   - [ ] Implement change
   - [ ] Add/update tests
   - [ ] Run `just verify`
   - [ ] Run `just fmt`
   - [ ] Update docs if behavior changed
   ```
6. **Implement smallest coherent change** — one concern at a time
7. **Run focused proof**:
   - `just check` for quick validation
   - `just test` for test coverage
   - `just verify` for final gate
   - `just fmt` for formatting
8. **Update checklist** with proof results
9. **Repeat** until all items done or blocked
10. **Prepare PR** — body includes `Closes #N` and summary of changes

## Safety

- Do not rewrite the user's original problem statement
- Do not silently expand scope
- Do not mutate production systems (no `just release` without approval)
- Do not overwrite unrelated user changes
- If work crosses package boundaries, inspect each boundary before editing
- If issue is unclear, ask before implementing

## Proof

Work is not complete until:

- [ ] `just verify` passes
- [ ] `just fmt` passes
- [ ] Tests added or updated for the change
- [ ] No new compiler warnings
- [ ] No secrets or local artifacts added
- [ ] Relevant docs updated (README, AGENTS.md, or internal-docs/ai/)

## Final Response

Report:
- What changed
- What proof was run
- What was skipped and why
- Remaining risks or follow-ups
- PR ready for review
