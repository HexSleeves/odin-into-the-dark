---
name: review-change
description: Review code changes for correctness, conventions, safety, and test coverage before merge.
---

# Review Change

## Use When

- User asks to review a PR or diff
- Before claiming a task is complete
- After implementing but before merge
- CI failed and need to review what went wrong

## Inputs

| Input | Required | Notes |
|---|---|---|
| PR number or diff | yes | What to review |
| Focus area | no | Specific concern (performance, safety, correctness) |

## Workflow

1. **Read the PR description** — understand intent and scope
2. **Read the diff** — `git diff` or GitHub PR files
3. **Check conventions**:
   - Naming follows `internal-docs/ai/coding-style.md`
   - No Raylib imports in `src/engine/`
   - No Clay imports in `src/engine/`
   - Comments explain "why" not "what"
4. **Check correctness**:
   - Logic matches the issue description
   - No off-by-one errors in map/grid operations
   - Memory management: `new` paired with `free`, `[dynamic]` initialized/freed
   - Backend injection pattern used correctly
5. **Check tests**:
   - New logic has test coverage
   - Existing tests still pass
   - Fake backends used where appropriate
6. **Check safety**:
   - No secrets committed
   - No `.env` or local files committed
   - No save file corruption risk
   - No CI workflow changes without approval
7. **Check docs**:
   - README updated if user-facing behavior changed
   - AGENTS.md updated if architecture or commands changed
   - `internal-docs/ai/` updated if conventions changed
8. **Run verification**:
   - `just check` (quick)
   - `just test` (thorough)
   - `just verify` (full gate)

## Review Checklist

```md
## Review checklist
- [ ] Correctness: logic matches intent
- [ ] Conventions: naming, style, comments
- [ ] Architecture: no boundary violations
- [ ] Memory: proper allocation/cleanup
- [ ] Tests: coverage exists and passes
- [ ] Safety: no secrets, no destructive changes
- [ ] Docs: user-facing changes documented
- [ ] Verify: `just verify` passes
```

## Safety

- Do not approve changes that break `just verify`
- Do not approve changes that modify `vendor/` or `data/` without justification
- Do not approve changes that add panics instead of `logger_fatalf` + cleanup
- Flag any save format or serialization changes for explicit approval

## Proof

Review is complete when:

- All checklist items pass
- `just verify` passes on the branch
- Or explicit issues are documented with recommended fixes

## Final Response

Report:
- Summary of changes
- What passed
- What failed or needs attention
- Recommended fixes
- Approve / Request changes / Needs discussion
