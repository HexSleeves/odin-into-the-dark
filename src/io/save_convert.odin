package gameio

import "base:runtime"
string_to_save :: proc(s: string) -> Save_String {
	result: Save_String
	copy_len := min(len(s), MAX_NAME_LEN)
	for i in 0 ..< copy_len {
		result.data[i] = s[i]
	}
	result.len = copy_len
	return result
}

enemy_to_save :: proc(e: ^Enemy) -> Save_Enemy {
	return Save_Enemy {
		pos = e.pos,
		hp = e.hp,
		max_hp = e.max_hp,
		attack = e.attack,
		enemy_type = string_to_save(e.enemy_type),
		name = string_to_save(e.name),
		glyph = e.glyph,
		color = e.color,
		alive = e.alive,
		ability_type = string_to_save(e.ability_type),
		ability_cooldown = e.ability_cooldown,
		ability_max_cd = e.ability_max_cd,
		ability_range = e.ability_range,
		is_boss = e.is_boss,
		detection_radius = e.detection_radius,
		aware = e.aware,
		memory_turns = e.memory_turns,
		aware_turns_left = e.aware_turns_left,
	}
}

save_to_enemy :: proc(content: ^Content_Manager, se: ^Save_Enemy) -> Enemy {
	etype := save_to_string(content, &se.enemy_type)
	def := content_manager_enemy_def(content, etype)
	qn := 100
	ms := 100
	beh := ""
	glyph := se.glyph
	cc := 0
	ad := 0
	if def != nil {
		qn = 100 if def.quickness == 0 else def.quickness
		ms = 100 if def.move_speed == 0 else def.move_speed
		beh = def.behavior
		cc = def.crit_chance
		ad = def.ability.damage
		if len(def.glyph) > 0 {glyph = rune(def.glyph[0])}
	}
	return Enemy {
		pos = se.pos,
		hp = se.hp,
		max_hp = se.max_hp,
		attack = se.attack,
		crit_chance = cc,
		enemy_type = etype,
		name = save_to_string(content, &se.name),
		glyph = glyph,
		color = se.color,
		alive = se.alive,
		ability_type = save_to_string(content, &se.ability_type),
		ability_cooldown = se.ability_cooldown,
		ability_max_cd = se.ability_max_cd,
		ability_range = se.ability_range,
		ability_damage = ad,
		is_boss = se.is_boss,
		detection_radius = max(se.detection_radius, DEFAULT_ENEMY_DETECTION_RADIUS),
		memory_turns = max(se.memory_turns, DEFAULT_ENEMY_MEMORY_TURNS),
		aware = se.aware,
		aware_turns_left = se.aware_turns_left,
		behavior = beh,
		quickness = qn,
		move_speed = ms,
		energy = 0,
	}
}

// Resolve a Save_String back to a stable string pointer from loaded content.
// All game strings originate from data definitions (lifetime = program),
// so we look them up instead of allocating.
save_to_string :: proc(content: ^Content_Manager, s: ^Save_String) -> string {
	if s.len == 0 {
		return ""
	}
	temp := string(s.data[:s.len])

	// Look up in enemy definitions
	enemies: []Enemy_Def
	if content != nil {
		enemies = content.registry.enemies.enemies
	}
	for &def in enemies {
		if def.id == temp {return def.id}
		if def.name == temp {return def.name}
		if def.ability.type == temp {return def.ability.type}
	}

	// Look up in item definitions
	items: []Item_Def
	if content != nil {
		items = content.registry.items.items
	}
	for &def in items {
		if def.id == temp {return def.id}
		if def.name == temp {return def.name}
		if def.equipment_slot == temp {return def.equipment_slot}
	}

	// Known constant strings (string literals — always valid)
	known := [?]string {
		ENEMY_ABILITY_WEB,
		ENEMY_ABILITY_PULL,
		ENEMY_ABILITY_POISON_CLOUD,
		ENEMY_ABILITY_TELEPORT,
		ENEMY_ABILITY_SLAM,
		ENEMY_ABILITY_DARKNESS,
		EQUIPMENT_SLOT_WEAPON,
		EQUIPMENT_SLOT_ARMOR,
		EQUIPMENT_SLOT_HELMET,
		ITEM_EFFECT_MATERIAL,
	}
	for k in known {
		if k == temp {return k}
	}

	return ""
}

// ─── Item conversion helpers ──────────────────────────────────────────────────

item_to_save :: proc(item: ^Item) -> Save_Item {
	return Save_Item {
		pos = item.pos,
		item_type = string_to_save(item.item_type),
		name = string_to_save(item.name),
		glyph = item.glyph,
		color = item.color,
		picked_up = item.picked_up,
		quantity = item.quantity,
		equipment_slot = string_to_save(item.equipment_slot),
		stat_bonus = item.stat_bonus,
		durability = item.durability,
		max_durability = item.max_durability,
	}
}

save_to_item :: proc(content: ^Content_Manager, si: ^Save_Item) -> Item {
	itype := save_to_string(content, &si.item_type)
	def := content_manager_item_def(content, itype)
	glyph := si.glyph
	if def != nil && len(def.glyph) > 0 {
		glyph = rune(def.glyph[0])
	}
	return Item {
		pos = si.pos,
		item_type = itype,
		name = save_to_string(content, &si.name),
		glyph = glyph,
		color = si.color,
		picked_up = si.picked_up,
		quantity = si.quantity,
		equipment_slot = save_to_string(content, &si.equipment_slot),
		stat_bonus = si.stat_bonus,
		durability = si.durability,
		max_durability = si.max_durability,
	}
}

floor_to_save :: proc(floor: ^Saved_Floor, result: ^Save_Floor) {
	if floor == nil || result == nil {return}
	result.tiles = floor.tiles
	result.tile_states = floor.tile_states
	result.web_tiles = floor.web_tiles
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		result.ore_veins[i] = Save_Ore_Vein {
			ore_type = string_to_save(floor.ore_veins[i].ore_type),
			color    = floor.ore_veins[i].color,
		}
	}
	result.player_pos = floor.player_pos
	result.enemy_count = min(len(floor.enemies), MAX_SAVE_ENEMIES)
	for i in 0 ..< result.enemy_count {
		result.enemies[i] = enemy_to_save(&floor.enemies[i])
	}
	result.item_count = min(len(floor.items), MAX_SAVE_ITEMS)
	for i in 0 ..< result.item_count {
		result.items[i] = item_to_save(&floor.items[i])
	}
	result.room_count = min(len(floor.rooms), MAX_SAVE_ROOMS)
	for i in 0 ..< result.room_count {
		result.rooms[i] = floor.rooms[i]
	}
	result.light_source_count = min(len(floor.light_sources), MAX_SAVE_LIGHTS)
	for i in 0 ..< result.light_source_count {
		result.light_sources[i] = floor.light_sources[i]
	}
	result.palette = floor.palette
	result.event_used = floor.event_used
	result.npcs = floor.npcs
	result.npc_count = floor.npc_count
}

save_to_floor :: proc(content: ^Content_Manager, saved: ^Save_Floor, floor: ^Saved_Floor) {
	if saved == nil || floor == nil {return}
	old_context := context
	context.allocator = runtime.default_allocator()
	defer {
		context = old_context
	}

	floor.tiles = saved.tiles
	floor.tile_states = saved.tile_states
	floor.web_tiles = saved.web_tiles
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		floor.ore_veins[i] = Ore_Vein {
			ore_type = save_to_string(content, &saved.ore_veins[i].ore_type),
			color    = saved.ore_veins[i].color,
		}
	}
	floor.player_pos = saved.player_pos

	// Clamp file-controlled counts to fixed-array capacities before iterating.
	room_count := clamp(saved.room_count, 0, MAX_SAVE_ROOMS)
	enemy_count := clamp(saved.enemy_count, 0, MAX_SAVE_ENEMIES)
	item_count := clamp(saved.item_count, 0, MAX_SAVE_ITEMS)
	light_count := clamp(saved.light_source_count, 0, MAX_SAVE_LIGHTS)

	floor.rooms = make([dynamic]Room)
	for i in 0 ..< room_count {
		append(&floor.rooms, saved.rooms[i])
	}
	floor.enemies = make([dynamic]Enemy)
	for i in 0 ..< enemy_count {
		append(&floor.enemies, save_to_enemy(content, &saved.enemies[i]))
	}
	floor.items = make([dynamic]Item)
	for i in 0 ..< item_count {
		append(&floor.items, save_to_item(content, &saved.items[i]))
	}
	floor.light_sources = make([dynamic]Light_Source)
	for i in 0 ..< light_count {
		append(&floor.light_sources, saved.light_sources[i])
	}
	floor.palette = saved.palette
	floor.event_used = saved.event_used
	floor.npcs = saved.npcs
	floor.npc_count = saved.npc_count
}

// ─── Save ─────────────────────────────────────────────────────────────────────
