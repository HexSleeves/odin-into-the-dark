# Plan 004: Web (WASM) save backend — stop saves silently no-opping on the web build

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat bf2a4bd..HEAD -- src/game_app_config.odin src/engine/file_system.odin src/engine/file_system_web.odin src/engine/file_system_desktop.odin src/main_web_stub.odin`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (independent; but coordinate with Plan 001's `rename`
  vtable behavior — see "Current state")
- **Category**: bug / migration
- **Planned at**: commit `bf2a4bd`, 2026-06-13

## Why this matters

On the web (WASM/karl2d) build, the game has **no filesystem**, and the game
layer never injects one: `game_engine_config` (`src/game_app_config.odin:16-33`)
sets `platform/render/input/texture/audio` backends but never sets
`config.file_system`. So on `#+build js` the engine falls back to
`engine_file_system_default()` which returns an empty `Engine_File_System{}`
(`src/engine/file_system_web.odin:6-8`). Every storage call then hits a nil hook
and is silently swallowed — saves, loads, autosaves, **and** the high-score table
all no-op with no user feedback, while autosave still runs every frame. A web
player's run can never be saved or scored. This plan adds a `#+build js`
`localStorage`-backed `Engine_File_System` and wires it into the web config so
web saves/scores actually persist (or, at minimum, fail loudly instead of
silently). Web is a secondary target, hence P3 — but a silently-broken core
feature is worse than an absent one.

## Current state

**Config never sets `file_system`** — `src/game_app_config.odin:16-33`:

```odin
game_engine_config :: proc() -> eng.Engine_Config {
	config := eng.engine_config_make(gcore.SCREEN_WIDTH, gcore.SCREEN_HEIGHT, "Into the Depths", 60)
	config.platform = gameio.karl2d_platform_backend()
	config.render = gameio.karl2d_render_backend()
	config.input = gameio.karl2d_input_backend()
	config.texture = gameio.karl2d_texture_backend()
	when !NO_AUDIO { config.audio = gameaudio.game_audio_backend(gameaudio.audio_state()) }
	else { _ = gameaudio.audio_state }
	return config
}
```

`game_engine_config` is called by both the web entry (`src/main_web_stub.odin:39`)
and desktop (`src/main.odin:15`).

**The engine FS vtable** — `src/engine/file_system.odin:9-25`:

```odin
Engine_File_System :: struct {
	ctx:               rawptr,
	read_entire_file:  proc(ctx: rawptr, path: string, allocator: runtime.Allocator) -> ([]u8, bool),
	write_entire_file: proc(ctx: rawptr, path: string, data: []u8) -> bool,
	exists:            proc(ctx: rawptr, path: string) -> bool,
	remove:            proc(ctx: rawptr, path: string) -> bool,
	rename:            proc(ctx: rawptr, old_path, new_path: string) -> bool, // nil on WASM; callers fall back to direct write
}
engine_file_system_is_valid :: proc(fs) -> bool { // requires read/write/exists/remove non-nil; rename optional
	return fs.read_entire_file != nil && fs.write_entire_file != nil && fs.exists != nil && fs.remove != nil
}
```

Note: `engine_file_system_is_valid` does **not** require `rename`. The save
writer (Plan 001 / `src/io/save_write.odin`) already falls back to a direct write
when `rename` is nil. So a web backend that implements read/write/exists/remove
and leaves `rename = nil` is valid and will use the direct-write path — no atomic
rename needed on web. **Do not implement `rename` on web** unless localStorage
copy semantics are trivial; nil is the correct, supported choice.

**Web default is empty** — `src/engine/file_system_web.odin:1-8`:

```odin
#+build js
package engine
engine_file_system_default :: proc() -> Engine_File_System {
	return Engine_File_System{} // empty → all storage no-ops
}
```

**Desktop default for reference** — `src/engine/file_system_desktop.odin`:
implements `os_read_entire_file/os_write_entire_file/os_exists/os_remove/os_rename`
as `@(private="file")` procs wired into the struct. Match this shape for the web
backend (file-private hook procs + a constructor).

**Where the config wires storage**: services build storage from
`eng.engine_file_system(engine)` (`src/game_services.odin:44,47`), which returns
`engine.file_system` (set from `config.file_system` at engine init,
`src/engine/engine.odin:213`). So setting `config.file_system` in
`game_engine_config` for the web build is the single wiring point.

**Conventions:**

- Platform-split files use `#+build js` / `#+build !js` at the top (see
  `file_system_web.odin` vs `file_system_desktop.odin`, `logger_web.odin`,
  `main_web_stub.odin`). The engine layer stays raylib-free; the web FS backend
  lives in the **game** `io` layer (`package gameio`) like the other karl2d
  web glue, OR in `package engine` next to the web default — prefer `gameio`
  (`src/io/`) so the engine stays backend-agnostic and the game injects it, which
  is exactly the documented contract in `file_system_web.odin`'s comment.
- WASM/JS interop in Odin uses `foreign import` of JS shims. Check how karl2d /
  existing web glue does interop (`grep -rn "foreign import" src/`) and reuse
  that mechanism. localStorage is reachable via a small JS shim or via an
  existing karl2d/emscripten-free helper — confirm what this project already has
  before inventing a new interop path.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Type-check (desktop) | `just check` | exit 0 |
| Full gate (desktop) | `just verify` | `✓ tests + flag matrix + check + build passed` |
| Web build | `just release-web` (→ `bash scripts/build_karl2d_web.sh`) | builds `build/web` |
| Serve + manual test | `just run-web` then open `http://localhost:8080` | game loads |
| Format | `just fmt` | exit 0 |
| Find interop pattern | `grep -rn "foreign import\|#+build js" src/` | shows existing JS glue |

## Suggested executor toolkit

- Read `CLAUDE.md` → "Web / WASM Build" and `scripts/build_karl2d_web.sh` before
  starting; the web toolchain has prerequisites (STB libs, `../karl2d` sibling
  checkout) and is karl2d-native (no Emscripten).
- `graphify query "how does the web build inject backends"` to find the JS glue
  fast.

## Scope

**In scope:**

- New file `src/io/file_system_web_storage.odin` (`#+build js`, `package gameio`)
  — a `localStorage`-backed `Engine_File_System` constructor
  (`web_storage_file_system :: proc() -> eng.Engine_File_System`) implementing
  read/write/exists/remove (leave `rename = nil`). localStorage stores strings;
  encode bytes as base64 (or hex) under a key derived from `path`.
- Any small JS shim file the build needs for localStorage get/set/remove/has, in
  the location the web build already loads shims from (discover via
  `scripts/build_karl2d_web.sh`).
- `src/game_app_config.odin` — in `game_engine_config`, set
  `when ODIN_OS == .JS { config.file_system = gameio.web_storage_file_system() }`
  (or the project's existing web-detection `when`; match how other `#+build js`
  splits are gated here — there may be a dedicated web config path instead).
- Optional UX: if implementing persistence is deemed too heavy in this pass, the
  fallback deliverable is to surface "saving unavailable on web" and gate the
  Continue/Save UI off on web — but the **primary goal is real persistence**.

**Out of scope (do NOT touch):**

- Desktop FS (`file_system_desktop.odin`) — already correct.
- The save format / CRC / migration — unrelated.
- The atomic `rename` path — web correctly leaves `rename = nil` and uses direct
  write; do not implement rename on web.
- The autosave cadence — out of scope here (a separate finding: autosave runs
  every `engine_step`); just make it persist when it does fire.

## Git workflow

- Branch: `advisor/004-web-save-backend`.
- Conventional Commits; suggested: `feat(io): localStorage save backend for the web build`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Find the existing JS interop mechanism

`grep -rn "foreign import\|#+build js" src/` and read `scripts/build_karl2d_web.sh`
to learn how this project calls JS from Odin/WASM and where shim `.js` files are
loaded. Do not invent a new interop path if one exists.

**Verify**: you can name the existing interop mechanism and the shim load point.
If there is **no** existing JS-interop path and adding one is non-trivial, STOP
and report — propose the "fail loudly + gate Save UI off" fallback instead.

### Step 2: Implement the localStorage backend

Create `src/io/file_system_web_storage.odin` (`#+build js`, `package gameio`):

- file-private hook procs `web_read_entire_file`, `web_write_entire_file`,
  `web_exists`, `web_remove` calling the JS shim (`localStorage` get/set/has/
  remove), with a `path → key` mapping (e.g. prefix `itd:` + path).
- bytes ↔ string via base64 (localStorage is UTF-16 string storage; do not store
  raw bytes).
- `web_storage_file_system :: proc() -> eng.Engine_File_System` returning the
  struct with `rename = nil`.

**Verify**: `just release-web` builds without error
(`grep`-confirm the file compiles under `#+build js`). `just check` (desktop)
still exits 0 (the new file is js-only, must not affect desktop).

### Step 3: Wire it into the web config

In `src/game_app_config.odin` `game_engine_config`, set `config.file_system` to
`gameio.web_storage_file_system()` under the project's web `when` guard. Keep
desktop unchanged (desktop uses the engine default).

**Verify**: `just check` (desktop) exits 0; `just release-web` builds.

### Step 4: Manual web smoke test

`just run-web`, open the served page. Start a run, trigger a save (or autosave),
reload the page, and confirm Continue restores the run. Open browser devtools →
Application → Local Storage and confirm a key under the chosen prefix exists.
Confirm the high-score overlay persists a score across reloads.

**Verify**: save persists across a page reload; localStorage key present; no
console errors about nil FS hooks.

### Step 5: Format + desktop gate

`just fmt`; `just verify` (desktop) to confirm nothing regressed on the primary
platform.

**Verify**: `✓ tests + flag matrix + check + build passed`.

## Test plan

- The localStorage backend itself is JS-only and cannot run in the headless Odin
  test runner. Add a **platform-agnostic** unit test for the byte↔string
  (base64) codec if you factor it into a `#+build !js`-testable helper:
  `web_storage_base64_round_trips_arbitrary_bytes` in `test/io/`.
- Primary verification is the **manual web smoke test** (Step 4) — document the
  exact steps performed and the result in the PR / status note, since CI cannot
  run it.
- Desktop regression: `just verify` must stay green (the js-only file must not
  touch desktop builds).

## Done criteria

ALL must hold:

- [ ] `src/io/file_system_web_storage.odin` exists (`#+build js`) implementing
      read/write/exists/remove, `rename = nil`
- [ ] `game_engine_config` sets `config.file_system` on the web build
- [ ] `just release-web` builds with no error
- [ ] Manual web smoke: a save persists across a page reload (documented)
- [ ] `just verify` (desktop) → `✓ tests + flag matrix + check + build passed`
- [ ] Desktop save behavior unchanged (js-only file does not affect `#+build !js`)
- [ ] If a base64 helper was factored out, its round-trip test passes
- [ ] `git status` shows only in-scope files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- There is no existing JS-interop path and adding one is non-trivial — propose the
  "fail loudly + gate Save UI off on web" fallback rather than building a new
  interop layer blind.
- The web build toolchain prerequisites are missing (`../karl2d` sibling absent,
  STB libs not built) and cannot be satisfied — you cannot verify Step 2/4.
- Setting `config.file_system` on web breaks the desktop `just check`/`just verify`
  (the `when` guard is wrong — it must be js-only).
- localStorage quota (~5 MB) cannot hold the save: the desktop save measured
  ~3.9 MB; base64 inflates it ~33% to ~5.2 MB, which **exceeds** the typical
  localStorage quota. If so, STOP and report — this likely needs IndexedDB
  instead of localStorage, or it must wait for the save-size reduction in the
  deferred "present-floors-only" / data-diet work (Plan 002 + follow-ups).

## Maintenance notes

- **Save size vs localStorage quota is the real risk.** A ~3.9 MB save base64-
  encodes to ~5.2 MB, over the ~5 MB localStorage limit. Strongly consider
  sequencing this *after* the save-size reductions (Plan 002 data diet + the
  deferred present-floors-only / compression follow-ups), or use IndexedDB
  (larger quota, async) from the start. Flag this trade-off to the operator.
- If IndexedDB is chosen, note it is asynchronous; the engine's storage API is
  synchronous (`read_entire_file` returns immediately). Reconcile this (e.g. a
  synchronous localStorage shim mirroring an async IndexedDB store, or an
  in-memory cache hydrated at load) before committing to IndexedDB.
- A reviewer should confirm the js-only file truly never compiles into desktop
  and that `config.file_system` is gated correctly.
