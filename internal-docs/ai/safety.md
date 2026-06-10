# Safety

> Secrets, production, data, infrastructure, and approval boundaries.

## Secrets

### What Must Never Be Committed

- `.env` files (already in `.gitignore`)
- Save game files (`savegame.dat`, `scores.json` — already in `.gitignore`)
- Local build artifacts (`into_the_depths`, `game`, `src.bin` — already in `.gitignore`)
- API keys, tokens, credentials (none currently in use)

### What Must Never Be Printed

- Full file paths containing username
- Save file binary contents
- Player names or personal data
- Connection strings (if any added later)

## Production Data

### Save Games

- `savegame.dat` — player progress, can be read locally
- `scores.json` — high scores, can be read locally
- AI must not corrupt, delete, or mutate these without explicit approval
- AI must not read these files in final answers (redact contents)

### Data Files

- `data/*.json5` — game content definitions
- Safe to edit (data-driven design)
- But changes affect game balance — get approval for stat changes

## Infrastructure

### What the AI Can Do

- Read CI config (`.github/workflows/`)
- Read build scripts (`scripts/`)
- Read justfile

### What the AI Must Not Do

- Edit CI secrets or `secrets.GITHUB_TOKEN` references
- Run `git push --force` or destructive git operations
- Run `rm -rf` on `assets/`, `data/`, or `src/`
- Mutate GitHub repository settings
- Create or delete GitHub releases without approval
- Run `just release` without approval (creates optimized binary)

### What Requires Explicit Approval

- Any change to `data/*.json5` that affects game balance
- Any change to save format or serialization
- Any change to CI/CD workflows
- Any deletion of test files
- Any change to `vendor/` or `src/vendor/`
- Any release build or tag creation

## Build Safety

- `just release` strips asserts and bounds checks — only for actual releases
- `just verify` is the safe default (debug build, all checks enabled)
- Never commit build artifacts
- Never commit `vendor/` changes (should be pinned)

## Runtime Safety

- Game logs may contain player actions — redact in output
- `into_the_depths.log` is diagnostic, not sensitive
- No network calls in game — no remote data leakage risk

## Compliance

- No regulated data (health, finance, PII)
- Open source (MIT license)
- No age-restricted content (fantasy combat)
