# Build — Compile the Game

Build the game binary with optional feature flags.

$ARGUMENTS

## Quick Reference

```bash
# Debug build (default)
just build

# Debug build + run immediately
just run

# Release build (optimized)
just release

# Type-check only (fastest)
just check
```

## Feature Flags

Compose flags using environment variables:

| Flag | Effect | When to use |
|------|--------|-------------|
| `CHEATS=true` | Enables Shift+C cheat menu | Manual QA, testing |
| `SPRITES=true` | Start in sprite render mode | Sprite QA |
| `NO_AUDIO=true` | Nil audio backend | Headless testing, CI |
| `NO_SPRITES=true` | Skip atlas load/copy | Fast iteration |
| `SKIP_TITLE=true` | Jump straight to gameplay | Faster test loops |
| `FIXED_SEED=N` | Deterministic map seed | Reproducible runs |

### Example Combinations

```bash
# Fast dev loop — skip title, cheats on
CHEATS=true SKIP_TITLE=true just run-built

# Reproducible bug reproduction
FIXED_SEED=42 SKIP_TITLE=true just run-built

# Audio-free profiling build
NO_AUDIO=true just profile

# Full-fat release
just release

# macOS .app bundle
just release-macos
```

## Build Outputs

| Command | Output |
|---------|--------|
| `just build` | `./into_the_depths` |
| `just release` | `./into_the_depths` (optimized) |
| `just release-macos` | `build/macos/Into the Depths.app` |
| `just release-linux` | `build/linux/into_the_depths` |
| `just release-web` | `build/web/` (WASM) |

## Interpreting Errors

- **Undefined identifier** — check imports; engine layer cannot import Raylib
- **Procedure not found** — check the package prefix; engine procs are in `engine.` namespace
- **Type mismatch** — Odin is strict; check if you need a cast or the type hierarchy
- **Unused variable** — `-vet` makes these errors; delete the variable or use `_`
- **Linker error** — usually a missing Raylib dependency; check `vendor:raylib` is available

## Clean Build

```bash
just clean
just build
```
