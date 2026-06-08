package gameplay

import gcore "../core"
import eng "../engine"

NPC_Role :: gcore.NPC_Role
NPC :: gcore.NPC
Quest_State :: gcore.Quest_State
Dlg_Effect :: gcore.Dlg_Effect

quest_objective_text :: gcore.quest_objective_text

// start_conversation selects and begins a conversation with the NPC at npc_idx.
start_conversation :: proc(
	messages: ^Message_Manager,
	content: ^Content_Manager,
	game: ^Game,
	npc_idx: int,
) {
	if npc_idx < 0 || npc_idx >= game.npc_count {return}
	npc := &game.npcs[npc_idx]
	game.active_npc = npc_idx

	conv_idx, ok := gcore.dialogue_select_conv(content, game, npc.role)
	if !ok {return}

	conv := &content.registry.dialogue.conversations[conv_idx]
	node_idx := -1
	for &n, i in conv.nodes {
		if n.id == conv.start {
			node_idx = i
			break
		}
	}
	if node_idx < 0 {return}

	game.active_conv_idx = conv_idx
	game.active_node_idx = node_idx
	game.dialogue_choice = 0
	game.state = .Viewing_Dialogue
}

// advance_dialogue moves to the next node, applying effects.
// No-ops if the current node has choices (player must confirm first).
advance_dialogue :: proc(messages: ^Message_Manager, content: ^Content_Manager, game: ^Game) {
	node, ok := gcore.dialogue_current_node(content, game)
	if !ok {
		close_dialogue(game)
		return
	}
	if len(node.choices) > 0 {return}

	apply_dlg_effects(messages, content, game, node.effects)

	if node.next == "" || game.state != .Viewing_Dialogue {
		finish_conversation(game, content)
		return
	}

	next_node, found := gcore.dialogue_find_node(content, game, node.next)
	if !found {
		finish_conversation(game, content)
		return
	}
	conv := &content.registry.dialogue.conversations[game.active_conv_idx]
	for &n, i in conv.nodes {
		if &n == next_node {
			game.active_node_idx = i
			game.dialogue_choice = 0
			return
		}
	}
	finish_conversation(game, content)
}

// confirm_dialogue_choice validates the selected choice, applies effects, and jumps to the target node.
confirm_dialogue_choice :: proc(
	messages: ^Message_Manager,
	content: ^Content_Manager,
	game: ^Game,
) {
	node, ok := gcore.dialogue_current_node(content, game)
	if !ok {return}
	if len(node.choices) == 0 {return}
	idx := game.dialogue_choice
	if idx < 0 || idx >= len(node.choices) {return}

	choice := &node.choices[idx]
	apply_dlg_effects(messages, content, game, choice.effects)

	if game.state != .Viewing_Dialogue {
		finish_conversation(game, content)
		return
	}

	if choice.to == "" {
		finish_conversation(game, content)
		return
	}

	conv := &content.registry.dialogue.conversations[game.active_conv_idx]
	for &n, i in conv.nodes {
		if n.id == choice.to {
			game.active_node_idx = i
			game.dialogue_choice = 0
			return
		}
	}
	finish_conversation(game, content)
}

// apply_dlg_effects applies a slice of dialogue effects.
apply_dlg_effects :: proc(
	messages: ^Message_Manager,
	content: ^Content_Manager,
	game: ^Game,
	effects: []Dlg_Effect,
) {
	for &eff in effects {
		apply_single_effect(messages, content, game, &eff)
	}
}

// close_dialogue resets dialogue state and returns to Playing (unless already in Merchant or Victory).
close_dialogue :: proc(game: ^Game) {
	game.active_npc = -1
	game.active_conv_idx = -1
	game.active_node_idx = -1
	game.dialogue_choice = -1
	if game.state != .Viewing_Merchant && game.state != .Victory {
		game.state = .Playing
	}
}

@(private = "file")
finish_conversation :: proc(game: ^Game, content: ^Content_Manager) {
	if game.active_conv_idx >= 0 {
		conv := &content.registry.dialogue.conversations[game.active_conv_idx]
		if conv.one_shot {
			gcore.dialogue_mark_seen(game, conv.id)
		}
	}
	close_dialogue(game)
}

@(private = "file")
apply_single_effect :: proc(
	messages: ^Message_Manager,
	content: ^Content_Manager,
	game: ^Game,
	eff: ^Dlg_Effect,
) {
	switch eff.type {
	case "set_flag":
		gcore.dialogue_set_flag(game, eff.flag)
	case "clear_flag":
		gcore.dialogue_clear_flag(game, eff.flag)
	case "set_quest":
		new_state := parse_quest_state(eff.state)
		game.quest = new_state
		switch new_state {
		case .Active:
			add_message(
				messages,
				game,
				"Quest accepted: retrieve the Ancient Treasure from the mine.",
				eng.Engine_Color{255, 215, 0, 255},
			)
		case .Complete:
			add_message(
				messages,
				game,
				"You hand over the Ancient Treasure. The Old Miner rewards you!",
				eng.Engine_Color{255, 215, 0, 255},
			)
		case .Not_Started, .Treasure_Found:
		}
	case "hp_delta":
		game.player.hp = clamp(game.player.hp + eff.value, 0, game.player.max_hp)
	case "grant_item":
		def := content_manager_item_def(content, eff.item_id)
		if def != nil {
			it := item_make_from_def(def, game.player.pos)
			slot := inventory_first_empty_slot(game)
			if slot >= 0 {inventory_put_slot(game, slot, it, 1)}
		}
	case "open_shop":
		generate_shopkeeper_stock(game)
		game.state = .Viewing_Merchant
		add_message(
			messages,
			game,
			"Bram lays out a few town supplies.",
			eng.Engine_Color{80, 220, 120, 255},
		)
	case "trigger_victory":
		game.state = .Victory
	}
}

@(private = "file")
parse_quest_state :: proc(s: string) -> Quest_State {
	switch s {
	case "Active":
		return .Active
	case "Treasure_Found":
		return .Treasure_Found
	case "Complete":
		return .Complete
	}
	return .Not_Started
}
