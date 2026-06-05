# Review — Code Review Changed Files

Review recent changes for correctness, style, test coverage, and project convention compliance.

$ARGUMENTS

## How to Use

- `/review` — Review all uncommitted changes
- `/review HEAD~1` — Review the last commit
- `/review src/combat.odin` — Review a specific file

## Review Checklist

### 1. Get the Diff

```bash
# Uncommitted changes
git diff

# Last commit
git diff HEAD~1 HEAD

# Specific file
git diff src/combat.odin
```

### 2. Correctness

- [ ] Logic matches the intended behaviour described in comments/issue
- [ ] No off-by-one errors in map indexing (map is `MAP_WIDTH * MAP_HEIGHT = 80×50`)
- [ ] No out-of-bounds array accesses — check index arithmetic
- [ ] Nil guards before pointer dereferences (`if thing == nil { return }`)
- [ ] Dynamic collections (`[dynamic]T`) are freed in the matching `_destroy`/`_cleanup` proc
- [ ] No memory leaked — every `new(T)` or `make([dynamic]T)` has a matching `free`/`delete`

### 3. Architecture

- [ ] Engine layer (`src/engine/`) has zero Raylib imports
- [ ] New functionality in the right layer (engine if reusable + backend-agnostic, else game)
- [ ] Services retrieved via `engine_services_get` with correct service ID, not stored as globals
- [ ] Backend injection used for I/O — no raw OS calls in engine layer
- [ ] Clay UI kept in the game layer — engine never imports Clay

### 4. Odin Style (`-vet -strict-style`)

- [ ] Types: `PascalCase` — `My_Type`
- [ ] Procs: `snake_case` with `type_verb` prefix — `enemy_manager_spawn`
- [ ] Constants: `SCREAMING_SNAKE_CASE`
- [ ] Fields / locals: `snake_case`
- [ ] No unused variables (Odin treats these as errors under `-vet`)
- [ ] No shadowed variables
- [ ] Comments explain **why**, not **what** — no docstrings

### 5. Tests

- [ ] New procs with non-trivial logic have at least one test
- [ ] Test names are full sentences: `thing_does_x_when_y`
- [ ] Fake backends used for I/O — no real files opened in tests
- [ ] Tests are window-free (engine tests especially)
- [ ] Edge cases covered: empty input, nil, zero, boundary values

### 6. Data Files

If `data/*.json5` was changed:

- [ ] New enemy/item ID is unique and `snake_case`
- [ ] Added to relevant `spawn_tables` / `spawn_weights`
- [ ] Color is `[r, g, b, 255]` format
- [ ] Glyph is a single character string

### 7. Run Verification

```bash
just verify
```

Report any failures with the exact error output.

## Summary Format

After reviewing, report findings as:

**Bugs / Correctness Issues** (must fix)

- …

**Style / Convention Issues** (should fix)

- …

**Missing Tests** (should add)

- …

**Looks Good**

- …
