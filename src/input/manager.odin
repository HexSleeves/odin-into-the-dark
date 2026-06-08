package gameinput

import eng "../engine"

Game_Action :: enum {
	Move_North,
	Move_South,
	Move_East,
	Move_West,
	Wait,
	Quit,
	Pickup,
	Mine,
	Inventory,
	Crafting,
	Help,
	Toggle_Map,
	Save,
	Load,
	Toggle_Audio,
	Cheat_Menu,
	Toggle_Sprites,
	Menu_Up,
	Menu_Down,
	Menu_Confirm,
	Menu_New_Game,
	Menu_Continue,
	Menu_High_Scores,
	Menu_Quit,
	Menu_Back,
	Restart,
	Inv_Drop_Mode,
	Inv_Equip_Mode,
	Inv_Slot_1,
	Inv_Slot_2,
	Inv_Slot_3,
	Inv_Slot_4,
	Inv_Slot_5,
	Inv_Slot_6,
	Inv_Slot_7,
	Inv_Slot_8,
	Inv_Slot_9,
	Craft_1,
	Craft_2,
	Craft_3,
	Craft_4,
	Inv_Tab_Equipment,
}

Key_Binding :: eng.Engine_Key_Binding
Repeat_State :: eng.Engine_Repeat_State
KEY_REPEAT_DELAY :: f32(0.20)
KEY_REPEAT_RATE :: f32(0.08)
Input_Manager :: eng.Action_Input_Manager

input_manager_make :: proc() -> Input_Manager {
	input: Input_Manager
	input_manager_init(&input)
	return input
}

input_manager_init :: proc(im: ^Input_Manager) {
	im^ = eng.action_input_manager_make(KEY_REPEAT_DELAY, KEY_REPEAT_RATE)
	input_default_bindings(im)
}

input_default_bindings :: proc(im: ^Input_Manager) {
	input_set_binding(im, .Move_North, {primary = .W, alt = .Up})
	input_set_binding(im, .Move_South, {primary = .S, alt = .Down})
	input_set_binding(im, .Move_East, {primary = .D, alt = .Right})
	input_set_binding(im, .Move_West, {primary = .A, alt = .Left})
	input_set_binding(im, .Wait, {primary = .Period})
	input_set_binding(im, .Quit, {primary = .Escape})
	input_set_binding(im, .Pickup, {primary = .G})
	input_set_binding(im, .Mine, {primary = .X})
	input_set_binding(im, .Inventory, {primary = .I})
	input_set_binding(im, .Crafting, {primary = .C})
	input_set_binding(im, .Help, {primary = .Slash, needs_shift = true})
	input_set_binding(im, .Toggle_Map, {primary = .M})
	input_set_binding(im, .Save, {primary = .F5})
	input_set_binding(im, .Load, {primary = .F9})
	input_set_binding(im, .Toggle_Audio, {primary = .F1})
	input_set_binding(im, .Cheat_Menu, {primary = .C, needs_shift = true})
	input_set_binding(im, .Toggle_Sprites, {primary = .F2})
	input_set_binding(im, .Menu_Up, {primary = .W, alt = .Up})
	input_set_binding(im, .Menu_Down, {primary = .S, alt = .Down})
	input_set_binding(im, .Menu_Confirm, {primary = .Enter, alt = .Space})
	input_set_binding(im, .Menu_New_Game, {primary = .N})
	input_set_binding(im, .Menu_Continue, {primary = .C})
	input_set_binding(im, .Menu_High_Scores, {primary = .H})
	input_set_binding(im, .Menu_Quit, {primary = .Q})
	input_set_binding(im, .Menu_Back, {primary = .Escape})
	input_set_binding(im, .Restart, {primary = .R})
	input_set_binding(im, .Inv_Drop_Mode, {primary = .D})
	input_set_binding(im, .Inv_Equip_Mode, {primary = .E})
	input_set_binding(im, .Inv_Slot_1, {primary = .One})
	input_set_binding(im, .Inv_Slot_2, {primary = .Two})
	input_set_binding(im, .Inv_Slot_3, {primary = .Three})
	input_set_binding(im, .Inv_Slot_4, {primary = .Four})
	input_set_binding(im, .Inv_Slot_5, {primary = .Five})
	input_set_binding(im, .Inv_Slot_6, {primary = .Six})
	input_set_binding(im, .Inv_Slot_7, {primary = .Seven})
	input_set_binding(im, .Inv_Slot_8, {primary = .Eight})
	input_set_binding(im, .Inv_Slot_9, {primary = .Nine})
	input_set_binding(im, .Craft_1, {primary = .One})
	input_set_binding(im, .Craft_2, {primary = .Two})
	input_set_binding(im, .Craft_3, {primary = .Three})
	input_set_binding(im, .Craft_4, {primary = .Four})
	input_set_binding(im, .Inv_Tab_Equipment, {primary = .Tab})
}

input_set_binding :: proc(im: ^Input_Manager, action: Game_Action, binding: Key_Binding) -> bool {
	return eng.action_input_manager_set_binding(im, int(action), binding)
}

input_tick :: proc(im: ^Input_Manager, backend: eng.Engine_Input_Backend) {
	if im == nil {return}
	im.backend = backend
}

action_pressed :: proc(im: ^Input_Manager, action: Game_Action) -> bool {
	return eng.action_input_pressed(im, int(action))
}

action_binding :: proc(im: ^Input_Manager, action: Game_Action) -> Key_Binding {
	if im == nil {return {}}
	return im.bindings[int(action)]
}

action_binding_ptr :: proc(im: ^Input_Manager, action: Game_Action) -> ^Key_Binding {
	if im == nil {return nil}
	return &im.bindings[int(action)]
}

reset_repeats :: proc(im: ^Input_Manager) {
	if im == nil {return}
	for i in 0 ..< len(im.repeat) {
		im.repeat[i] = {}
	}
}

check_repeat :: proc(im: ^Input_Manager, action: Game_Action) -> bool {
	return eng.action_input_repeat(im, int(action))
}
