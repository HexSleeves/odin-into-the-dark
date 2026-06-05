# New Feature — Implement a Game Feature

Scaffold and implement a new gameplay feature following project conventions.

$ARGUMENTS

## Process

### 1. Understand the Scope

Read the feature request carefully. Identify which layer it belongs to:

| Layer | Path | When |
|-------|------|------|
| Engine (reusable) | `src/engine/` | Backend-agnostic managers, no Raylib |
| Game (specific) | `src/` | Game logic, scenes, rendering, UI |
| Data-only | `data/` | Content — no code change needed |

**Key constraint:** Engine layer must never import Raylib. Game layer may use both.

### 2. Check Existing Code

Before writing new code, grep for related functionality:

```bash
# Find related procs
rg "feature_keyword" src/ --type odin

# Check types
rg "struct" src/types.odin

# Check what's already in the game loop
cat src/game_app.odin
cat src/scene.odin
```

### 3. Design the Data Structures

Add new types to `src/types.odin` following conventions:

- Types/Enums: `PascalCase` — `My_Feature_State`
- Fields: `snake_case` — `is_active: bool`
- Keep the `Game` struct lean — it's already ~112 KB heap-allocated

### 4. Implement the Feature

**Logic file** — create `src/my_feature.odin`:

```odin
package main

// Brief comment explaining why this module exists (not what it does)

my_feature_init :: proc(game: ^Game) {
    // initialize
}

my_feature_update :: proc(game: ^Game) {
    // per-turn or per-frame update
}
```

**Wire into game loop** — hook into the right call site:

- Per-turn effects → `src/actions.odin` (inside `advance_turn`)
- Per-frame rendering → `src/render.odin` or the appropriate `render_*.odin`
- Input handling → `src/input.odin`
- Scene-specific → `src/scene.odin` scene callbacks

### 5. Write Tests

Create `src/my_feature_test.odin`:

```odin
package main

import "core:testing"

@(test)
my_feature_does_the_expected_thing :: proc(t: ^testing.T) {
    // Arrange: set up minimal game state
    game := new(Game)
    defer free(game)
    game_init_minimal(game)  // or construct what you need

    // Act
    my_feature_update(game)

    // Assert
    testing.expect_value(t, game.some_field, expected_value)
}
```

Test names are full sentences. Inject fakes for I/O.

### 6. Update Rendering (if visual)

- ASCII render path: `src/render_map.odin` or `src/render_hud.odin`
- Clay UI path: `src/clay_hud.odin` or `src/clay_overlays.odin`
- Keep ASCII and Clay paths in sync — both must show the feature

### 7. Add Messages (if player-facing)

Use the message system from `src/messages.odin`:

```odin
message_manager_add(&game.messages, "You triggered the feature!", .Info)
```

### 8. Verify

```bash
just verify
```

Fix all type-check errors and test failures before marking complete.

## Common Pitfalls

- **Forgetting `-vet -strict-style`** — `odin check src/ -vet -strict-style` catches unused variables, shadowed names, and style issues
- **Importing Raylib in engine layer** — never do this; use the render/input/audio backends
- **Allocating in the wrong context** — frame-scoped allocs are fine in update/render; save-affecting data must outlive frames
- **Missing test** — every new manager or non-trivial proc needs a test
