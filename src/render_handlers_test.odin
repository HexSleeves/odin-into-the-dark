#+build !js
package main

import eng "./engine"
import "core:os"
import "core:strings"
import "core:testing"

@(test)
render_handlers_accept_engine_context_for_runtime_surfaces :: proc(t: ^testing.T) {
	top_level_render: proc(engine: ^eng.Engine, game: ^Game) = render_game
	map_render: proc(engine: ^eng.Engine, game: ^Game) = render_map
	webs_render: proc(engine: ^eng.Engine, game: ^Game) = render_webs
	player_render: proc(engine: ^eng.Engine, game: ^Game) = render_player
	enemies_render: proc(engine: ^eng.Engine, game: ^Game) = render_enemies
	items_render: proc(engine: ^eng.Engine, game: ^Game) = render_items
	clay_screen_render: proc(engine: ^eng.Engine, game: ^Game) = clay_render_screen_ui

	testing.expect(t, top_level_render != nil)
	testing.expect(t, map_render != nil)
	testing.expect(t, webs_render != nil)
	testing.expect(t, player_render != nil)
	testing.expect(t, enemies_render != nil)
	testing.expect(t, items_render != nil)
	testing.expect(t, clay_screen_render != nil)
}

@(test)
render_entry_uses_engine_render_backend_for_frame_operations :: proc(t: ^testing.T) {
	source, read_err := os.read_entire_file("src/render.odin", context.allocator)
	testing.expect(t, read_err == nil)
	if read_err != nil {return}
	defer delete(source, context.allocator)
	text := string(source)

	testing.expect(t, !strings.contains(text, "rl.BeginDrawing"))
	testing.expect(t, !strings.contains(text, "rl.EndDrawing"))
	testing.expect(t, !strings.contains(text, "rl.ClearBackground"))
	testing.expect(t, !strings.contains(text, "rl.BeginScissorMode"))
	testing.expect(t, !strings.contains(text, "rl.EndScissorMode"))
}

@(test)
clay_renderer_and_particles_use_engine_render_backend :: proc(t: ^testing.T) {
	clay_source, clay_read_err := os.read_entire_file("src/clay_renderer.odin", context.allocator)
	testing.expect(t, clay_read_err == nil)
	if clay_read_err != nil {return}
	defer delete(clay_source, context.allocator)

	particle_source, particle_read_err := os.read_entire_file(
		"src/particles.odin",
		context.allocator,
	)
	testing.expect(t, particle_read_err == nil)
	if particle_read_err != nil {return}
	defer delete(particle_source, context.allocator)

	clay_text := string(clay_source)
	particle_text := string(particle_source)
	testing.expect(t, !strings.contains(clay_text, "rl.DrawRectangle"))
	testing.expect(t, !strings.contains(clay_text, "rl.DrawText"))
	testing.expect(t, !strings.contains(particle_text, "rl.DrawRectangle"))
}

@(test)
map_world_layers_use_shared_shaken_screen_coordinates :: proc(t: ^testing.T) {
	map_source, map_read_err := os.read_entire_file("src/render_map.odin", context.allocator)
	testing.expect(t, map_read_err == nil)
	if map_read_err != nil {return}
	defer delete(map_source, context.allocator)
	items_source, items_read_err := os.read_entire_file("src/items.odin", context.allocator)
	testing.expect(t, items_read_err == nil)
	if items_read_err != nil {return}
	defer delete(items_source, context.allocator)

	map_text := string(map_source)
	items_text := string(items_source)
	testing.expect(t, strings.contains(map_text, "camera_world_x_to_screen_shaken"))
	testing.expect(t, strings.contains(map_text, "camera_world_y_to_screen_shaken"))
	testing.expect(
		t,
		!strings.contains(map_text, "sx := camera_world_x_to_screen(camera, x * TILE_SIZE)"),
	)
	testing.expect(
		t,
		!strings.contains(
			map_text,
			"px := camera_world_x_to_screen(camera, game.player.pos.x * TILE_SIZE)",
		),
	)
	testing.expect(
		t,
		!strings.contains(
			map_text,
			"ex := camera_world_x_to_screen(camera, enemy.pos.x * TILE_SIZE)",
		),
	)
	testing.expect(
		t,
		!strings.contains(
			items_text,
			"ix := camera_world_x_to_screen(camera, item.pos.x * TILE_SIZE)",
		),
	)
}

@(test)
world_and_item_rendering_use_engine_render_backend_primitives :: proc(t: ^testing.T) {
	map_source, map_read_err := os.read_entire_file("src/render_map.odin", context.allocator)
	testing.expect(t, map_read_err == nil)
	if map_read_err != nil {return}
	defer delete(map_source, context.allocator)

	items_source, items_read_err := os.read_entire_file("src/items.odin", context.allocator)
	testing.expect(t, items_read_err == nil)
	if items_read_err != nil {return}
	defer delete(items_source, context.allocator)

	map_text := string(map_source)
	items_text := string(items_source)
	testing.expect(t, !strings.contains(map_text, "rl.DrawRectangle"))
	testing.expect(t, !strings.contains(map_text, "rl.DrawText("))
	testing.expect(t, !strings.contains(map_text, "rl.MeasureText"))
	testing.expect(t, !strings.contains(map_text, "rl.GetMousePosition"))
	testing.expect(t, !strings.contains(items_text, "rl.DrawText"))
}

@(test)
sprite_rendering_uses_engine_render_backend_for_texture_regions :: proc(t: ^testing.T) {
	manager_source, manager_read_err := os.read_entire_file(
		"src/sprite_manager.odin",
		context.allocator,
	)
	testing.expect(t, manager_read_err == nil)
	if manager_read_err != nil {return}
	defer delete(manager_source, context.allocator)

	sprites_source, sprites_read_err := os.read_entire_file("src/sprites.odin", context.allocator)
	testing.expect(t, sprites_read_err == nil)
	if sprites_read_err != nil {return}
	defer delete(sprites_source, context.allocator)

	manager_text := string(manager_source)
	sprites_text := string(sprites_source)
	testing.expect(t, !strings.contains(manager_text, "rl.DrawTexturePro"))
	testing.expect(t, !strings.contains(sprites_text, "rl.DrawTexturePro"))
	testing.expect(t, !strings.contains(sprites_text, "rl.LoadTexture"))
	testing.expect(t, !strings.contains(sprites_text, "rl.UnloadTexture"))
	testing.expect(t, strings.contains(sprites_text, "engine_texture_manager_load"))
	testing.expect(t, strings.contains(sprites_text, "engine_texture_manager_unload"))
}
