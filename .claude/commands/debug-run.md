# Debug Run — Run the Game with Debug Flags

Build and launch the game with a configured set of development flags for fast iteration.

$ARGUMENTS

Optionally specify a fixed seed: `/debug-run 42`

## Default Debug Session

```bash
CHEATS=true SKIP_TITLE=true just run-built
```

This builds with cheats enabled and skips the title screen so you land directly in gameplay.

## With a Fixed Seed

If `$ARGUMENTS` is a number, use it as the map seed for reproducibility:

```bash
CHEATS=true SKIP_TITLE=true FIXED_SEED=$ARGUMENTS just run-built
```

## Cheat Menu (in-game)

Press **Shift+C** to open the cheat menu. Available cheats:

- **Heal** — restore full HP
- **Cure statuses** — clear poison, freeze, etc.
- **Teleport to descent** — jump to the stairs
- **Depth jump** — skip N floors
- **Vault key** — spawn a treasure vault key

## Useful Flag Combinations

```bash
# Reproduce a specific bug on a known seed
CHEATS=true SKIP_TITLE=true FIXED_SEED=1234 just run-built

# Test sprite rendering
CHEATS=true SKIP_TITLE=true SPRITES=true just run-built

# Test audio-off path
CHEATS=true SKIP_TITLE=true NO_AUDIO=true just run-built

# No sprites, no audio — pure logic testing
CHEATS=true SKIP_TITLE=true NO_SPRITES=true NO_AUDIO=true just run-built
```

## Checking Logs

Game logs are written to `into_the_depths.log`:

```bash
tail -f into_the_depths.log
```

## Save File Location

The save file is `savegame.dat` in the repo root. Delete it to start fresh:

```bash
rm -f savegame.dat
```
