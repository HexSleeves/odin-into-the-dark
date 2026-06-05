package main

import gameinput "./input"

Game_Action :: gameinput.Game_Action
Key_Binding :: gameinput.Key_Binding
Repeat_State :: gameinput.Repeat_State
Input_Manager :: gameinput.Input_Manager
KEY_REPEAT_DELAY :: gameinput.KEY_REPEAT_DELAY
KEY_REPEAT_RATE :: gameinput.KEY_REPEAT_RATE

input_manager_make :: gameinput.input_manager_make
input_manager_init :: gameinput.input_manager_init
input_default_bindings :: gameinput.input_default_bindings
input_set_binding :: gameinput.input_set_binding
input_tick :: gameinput.input_tick
action_pressed :: gameinput.action_pressed
action_binding :: gameinput.action_binding
action_binding_ptr :: gameinput.action_binding_ptr
reset_repeats :: gameinput.reset_repeats
check_repeat :: gameinput.check_repeat

// ─── Input handlers ──────────────────────────────────────────────────────────
Input_Result :: gameinput.Input_Result
handle_input :: gameinput.handle_input
read_cardinal_press :: gameinput.read_cardinal_press

// ─── State update handlers ────────────────────────────────────────────────────
update_playing :: gameinput.update_playing
update_title_screen :: gameinput.update_title_screen
update_game_over :: gameinput.update_game_over
update_victory :: gameinput.update_victory
update_viewing_inventory :: gameinput.update_viewing_inventory
update_viewing_crafting :: gameinput.update_viewing_crafting
update_viewing_help :: gameinput.update_viewing_help
update_viewing_scores :: gameinput.update_viewing_scores
handle_global_input :: gameinput.handle_global_input

// ─── Playing sub-handlers ─────────────────────────────────────────────────────
handle_forced_turn :: gameinput.handle_forced_turn
handle_mining_input :: gameinput.handle_mining_input
handle_playing_hotkeys :: gameinput.handle_playing_hotkeys

// ─── Cheats ───────────────────────────────────────────────────────────────────
cheat_open_if_requested :: gameinput.cheat_open_if_requested
update_viewing_cheats :: gameinput.update_viewing_cheats

// ─── Callbacks ────────────────────────────────────────────────────────────────
register_restart_game :: gameinput.register_restart_game
register_handle_player_action :: gameinput.register_handle_player_action

// ─── Config type ──────────────────────────────────────────────────────────────
Input_Game_Config :: gameinput.Game_Config
