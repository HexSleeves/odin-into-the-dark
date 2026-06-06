package gameplay

import gcore "../core"
import eng "../engine"

NPC_Role :: gcore.NPC_Role
NPC :: gcore.NPC
Quest_State :: gcore.Quest_State

npc_dialogue :: gcore.npc_dialogue
dialogue_current_line :: gcore.dialogue_current_line
quest_objective_text :: gcore.quest_objective_text

// advance_dialogue moves to the next line; closes and applies effects at the end.
advance_dialogue :: proc(messages: ^Message_Manager, game: ^Game) {
	if game.active_npc < 0 || game.active_npc >= game.npc_count {
		close_dialogue(game)
		return
	}
	npc := &game.npcs[game.active_npc]
	lines := npc_dialogue(game, npc)
	game.dialogue_line += 1
	if game.dialogue_line >= len(lines) {
		on_dialogue_complete(messages, game, npc)
		close_dialogue(game)
	}
}

close_dialogue :: proc(game: ^Game) {
	game.active_npc = -1
	game.dialogue_line = 0
	game.state = .Playing
}

@(private = "file")
on_dialogue_complete :: proc(messages: ^Message_Manager, game: ^Game, npc: ^NPC) {
	if npc.role != .Old_Miner {return}
	#partial switch game.quest {
	case .Not_Started:
		game.quest = .Active
		add_message(
			messages,
			game,
			"Quest accepted: retrieve the Ancient Treasure from the mine.",
			eng.Engine_Color{255, 215, 0, 255},
		)
	case .Treasure_Found:
		game.quest = .Complete
		add_message(
			messages,
			game,
			"You hand over the Ancient Treasure. The Old Miner rewards you!",
			eng.Engine_Color{255, 215, 0, 255},
		)
		game.state = .Victory
	}
}
