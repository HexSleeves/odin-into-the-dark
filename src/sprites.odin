package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"

// ─── Sprite types ─────────────────────────────────────────────────────────────

Sprite :: struct {
	src: rl.Rectangle,
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
	texture:    rl.Texture2D,
	tile_size:  int, // source sprite size from data
	tile_map:   map[string]Sprite, // "wall", "floor", etc.
	char_map:   map[string]Sprite, // "player", "rat", etc.
	item_map:   map[string]Sprite, // "health_potion", etc.
	loaded:     bool,
}

g_sprites: Sprite_Atlas

// ─── Helpers ──────────────────────────────────────────────────────────────────

sprite_at :: proc(col, row, size: int) -> Sprite {
	return Sprite {
		src = rl.Rectangle {
			x      = f32(col * size),
			y      = f32(row * size),
			width  = f32(size),
			height = f32(size),
		},
	}
}

// ─── Init / Cleanup ───────────────────────────────────────────────────────────

sprites_init :: proc() {
	// Load sprite mapping data
	data, read_err := os.read_entire_file("data/sprites.json5", context.allocator)
	if read_err != nil {
		fmt.eprintln("[sprites] ERROR: could not read data/sprites.json5")
		return
	}
	defer delete(data, context.allocator)

	sprite_data: Sprite_Data
	parse_err := json.unmarshal(data, &sprite_data, spec = .JSON5)
	if parse_err != nil {
		fmt.eprintfln("[sprites] ERROR: parse failed for data/sprites.json5: %v", parse_err)
		return
	}

	// Load the tileset texture
	tileset_path := sprite_data.tileset
	if tileset_path == "" { tileset_path = "assets/kenney_1bit.png" }

	// Convert to cstring for Raylib
	path_buf: [256]u8
	copy_len := min(len(tileset_path), 255)
	for i in 0 ..< copy_len { path_buf[i] = tileset_path[i] }
	path_buf[copy_len] = 0
	path_cstr := cast(cstring)&path_buf[0]

	g_sprites.texture = rl.LoadTexture(path_cstr)
	if g_sprites.texture.id == 0 {
		fmt.eprintfln("[sprites] ERROR: failed to load texture '%s'", tileset_path)
		return
	}

	size := sprite_data.sprite_size
	if size <= 0 { size = SPRITE_SIZE }
	g_sprites.tile_size = size

	// Build tile sprite map
	for id, pos in sprite_data.tiles {
		(&g_sprites.tile_map)[id] = sprite_at(pos.col, pos.row, size)
	}

	// Build character sprite map
	for id, pos in sprite_data.characters {
		(&g_sprites.char_map)[id] = sprite_at(pos.col, pos.row, size)
	}

	// Build item sprite map
	for id, pos in sprite_data.items {
		(&g_sprites.item_map)[id] = sprite_at(pos.col, pos.row, size)
	}

	g_sprites.loaded = true

	tile_count := len(sprite_data.tiles)
	char_count := len(sprite_data.characters)
	item_count := len(sprite_data.items)
	fmt.printfln(
		"[sprites] loaded '%s' (%dx%d) — %d tiles, %d chars, %d items",
		tileset_path,
		g_sprites.texture.width, g_sprites.texture.height,
		tile_count, char_count, item_count,
	)
}

sprites_cleanup :: proc() {
	if !g_sprites.loaded { return }
	rl.UnloadTexture(g_sprites.texture)
	delete(g_sprites.tile_map)
	delete(g_sprites.char_map)
	delete(g_sprites.item_map)
}

// ─── Drawing ──────────────────────────────────────────────────────────────────

draw_sprite :: proc(spr: Sprite, x, y: i32, tint: rl.Color = rl.WHITE) {
	if !g_sprites.loaded { return }
	dest := rl.Rectangle {
		x      = f32(x),
		y      = f32(y),
		width  = f32(TILE_SIZE),
		height = f32(TILE_SIZE),
	}
	rl.DrawTexturePro(g_sprites.texture, spr.src, dest, {0, 0}, 0, tint)
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
	case .Wall:     key = "wall"
	case .Floor:    key = "floor"
	case .Rubble:   key = "rubble"
	case .Descent:  key = "descent"
	case .Water:    key = "water"
	case .Gas_Vent: key = "gas_vent"
	case .Unstable: key = "unstable"
	case .Chasm:    key = "chasm"
	case .Anvil:    key = "anvil"
	case:           key = "floor"
	}
	spr, ok := g_sprites.tile_map[key]
	if ok { return spr }
	return fallback_sprite()
}

get_enemy_sprite :: proc(enemy_type: string) -> Sprite {
	spr, ok := g_sprites.char_map[enemy_type]
	if ok { return spr }
	return fallback_sprite()
}

get_item_sprite :: proc(item_type: string) -> Sprite {
	spr, ok := g_sprites.item_map[item_type]
	if ok { return spr }
	return fallback_sprite()
}

// Special named sprites accessed directly
get_named_sprite :: proc(category: string, name: string) -> Sprite {
	if category == "tile" {
		spr, ok := g_sprites.tile_map[name]
		if ok { return spr }
	} else if category == "character" {
		spr, ok := g_sprites.char_map[name]
		if ok { return spr }
	} else if category == "item" {
		spr, ok := g_sprites.item_map[name]
		if ok { return spr }
	}
	return fallback_sprite()
}
