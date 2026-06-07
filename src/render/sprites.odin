package renderer

import gameio "../io"

import gcore "../core"

import eng "../engine"
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
	npcs:        map[string]Sprite_Pos,
}

sprite_data_destroy :: proc(data: ^Sprite_Data, delete_strings := true) {
	if data == nil {return}
	if delete_strings {
		delete(data.tileset)
		for id in data.tiles {delete(id)}
		for id in data.characters {delete(id)}
		for id in data.items {delete(id)}
		for id in data.npcs {delete(id)}
	}
	delete(data.tiles)
	delete(data.characters)
	delete(data.items)
	delete(data.npcs)
	data^ = {}
}

// ─── Global sprite atlas ──────────────────────────────────────────────────────

Sprite_Atlas :: struct {
	texture:        eng.Engine_Texture,
	texture_handle: eng.Engine_Texture_Handle,
	tile_size:      int, // source sprite size from data
	tile_map:       map[string]Sprite, // "wall", "floor", etc.
	char_map:       map[string]Sprite, // "player", "rat", etc.
	item_map:       map[string]Sprite, // "health_potion", etc.
	npc_map:        map[string]Sprite, // "shopkeeper", "guard", etc.
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
	if g_sprites.loaded {
		sprites_cleanup(engine)
	}

	// Compile-time embedded sprite data — no runtime file I/O.
	// json.unmarshal still allocates strings/maps; ownership is moved into g_sprites.
	EMBEDDED_SPRITES :: #load("../../data/sprites.json5")

	sprite_data: Sprite_Data
	parse_err := json.unmarshal(EMBEDDED_SPRITES, &sprite_data, spec = .JSON5)
	if parse_err != nil {
		gameio.logger_errorf(.Sprites, "parse failed for data/sprites.json5: %v", parse_err)
		sprite_data_destroy(&sprite_data)
		return
	}


	// Load the tileset texture
	tileset_path := sprite_data.tileset
	if tileset_path == "" {tileset_path = "assets/kenney_1bit.png"}

	g_sprites.texture_handle = eng.engine_texture_manager_load(engine, tileset_path)
	g_sprites.texture = eng.engine_texture_manager_get(engine, g_sprites.texture_handle)
	if !eng.engine_texture_is_valid(g_sprites.texture) {
		gameio.logger_errorf(.Sprites, "failed to load texture '%s'", tileset_path)
		sprite_data_destroy(&sprite_data)
		return
	}

	size := sprite_data.sprite_size
	if size <= 0 {size = gcore.SPRITE_SIZE}
	g_sprites.tile_size = size
	g_sprites.tile_map = make(map[string]Sprite)
	g_sprites.char_map = make(map[string]Sprite)
	g_sprites.item_map = make(map[string]Sprite)
	g_sprites.npc_map = make(map[string]Sprite)
	g_sprites.owned_strings = make([dynamic]string)
	if sprite_data.tileset != "" {
		append(&g_sprites.owned_strings, sprite_data.tileset)
	}

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

	// Build NPC sprite map
	for id, pos in sprite_data.npcs {
		append(&g_sprites.owned_strings, id)
		(&g_sprites.npc_map)[id] = sprite_at(pos.col, pos.row, size)
	}

	g_sprites.loaded = true

	tile_count := len(sprite_data.tiles)
	char_count := len(sprite_data.characters)
	item_count := len(sprite_data.items)
	npc_count := len(sprite_data.npcs)
	sprite_data_destroy(&sprite_data, delete_strings = false)
	gameio.logger_debugf(
		.Sprites,
		"loaded '%s' (%dx%d) - %d tiles, %d chars, %d items, %d npcs",
		tileset_path,
		g_sprites.texture.width,
		g_sprites.texture.height,
		tile_count,
		char_count,
		item_count,
		npc_count,
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
	delete(g_sprites.npc_map)
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
	dest_size: i32 = gcore.TILE_SIZE,
) {
	if !g_sprites.loaded {return}
	size := max(dest_size, 1)
	dest := eng.Engine_Rect {
		x      = f32(x),
		y      = f32(y),
		width  = f32(size),
		height = f32(size),
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
	return sprite_at(0, 0, g_sprites.tile_size if g_sprites.tile_size > 0 else gcore.SPRITE_SIZE)
}

// Canonical tile-type → sprite-key mapping shared by all lookup paths.
tile_type_to_sprite_key :: proc(tile_type: gcore.Tile_Type) -> string {
	#partial switch tile_type {
	case .Wall:
		return "wall"
	case .Floor:
		return "floor"
	case .Rubble:
		return "rubble"
	case .Descent:
		return "descent"
	case .Ascent:
		return "ascent"
	case .Water:
		return "water"
	case .Gas_Vent:
		return "gas_vent"
	case .Fire_Vent:
		return "gas_vent"
	case .Unstable:
		return "unstable"
	case .Chasm:
		return "chasm"
	case .Anvil:
		return "anvil"
	case .Fountain:
		return "water"
	case .Locked_Door:
		return "locked_door"
	case .Shrine:
		return "shrine"
	case .Chest:
		return "chest"
	case .Merchant:
		return "merchant"
	case:
		return "floor"
	}
}

get_tile_sprite :: proc(tile_type: gcore.Tile_Type) -> Sprite {
	key := tile_type_to_sprite_key(tile_type)
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

npc_role_to_sprite_key :: proc(role: gcore.NPC_Role) -> string {
	#partial switch role {
	case .Shopkeeper:
		return "shopkeeper"
	case .Guard:
		return "guard"
	case .Elder:
		return "elder"
	case .Old_Miner:
		return "old_miner"
	}
	return "old_miner"
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
	} else if category == "npc" {
		spr, ok := g_sprites.npc_map[name]
		if ok {return spr}
	}
	return fallback_sprite()
}
