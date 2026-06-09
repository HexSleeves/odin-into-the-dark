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
	id:               string,
	name:             string,
	glyph:            string,
	color:            Color_Array,
	hp:               int,
	attack:           int,
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
	description:    string,
	glyph:          string,
	color:          Color_Array,
	stack_limit:    int,
	effect:         Item_Effect,
	equipment_slot: string,
	durability:     int,
	action_cost:    int,
	crit_chance:    int,
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

// ── Dialogue data ──

Dlg_Effect :: struct {
	type:    string, // "set_flag","clear_flag","set_quest","hp_delta","grant_item","open_shop","trigger_victory"
	flag:    string,
	state:   string,
	item_id: string,
	value:   int,
}

Dlg_Requires :: struct {
	flags:     []string,
	not_flags: []string,
	not_seen:  string,
	quest_is:  string, // "" = any
	quest_not: string, // "" = no restriction
}

Dlg_Choice :: struct {
	text:     string,
	to:       string,
	requires: Dlg_Requires,
	effects:  []Dlg_Effect,
}

Dlg_Node :: struct {
	id:      string,
	speaker: string,
	text:    string,
	choices: []Dlg_Choice,
	effects: []Dlg_Effect,
	next:    string,
}

Conversation_Def :: struct {
	id:       string,
	npc_role: string,
	priority: int,
	one_shot: bool,
	requires: Dlg_Requires,
	start:    string,
	nodes:    []Dlg_Node,
}

Dialogue_Data :: struct {
	conversations: []Conversation_Def,
}

// ─── Global data registry ─────────────────────────────────────────────────────

Data_Registry :: struct {
	enemies:  Enemy_Data,
	items:    Item_Data,
	player:   Player_Def,
	dialogue: Dialogue_Data,
	loaded:   bool,
	owned:    bool,
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
		delete(item.description)
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
	for &conv in registry.dialogue.conversations {
		delete(conv.id)
		delete(conv.npc_role)
		delete(conv.start)
		delete(conv.requires.not_seen)
		delete(conv.requires.quest_is)
		delete(conv.requires.quest_not)
		for f in conv.requires.flags {delete(f)}
		delete(conv.requires.flags)
		for f in conv.requires.not_flags {delete(f)}
		delete(conv.requires.not_flags)
		for &node in conv.nodes {
			delete(node.id)
			delete(node.speaker)
			delete(node.text)
			delete(node.next)
			for &eff in node.effects {
				delete(eff.type)
				delete(eff.flag)
				delete(eff.state)
				delete(eff.item_id)
			}
			delete(node.effects)
			for &ch in node.choices {
				delete(ch.text)
				delete(ch.to)
				for f in ch.requires.flags {delete(f)}
				delete(ch.requires.flags)
				for f in ch.requires.not_flags {delete(f)}
				delete(ch.requires.not_flags)
				delete(ch.requires.not_seen)
				delete(ch.requires.quest_is)
				delete(ch.requires.quest_not)
				for &eff in ch.effects {
					delete(eff.type)
					delete(eff.flag)
					delete(eff.state)
					delete(eff.item_id)
				}
				delete(ch.effects)
			}
			delete(node.choices)
		}
		delete(conv.nodes)
	}
	delete(registry.dialogue.conversations)
	registry^ = {}
}
