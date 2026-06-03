# SPIKE: karl2d as an engine backend

Proof that the engine's four swappable backend tables can be satisfied by
[karl2d](https://github.com/karl-zylinski/karl2d) instead of Raylib, **without
touching the engine package or any game logic**. This directory is excluded from
`odin build src/` / `just verify`, so it cannot break the shipped desktop build.

## Status: ✅ type-checks clean

```bash
# from repo root
odin check spike/karl2d_backend -no-entry-point
```

One-time prerequisite (karl2d pulls in vendor:stb for fonts + vorbis audio):

```bash
make -C "$(dirname "$(dirname "$(which odin)")")/libexec/vendor/stb/src"
# (or whatever your Odin install's vendor/stb/src path is)
```

## What it implements

`karl2d_backend.odin` provides four constructors returning engine backend tables:

| Constructor | Satisfies | karl2d procs used |
|---|---|---|
| `karl2d_platform_backend()` | `eng.Engine_Platform_Backend` | `init`, `shutdown`, `close_window_requested` |
| `karl2d_render_backend()` | `eng.Engine_Render_Backend` | `clear`, `present`, `draw_rect`, `draw_rect_outline`, `draw_text`, `measure_text`, `draw_texture_fit`, `set_scissor_rect`, frame procs |
| `karl2d_input_backend()` | `eng.Engine_Input_Backend` | `key_is_held`, `key_went_down`, `key_went_up`, `get_frame_time`, `get_mouse_position` |
| `karl2d_texture_backend()` | `eng.Engine_Texture_Backend` | `load_texture_from_file`, `destroy_texture` |

Every `Engine_Key` maps to a karl2d `Keyboard_Key`. `Engine_Color{r,g,b,a}` ↔
`k2.Color [4]u8` is a trivial reorder.

## Wiring it into the game (when promoting beyond spike)

The single injection point is `game_engine_config()` in `src/game_app.odin`.
Today it sets only `config.audio`. To run on karl2d you also set:

```odin
game_engine_config :: proc() -> eng.Engine_Config {
    config := eng.engine_config_make(SCREEN_WIDTH, SCREEN_HEIGHT, "Into the Depths", 60)
    config.audio    = game_audio_backend(&g_audio)
    config.platform = karl2d_platform_backend()   // was Raylib default
    config.render   = karl2d_render_backend()
    config.input    = karl2d_input_backend()
    config.texture  = karl2d_texture_backend()
    return config
}
```

Because the engine falls back to its Raylib defaults when a table is the zero
value (`*_backend_or_default`), you can gate this with `when ODIN_OS == .JS` to
ship **karl2d on web, Raylib on desktop** from one codebase.

## Known seams (what a real port must still solve)

1. **Audio is NOT covered here.** `audio.odin` / `music.odin` call Raylib audio
   directly. karl2d has a software mixer that covers one-shot SFX, but its
   streaming model has no `UpdateMusicStream` 1:1 equivalent — music needs a
   design pass (decode-to-buffer or chunked feed). This is the only genuinely
   new work in the migration.

2. **Frame loop ordering.** Raylib splits `BeginDrawing`/`EndDrawing`; karl2d's
   `update()` bundles `process_events` + `calculate_frame_time` +
   `reset_frame_allocator`. The spike runs those granular procs in
   `begin_frame`. Validate the call order against `engine_run`'s loop —
   `window_should_close()` (→ `close_window_requested`) must run *after*
   `process_events` for the close signal to be fresh.

3. **Rotation units.** Raylib `DrawTexturePro` takes degrees; karl2d takes
   radians. The spike passes the value through unchanged (1:1, obvious). A real
   port converts in `draw_texture_region`.

4. **Web asset loading.** On web, karl2d cannot read files from disk
   (`file_system_web.odin` is a stub). `data/*.json5` and spritesheets must be
   embedded via `#load` / `load_texture_from_bytes`. This affects the texture
   backend (swap `load_texture_from_file` → bytes loader) **and** the game's
   `storage_manager_read` data-loading path.

5. **Beta + no unit tests + single maintainer.** karl2d is Beta 3; API churns
   toward 1.0 (Metal + cross-API shader compiler still ahead). Recommend
   pinning a commit and keeping Raylib as the desktop default until 1.0.

## Recommendation

Adopt karl2d **for the web target first**, behind `when ODIN_OS == .JS`, keeping
Raylib as the desktop default. This deletes the in-flight emscripten toolchain
(`scripts/build_web.sh`) and its CI fragility, while the spike proves the
render/input/texture/platform seam already fits. Tackle audio streaming as the
one separate work item.
