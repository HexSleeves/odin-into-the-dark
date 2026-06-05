package main

import eng "./engine"
import clay "./vendor/clay"

@(private = "file")
clay_theme_import_anchor :: proc() {
	_ = eng.Engine_Color{}
	_ = clay.Color{}
}

CLAY_FONT_SMALL :: u16(12)
CLAY_FONT_BODY :: u16(13)
CLAY_FONT_TITLE :: u16(14)

CLAY_SPACE_XS :: u16(2)
CLAY_SPACE_SM :: u16(4)
CLAY_SPACE_MD :: u16(8)
CLAY_SPACE_LG :: u16(16)

clay_color :: proc(color: eng.Engine_Color) -> clay.Color {
	return {f32(color.r), f32(color.g), f32(color.b), f32(color.a)}
}

clay_theme_divider :: proc(id: string, color := SB_DIVIDER) {
	if clay.UI(clay.ID(id))(
	clay.ElementDeclaration {
		layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(1)}},
		backgroundColor = clay_color(color),
	},
	) {}
}
