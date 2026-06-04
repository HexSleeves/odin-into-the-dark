package main

import eng "./engine"

// ─── Sprite manager facade ───────────────────────────────────────────────────

Sprite_Manager :: struct {
	backend: ^Sprite_Atlas,
}

sprite_manager_make :: proc() -> Sprite_Manager {
	return Sprite_Manager{backend = &g_sprites}
}

sprite_manager_is_loaded :: proc(sprites: ^Sprite_Manager) -> bool {
	if sprites == nil || sprites.backend == nil {
		return g_sprites.loaded
	}
	return sprites.backend.loaded
}

sprite_manager_draw :: proc(
	engine: ^eng.Engine,
	sprites: ^Sprite_Manager,
	spr: Sprite,
	x, y: i32,
	tint: eng.Engine_Color = eng.Engine_Color{255, 255, 255, 255},
	dest_size: i32 = TILE_SIZE,
) {
	if sprites == nil || sprites.backend == nil || sprites.backend == &g_sprites {
		draw_sprite(engine, spr, x, y, tint, dest_size)
		return
	}
	if !sprites.backend.loaded {
		return
	}
	size := max(dest_size, 1)
	dest := eng.Engine_Rect {
		x      = f32(x),
		y      = f32(y),
		width  = f32(size),
		height = f32(size),
	}
	eng.engine_render_draw_texture_region(
		engine,
		sprites.backend.texture,
		spr.src,
		dest,
		eng.Engine_Vec2{0, 0},
		0,
		tint,
	)
}

sprite_manager_tile :: proc(sprites: ^Sprite_Manager, tile_type: Tile_Type) -> Sprite {
	if sprites == nil || sprites.backend == nil || sprites.backend == &g_sprites {
		return get_tile_sprite(tile_type)
	}
	key: string
	#partial switch tile_type {
	case .Wall:
		key = "wall"
	case .Floor:
		key = "floor"
	case .Rubble:
		key = "rubble"
	case .Descent:
		key = "descent"
	case .Water:
		key = "water"
	case .Gas_Vent:
		key = "gas_vent"
	case .Unstable:
		key = "unstable"
	case .Chasm:
		key = "chasm"
	case .Anvil:
		key = "anvil"
	case .Fountain:
		key = "water"
	case:
		key = "floor"
	}
	spr, ok := sprites.backend.tile_map[key]
	if ok {return spr}
	return sprite_manager_fallback(sprites)
}

sprite_manager_enemy :: proc(sprites: ^Sprite_Manager, enemy_type: string) -> Sprite {
	if sprites == nil || sprites.backend == nil || sprites.backend == &g_sprites {
		return get_enemy_sprite(enemy_type)
	}
	spr, ok := sprites.backend.char_map[enemy_type]
	if ok {return spr}
	return sprite_manager_fallback(sprites)
}

sprite_manager_item :: proc(sprites: ^Sprite_Manager, item_type: string) -> Sprite {
	if sprites == nil || sprites.backend == nil || sprites.backend == &g_sprites {
		return get_item_sprite(item_type)
	}
	spr, ok := sprites.backend.item_map[item_type]
	if ok {return spr}
	return sprite_manager_fallback(sprites)
}

sprite_manager_named :: proc(sprites: ^Sprite_Manager, category: string, name: string) -> Sprite {
	if sprites == nil || sprites.backend == nil || sprites.backend == &g_sprites {
		return get_named_sprite(category, name)
	}
	if category == "tile" {
		spr, ok := sprites.backend.tile_map[name]
		if ok {return spr}
	} else if category == "character" {
		spr, ok := sprites.backend.char_map[name]
		if ok {return spr}
	} else if category == "item" {
		spr, ok := sprites.backend.item_map[name]
		if ok {return spr}
	}
	return sprite_manager_fallback(sprites)
}

sprite_manager_fallback :: proc(sprites: ^Sprite_Manager) -> Sprite {
	if sprites == nil || sprites.backend == nil || sprites.backend == &g_sprites {
		return get_named_sprite("tile", "floor")
	}
	size := sprites.backend.tile_size if sprites.backend.tile_size > 0 else SPRITE_SIZE
	return sprite_at(0, 0, size)
}
