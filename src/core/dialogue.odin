package core

// Data-driven NPC dialogue. Lives in core so the render layer can query it
// without importing gameplay (which would create a cycle).

// ─── Conversation selection ───────────────────────────────────────────────────

// dialogue_select_conv picks the highest-priority conversation that passes all
// requires checks for the given NPC role, skipping one-shots already seen.
// Returns the index into content.dialogue.conversations, or -1.
dialogue_select_conv :: proc(
	content: ^Content_Manager,
	game: ^Game,
	npc_role: NPC_Role,
) -> (
	idx: int,
	ok: bool,
) {
	role_str := npc_role_to_string(npc_role)
	best_idx := -1
	best_pri := -1
	for &conv, i in content.registry.dialogue.conversations {
		if conv.npc_role != role_str {continue}
		if conv.one_shot && dialogue_has_seen(game, conv.id) {continue}
		if !dialogue_check_requires(game, &conv.requires, conv.id) {continue}
		if conv.priority > best_pri {
			best_pri = conv.priority
			best_idx = i
		}
	}
	if best_idx < 0 {return -1, false}
	return best_idx, true
}

// dialogue_find_node returns a pointer to a node by ID within the active conversation.
dialogue_find_node :: proc(
	content: ^Content_Manager,
	game: ^Game,
	node_id: string,
) -> (
	node: ^Dlg_Node,
	ok: bool,
) {
	if game.active_conv_idx < 0 {return nil, false}
	conv := &content.registry.dialogue.conversations[game.active_conv_idx]
	for &n in conv.nodes {
		if n.id == node_id {return &n, true}
	}
	return nil, false
}

// dialogue_current_node returns a pointer to the currently active node.
dialogue_current_node :: proc(
	content: ^Content_Manager,
	game: ^Game,
) -> (
	node: ^Dlg_Node,
	ok: bool,
) {
	if game.active_conv_idx < 0 || game.active_node_idx < 0 {return nil, false}
	conv := &content.registry.dialogue.conversations[game.active_conv_idx]
	if game.active_node_idx >= len(conv.nodes) {return nil, false}
	return &conv.nodes[game.active_node_idx], true
}

// dialogue_current_line returns the speaker, text, and choices for the current node.
dialogue_current_line :: proc(
	content: ^Content_Manager,
	game: ^Game,
) -> (
	speaker, text: string,
	choices: []Dlg_Choice,
	ok: bool,
) {
	node, node_ok := dialogue_current_node(content, game)
	if !node_ok {return "", "", nil, false}
	return node.speaker, node.text, node.choices, true
}

// ─── Flags ────────────────────────────────────────────────────────────────────

dialogue_has_flag :: proc(game: ^Game, flag: string) -> bool {
	for i in 0 ..< game.dlg_flag_count {
		s := string(game.dlg_flags[i][:game.dlg_flag_lens[i]])
		if s == flag {return true}
	}
	return false
}

dialogue_set_flag :: proc(game: ^Game, flag: string) {
	if dialogue_has_flag(game, flag) {return}
	if game.dlg_flag_count >= MAX_DLG_FLAGS {return}
	n := min(len(flag), MAX_FLAG_LEN)
	copy(game.dlg_flags[game.dlg_flag_count][:], flag[:n])
	game.dlg_flag_lens[game.dlg_flag_count] = n
	game.dlg_flag_count += 1
}

dialogue_clear_flag :: proc(game: ^Game, flag: string) {
	for i in 0 ..< game.dlg_flag_count {
		s := string(game.dlg_flags[i][:game.dlg_flag_lens[i]])
		if s == flag {
			// swap-remove
			last := game.dlg_flag_count - 1
			game.dlg_flags[i] = game.dlg_flags[last]
			game.dlg_flag_lens[i] = game.dlg_flag_lens[last]
			game.dlg_flag_count -= 1
			return
		}
	}
}

// ─── Seen set ─────────────────────────────────────────────────────────────────

dialogue_has_seen :: proc(game: ^Game, conv_id: string) -> bool {
	for i in 0 ..< game.seen_count {
		s := string(game.seen_convs[i][:game.seen_lens[i]])
		if s == conv_id {return true}
	}
	return false
}

dialogue_mark_seen :: proc(game: ^Game, conv_id: string) {
	if dialogue_has_seen(game, conv_id) {return}
	if game.seen_count >= MAX_SEEN_CONVS {return}
	n := min(len(conv_id), MAX_CONV_ID_LEN)
	copy(game.seen_convs[game.seen_count][:], conv_id[:n])
	game.seen_lens[game.seen_count] = n
	game.seen_count += 1
}

// ─── Requires check ───────────────────────────────────────────────────────────

dialogue_check_requires :: proc(game: ^Game, req: ^Dlg_Requires, conv_id: string) -> bool {
	for f in req.flags {
		if !dialogue_has_flag(game, f) {return false}
	}
	for f in req.not_flags {
		if dialogue_has_flag(game, f) {return false}
	}
	if req.not_seen != "" && dialogue_has_seen(game, req.not_seen) {return false}
	if req.quest_is != "" && quest_state_to_string(game.quest) != req.quest_is {return false}
	if req.quest_not != "" && quest_state_to_string(game.quest) == req.quest_not {return false}
	return true
}

// ─── Quest / objectives ───────────────────────────────────────────────────────

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
	town_add_npc(
		game,
		NPC {
			pos = Vec2{17, 18},
			name = "Bram the Shopkeeper",
			glyph = 'S',
			color = {80, 220, 120, 255},
			role = .Shopkeeper,
		},
	)
	town_add_npc(
		game,
		NPC {
			pos = Vec2{MAP_WIDTH / 2, MAP_HEIGHT - 8},
			name = "Sergeant Hild",
			glyph = 'G',
			color = {120, 160, 230, 255},
			role = .Guard,
		},
	)
	town_add_npc(
		game,
		NPC {
			pos = Vec2{MAP_WIDTH - 19, 18},
			name = "Elder Marisa",
			glyph = 'E',
			color = {220, 200, 120, 255},
			role = .Elder,
		},
	)
	town_add_npc(
		game,
		NPC {
			pos = Vec2{MAP_WIDTH / 2 + 3, 9},
			name = "Old Miner Tobias",
			glyph = 'M',
			color = {230, 180, 90, 255},
			role = .Old_Miner,
		},
	)
}

@(private = "file")
town_add_npc :: proc(game: ^Game, npc: NPC) {
	if game.npc_count >= MAX_NPCS {return}
	game.tiles[pos_to_idx(npc.pos.x, npc.pos.y)].type = .Floor
	game.npcs[game.npc_count] = npc
	game.npc_count += 1
}

@(private = "file")
npc_role_to_string :: proc(role: NPC_Role) -> string {
	switch role {
	case .Old_Miner:
		return "Old_Miner"
	case .Shopkeeper:
		return "Shopkeeper"
	case .Guard:
		return "Guard"
	case .Elder:
		return "Elder"
	}
	return ""
}

@(private = "file")
quest_state_to_string :: proc(q: Quest_State) -> string {
	switch q {
	case .Not_Started:
		return "Not_Started"
	case .Active:
		return "Active"
	case .Treasure_Found:
		return "Treasure_Found"
	case .Complete:
		return "Complete"
	}
	return ""
}
