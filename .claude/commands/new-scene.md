# New Scene — Add a Game Scene

Add a new scene to the `Game_State` / `Game_Scene` system following the existing pattern.

$ARGUMENTS

## Architecture

Scenes map 1:1 to `Game_State` enum values. The `scene_for_state` proc in `src/scene.odin` maps each state to a `Game_Scene` with enter/update/render/exit callbacks. `engine.Scene_Manager` owns the lifecycle.

## Workflow

### 1. Add to `Game_State` enum — `src/types.odin`

```odin
Game_State :: enum {
    Title,
    Playing,
    // ... existing states ...
    My_New_Scene,   // <-- add here
}
```

### 2. Add to `Game_Scene` enum — `src/scene.odin`

```odin
Game_Scene :: enum {
    Title,
    Playing,
    // ... existing scenes ...
    My_New_Scene,   // <-- add here
}
```

### 3. Map state → scene — `src/scene.odin` in `scene_for_state`

```odin
scene_for_state :: proc(state: Game_State) -> Game_Scene {
    switch state {
    case .Title:       return .Title
    case .Playing:     return .Playing
    // ...
    case .My_New_Scene: return .My_New_Scene
    }
    return .Title
}
```

### 4. Register callbacks — `src/scene.odin` in `scene_register_all`

```odin
scene_register_all :: proc(sm: ^engine.Scene_Manager, game: ^Game) {
    // ... existing registrations ...
    engine.scene_manager_register(sm, int(Game_Scene.My_New_Scene), engine.Scene_Callbacks{
        enter  = my_new_scene_enter,
        update = my_new_scene_update,
        render = my_new_scene_render,
        exit   = my_new_scene_exit,
    })
}
```

### 5. Implement callbacks — `src/scene_my_new_scene.odin`

```odin
package main

my_new_scene_enter :: proc(ctx: rawptr) {
    game := cast(^Game)ctx
    // initialize scene-local state
}

my_new_scene_update :: proc(ctx: rawptr) {
    game := cast(^Game)ctx
    // per-frame update; call engine.scene_manager_transition to switch
}

my_new_scene_render :: proc(ctx: rawptr) {
    game := cast(^Game)ctx
    // render the scene
}

my_new_scene_exit :: proc(ctx: rawptr) {
    game := cast(^Game)ctx
    // clean up scene-local state
}
```

### 6. Transition to the scene

From anywhere in game code:

```odin
engine.scene_manager_transition(&engine.scenes, int(Game_Scene.My_New_Scene))
```

### 7. Write a smoke test — `src/scene_test.odin`

```odin
@(test)
my_new_scene_is_registered_for_its_state :: proc(t: ^testing.T) {
    testing.expect_value(
        t,
        scene_for_state(.My_New_Scene),
        Game_Scene.My_New_Scene,
    )
}
```

### 8. Verify

```bash
just verify
```

Check that the type-checker finds no unhandled enum cases (Odin warns on incomplete switches when `-vet` is active).
