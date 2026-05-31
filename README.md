# Into the Depths

A turn-based dungeon crawler built with [Odin](https://odin-lang.org/) and [Raylib](https://www.raylib.com/).

## Prerequisites

- **Odin** dev-2026-05 or later
- **macOS ARM64** (Raylib vendor bindings are included with Odin)

## Build

```sh
odin build src/ -out:into_the_depths
```

## Run

Run directly (build + execute):

```sh
odin run src/
```

Or build first, then run the binary:

```sh
./into_the_depths
```

## Controls

| Key    | Action     |
| ------ | ---------- |
| W / ↑  | Move up    |
| S / ↓  | Move down  |
| A / ←  | Move left  |
| D / →  | Move right |
| Escape | Quit       |

## Current State

- 1280×800 window with a hardcoded two-room test map
- 16×16 colored tile rendering (Wall, Floor, Rubble, Descent)
- Turn-based movement with wall collision
- Deterministic RNG seed printed to stdout on startup
- No procedural generation, FOV, or enemies yet
