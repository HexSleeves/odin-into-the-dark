#+build !js
package engine

import "core:testing"

Scene_Manager_Test_State :: struct {
	enter_count:     int,
	exit_count:      int,
	update_count:    int,
	render_count:    int,
	quit_on_update:  bool,
	seen_target_fps: i32,
}

@(private = "file")
scene_manager_test_enter :: proc(engine: ^Engine, ctx: rawptr) {
	state := cast(^Scene_Manager_Test_State)ctx
	state.enter_count += 1
	state.seen_target_fps = engine.config.target_fps
}

@(private = "file")
scene_manager_test_exit :: proc(engine: ^Engine, ctx: rawptr) {
	state := cast(^Scene_Manager_Test_State)ctx
	state.exit_count += 1
	state.seen_target_fps = engine.config.target_fps
}

@(private = "file")
scene_manager_test_update :: proc(engine: ^Engine, ctx: rawptr) -> bool {
	state := cast(^Scene_Manager_Test_State)ctx
	state.update_count += 1
	state.seen_target_fps = engine.config.target_fps
	return state.quit_on_update
}

@(private = "file")
scene_manager_test_render :: proc(engine: ^Engine, ctx: rawptr) {
	state := cast(^Scene_Manager_Test_State)ctx
	state.render_count += 1
	state.seen_target_fps = engine.config.target_fps
}

@(private = "file")
scene_manager_test_engine :: proc() -> Engine {
	return Engine{config = engine_config_make(320, 200, "Scene Test", 17)}
}

@(test)
scene_manager_switches_active_scene_with_lifecycle_callbacks :: proc(t: ^testing.T) {
	state := Scene_Manager_Test_State{}
	scenes := [?]Engine_Scene {
		Engine_Scene {
			id = 10,
			ctx = &state,
			enter = scene_manager_test_enter,
			exit = scene_manager_test_exit,
		},
		Engine_Scene {
			id = 20,
			ctx = &state,
			enter = scene_manager_test_enter,
			exit = scene_manager_test_exit,
		},
	}
	manager := scene_manager_make(scenes[:])
	engine := scene_manager_test_engine()

	testing.expect(t, !scene_manager_has_active(&manager))
	testing.expect(t, scene_manager_set_active(&manager, &engine, 10))
	testing.expect(t, scene_manager_has_active(&manager))
	testing.expect_value(t, scene_manager_active_id(&manager), 10)
	testing.expect_value(t, state.enter_count, 1)
	testing.expect_value(t, state.exit_count, 0)
	testing.expect_value(t, state.seen_target_fps, 17)

	testing.expect(t, scene_manager_set_active(&manager, &engine, 20))
	testing.expect_value(t, scene_manager_active_id(&manager), 20)
	testing.expect_value(t, state.enter_count, 2)
	testing.expect_value(t, state.exit_count, 1)
	testing.expect_value(t, state.seen_target_fps, 17)
}

@(test)
scene_manager_update_and_render_delegate_to_active_scene :: proc(t: ^testing.T) {
	state := Scene_Manager_Test_State{}
	scenes := [?]Engine_Scene {
		Engine_Scene {
			id = 1,
			ctx = &state,
			update = scene_manager_test_update,
			render = scene_manager_test_render,
		},
	}
	manager := scene_manager_make(scenes[:])
	engine := scene_manager_test_engine()
	testing.expect(t, scene_manager_set_active(&manager, &engine, 1))

	testing.expect(t, !scene_manager_update(&manager, &engine))
	scene_manager_render(&manager, &engine)
	testing.expect_value(t, state.update_count, 1)
	testing.expect_value(t, state.render_count, 1)
	testing.expect_value(t, state.seen_target_fps, 17)

	state.quit_on_update = true
	testing.expect(t, scene_manager_update(&manager, &engine))
	testing.expect_value(t, state.update_count, 2)
	testing.expect_value(t, state.seen_target_fps, 17)
}