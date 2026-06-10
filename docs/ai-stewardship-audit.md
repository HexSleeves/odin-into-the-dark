# AI Stewardship Audit

## Present

- **AGENTS.md** exists (348 lines) — comprehensive always-loaded contract with architecture, commands, conventions, testing, GitHub Project board integration
- **CLAUDE.md** exists (115 lines) — Claude-specific instructions with headroom learned patterns
- **CONTEXT.md** exists (53 lines) — handoff context for src/ reorganization
- **CI/CD** — `.github/workflows/ci.yml` + `release.yml` with macOS/Linux/Web builds
- **Work tracking** — GitHub Project board v4 with GraphQL mutations documented in AGENTS.md
- **GSD planning** — `docs/superpowers/plans/` + `specs/` already in use
- **Build system** — `justfile` with verify/test/check/build/fmt/release targets
- **Testing** — Python test runner in `scripts/run_odin_tests.py`, test files in `test/`

## Missing

- **No `internal-docs/ai/`** — all long-form docs are embedded in AGENTS.md
- **No `docs/ai-decisions.md`** — no record of tradeoffs made during setup
- **No `docs/ai-operating-model.md`** — no explicit delivery loop mapping
- **No `.agents/skills/`** — no repeatable workflows; everything is prose
- **No safety doc** — safety rules are not explicit
- **No domain model doc** — game concepts are implicit in code

## Risk

- AGENTS.md is 348 lines — too long for always-loaded context
- GitHub Project GraphQL mutations are fragile (hardcoded IDs may drift)
- No explicit safety rules for save data, production builds, or CI secrets
- No skill for "what to do when CI fails" or "how to cut a release"
- Engine layer safety (no Raylib imports) is convention, not enforced by skill

## Proposed Changes

- **Refactor AGENTS.md** to ~80 lines: link to internal-docs/ai/ instead of embedding
- **Create internal-docs/ai/**: architecture, coding-style, domain-model, quality-gates, safety
- **Create docs/ai-decisions.md** — log existing choices (engine split, test runner, Clay, etc.)
- **Create docs/ai-operating-model.md** — map GitHub Project → PR → review → QA → release
- **Create .agents/skills/**: execute-work-item, review-change, qa-pass, release-change, create-work-item
- **Preserve** all existing conventions, justfile, CI, test runner, and GitHub board setup
