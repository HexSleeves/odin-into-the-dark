# Quality Gates

> Install, run, lint, test, build, and release proof for Into the Depths.

## Prerequisites

- [Odin](https://odin-lang.org/docs/install/) (dev-2026-05 or later)
- [just](https://just.systems/) (task runner)
- `odinfmt` from OLS build (for formatting)
- Python 3 (for test runner)
- `../karl2d` (for web builds)

## Commands

| Command | What it does | When to run |
|---|---|---|
| `just check` | Type-check only, no binary | Quick validation |
| `just build` | Debug binary | Local development |
| `just run` | Build and run | Playtesting |
| `just test` | Run all tests via Python runner | Before PR |
| `just test-flags` | Compile-flag matrix tests | CI, before release |
| `just verify` | test + test-flags + check + build | **Required before any task completion** |
| `just fmt` | Format all .odin files | Before commit |
| `just release` | Optimized build (-o:speed, no asserts) | Release candidate |
| `just stats` | Line count | Curiosity |
| `just clean` | Remove build artifacts | Cleanup |

## Test Framework

Odin's built-in `core:testing`.

```odin
@(test)
my_test_procedure_name_is_a_full_sentence :: proc(t: ^testing.T) {
    testing.expect(t, condition)
    testing.expect_value(t, actual, expected)
}
```

## Test Organization

- Test files in `test/` mirroring `src/` structure
- Python runner copies `src/` to temp, overlays tests
- Engine tests: `package engine` (same package as source)
- Game tests: `package main`

## Running Single Tests

```bash
python3 scripts/run_odin_tests.py -define:ODIN_TEST_NAMES=main.test_proc_name_here
```

## Test Requirements

- Every new manager or public proc with non-trivial logic needs a test
- Backend injection paths must be tested with fake FS/backend
- Save/load round-trips must be tested with in-memory fake storage
- Engine tests must be window-free

## CI Gate

GitHub Actions runs:
1. `odin test src/ -collection:libs=vendor/`
2. `odin test src/engine/ -collection:libs=vendor/`
3. `odin check src/ -vet -strict-style -collection:libs=vendor/`
4. `odin build src/ -out:into_the_depths -collection:libs=vendor/ -define:PUBLIC_BUILD=true`

## Pre-Completion Checklist

- [ ] `just verify` passes
- [ ] `just fmt` passes
- [ ] Tests cover the change
- [ ] No new compiler warnings
- [ ] No secrets or local artifacts added
- [ ] Docs updated if behavior changed

## Expensive Commands

- `just test-flags` — runs multiple test suites, slow
- `just release` — optimized build, slower than debug
- `just release-macos` — builds .app bundle

Default to `just verify` for routine work. Use expensive commands only before release or when debugging build flags.
