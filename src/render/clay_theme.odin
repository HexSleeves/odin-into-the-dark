package renderer

import ui_pkg "../ui"

import "core:math"

import eng "../engine"
import clay "libs:clay"

@(private = "file")
clay_theme_import_anchor :: proc() {
	_ = eng.Engine_Color{}
	_ = clay.Color{}
}

CLAY_FONT_SMALL :: u16(16)
CLAY_FONT_BODY :: u16(18)
CLAY_FONT_TITLE :: u16(20)

CLAY_SPACE_XS :: u16(2)
CLAY_SPACE_SM :: u16(4)
CLAY_SPACE_MD :: u16(8)
CLAY_SPACE_LG :: u16(16)

CLAY_PANEL_PAD :: u16(6)

clay_color :: proc(color: eng.Engine_Color) -> clay.Color {
	return {f32(color.r), f32(color.g), f32(color.b), f32(color.a)}
}

// Number of filled cells for a segmented bar of `segments` cells at `ratio` (0..1).
bar_segment_fill_count :: proc(ratio: f32, segments: int) -> int {
	r := clamp(ratio, 0, 1)
	return clamp(int(math.round(r * f32(segments))), 0, segments)
}

// Bordered readout panel with an inset uppercase header. Use as:
//   if clay_panel_begin("hud-vitals", "VITALS") { ...child elements... }
clay_panel_begin :: proc(id: string, header: string) -> bool {
	open := clay.UI(clay.ID(id))(
	clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
			padding = {
				left = CLAY_PANEL_PAD,
				right = CLAY_PANEL_PAD,
				top = CLAY_PANEL_PAD,
				bottom = CLAY_PANEL_PAD,
			},
			layoutDirection = .TopToBottom,
			childGap = CLAY_SPACE_XS,
		},
		backgroundColor = clay_color(ui_pkg.SB_PANEL),
		cornerRadius = {2, 2, 2, 2},
		border = {color = clay_color(ui_pkg.SB_DIVIDER), width = {1, 1, 1, 1, 0}},
	},
	)
	if open {
		clay_text(header, CLAY_FONT_SMALL, ui_pkg.SB_HEADER)
	}
	return open
}

clay_theme_divider :: proc(id: string, color := ui_pkg.SB_DIVIDER) {
	if clay.UI(clay.ID(id))(
	clay.ElementDeclaration {
		layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(1)}},
		backgroundColor = clay_color(color),
	},
	) {}
}
