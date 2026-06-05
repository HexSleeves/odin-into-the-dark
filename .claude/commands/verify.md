# Verify — Full CI Gate

Run the complete pre-completion verification suite before finishing any task. This is the required gate that mirrors what GitHub CI checks.

## Steps

1. Run tests for both packages:

   ```bash
   odin test src/
   odin test src/engine/
   ```

2. Run the compile-flag matrix:

   ```bash
   odin test src/ -define:CHEATS=true
   odin test src/ -define:NO_AUDIO=true
   odin test src/ -define:SPRITES=true -define:NO_SPRITES=true
   odin test src/ -define:SKIP_TITLE=true
   odin test src/ -define:FIXED_SEED=12345
   odin check src/ -vet -strict-style -define:CHEATS=true -define:NO_AUDIO=true -define:SPRITES=true -define:NO_SPRITES=true -define:SKIP_TITLE=true -define:FIXED_SEED=12345
   ```

3. Type-check without building:

   ```bash
   odin check src/ -vet -strict-style
   ```

4. Build debug binary:

   ```bash
   odin build src/ -out:into_the_depths
   ```

Or run all of the above with a single `just` command:

```bash
just verify
```

## Interpreting Results

- **Test failures** — Fix the failing tests before proceeding. Test names are full sentences describing expected behaviour.
- **Flag matrix failures** — A build flag combination broke something. Check the flag-gated code paths (files like `build_flags_test.odin`, `audio_raylib.odin`, conditional `when` blocks).
- **Type-check errors** — Odin `-vet -strict-style` is strict. Fix all warnings; they are errors in this project.
- **Build failure** — Linking or compilation broke. Check recent changes to types, procedure signatures, or imports.

## Rules

- Never mark a task complete without passing `just verify`.
- If `just verify` takes too long, run `just test` + `just check` at minimum.
- Do not suppress errors with casts or `//lint` workarounds — fix the root cause.
