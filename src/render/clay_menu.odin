package renderer

import ui_pkg "../ui"

import gcore "../core"

import eng "../engine"
import "core:fmt"
import clay "libs:clay"

@(private = "file")
clay_menu_import_anchor :: proc() {
	_ = eng.Engine{}
	_ = clay.ElementDeclaration{}
	_ = fmt.tprintf
	_ = gcore.SCREEN_WIDTH
}

// full-screen dim backdrop that centers its children on BOTH axes. Returns a decl —
// the CALLER must open it so Clay's deferred close binds to the caller's scope:
//   if clay.UI(clay.ID("title-backdrop"))(clay_menu_backdrop_decl()) {
//       clay_render_title_embers(engine)
//       if clay.UI(clay.ID("title-card"))(clay_menu_card_decl()) { ...content... }
//   }
// (Wrapping clay.UI inside a bool-returning helper closes the element immediately on
// return, so children escape to the parent — hence decl-returning helpers.)
clay_menu_backdrop_decl :: proc(
	color := ui_pkg.SB_BACKDROP,
	floating := false,
) -> clay.ElementDeclaration {
	decl := clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			padding = clay.Padding{left = 24, right = 24, top = 24, bottom = 24},
			layoutDirection = .TopToBottom,
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = clay_color(color),
	}
	// Floating overlays (drawn over the live HUD) must cover the full screen out of
	// normal flow. Pure-menu screens are the sole root child, so a non-floating Grow
	// container fills the screen and centers the fixed-width card via childAlignment.
	if floating {
		decl.layout.sizing = {
			width  = clay.SizingFixed(f32(gcore.SCREEN_WIDTH)),
			height = clay.SizingFixed(f32(gcore.SCREEN_HEIGHT)),
		}
		decl.floating = {
			attachTo = .Parent,
			attachment = {element = .LeftTop, parent = .LeftTop},
		}
	}
	return decl
}

// centered framed card. SB_CARD bg, 2px SB_DIVIDER border, cornerRadius 8, fixed width,
// SizingFit height. Returns a decl — caller opens it (see clay_menu_backdrop_decl).
clay_menu_card_decl :: proc(width: f32 = 680) -> clay.ElementDeclaration {
	return clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingFixed(width), height = clay.SizingFit()},
			padding = clay.Padding{left = 28, right = 28, top = 24, bottom = 22},
			childGap = 8,
			layoutDirection = .TopToBottom,
			childAlignment = {x = .Center, y = .Top},
		},
		backgroundColor = clay_color(ui_pkg.SB_CARD),
		cornerRadius = {8, 8, 8, 8},
		border = {color = clay_color(ui_pkg.SB_DIVIDER), width = {2, 2, 2, 2, 0}},
	}
}

// decorative full-width 3px gold rule (SB_ACCENT). Use right under the title.
clay_menu_accent_rule :: proc(id: string) {
	if clay.UI(clay.ID(id))(
	clay.ElementDeclaration {
		layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(3)}},
		backgroundColor = clay_color(ui_pkg.SB_ACCENT),
	},
	) {}
}

// large centered title (default gold). Uses clay_text_centered.
clay_menu_title :: proc(text: string, color := ui_pkg.SB_TITLE, size: u16 = 40) {
	clay_text_centered(text, size, color, CLAY_FONT_ID_DISPLAY)
}

// centered tagline / subtitle.
clay_menu_subtitle :: proc(text: string, color := ui_pkg.SB_HEADER, size: u16 = 16) {
	clay_text_centered(text, size, color)
}

// section header: a top spacer (fixed 6h), uppercase SB_HEADER label (size 14) in a
// full-width left-aligned element, then clay_theme_divider beneath.
clay_menu_section :: proc(id: string, label: string) {
	clay_spacer_fixed(fmt.tprintf("%s-top", id), 1, 6)
	if clay.UI(clay.ID(fmt.tprintf("%s-label", id)))(
	clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
			childAlignment = {x = .Left, y = .Top},
		},
	},
	) {
		clay_text(label, 14, ui_pkg.SB_HEADER, CLAY_FONT_ID_DISPLAY)
	}
	clay_theme_divider(fmt.tprintf("%s-rule", id))
}

// selectable menu row. Container is LeftToRight, sizing width=SizingGrow height=SizingFit,
// padding {left=10,right=12,top=6,bottom=6}, childGap=8, cornerRadius {4,4,4,4},
// backgroundColor = SB_SELECT_BG when selected else fully transparent {0,0,0,0}.
// FIRST child: a 3px-wide gold (SB_ACCENT) bar, SizingFixed(3) x SizingGrow height, shown
// only when selected (when not selected use a 3px transparent spacer so labels stay aligned).
// Then label text: color = SB_DIM if disabled, SB_TITLE if selected, else SB_TEXT.
// Then clay_spacer_grow. Then hotkey text right-aligned in SB_DIM (skip if hotkey=="").
clay_menu_item :: proc(
	id: string,
	label: string,
	hotkey: string,
	selected: bool,
	disabled := false,
) {
	bg := eng.Engine_Color{0, 0, 0, 0}
	if selected {bg = ui_pkg.SB_SELECT_BG}
	if clay.UI(clay.ID(id))(
	clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
			padding = clay.Padding{left = 10, right = 12, top = 6, bottom = 6},
			childGap = 8,
			layoutDirection = .LeftToRight,
			childAlignment = {x = .Left, y = .Center},
		},
		backgroundColor = clay_color(bg),
		cornerRadius = {4, 4, 4, 4},
	},
	) {
		bar_color := eng.Engine_Color{0, 0, 0, 0}
		if selected {bar_color = ui_pkg.SB_ACCENT}
		if clay.UI(clay.ID_LOCAL("menu-item-bar"))(
		clay.ElementDeclaration {
			layout = {sizing = {width = clay.SizingFixed(3), height = clay.SizingGrow()}},
			backgroundColor = clay_color(bar_color),
		},
		) {}

		label_color := ui_pkg.SB_TEXT
		if disabled {
			label_color = ui_pkg.SB_DIM
		} else if selected {
			label_color = ui_pkg.SB_TITLE
		}
		clay_text(label, 16, label_color)

		clay_spacer_grow("menu-item-spacer")

		if hotkey != "" {
			clay_text(hotkey, 16, ui_pkg.SB_DIM)
		}
	}
}

// two-column key/action row for help: clay_row(id, key, action, size, key_color, action_color)
// with key left, action right.
clay_menu_kv :: proc(
	id: string,
	key: string,
	action: string,
	size: u16 = 16,
	key_color := ui_pkg.SB_PICK_OK,
	action_color := ui_pkg.SB_TEXT,
) {
	clay_row(id, key, action, size, key_color, action_color)
}

// bottom footer: clay_spacer_fixed gap (1x14), clay_theme_divider, clay_spacer_fixed (1x8),
// centered SB_DIM text size 13.
clay_menu_footer :: proc(id: string, text: string) {
	clay_spacer_fixed(fmt.tprintf("%s-gap", id), 1, 14)
	clay_theme_divider(fmt.tprintf("%s-rule", id))
	clay_spacer_fixed(fmt.tprintf("%s-gap2", id), 1, 8)
	clay_text_centered(text, 15, ui_pkg.SB_HEADER)
}
