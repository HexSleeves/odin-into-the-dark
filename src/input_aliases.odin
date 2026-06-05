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
