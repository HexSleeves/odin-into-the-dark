# Into the Depths — Next Steps

## Recently shipped

| Area        | Feature                                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------------------------ |
| Content     | Frozen status effect: deep_watcher freeze, doubled movement cost, timed thaw message, HUD indicator          |
| Content     | Treasure vault room: sealed perimeter, locked door, key elsewhere, guaranteed rare loot                      |
| Game feel   | Tile-specific footsteps for water, rubble, and stone/descent/anvil                                           |
| Progression | Victory screen score breakdown with boss status and item counts                                              |
| Dev tooling | `CHEATS` build flag with Shift+C cheat menu: heal, cure statuses, teleport to descent, depth jump, vault key |
| Dev tooling | ASCII is the default render mode; `SPRITES=true` opts into sprite default                                    |
| Dev tooling | Additional build flags: `NO_AUDIO`, `NO_SPRITES`, `SKIP_TITLE`, `FIXED_SEED=<n>`                             |
| Game feel   | Boss floors set a tighter camera zoom while a boss is alive                                                  |
| Engine      | App update/render now run with `engine_frame_allocator(engine)` as the default context allocator             |
| Shipping    | Release recipes propagate build flags; macOS bundler can skip asset copy for `NO_SPRITES=true`               |

## Build flag reference

```bash
CHEATS=true just run-built              # Shift+C cheat menu
SPRITES=true just run-built             # start in sprite mode
NO_AUDIO=true just run-built            # nil audio backend
NO_SPRITES=true just run-built          # skip sprite atlas runtime load/copy
SKIP_TITLE=true just run-built          # start directly in gameplay
FIXED_SEED=12345 just run-built         # deterministic map seed
```

Flags compose, for example:

```bash
CHEATS=true SKIP_TITLE=true FIXED_SEED=42 just run-built
NO_AUDIO=true NO_SPRITES=true just release-macos
```

## Remaining work

### Priority 1 — Shipping validation

1. **Manual QA pass for build flags**
   - Confirm each flag and common combinations behave correctly in a real run.
   - Especially verify `NO_SPRITES=true` cannot leave the renderer in sprite mode.

2. **macOS bundle smoke test**
   - Run `just release-macos` and launch the `.app`.
   - Verify ad-hoc signing and resource paths.

3. **WASM/web target smoke test**
   - Run `just release-web` and `just run-web`.
   - Verify karl2d backend, input, audio fallback, and embedded data path.

### Priority 2 — Polish

1. **Tune boss camera zoom**
   - Current zoom is intentionally conservative (`1.12`).
   - Adjust after playtesting boss rooms.

2. **Title screen polish follow-up**
   - Existing title has glow/embers and recent scores.
   - Next pass can add richer animation or title art if desired.

### Priority 3 — Engine maturity

1. **Texture-from-memory backend**
   - Data files are compile-time embedded.
   - PNG assets still need filesystem paths unless the texture backend gains `load_bytes`/memory-image support.

2. **Frame allocator audit**
   - Engine now scopes app update/render to the frame allocator.
   - Next pass: look for allocations that must outlive a frame and make those explicit.
