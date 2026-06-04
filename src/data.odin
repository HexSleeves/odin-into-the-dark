package main

import "core:encoding/json"
import "core:fmt"
import "core:math/rand"

import eng "./engine"

// ─── JSON5 data structures (mirrors the .json5 files) ─────────────────────────

// Color as 4-element array [r, g, b, a]
Color_Array :: [4]u8

json5_color_to_engine :: proc(c: Color_Array) -> eng.Engine_Color {
	return eng.Engine_Color{c[0], c[1], c[2], c[3]}
}

// ── Enemy data ──

Ability_Def :: struct {
	type:     string,
	cooldown: int,
	range:    int,
}

Enemy_Def :: struct {
	id:         string,
	name:       string,
	glyph:      string,
	color:      Color_Array,
	hp:         int,
	attack:     int,
	quickness:  int, // AP per round = quickness*10; 0 in data → defaults to 100
	move_speed: int, // move cost modifier; 0 in data → defaults to 100
	ability:    Ability_Def,
	behavior:   string, // "lurker" or "" for standard
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

Item_Spawn_Table :: struct {
	depth_min: int,
	depth_max: int,
	weights:   []Item_Spawn_Weight,
}

Item_Def :: struct {
	id:             string,
	name:           string,
	glyph:          string,
	color:          Color_Array,
	stack_limit:    int,
	effect:         Item_Effect,
	equipment_slot: string,
	durability:     int, // max durability (0 = no durability tracking)
	action_cost:    int, // AP cost to attack with this weapon (0 = use BASE_ACTION_COST)
}

Item_Spawn_Weight :: struct {
	id:     string,
	weight: int,
}

Item_Data :: struct {
	items:             []Item_Def,
	spawn_weights:     []Item_Spawn_Weight,
	item_spawn_tables: []Item_Spawn_Table,
	room_item_chance:  int,
}

// ── Player data ──

Player_Def :: struct {
	hp:           int,
	attack:       int,
	light_radius: int,
	glyph:        string,
	color:        Color_Array,
	quickness:    int, // 0 in data → defaults to 100
	move_speed:   int, // 0 in data → defaults to 100
}

// ─── Global data registry ─────────────────────────────────────────────────────

Data_Registry :: struct {
	enemies: Enemy_Data,
	items:   Item_Data,
	player:  Player_Def,
	loaded:  bool,
	owned:   bool,
}

g_data: Data_Registry

// ─── Loader ───────────────────────────────────────────────────────────────────

// Compile-time embedded data files — no runtime file I/O needed
@(private = "file")
EMBEDDED_ENEMIES :: #load("../data/enemies.json5")
@(private = "file")
EMBEDDED_ITEMS :: #load("../data/items.json5")
@(private = "file")
EMBEDDED_PLAYER :: #load("../data/player.json5")

data_load_all :: proc() -> bool {
	return data_load_all_into(&g_data)
}

data_load_all_into :: proc(registry: ^Data_Registry) -> bool {
	if registry == nil {
		return false
	}
	enemies, enemies_ok := load_json5_from_bytes(Enemy_Data, EMBEDDED_ENEMIES)
	if !enemies_ok {return false}

	items, items_ok := load_json5_from_bytes(Item_Data, EMBEDDED_ITEMS)
	if !items_ok {return false}

	player, player_ok := load_json5_from_bytes(Player_Def, EMBEDDED_PLAYER)
	if !player_ok {return false}

	registry.enemies = enemies
	registry.items = items
	registry.player = player
	registry.loaded = true
	registry.owned = true

	logger_debugf(
		.Data,
		"loaded %v enemies, %v spawn tables, %v items",
		len(registry.enemies.enemies),
		len(registry.enemies.spawn_tables),
		len(registry.items.items),
	)

	return true
}
load_json5_from_bytes :: proc($T: typeid, data: []u8) -> (result: T, ok: bool) {
	parse_err := json.unmarshal(data, &result, spec = .JSON5)
	if parse_err != nil {
		logger_errorf(.Data, "parse failed: %v", parse_err)
		return {}, false
	}
	return result, true
}

data_registry_destroy :: proc(registry: ^Data_Registry) {
	if registry == nil || !registry.owned {return}
	for &e in registry.enemies.enemies {
		delete(e.id)
		delete(e.name)
		delete(e.glyph)
		delete(e.ability.type)
		delete(e.behavior)
	}
	delete(registry.enemies.enemies)
	for &t in registry.enemies.spawn_tables {
		for &w in t.weights {delete(w.id)}
		delete(t.weights)
	}
	delete(registry.enemies.spawn_tables)
	for &item in registry.items.items {
		delete(item.id)
		delete(item.name)
		delete(item.glyph)
		delete(item.effect.type)
		delete(item.equipment_slot)
	}
	delete(registry.items.items)
	for &w in registry.items.spawn_weights {delete(w.id)}
	delete(registry.items.spawn_weights)
	for &t in registry.items.item_spawn_tables {
		for &w in t.weights {delete(w.id)}
		delete(t.weights)
	}
	delete(registry.items.item_spawn_tables)
	delete(registry.player.glyph)
	registry^ = {}
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
		pos              = pos,
		hp               = def.hp,
		max_hp           = def.hp,
		attack           = def.attack,
		enemy_type       = def.id,
		glyph            = g,
		color            = json5_color_to_engine(def.color),
		alive            = true,
		name             = def.name,
		ability_type     = def.ability.type,
		ability_cooldown = 0,
		ability_max_cd   = def.ability.cooldown,
		ability_range    = def.ability.range,
		behavior         = def.behavior,
		quickness        = 100 if def.quickness == 0 else def.quickness,
		move_speed       = 100 if def.move_speed == 0 else def.move_speed,
		energy           = 0, // granted at start of each enemy round
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
		color = json5_color_to_engine(def.color),
		picked_up = false,
		quantity = 1,
		name = def.name,
		equipment_slot = def.equipment_slot,
		stat_bonus = def.effect.value,
		durability = def.durability,
		max_durability = def.durability,
		action_cost = def.action_cost,
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

pick_item_def_for_depth :: proc(depth: int) -> ^Item_Def {
	for &table in g_data.items.item_spawn_tables {
		if depth >= table.depth_min && depth <= table.depth_max {
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
					def := find_item_def(w.id)
					if def != nil {return def}
					break
				}
			}
			break
		}
	}
	// Fallback to flat spawn_weights if no table matches
	return pick_item_def()
}

// ─── Data-driven item use ─────────────────────────────────────────────────────

apply_item_effect :: proc(messages: ^Message_Manager, game: ^Game, def: ^Item_Def) {
	eff := &def.effect

	if eff.type == "heal" {
		actual_heal := min(eff.value, game.player.max_hp - game.player.hp)
		game.player.hp = min(game.player.hp + eff.value, game.player.max_hp)
		add_message(
			messages,
			game,
			fmt.tprintf("You use a %s. Restored %d HP.", def.name, actual_heal),
			eng.Engine_Color{100, 255, 100, 255},
		)
	} else if eff.type == "light_boost" {
		max_r := eff.max_radius
		if max_r <= 0 {max_r = 10}
		game.player.light_radius = min(game.player.light_radius + eff.value, max_r)
		add_message(
			messages,
			game,
			fmt.tprintf("You use a %s. Light radius increased.", def.name),
			eng.Engine_Color{255, 180, 50, 255},
		)
	} else if eff.type == "timed_light_boost" {
		game.light_boost_bonus = eff.value
		game.light_boost_turns = eff.duration
		add_message(
			messages,
			game,
			"You apply lantern oil. Light burns brighter!",
			eng.Engine_Color{255, 200, 80, 255},
		)
	} else if eff.type == "equip" {
		add_message(
			messages,
			game,
			fmt.tprintf("Press E in inventory to equip the %s.", def.name),
			eng.Engine_Color{180, 180, 180, 255},
		)
	} else if eff.type == "material" {
		add_message(
			messages,
			game,
			"Raw materials cannot be used directly. Find an anvil to craft.",
			eng.Engine_Color{180, 180, 100, 255},
		)
	} else if eff.type == "cure_poison" {
		if game.poison_turns > 0 {
			game.poison_turns = 0
			add_message(
				messages,
				game,
				"You drink the antidote. Poison cured!",
				eng.Engine_Color{120, 220, 80, 255},
			)
		} else {
			add_message(
				messages,
				game,
				"You drink the antidote. (You weren't poisoned)",
				eng.Engine_Color{120, 220, 80, 255},
			)
		}
	} else {
		add_message(
			messages,
			game,
			fmt.tprintf("You use a %s. Nothing happens.", def.name),
			eng.Engine_Color{180, 180, 180, 255},
		)
	}
}
