package main

import "core:os"
import "core:strings"
import "core:testing"
import eng "./engine"

@(test)
render_handlers_accept_engine_context_for_services :: proc(t: ^testing.T) {
	top_level_render: proc(engine: ^eng.Engine, game: ^Game) = render_game
	title_render: proc(engine: ^eng.Engine, game: ^Game) = render_title_screen
	map_render: proc(engine: ^eng.Engine, game: ^Game) = render_map
	webs_render: proc(engine: ^eng.Engine, game: ^Game) = render_webs
	player_render: proc(engine: ^eng.Engine, game: ^Game) = render_player
	enemies_render: proc(engine: ^eng.Engine, game: ^Game) = render_enemies
	items_render: proc(engine: ^eng.Engine, game: ^Game) = render_items
	minimap_render: proc(engine: ^eng.Engine, game: ^Game) = render_minimap
	inventory_render: proc(engine: ^eng.Engine, game: ^Game) = render_inventory
	crafting_render: proc(engine: ^eng.Engine, game: ^Game) = render_crafting
	tooltip_render: proc(engine: ^eng.Engine, game: ^Game) = render_tooltip
	help_render: proc(engine: ^eng.Engine, game: ^Game) = render_help
	messages_render: proc(engine: ^eng.Engine) = render_messages_for_engine

	testing.expect(t, top_level_render != nil)
	testing.expect(t, title_render != nil)
	testing.expect(t, map_render != nil)
	testing.expect(t, webs_render != nil)
	testing.expect(t, player_render != nil)
	testing.expect(t, enemies_render != nil)
	testing.expect(t, items_render != nil)
	testing.expect(t, minimap_render != nil)
	testing.expect(t, inventory_render != nil)
	testing.expect(t, crafting_render != nil)
	testing.expect(t, tooltip_render != nil)
	testing.expect(t, help_render != nil)
	testing.expect(t, messages_render != nil)
}

@(test)
render_entry_uses_engine_render_backend_for_frame_operations :: proc(t: ^testing.T) {
	source, read_err := os.read_entire_file("src/render.odin", context.allocator)
	testing.expect(t, read_err == nil)
	if read_err != nil {
		return
	}
	defer delete(source, context.allocator)
	text := string(source)

	testing.expect(t, !strings.contains(text, "rl.BeginDrawing"))
	testing.expect(t, !strings.contains(text, "rl.EndDrawing"))
	testing.expect(t, !strings.contains(text, "rl.ClearBackground"))
	testing.expect(t, !strings.contains(text, "rl.BeginScissorMode"))
	testing.expect(t, !strings.contains(text, "rl.EndScissorMode"))
}

@(test)
message_and_particle_rendering_use_engine_render_backend :: proc(t: ^testing.T) {
	message_source, message_read_err := os.read_entire_file("src/messages.odin", context.allocator)
	testing.expect(t, message_read_err == nil)
	if message_read_err != nil {
		return
	}
	defer delete(message_source, context.allocator)

	particle_source, particle_read_err := os.read_entire_file("src/particles.odin", context.allocator)
	testing.expect(t, particle_read_err == nil)
	if particle_read_err != nil {
		return
	}
	defer delete(particle_source, context.allocator)

	message_text := string(message_source)
	particle_text := string(particle_source)
	testing.expect(t, !strings.contains(message_text, "rl.DrawRectangle"))
	testing.expect(t, !strings.contains(message_text, "rl.DrawText"))
	testing.expect(t, !strings.contains(particle_text, "rl.DrawRectangle"))
}

@(test)
hud_rendering_uses_engine_render_backend_primitives :: proc(t: ^testing.T) {
	source, read_err := os.read_entire_file("src/render_hud.odin", context.allocator)
	testing.expect(t, read_err == nil)
	if read_err != nil {
		return
	}
	defer delete(source, context.allocator)
	text := string(source)

	testing.expect(t, !strings.contains(text, "rl.DrawRectangle"))
	testing.expect(t, !strings.contains(text, "rl.DrawText"))
	testing.expect(t, !strings.contains(text, "rl.MeasureText"))
}

@(test)
minimap_and_item_rendering_use_engine_render_backend_primitives :: proc(t: ^testing.T) {
	minimap_source, minimap_read_err := os.read_entire_file("src/render_minimap.odin", context.allocator)
	testing.expect(t, minimap_read_err == nil)
	if minimap_read_err != nil {
		return
	}
	defer delete(minimap_source, context.allocator)

	items_source, items_read_err := os.read_entire_file("src/items.odin", context.allocator)
	testing.expect(t, items_read_err == nil)
	if items_read_err != nil {
		return
	}
	defer delete(items_source, context.allocator)

	minimap_text := string(minimap_source)
	items_text := string(items_source)
	testing.expect(t, !strings.contains(minimap_text, "rl.DrawRectangle"))
	testing.expect(t, !strings.contains(items_text, "rl.DrawText"))
}

@(test)
map_rendering_uses_engine_render_and_input_backends :: proc(t: ^testing.T) {
	source, read_err := os.read_entire_file("src/render_map.odin", context.allocator)
	testing.expect(t, read_err == nil)
	if read_err != nil {
		return
	}
	defer delete(source, context.allocator)
	text := string(source)

	testing.expect(t, !strings.contains(text, "rl.DrawRectangle"))
	testing.expect(t, !strings.contains(text, "rl.DrawText"))
	testing.expect(t, !strings.contains(text, "rl.MeasureText"))
	testing.expect(t, !strings.contains(text, "rl.GetMousePosition"))
}

@(test)
ui_rendering_uses_engine_render_backend_primitives :: proc(t: ^testing.T) {
	source, read_err := os.read_entire_file("src/render_ui.odin", context.allocator)
	testing.expect(t, read_err == nil)
	if read_err != nil {
		return
	}
	defer delete(source, context.allocator)
	text := string(source)

	testing.expect(t, !strings.contains(text, "rl.DrawRectangle"))
	testing.expect(t, !strings.contains(text, "rl.DrawRectangleLines"))
	testing.expect(t, !strings.contains(text, "rl.DrawText"))
	testing.expect(t, !strings.contains(text, "rl.MeasureText"))
}

@(test)
sprite_rendering_uses_engine_render_backend_for_texture_regions :: proc(t: ^testing.T) {
	manager_source, manager_read_err := os.read_entire_file("src/sprite_manager.odin", context.allocator)
	testing.expect(t, manager_read_err == nil)
	if manager_read_err != nil {
		return
	}
	defer delete(manager_source, context.allocator)

	sprites_source, sprites_read_err := os.read_entire_file("src/sprites.odin", context.allocator)
	testing.expect(t, sprites_read_err == nil)
	if sprites_read_err != nil {
		return
	}
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
