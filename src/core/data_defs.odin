package core

import eng "../engine"

// ─── JSON5 data structures (mirrors the .json5 files) ─────────────────────────

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
	quickness:        int,
	move_speed:       int,
	detection_radius: int, // 0 = use default
	memory_turns:     int, // 0 = use default; how long enemy remembers player
	ability:          Ability_Def,
	behavior:         string,
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
	max_radius: int,
	duration:   int,
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
	durability:     int,
	action_cost:    int,
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
	quickness:    int,
	move_speed:   int,
}

// ─── Global data registry ─────────────────────────────────────────────────────

Data_Registry :: struct {
	enemies: Enemy_Data,
	items:   Item_Data,
	player:  Player_Def,
	loaded:  bool,
	owned:   bool,
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
