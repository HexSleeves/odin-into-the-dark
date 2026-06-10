---
name: qa-pass
description: Manual QA for game builds — verify the game runs, features work, and no regressions.
---

# QA Pass

## Use When

- Before merging a feature that affects gameplay
- Before releasing a version
- After fixing a bug that affects player experience
- When user says "test this" or "QA this"

## Inputs

| Input | Required | Notes |
|---|---|---|
| Build | yes | Debug or release binary |
| Focus areas | no | Specific features to test |

## Workflow

1. **Build the game** — `just build` or `just run`
2. **Smoke test** — verify game launches without crash
3. **Test focus areas**:
   - If map generation changed: play 3 floors, verify no crashes
   - If combat changed: fight enemies, verify damage/death works
   - If items changed: pick up, use, drop, equip items
   - If UI changed: open inventory, crafting, minimap, help
   - If save/load changed: save game, quit, load, verify state
   - If audio changed: verify sound effects play
4. **Regression test** — verify unrelated features still work:
   - Title screen displays
   - Movement and combat
   - Descending floors
   - Game over and restart
5. **Check logs** — `into_the_depths.log` for errors or warnings
6. **Document results** — add QA note to issue/PR

## QA Checklist Template

```md
## QA Pass

### Build
- [ ] Game launches without crash
- [ ] No console errors

### Focus Areas
- [ ] Feature X works as described
- [ ] Edge case Y handled

### Regression
- [ ] Title screen
- [ ] Movement/combat
- [ ] Inventory/crafting
- [ ] Save/load
- [ ] Minimap

### Logs
- [ ] No errors in `into_the_depths.log`

### Result
PASS / FAIL — notes
```

## Safety

- Do not skip `just verify` before QA
- Do not QA on a dirty working tree
- If QA fails, document the failure and return to `execute-work-item`
- Save game corruption is a critical failure — never approve if suspected

## Proof

QA is complete when:

- Game launches and runs
- Focus areas verified
- No regressions detected
- Logs clean
- QA note added to issue/PR

## Final Response

Report:
- What was tested
- What passed
- What failed
- Recommended next steps
