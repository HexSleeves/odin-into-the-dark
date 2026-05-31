package main

import "core:fmt"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"

// ─── Map helpers ──────────────────────────────────────────────────────────────

pos_to_idx :: proc(x, y: int) -> int {
	return y * MAP_WIDTH + x
}

idx_to_pos :: proc(idx: int) -> Vec2 {
	return Vec2{idx % MAP_WIDTH, idx / MAP_WIDTH}
}

tile_at :: proc(game: ^Game, x, y: int) -> ^Tile {
	if x < 0 || x >= MAP_WIDTH || y < 0 || y >= MAP_HEIGHT {
		return nil
	}
	return &game.tiles[pos_to_idx(x, y)]
}

is_walkable :: proc(game: ^Game, x, y: int) -> bool {
	t := tile_at(game, x, y)
	if t == nil {
		return false
	}
	#partial switch t.type {
	case .Floor, .Rubble, .Descent, .Water, .Gas_Vent, .Unstable, .Anvil:
		return true
	}
	return false
}

// ─── Game initialization ─────────────────────────────────────────────────────

game_init :: proc() -> ^Game {
	// Derive seed from current time
	seed := u64(time.time_to_unix_nano(time.now()))

	fmt.printfln("[init] seed = %v", seed)

	// Initialize RNG (used later by proc-gen in S02; seeded now for R014)
	rand.reset(seed)

	// Allocate on heap — Game struct is ~112KB with fixed-size arrays
	game := new(Game)

	game.seed = seed
	game.map_width = MAP_WIDTH
	game.map_height = MAP_HEIGHT
	game.depth = 1
	game.turn_count = 0
	game.state = .Playing

	// Player defaults from data (position set by generate_map)
	init_player_from_data(game)

	// Initialize dynamic collections before generate_map uses them
	game.rooms = make([dynamic]Room)
	game.enemies = make([dynamic]Enemy)
	game.items = make([dynamic]Item)
	game.light_sources = make([dynamic]Light_Source)

	// Mining defaults
	game.pickaxe_durability = 20
	game.pickaxe_max_dur = 20

	// Procedurally generate the mine floor (sets player pos, descent, rooms)
	generate_map(game)

	// Give the player starting equipment
	give_starter_gear(game)

	return game
}

// ─── Reinitialize in place (for restart) ─────────────────────────────────────

game_reinit :: proc(game: ^Game) {
	seed := u64(time.time_to_unix_nano(time.now()))
	fmt.printfln("[init] seed = %v", seed)
	rand.reset(seed)

	game.seed = seed
	game.map_width = MAP_WIDTH
	game.map_height = MAP_HEIGHT
	game.depth = 1
	game.turn_count = 0
	game.state = .Playing

	init_player_from_data(game)

	game.rooms = make([dynamic]Room)
	game.enemies = make([dynamic]Enemy)
	game.items = make([dynamic]Item)
	game.light_sources = make([dynamic]Light_Source)

	clear_messages(game)

	// Mining defaults
	game.pickaxe_durability = 20
	game.pickaxe_max_dur = 20

	generate_map(game)

	// Give the player starting equipment
	give_starter_gear(game)
}

// ─── Starter gear ─────────────────────────────────────────────────────────────

give_starter_gear :: proc(game: ^Game) {
	// Equip a Rusty Pickaxe directly into the weapon slot
	pick_def := find_item_def("rusty_pickaxe")
	if pick_def != nil {
		pick := item_make_from_def(pick_def, Vec2{0, 0})
		pick.picked_up = true
		game.equipped_weapon = Equipment{occupied = true, item = pick}
	}

	// Put a Torch in inventory slot 0
	torch_def := find_item_def("torch")
	if torch_def != nil {
		torch := item_make_from_def(torch_def, Vec2{0, 0})
		torch.picked_up = true
		game.inventory[0] = Inventory_Slot{occupied = true, item = torch}
		game.inventory[0].item.quantity = 1
	}

	// Put 2 Bandages in inventory slot 1
	band_def := find_item_def("bandage")
	if band_def != nil {
		band := item_make_from_def(band_def, Vec2{0, 0})
		band.picked_up = true
		game.inventory[1] = Inventory_Slot{occupied = true, item = band}
		game.inventory[1].item.quantity = 2
	}
}

// ─── Initialize player from data ─────────────────────────────────────────────

init_player_from_data :: proc(game: ^Game) {
	p := &g_data.player
	p_glyph: rune = '@'
	if len(p.glyph) > 0 {p_glyph = rune(p.glyph[0])}
	game.player = Player {
		pos          = Vec2{0, 0},
		hp           = p.hp,
		max_hp       = p.hp,
		attack       = p.attack,
		light_radius = p.light_radius,
		glyph        = p_glyph,
		color        = json5_color_to_rl(p.color),
	}
}

// ─── Camera ───────────────────────────────────────────────────────────────

// Centers the viewport on the player, clamped to map edges.
camera_update :: proc(game: ^Game) {
	// Player pixel center
	px := game.player.pos.x * TILE_SIZE + TILE_SIZE / 2
	py := game.player.pos.y * TILE_SIZE + TILE_SIZE / 2

	// Viewport pixel size (map region only, not HUD/messages)
	vw := SCREEN_WIDTH
	vh := MAP_VIEW_HEIGHT

	// Center on player
	cam_x := px - vw / 2
	cam_y := py - vh / 2

	// Clamp so we never show past map edges
	map_pixel_w := MAP_WIDTH * TILE_SIZE
	map_pixel_h := MAP_HEIGHT * TILE_SIZE

	if cam_x < 0 {cam_x = 0}
	if cam_y < 0 {cam_y = 0}
	if cam_x + vw > map_pixel_w {cam_x = map_pixel_w - vw}
	if cam_y + vh > map_pixel_h {cam_y = map_pixel_h - vh}

	// If map is smaller than viewport, center it
	if map_pixel_w < vw {cam_x = -(vw - map_pixel_w) / 2}
	if map_pixel_h < vh {cam_y = -(vh - map_pixel_h) / 2}

	game.camera_x = cam_x
	game.camera_y = cam_y
}

// ─── Mining ───────────────────────────────────────────────────────────────────

mine_wall :: proc(game: ^Game, dx, dy: int) -> bool {
	tx := game.player.pos.x + dx
	ty := game.player.pos.y + dy

	// Check bounds
	if tx < 0 || tx >= MAP_WIDTH || ty < 0 || ty >= MAP_HEIGHT { return false }

	t := tile_at(game, tx, ty)
	if t == nil || t.type != .Wall {
		add_message(game, "Nothing to mine there.", rl.Color{180, 180, 180, 255})
		return false
	}

	// Check pickaxe
	if game.pickaxe_durability <= 0 {
		add_message(game, "Your pickaxe is broken!", rl.Color{255, 100, 100, 255})
		return false
	}

	// Mine the wall
	idx := pos_to_idx(tx, ty)
	vein := game.ore_veins[idx]

	// Convert wall to rubble
	t.type = .Rubble

	// If ore vein, spawn material item
	if vein.ore_type != "" {
		def := find_item_def(vein.ore_type)
		if def != nil {
			ore_item := item_make_from_def(def, Vec2{tx, ty})
			append(&game.items, ore_item)
			add_message(game, fmt.tprintf("You found %s!", def.name), vein.color)
		} else {
			add_message(game, "You mine through a vein, but nothing useful falls out.", rl.Color{180, 160, 100, 255})
		}
		game.ore_veins[idx] = {} // clear the vein
	} else {
		add_message(game, "You mine through the wall.", rl.Color{180, 160, 100, 255})
	}

	// Decrease pickaxe durability
	game.pickaxe_durability -= 1
	if game.pickaxe_durability <= 0 {
		add_message(game, "Your pickaxe breaks!", rl.Color{255, 80, 80, 255})
	} else if game.pickaxe_durability <= 5 {
		add_message(game, fmt.tprintf("Pickaxe wearing down... (%d/%d)", game.pickaxe_durability, game.pickaxe_max_dur), rl.Color{255, 180, 50, 255})
	}

	// Consume a turn
	game.turn_count += 1
	return true
}

// ─── Cleanup ──────────────────────────────────────────────────────────────────

// Release dynamic allocations (rooms, enemies, light_sources)
game_cleanup :: proc(game: ^Game) {
	delete(game.rooms)
	delete(game.enemies)
	delete(game.items)
	delete(game.light_sources)
}

// Full destroy — cleanup + free heap allocation
game_destroy :: proc(game: ^Game) {
	game_cleanup(game)
	free(game)
}
