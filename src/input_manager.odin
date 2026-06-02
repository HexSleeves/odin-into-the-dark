package main

import rl "vendor:raylib"

// ---------------------------------------------------------------------------
// Game_Action enum
// ---------------------------------------------------------------------------

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
}

// ---------------------------------------------------------------------------
// Structs
// ---------------------------------------------------------------------------

Key_Binding :: struct {
	primary:     rl.KeyboardKey,
	alt:         rl.KeyboardKey,
	needs_shift: bool,
}

Repeat_State :: struct {
	hold_time:    f32,
	repeat_timer: f32,
	last_fired:   bool,
}

KEY_REPEAT_DELAY :: f32(0.20)
KEY_REPEAT_RATE  :: f32(0.08)

Input_Manager :: struct {
	bindings:     [Game_Action]Key_Binding,
	repeat:       [Game_Action]Repeat_State,
	repeat_delay: f32,
	repeat_rate:  f32,
}

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

input_manager_init :: proc(im: ^Input_Manager) {
	im.repeat_delay = KEY_REPEAT_DELAY
	im.repeat_rate = KEY_REPEAT_RATE
	input_default_bindings(im)
}

// ---------------------------------------------------------------------------
// Default bindings
// ---------------------------------------------------------------------------

input_default_bindings :: proc(im: ^Input_Manager) {
	im.bindings[.Move_North] = {primary = .W, alt = .UP}
	im.bindings[.Move_South] = {primary = .S, alt = .DOWN}
	im.bindings[.Move_East] = {primary = .D, alt = .RIGHT}
	im.bindings[.Move_West] = {primary = .A, alt = .LEFT}
	im.bindings[.Wait] = {primary = .PERIOD}
	im.bindings[.Quit] = {primary = .ESCAPE}
	im.bindings[.Pickup] = {primary = .G}
	im.bindings[.Mine] = {primary = .X}
	im.bindings[.Inventory] = {primary = .I}
	im.bindings[.Crafting] = {primary = .C}
	im.bindings[.Help] = {primary = .SLASH, needs_shift = true}
	im.bindings[.Toggle_Map] = {primary = .M}
	im.bindings[.Save] = {primary = .F5}
	im.bindings[.Load] = {primary = .F9}
	im.bindings[.Toggle_Audio] = {primary = .F1}
	im.bindings[.Toggle_Sprites] = {primary = .F2}
	im.bindings[.Menu_Up] = {primary = .W, alt = .UP}
	im.bindings[.Menu_Down] = {primary = .S, alt = .DOWN}
	im.bindings[.Menu_Confirm] = {primary = .ENTER, alt = .SPACE}
	im.bindings[.Menu_New_Game] = {primary = .N}
	im.bindings[.Menu_Continue] = {primary = .C}
	im.bindings[.Menu_High_Scores] = {primary = .H}
	im.bindings[.Menu_Quit] = {primary = .Q}
	im.bindings[.Menu_Back] = {primary = .ESCAPE}
	im.bindings[.Restart] = {primary = .R}
	im.bindings[.Inv_Drop_Mode] = {primary = .D}
	im.bindings[.Inv_Equip_Mode] = {primary = .E}
	im.bindings[.Inv_Slot_1] = {primary = .ONE}
	im.bindings[.Inv_Slot_2] = {primary = .TWO}
	im.bindings[.Inv_Slot_3] = {primary = .THREE}
	im.bindings[.Inv_Slot_4] = {primary = .FOUR}
	im.bindings[.Inv_Slot_5] = {primary = .FIVE}
	im.bindings[.Inv_Slot_6] = {primary = .SIX}
	im.bindings[.Inv_Slot_7] = {primary = .SEVEN}
	im.bindings[.Inv_Slot_8] = {primary = .EIGHT}
	im.bindings[.Inv_Slot_9] = {primary = .NINE}
	im.bindings[.Craft_1] = {primary = .ONE}
	im.bindings[.Craft_2] = {primary = .TWO}
	im.bindings[.Craft_3] = {primary = .THREE}
	im.bindings[.Craft_4] = {primary = .FOUR}
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

@(private = "file")
_binding_matches_held :: proc(b: Key_Binding) -> bool {
	if b.primary == .KEY_NULL {return false}
	if b.needs_shift && !(rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)) {return false}
	return rl.IsKeyDown(b.primary) || (b.alt != .KEY_NULL && rl.IsKeyDown(b.alt))
}

@(private = "file")
_binding_matches_pressed :: proc(b: Key_Binding) -> bool {
	if b.primary == .KEY_NULL {return false}
	if b.needs_shift && !(rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)) {return false}
	return rl.IsKeyPressed(b.primary) || (b.alt != .KEY_NULL && rl.IsKeyPressed(b.alt))
}

// ---------------------------------------------------------------------------
// Public query procs
// ---------------------------------------------------------------------------

action_pressed :: proc(im: ^Input_Manager, action: Game_Action) -> bool {
	return _binding_matches_pressed(im.bindings[action])
}

action_held :: proc(im: ^Input_Manager, action: Game_Action) -> bool {
	return _binding_matches_held(im.bindings[action])
}

action_released :: proc(im: ^Input_Manager, action: Game_Action) -> bool {
	b := im.bindings[action]
	if b.primary == .KEY_NULL {return false}
	if b.needs_shift && !(rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)) {return false}
	return rl.IsKeyReleased(b.primary) || (b.alt != .KEY_NULL && rl.IsKeyReleased(b.alt))
}

// ---------------------------------------------------------------------------
// Key repeat
// ---------------------------------------------------------------------------

check_repeat :: proc(im: ^Input_Manager, action: Game_Action) -> bool {
	dt := rl.GetFrameTime()
	rs := &im.repeat[action]

	held := _binding_matches_held(im.bindings[action])

	if !held {
		rs.hold_time = 0
		rs.repeat_timer = 0
		rs.last_fired = false
		return false
	}

	if !rs.last_fired {
		rs.last_fired = true
		rs.hold_time = 0
		rs.repeat_timer = 0
		return true
	}

	rs.hold_time += dt
	if rs.hold_time < im.repeat_delay {
		return false
	}

	rs.repeat_timer += dt
	if rs.repeat_timer >= im.repeat_rate {
		rs.repeat_timer -= im.repeat_rate
		return true
	}

	return false
}
