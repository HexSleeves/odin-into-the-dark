# Stats — Codebase Statistics

Show line counts and project size metrics.

## Commands

### Lines by file (sorted by size)

```bash
wc -l src/*.odin src/engine/*.odin | sort -rn | head -30
```

### Total lines

```bash
echo "=== Source ===" && wc -l src/*.odin | tail -1
echo "=== Engine ===" && wc -l src/engine/*.odin | tail -1
echo "=== Data ===" && wc -l data/*.json5 | tail -1
```

### Via justfile

```bash
just stats
```

### Test file count

```bash
find src/ -name "*_test.odin" | wc -l
echo "test files"
find src/ -name "*_test.odin" | xargs wc -l | tail -1
echo "test lines"
```

### Largest files (good candidates for refactoring)

```bash
wc -l src/*.odin src/engine/*.odin | sort -rn | head -15
```

### File count by layer

```bash
echo "Game layer:   $(ls src/*.odin | wc -l) files"
echo "Engine layer: $(ls src/engine/*.odin | wc -l) files"
echo "Test files:   $(find src/ -name '*_test.odin' | wc -l) files"
echo "Data files:   $(ls data/*.json5 | wc -l) files"
```

### Recent changes

```bash
git log --oneline -10
git diff --stat HEAD~1 HEAD
```
