package core


enemy_make_from_def :: proc(def: ^Enemy_Def, pos: Vec2) -> Enemy {
	g: rune = '?'
	if len(def.glyph) > 0 {
		g = rune(def.glyph[0])
	}
	det := DEFAULT_ENEMY_DETECTION_RADIUS
	if def.detection_radius > 0 {det = def.detection_radius}
	mem := DEFAULT_ENEMY_MEMORY_TURNS
	if def.memory_turns > 0 {mem = def.memory_turns}
	return Enemy {
		pos = pos,
		hp = def.hp,
		max_hp = def.hp,
		attack = def.attack,
		enemy_type = def.id,
		glyph = g,
		color = json5_color_to_engine(def.color),
		alive = true,
		name = def.name,
		ability_type = def.ability.type,
		ability_cooldown = 0,
		ability_max_cd = def.ability.cooldown,
		ability_range = def.ability.range,
		behavior = def.behavior,
		detection_radius = det,
		memory_turns = mem,
		quickness = 100 if def.quickness == 0 else def.quickness,
		move_speed = 100 if def.move_speed == 0 else def.move_speed,
		energy = 0,
	}
}

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
		description = def.description,
		equipment_slot = def.equipment_slot,
		stat_bonus = def.effect.value,
		durability = def.durability,
		max_durability = def.durability,
		action_cost = def.action_cost,
		crit_chance = def.crit_chance,
	}
}
