package renderer

import gcore "../core"

import eng "../engine"
import ui_pkg "../ui"
import clay "libs:clay"

@(private = "file")
clay_messages_import_anchor :: proc() {
	_ = clay.ElementDeclaration{}
	_ = gcore.Message{}
}

MSG_PANEL_HEIGHT :: i32(gcore.MSG_REGION_HEIGHT)
MSG_FONT_SIZE :: i32(14)
MSG_LINE_HEIGHT :: i32(16)
MSG_MAX_VISIBLE :: 7

clay_render_messages :: proc(messages: ^eng.Message_Manager) {
	if messages == nil {
		return
	}
	log := &messages.log
	visible_count := min(log.count, MSG_MAX_VISIBLE)
	if clay.UI(clay.ID("messages-panel"))(
	clay.ElementDeclaration {
		layout = {
			sizing = {
				width = clay.SizingFixed(f32(gcore.SCREEN_WIDTH)),
				height = clay.SizingFixed(f32(MSG_PANEL_HEIGHT)),
			},
			padding = clay.Padding{left = 8, right = 8, top = 4, bottom = 4},
			layoutDirection = .TopToBottom,
			childGap = u16(MSG_LINE_HEIGHT - MSG_FONT_SIZE),
		},
		backgroundColor = clay_color(ui_pkg.SB_BG),
		border = {color = clay_color(ui_pkg.SB_DIVIDER), width = {0, 0, 1, 0, 0}}, // top edge only
	},
	) {
		for i in 0 ..< visible_count {
			msg_offset := visible_count - 1 - i
			msg_idx := (log.head - 1 - msg_offset + gcore.MAX_MESSAGES * 2) % gcore.MAX_MESSAGES
			msg := &log.messages[msg_idx]
			// i == visible_count-1 is newest (brightest); older lines dim toward 0.5.
			recency := f32(i + 1) / f32(visible_count)
			fade := 0.5 + 0.5 * recency
			c := msg.color
			faded := eng.Engine_Color {
				u8(f32(c.r) * fade),
				u8(f32(c.g) * fade),
				u8(f32(c.b) * fade),
				c.a,
			}
			clay.TextDynamic(
				string(msg.text[:msg.text_len]),
				{
					textColor = clay_color(faded),
					fontSize = CLAY_FONT_SMALL,
					lineHeight = u16(MSG_LINE_HEIGHT),
				},
			)
		}
	}
}
