package engine

import "core:testing"

@(private = "file")
scene_manager_test_enter_count: int
@(private = "file")
scene_manager_test_exit_count: int
@(private = "file")
scene_manager_test_update_count: int
@(private = "file")
scene_manager_test_render_count: int
@(private = "file")
scene_manager_test_quit_on_update: bool
@(private = "file")
scene_manager_test_seen_target_fps: i32

@(private = "file")
scene_manager_test_reset :: proc() {
	scene_manager_test_enter_count = 0
	scene_manager_test_exit_count = 0
	scene_manager_test_update_count = 0
	scene_manager_test_render_count = 0
	scene_manager_test_quit_on_update = false
	scene_manager_test_seen_target_fps = 0
}

@(private = "file")
scene_manager_test_enter :: proc(engine: ^Engine, ctx: rawptr) {
	scene_manager_test_enter_count += 1
	scene_manager_test_seen_target_fps = engine.config.target_fps
}

@(private = "file")
scene_manager_test_exit :: proc(engine: ^Engine, ctx: rawptr) {
	scene_manager_test_exit_count += 1
	scene_manager_test_seen_target_fps = engine.config.target_fps
}

@(private = "file")
scene_manager_test_update :: proc(engine: ^Engine, ctx: rawptr) -> bool {
	scene_manager_test_update_count += 1
	scene_manager_test_seen_target_fps = engine.config.target_fps
	return scene_manager_test_quit_on_update
}

@(private = "file")
scene_manager_test_render :: proc(engine: ^Engine, ctx: rawptr) {
	scene_manager_test_render_count += 1
	scene_manager_test_seen_target_fps = engine.config.target_fps
}

@(private = "file")
scene_manager_test_engine :: proc() -> Engine {
	return Engine {
		config = engine_config_make(320, 200, "Scene Test", 17),
	}
}

@(test)
scene_manager_switches_active_scene_with_lifecycle_callbacks :: proc(t: ^testing.T) {
	scene_manager_test_reset()
	scenes := [?]Engine_Scene {
		Engine_Scene{id = 10, enter = scene_manager_test_enter, exit = scene_manager_test_exit},
		Engine_Scene{id = 20, enter = scene_manager_test_enter, exit = scene_manager_test_exit},
	}
	manager := scene_manager_make(scenes[:])
	engine := scene_manager_test_engine()

	testing.expect(t, !scene_manager_has_active(&manager))
	testing.expect(t, scene_manager_set_active(&manager, &engine, 10))
	testing.expect(t, scene_manager_has_active(&manager))
	testing.expect_value(t, scene_manager_active_id(&manager), 10)
	testing.expect_value(t, scene_manager_test_enter_count, 1)
	testing.expect_value(t, scene_manager_test_exit_count, 0)
	testing.expect_value(t, scene_manager_test_seen_target_fps, 17)

	testing.expect(t, scene_manager_set_active(&manager, &engine, 20))
	testing.expect_value(t, scene_manager_active_id(&manager), 20)
	testing.expect_value(t, scene_manager_test_enter_count, 2)
	testing.expect_value(t, scene_manager_test_exit_count, 1)
	testing.expect_value(t, scene_manager_test_seen_target_fps, 17)
}

@(test)
scene_manager_update_and_render_delegate_to_active_scene :: proc(t: ^testing.T) {
	scene_manager_test_reset()
	scenes := [?]Engine_Scene {
		Engine_Scene {
			id = 1,
			update = scene_manager_test_update,
			render = scene_manager_test_render,
		},
	}
	manager := scene_manager_make(scenes[:])
	engine := scene_manager_test_engine()
	testing.expect(t, scene_manager_set_active(&manager, &engine, 1))

	testing.expect(t, !scene_manager_update(&manager, &engine))
	scene_manager_render(&manager, &engine)
	testing.expect_value(t, scene_manager_test_update_count, 1)
	testing.expect_value(t, scene_manager_test_render_count, 1)
	testing.expect_value(t, scene_manager_test_seen_target_fps, 17)

	scene_manager_test_quit_on_update = true
	testing.expect(t, scene_manager_update(&manager, &engine))
	testing.expect_value(t, scene_manager_test_update_count, 2)
	testing.expect_value(t, scene_manager_test_seen_target_fps, 17)
}
