package main

import "core:encoding/json"
import "core:fmt"
import "core:math/rand"
import "core:os"

import rl "vendor:raylib"

// ─── JSON5 data structures (mirrors the .json5 files) ─────────────────────────

// Color as 4-element array [r, g, b, a]
Color_Array :: [4]u8

json5_color_to_rl :: proc(c: Color_Array) -> rl.Color {
	return rl.Color{c[0], c[1], c[2], c[3]}
}

// ── Enemy data ──

Ability_Def :: struct {
	type:     string,
	cooldown: int,
	range:    int,
}

Enemy_Def :: struct {
	id:      string,
	name:    string,
	glyph:   string,
	color:   Color_Array,
	hp:      int,
	attack:  int,
	ability: Ability_Def,
}

Spawn_Weight :: struct {
	id:     string,
	weight: int,
}

Spawn_Table :: struct {
	depth_min: int,
	depth_max: int,
	weights:   []Spawn_Weight,
}

Enemy_Data :: struct {
	enemies:      []Enemy_Def,
	spawn_tables: []Spawn_Table,
}

// ── Item data ──

Item_Effect :: struct {
	type:       string,
	value:      int,
	max_radius: int, // optional, used by light_boost
	duration:   int, // optional, used by timed_light_boost
}

Item_Def :: struct {
	id:             string,
	name:           string,
	glyph:          string,
	color:          Color_Array,
	stack_limit:    int,
	effect:         Item_Effect,
	equipment_slot: string,
	durability:     int,  // max durability (0 = no durability tracking)
}

Item_Spawn_Weight :: struct {
	id:     string,
	weight: int,
}

Item_Data :: struct {
	items:            []Item_Def,
	spawn_weights:    []Item_Spawn_Weight,
	room_item_chance: int,
}

// ── Player data ──

Player_Def :: struct {
	hp:           int,
	attack:       int,
	light_radius: int,
	glyph:        string,
	color:        Color_Array,
}

// ─── Global data registry ─────────────────────────────────────────────────────

Data_Registry :: struct {
	enemies: Enemy_Data,
	items:   Item_Data,
	player:  Player_Def,
	loaded:  bool,
}

g_data: Data_Registry

// ─── Loader ───────────────────────────────────────────────────────────────────

load_json5 :: proc($T: typeid, path: string) -> (result: T, ok: bool) {
	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		fmt.eprintfln("[data] ERROR: could not read %s: %v", path, read_err)
		return {}, false
	}
	defer delete(data, context.allocator)

	parse_err := json.unmarshal(data, &result, spec = .JSON5)
	if parse_err != nil {
		fmt.eprintfln("[data] ERROR: parse failed for %s: %v", path, parse_err)
		return {}, false
	}

	return result, true
}

data_load_all :: proc() -> bool {
	enemies, enemies_ok := load_json5(Enemy_Data, "data/enemies.json5")
	if !enemies_ok {return false}

	items, items_ok := load_json5(Item_Data, "data/items.json5")
	if !items_ok {return false}

	player, player_ok := load_json5(Player_Def, "data/player.json5")
	if !player_ok {return false}

	g_data.enemies = enemies
	g_data.items = items
	g_data.player = player
	g_data.loaded = true

	fmt.printfln(
		"[data] loaded %v enemies, %v spawn tables, %v items",
		len(g_data.enemies.enemies),
		len(g_data.enemies.spawn_tables),
		len(g_data.items.items),
	)

	return true
}

// ─── Data lookup helpers ──────────────────────────────────────────────────────

find_enemy_def :: proc(id: string) -> ^Enemy_Def {
	for &def in g_data.enemies.enemies {
		if def.id == id {return &def}
	}
	return nil
}

find_item_def :: proc(id: string) -> ^Item_Def {
	for &def in g_data.items.items {
		if def.id == id {return &def}
	}
	return nil
}

// ─── Data-driven enemy factory ────────────────────────────────────────────────

enemy_make_from_def :: proc(def: ^Enemy_Def, pos: Vec2) -> Enemy {
	g: rune = '?'
	if len(def.glyph) > 0 {
		g = rune(def.glyph[0])
	}
	return Enemy {
		pos = pos,
		hp = def.hp,
		max_hp = def.hp,
		attack = def.attack,
		enemy_type = def.id,
		glyph = g,
		color = json5_color_to_rl(def.color),
		alive = true,
		name = def.name,
		ability_type = def.ability.type,
		ability_cooldown = 0,
		ability_max_cd = def.ability.cooldown,
		ability_range = def.ability.range,
	}
}

// ─── Data-driven enemy spawn picker ───────────────────────────────────────────

pick_enemy_def_for_depth :: proc(depth: int) -> ^Enemy_Def {
	// Find the matching spawn table
	for &table in g_data.enemies.spawn_tables {
		if depth >= table.depth_min && depth <= table.depth_max {
			// Weighted random from this table
			total_weight := 0
			for &w in table.weights {
				total_weight += w.weight
			}
			if total_weight <= 0 {break}

			roll := rand.int_max(total_weight)
			acc := 0
			for &w in table.weights {
				acc += w.weight
				if roll < acc {
					def := find_enemy_def(w.id)
					if def != nil {return def}
					break
				}
			}
			break
		}
	}

	// Fallback: first enemy
	if len(g_data.enemies.enemies) > 0 {
		return &g_data.enemies.enemies[0]
	}
	return nil
}

// ─── Data-driven item factory ─────────────────────────────────────────────────

item_make_from_def :: proc(def: ^Item_Def, pos: Vec2) -> Item {
	g: rune = '?'
	if len(def.glyph) > 0 {
		g = rune(def.glyph[0])
	}
	return Item {
		pos = pos,
		item_type = def.id,
		glyph = g,
		color = json5_color_to_rl(def.color),
		picked_up = false,
		quantity = 1,
		name = def.name,
		equipment_slot = def.equipment_slot,
		stat_bonus = def.effect.value,
		durability = def.durability,
		max_durability = def.durability,
	}
}

// ─── Data-driven item spawn picker ────────────────────────────────────────────

pick_item_def :: proc() -> ^Item_Def {
	total_weight := 0
	for &w in g_data.items.spawn_weights {
		total_weight += w.weight
	}
	if total_weight <= 0 && len(g_data.items.items) > 0 {
		return &g_data.items.items[0]
	}

	roll := rand.int_max(total_weight)
	acc := 0
	for &w in g_data.items.spawn_weights {
		acc += w.weight
		if roll < acc {
			def := find_item_def(w.id)
			if def != nil {return def}
			break
		}
	}

	if len(g_data.items.items) > 0 {
		return &g_data.items.items[0]
	}
	return nil
}

// ─── Data-driven item use ─────────────────────────────────────────────────────

apply_item_effect :: proc(game: ^Game, def: ^Item_Def) {
	eff := &def.effect

	if eff.type == "heal" {
		actual_heal := min(eff.value, game.player.max_hp - game.player.hp)
		game.player.hp = min(game.player.hp + eff.value, game.player.max_hp)
		add_message(
			game,
			fmt.tprintf("You use a %s. Restored %d HP.", def.name, actual_heal),
			rl.Color{100, 255, 100, 255},
		)
	} else if eff.type == "light_boost" {
		max_r := eff.max_radius
		if max_r <= 0 {max_r = 10}
		game.player.light_radius = min(game.player.light_radius + eff.value, max_r)
		add_message(
			game,
			fmt.tprintf("You use a %s. Light radius increased.", def.name),
			rl.Color{255, 180, 50, 255},
		)
	} else if eff.type == "timed_light_boost" {
		game.light_boost_bonus = eff.value
		game.light_boost_turns = eff.duration
		add_message(
			game,
			"You apply lantern oil. Light burns brighter!",
			rl.Color{255, 200, 80, 255},
		)
	} else if eff.type == "equip" {
		add_message(
			game,
			fmt.tprintf("Press E in inventory to equip the %s.", def.name),
			rl.Color{180, 180, 180, 255},
		)
	} else if eff.type == "material" {
		add_message(
			game,
			"Raw materials cannot be used directly. Find an anvil to craft.",
			rl.Color{180, 180, 100, 255},
		)
	} else {
		add_message(
			game,
			fmt.tprintf("You use a %s. Nothing happens.", def.name),
			rl.Color{180, 180, 180, 255},
		)
	}
}
