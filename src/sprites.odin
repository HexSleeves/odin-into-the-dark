package main

import eng "./engine"
import "core:encoding/json"

// ─── Sprite types ─────────────────────────────────────────────────────────────

Sprite :: struct {
	src: eng.Engine_Rect,
}

// ─── JSON5 data structures for sprite mappings ────────────────────────────────

Sprite_Pos :: struct {
	col: int,
	row: int,
}

Sprite_Data :: struct {
	tileset:     string,
	sprite_size: int,
	tiles:       map[string]Sprite_Pos,
	characters:  map[string]Sprite_Pos,
	items:       map[string]Sprite_Pos,
}

// ─── Global sprite atlas ──────────────────────────────────────────────────────

Sprite_Atlas :: struct {
	texture:        eng.Engine_Texture,
	texture_handle: eng.Engine_Texture_Handle,
	tile_size:      int, // source sprite size from data
	tile_map:       map[string]Sprite, // "wall", "floor", etc.
	char_map:       map[string]Sprite, // "player", "rat", etc.
	item_map:       map[string]Sprite, // "health_potion", etc.
	owned_strings:  [dynamic]string,
	loaded:         bool,
}

g_sprites: Sprite_Atlas

// ─── Helpers ──────────────────────────────────────────────────────────────────

sprite_at :: proc(col, row, size: int) -> Sprite {
	return Sprite {
		src = eng.Engine_Rect {
			x = f32(col * size),
			y = f32(row * size),
			width = f32(size),
			height = f32(size),
		},
	}
}

// ─── Init / Cleanup ───────────────────────────────────────────────────────────

sprites_init :: proc(engine: ^eng.Engine) {
	// Compile-time embedded sprite data — no runtime file I/O
	EMBEDDED_SPRITES :: #load("../data/sprites.json5")

	sprite_data: Sprite_Data
	parse_err := json.unmarshal(EMBEDDED_SPRITES, &sprite_data, spec = .JSON5)
	if parse_err != nil {
		logger_errorf(.Sprites, "parse failed for data/sprites.json5: %v", parse_err)
		return
	}

	if sprite_data.tileset != "" {
		defer delete(sprite_data.tileset)
	}
	defer delete(sprite_data.tiles)
	defer delete(sprite_data.characters)
	defer delete(sprite_data.items)

	// Load the tileset texture
	tileset_path := sprite_data.tileset
	if tileset_path == "" {tileset_path = "assets/kenney_1bit.png"}

	g_sprites.texture_handle = eng.engine_texture_manager_load(engine, tileset_path)
	g_sprites.texture = eng.engine_texture_manager_get(engine, g_sprites.texture_handle)
	if !eng.engine_texture_is_valid(g_sprites.texture) {
		logger_errorf(.Sprites, "failed to load texture '%s'", tileset_path)
		return
	}

	size := sprite_data.sprite_size
	if size <= 0 {size = SPRITE_SIZE}
	g_sprites.tile_size = size
	g_sprites.tile_map = make(map[string]Sprite)
	g_sprites.char_map = make(map[string]Sprite)
	g_sprites.item_map = make(map[string]Sprite)
	g_sprites.owned_strings = make([dynamic]string)

	// Build tile sprite map
	for id, pos in sprite_data.tiles {
		append(&g_sprites.owned_strings, id)
		(&g_sprites.tile_map)[id] = sprite_at(pos.col, pos.row, size)
	}

	// Build character sprite map
	for id, pos in sprite_data.characters {
		append(&g_sprites.owned_strings, id)
		(&g_sprites.char_map)[id] = sprite_at(pos.col, pos.row, size)
	}

	// Build item sprite map
	for id, pos in sprite_data.items {
		append(&g_sprites.owned_strings, id)
		(&g_sprites.item_map)[id] = sprite_at(pos.col, pos.row, size)
	}

	g_sprites.loaded = true

	tile_count := len(sprite_data.tiles)
	char_count := len(sprite_data.characters)
	item_count := len(sprite_data.items)
	logger_debugf(
		.Sprites,
		"loaded '%s' (%dx%d) - %d tiles, %d chars, %d items",
		tileset_path,
		g_sprites.texture.width,
		g_sprites.texture.height,
		tile_count,
		char_count,
		item_count,
	)
}

sprites_cleanup :: proc(engine: ^eng.Engine) {
	if !g_sprites.loaded {return}
	if eng.texture_handle_is_valid(g_sprites.texture_handle) {
		_ = eng.engine_texture_manager_unload(engine, g_sprites.texture_handle)
	} else {
		eng.engine_texture_unload(engine, &g_sprites.texture)
	}
	delete(g_sprites.tile_map)
	delete(g_sprites.char_map)
	delete(g_sprites.item_map)
	for owned in g_sprites.owned_strings {
		delete(owned)
	}
	delete(g_sprites.owned_strings)
	g_sprites.texture = eng.Engine_Texture{}
	g_sprites.texture_handle = eng.ENGINE_TEXTURE_HANDLE_NONE
	g_sprites.loaded = false
}

// ─── Drawing ──────────────────────────────────────────────────────────────────

draw_sprite :: proc(
	engine: ^eng.Engine,
	spr: Sprite,
	x, y: i32,
	tint: eng.Engine_Color = eng.Engine_Color{255, 255, 255, 255},
) {
	if !g_sprites.loaded {return}
	dest := eng.Engine_Rect {
		x      = f32(x),
		y      = f32(y),
		width  = f32(TILE_SIZE),
		height = f32(TILE_SIZE),
	}
	eng.engine_render_draw_texture_region(
		engine,
		g_sprites.texture,
		spr.src,
		dest,
		eng.Engine_Vec2{0, 0},
		0,
		tint,
	)
}

// ─── Lookup helpers ───────────────────────────────────────────────────────────

// Fallback sprite (first tile in the sheet)
@(private = "file")
fallback_sprite :: proc() -> Sprite {
	return sprite_at(0, 0, g_sprites.tile_size if g_sprites.tile_size > 0 else SPRITE_SIZE)
}

get_tile_sprite :: proc(tile_type: Tile_Type) -> Sprite {
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
	case .Fire_Vent:
		key = "gas_vent"
	case .Unstable:
		key = "unstable"
	case .Chasm:
		key = "chasm"
	case .Anvil:
		key = "anvil"
	case .Fountain:
		key = "water"
	case .Locked_Door:
		key = "anvil"
	case:
		key = "floor"
	}
	spr, ok := g_sprites.tile_map[key]
	if ok {return spr}
	return fallback_sprite()
}

get_enemy_sprite :: proc(enemy_type: string) -> Sprite {
	spr, ok := g_sprites.char_map[enemy_type]
	if ok {return spr}
	return fallback_sprite()
}

get_item_sprite :: proc(item_type: string) -> Sprite {
	spr, ok := g_sprites.item_map[item_type]
	if ok {return spr}
	return fallback_sprite()
}

// Special named sprites accessed directly
get_named_sprite :: proc(category: string, name: string) -> Sprite {
	if category == "tile" {
		spr, ok := g_sprites.tile_map[name]
		if ok {return spr}
	} else if category == "character" {
		spr, ok := g_sprites.char_map[name]
		if ok {return spr}
	} else if category == "item" {
		spr, ok := g_sprites.item_map[name]
		if ok {return spr}
	}
	return fallback_sprite()
}
