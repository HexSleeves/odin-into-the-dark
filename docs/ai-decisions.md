# AI Decisions

> Important choices made during this project's AI stewardship setup. Record tradeoffs, rationale, and open questions.

## Architecture Decisions

### 1. Engine / Game Split

- **Decision:** Two Odin packages — `engine` (backend-agnostic) and `main` (game logic)
- **Rationale:** Engine can be reused; tests run headless without Raylib
- **Tradeoff:** Cross-package imports require alias management (`gcore`, `gameio`, etc.)
- **Status:** Stable. Verified by `odin check` and CI.

### 2. Sub-package Organization

- **Decision:** src/ split into `core/`, `engine/`, `gameplay/`, `input/`, `render/`, `audio/`, `io/`, `ui/`, `ai/`, `gen/`
- **Rationale:** Odin is directory-based; one folder = one package
- **Tradeoff:** Root-level alias files (`core_aliases.odin`) needed for unqualified access
- **Status:** Stable. Reorganization completed.

### 3. Clay UI Integration

- **Decision:** Vendored Clay at `src/vendor/clay/` (or top-level `vendor/clay/`); translated through `Engine_Render_Backend`
- **Rationale:** Immediate-mode UI layout without external dependencies
- **Tradeoff:** Engine layer must never import Clay; all Clay stays in game layer
- **Status:** Stable. Default UI path.

### 4. Test Runner

- **Decision:** Python script `scripts/run_odin_tests.py` copies `src/` to temp dir, overlays `test/**/*_test.odin`
- **Rationale:** Odin test files must be in same package; keeping tests in `test/` mirrors src structure
- **Tradeoff:** Requires Python; not pure Odin toolchain
- **Status:** Stable. CI uses it.

### 5. Data-Driven Design

- **Decision:** Game data (enemies, items, player, sprites) in `data/*.json5`
- **Rationale:** Content changes without code modifications
- **Tradeoff:** Runtime uses string IDs for type lookups; no compile-time verification
- **Status:** Stable. Content manager loads at init.

## Tooling Decisions

### 6. Build System

- **Decision:** `just` instead of Make/CMake
- **Rationale:** Modern, simple, cross-platform task runner
- **Tradeoff:** Requires `just` installation
- **Status:** Stable. `just verify` is the completion gate.

### 7. Formatter

- **Decision:** `odinfmt` from OLS build (not `odin fmt` — not a valid subcommand)
- **Rationale:** Only available formatter for Odin
- **Tradeoff:** Must be installed at hardcoded path (`~/Developer/games/ols/odinfmt`)
- **Status:** Stable. Run via `just fmt`.

### 8. Language Server

- **Decision:** OLS with `-vet -strict-style`
- **Rationale:** Strict style enforcement catches issues early
- **Tradeoff:** Strict style may reject valid patterns
- **Status:** Stable. Config in `ols.json`.

### 9. CI/CD

- **Decision:** GitHub Actions with `laytan/setup-odin@v2`
- **Rationale:** Automatic Odin nightly setup; macOS + Linux matrix
- **Tradeoff:** Uses nightly Odin; may break on upstream changes
- **Status:** Stable. CI runs on push/PR.

### 10. Web Backend

- **Decision:** karl2d for WASM/WebGL build (no Emscripten)
- **Rationale:** Native WebGL backend without heavy toolchain
- **Tradeoff:** Requires sibling repo checkout (`../karl2d`)
- **Status:** Stable. Web build script handles linking.

## Open Questions

- Should skills be stored in the repo or in a separate AI config repo?
- Should the GitHub Project board mutations be wrapped in a script instead of raw GraphQL in docs?
- Should `internal-docs/ai/` be under `docs/` instead of `internal-docs/`?
- How to handle save game compatibility across versions?
- Should there be a skill for "debug production crash from save file"?

## Assumptions

- Odin 2026-05+ is available on all dev machines (Homebrew on macOS)
- All devs have `just` installed
- `odinfmt` is at the path in `justfile`
- `../karl2d` exists for web builds
- GitHub Project board v4 API IDs remain stable
