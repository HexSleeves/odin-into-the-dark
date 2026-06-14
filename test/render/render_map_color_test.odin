package renderer

import gcore "../core"
import eng "../engine"
import "core:testing"

// Dedup lock: render_map no longer reimplements tile-color math inline; it goes
// through get_tile_color (directly and via the color cache). This pins
// get_tile_color to the exact legacy inline formula for the three tile states so
// a future refactor cannot silently change visible-pixel output.
@(test)
get_tile_color_matches_legacy_inline_math_for_visible_explored_and_unseen :: proc(t: ^testing.T) {
	palette := gcore.Floor_Palette {
		wall    = {100, 100, 110, 255},
		floor   = {60, 55, 50, 255},
		rubble  = {90, 80, 70, 255},
		descent = {200, 180, 60, 255},
	}
	glow := light_glow_tint(20)

	// Legacy inline math, reproduced verbatim from the pre-dedup render_map.
	legacy :: proc(
		tile: gcore.Tile,
		state: eng.Tile_State,
		palette: gcore.Floor_Palette,
		glow: eng.Engine_Color,
	) -> eng.Engine_Color {
		if state.visible {
			return dim_color(
				mul_color(base_tile_color(tile.type, palette), glow),
				max(state.light_level, 0.5),
			)
		}
		if state.explored {
			return dim_color(base_tile_color(tile.type, palette), EXPLORED_DIM)
		}
		return UNSEEN_COLOR
	}

	types := []gcore.Tile_Type{.Wall, .Floor, .Rubble, .Descent}
	for ty in types {
		tile := gcore.Tile {
			type = ty,
		}

		visible := eng.Tile_State {
			visible     = true,
			light_level = 0.8,
		}
		testing.expect_value(
			t,
			get_tile_color(tile, visible, palette, glow),
			legacy(tile, visible, palette, glow),
		)

		// Low light still floors at 0.5 in both paths.
		dim := eng.Tile_State {
			visible     = true,
			light_level = 0.1,
		}
		testing.expect_value(
			t,
			get_tile_color(tile, dim, palette, glow),
			legacy(tile, dim, palette, glow),
		)

		explored := eng.Tile_State {
			explored = true,
		}
		testing.expect_value(
			t,
			get_tile_color(tile, explored, palette, glow),
			legacy(tile, explored, palette, glow),
		)

		unseen := eng.Tile_State{}
		testing.expect_value(
			t,
			get_tile_color(tile, unseen, palette, glow),
			legacy(tile, unseen, palette, glow),
		)
	}
}
