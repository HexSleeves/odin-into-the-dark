#+build !js
package main

import "core:testing"

@(test)
default_sprite_mode_honors_compile_time_sprite_flags :: proc(t: ^testing.T) {
	when NO_SPRITES {
		testing.expect(t, !DEFAULT_USE_SPRITES)
	} else {
		when SPRITES_REQUESTED {
			testing.expect(t, DEFAULT_USE_SPRITES)
		} else {
			testing.expect(t, !DEFAULT_USE_SPRITES)
		}
	}
}


@(test)
fixed_seed_flag_controls_new_game_seed :: proc(t: ^testing.T) {
	when FIXED_SEED > 0 {
		testing.expect_value(t, game_next_seed(), u64(FIXED_SEED))
	}
}

@(test)
skip_title_flag_controls_initial_state :: proc(t: ^testing.T) {
	when SKIP_TITLE {
		testing.expect_value(t, game_initial_state(), Game_State.Playing)
	} else {
		testing.expect_value(t, game_initial_state(), Game_State.Title_Screen)
	}
}
