package gameio


string_to_save :: proc(s: string) -> Save_String {
	result: Save_String
	copy_len := min(len(s), MAX_NAME_LEN)
	for i in 0 ..< copy_len {
		result.data[i] = s[i]
	}
	result.len = copy_len
	return result
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
	return Item {
		pos = si.pos,
		item_type = save_to_string(content, &si.item_type),
		name = save_to_string(content, &si.name),
		glyph = si.glyph,
		color = si.color,
		picked_up = si.picked_up,
		quantity = si.quantity,
		equipment_slot = save_to_string(content, &si.equipment_slot),
		stat_bonus = si.stat_bonus,
		durability = si.durability,
		max_durability = si.max_durability,
	}
}

// ─── Save ─────────────────────────────────────────────────────────────────────
