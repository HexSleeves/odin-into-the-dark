package ui

import gcore "../core"

UI_APP_TITLE :: "INTO THE DEPTHS"
UI_APP_NAME :: "Into the Depths"
UI_APP_VERSION :: "v0.3.0"
UI_TITLE_SUBTITLE :: "A turn-based mining roguelike"
UI_TITLE_TAGLINE :: "Mine the dark. Keep the lamp alive. Escape with the treasure."
UI_TITLE_CONTINUE_DISABLED :: "No save file found — Continue is disabled"
UI_TITLE_FOOTER :: "Up/Down: Select  |  Enter: Confirm  |  N/C/H/?: Shortcuts  |  Esc/Q: Quit"
UI_TITLE_OPTIONS :: [gcore.TITLE_OPTION_COUNT]string {
	"New Game",
	"Continue",
	"High Scores",
	"Help",
	"Quit",
}
UI_Help_Row :: struct {
	key:    string,
	action: string,
}
UI_Help_Section :: struct {
	title: string,
	rows:  []UI_Help_Row,
}

@(private = "file")
ui_help_rows_movement := [?]UI_Help_Row {
	{"WASD / Arrows", "Move"},
	{".", "Wait a turn"},
	{"Walk into enemy", "Attack"},
}

@(private = "file")
ui_help_rows_items := [?]UI_Help_Row {
	{"G", "Pick up item"},
	{"I", "Open inventory"},
	{"1-9", "Use item"},
	{"D / E", "Drop or equip"},
}

@(private = "file")
ui_help_rows_tools := [?]UI_Help_Row {
	{"X", "Mine adjacent wall/hazard"},
	{"C", "Craft at anvils"},
	{"M", "Toggle minimap"},
	{"F1", "Mute audio"},
	{"ESC / Q", "Close menu / quit"},
}

ui_help_sections :: proc() -> []UI_Help_Section {
	@(static) sections: [3]UI_Help_Section
	sections[0] = {"MOVEMENT", ui_help_rows_movement[:]}
	sections[1] = {"ITEMS", ui_help_rows_items[:]}
	sections[2] = {"TOOLS", ui_help_rows_tools[:]}
	return sections[:]
}
UI_HINT_MINING :: "[MINING] Direction (WASD/arrows) | ESC cancel"
UI_HINT_ANVIL :: "[C = Craft]"
UI_HINT_FOUNTAIN :: "[Fountain — restores HP]"
UI_INVENTORY_TITLE :: "INVENTORY"
UI_INVENTORY_HELP :: "1-9=Use | D=Drop | E=Equip | Up/Down=Inspect | I/ESC=Close"
UI_INVENTORY_DROP_MODE :: "[DROP MODE] Press 1-9 to drop"
UI_INVENTORY_EQUIP_MODE :: "[EQUIP MODE] Press 1-9 to equip"
UI_CRAFTING_TITLE :: "CRAFTING"
UI_CRAFTING_HELP :: "Press 1-4 to craft | C or ESC to close"
UI_PAUSE_TITLE :: "PAUSED"
UI_PAUSE_HELP :: "Up/Down: Select  |  Enter: Confirm  |  ESC: Resume"
UI_PAUSE_OPTIONS :: [gcore.PAUSE_OPTION_COUNT]string{"Resume", "Quit to Title"}
UI_HELP_TITLE :: "CONTROLS & HELP"
UI_HELP_FOOTER :: "Press ESC or ? to return"
UI_SCORES_TITLE :: "HIGH SCORES"
UI_SCORES_EMPTY :: "No scores yet."
UI_SCORES_FOOTER :: "Press ESC or H to return"
UI_GAME_OVER_TITLE :: "GAME OVER"
UI_GAME_OVER_FOOTER :: "Press R to restart or Q to quit"
UI_VICTORY_TITLE :: "VICTORY!"
UI_VICTORY_SUBTITLE :: "You have conquered the depths!"
UI_VICTORY_FOOTER :: "Press R to play again or Q to quit"
UI_CHEATS_TITLE :: "CHEAT MENU"
UI_CHEATS_HELP :: "Open with ` (backtick). Press 1-8 or Enter; Esc/` closes."
