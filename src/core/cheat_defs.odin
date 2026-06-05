package core

CHEATS_ENABLED :: #config(CHEATS, false)

when CHEATS_ENABLED {
	Cheat_Command :: enum {
		Heal_Full,
		Cure_Statuses,
		Teleport_Descent,
		Depth_Down,
		Depth_Up,
		Depth_Max,
		Add_Vault_Key,
		Explore_Map,
	}

	CHEAT_COMMAND_COUNT :: 8

	cheat_command_label :: proc(command: Cheat_Command) -> cstring {
		switch command {
		case .Heal_Full:
			return cstring("Heal to full")
		case .Cure_Statuses:
			return cstring("Clear poison/burning/frozen/web")
		case .Teleport_Descent:
			return cstring("Teleport to descent")
		case .Depth_Down:
			return cstring("Go up one depth")
		case .Depth_Up:
			return cstring("Go down one depth")
		case .Depth_Max:
			return cstring("Go to final depth")
		case .Add_Vault_Key:
			return cstring("Add vault key")
		case .Explore_Map:
			return cstring("Reveal whole map on minimap")
		}
		return cstring("")
	}

	cheat_command_for_index :: proc(index: int) -> Cheat_Command {
		return cast(Cheat_Command)clamp(index, 0, CHEAT_COMMAND_COUNT - 1)
	}
}
