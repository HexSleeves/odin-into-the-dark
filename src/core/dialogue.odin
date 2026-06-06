package core

// Static NPC dialogue + pure read helpers. Lives in core so the render layer
// can query it without importing gameplay (which would be a cycle).

@(private = "file")
DLG_SHOPKEEPER := [?]string {
	"Welcome, traveler! Bram's Goods, finest in the valley.",
	"Stock up before you go below — the mine eats the unprepared.",
	"Pickaxes wear down. Mind your durability down there.",
}

@(private = "file")
DLG_GUARD := [?]string {
	"Halt. ...Oh, just another treasure-seeker.",
	"The mine's been restless. Things crawl up from the deep.",
	"If you hear scratching in the dark, you're already too close.",
}

@(private = "file")
DLG_ELDER := [?]string {
	"This town was carved by miners, long before the dark came.",
	"They dug too greedily. Now something guards the depths.",
	"Light keeps the worst of it at bay. Never let your torch die.",
}

@(private = "file")
DLG_MINER_INTRO := [?]string {
	"You there — you've the look of someone needing coin.",
	"Deep in this mine lies an Ancient Treasure, lost generations ago.",
	"Bring it back to me and I'll make you rich. The descent is just there.",
	"Mind the dark. Few who go down ever climb back up.",
}

@(private = "file")
DLG_MINER_ACTIVE := [?]string {
	"Still here? The treasure won't fetch itself.",
	"Take the descent. Go deep. Don't come back empty-handed.",
}

@(private = "file")
DLG_MINER_DONE := [?]string {
	"By the depths... you actually found it!",
	"You've earned every coin. The town owes you its legend.",
}

// npc_dialogue returns the lines for an NPC given the current quest state.
npc_dialogue :: proc(game: ^Game, npc: ^NPC) -> []string {
	switch npc.role {
	case .Shopkeeper:
		return DLG_SHOPKEEPER[:]
	case .Guard:
		return DLG_GUARD[:]
	case .Elder:
		return DLG_ELDER[:]
	case .Old_Miner:
		#partial switch game.quest {
		case .Treasure_Found, .Complete:
			return DLG_MINER_DONE[:]
		case .Active:
			return DLG_MINER_ACTIVE[:]
		case:
			return DLG_MINER_INTRO[:]
		}
	}
	return DLG_SHOPKEEPER[:]
}

// dialogue_current_line returns the active NPC's current line (or ok=false when done).
dialogue_current_line :: proc(game: ^Game) -> (name: string, line: string, ok: bool) {
	if game.active_npc < 0 || game.active_npc >= game.npc_count {return "", "", false}
	npc := &game.npcs[game.active_npc]
	lines := npc_dialogue(game, npc)
	if game.dialogue_line < 0 || game.dialogue_line >= len(lines) {return npc.name, "", false}
	return npc.name, lines[game.dialogue_line], true
}

quest_objective_text :: proc(game: ^Game) -> string {
	switch game.quest {
	case .Not_Started:
		return "Speak to the Old Miner"
	case .Active:
		return "Find the Ancient Treasure"
	case .Treasure_Found:
		return "Return to the Old Miner"
	case .Complete:
		return "Quest complete!"
	}
	return ""
}

// ─── Town NPC placement (deterministic; not serialized) ───────────────────────

place_town_npcs :: proc(game: ^Game) {
	game.npc_count = 0
	town_add_npc(game, NPC {
		pos = Vec2{17, 18},
		name = "Bram the Shopkeeper",
		glyph = 'S',
		color = {80, 220, 120, 255},
		role = .Shopkeeper,
	})
	town_add_npc(game, NPC {
		pos = Vec2{MAP_WIDTH / 2, MAP_HEIGHT - 8},
		name = "Sergeant Hild",
		glyph = 'G',
		color = {120, 160, 230, 255},
		role = .Guard,
	})
	town_add_npc(game, NPC {
		pos = Vec2{MAP_WIDTH - 19, 18},
		name = "Elder Marisa",
		glyph = 'E',
		color = {220, 200, 120, 255},
		role = .Elder,
	})
	town_add_npc(game, NPC {
		pos = Vec2{MAP_WIDTH / 2 + 3, 9},
		name = "Old Miner Tobias",
		glyph = 'M',
		color = {230, 180, 90, 255},
		role = .Old_Miner,
	})
}

@(private = "file")
town_add_npc :: proc(game: ^Game, npc: NPC) {
	if game.npc_count >= MAX_NPCS {return}
	game.tiles[pos_to_idx(npc.pos.x, npc.pos.y)].type = .Floor
	game.npcs[game.npc_count] = npc
	game.npc_count += 1
}
