package main

import clay "./vendor/clay"
import eng "./engine"

@(private = "file")
clay_messages_import_anchor :: proc() {
	_ = clay.ElementDeclaration{}
	_ = eng.Message{}
}

when USE_CLAY {
	clay_render_messages :: proc(messages: ^Message_Manager) {
		if messages == nil {
			return
		}
		log := &messages.log
		visible_count := min(log.count, MSG_MAX_VISIBLE)
		if clay.UI(clay.ID("messages-panel"))(
		clay.ElementDeclaration {
			layout = {
				sizing = {
					width = clay.SizingFixed(f32(SCREEN_WIDTH)),
					height = clay.SizingFixed(f32(MSG_PANEL_HEIGHT)),
				},
				padding = clay.Padding{left = 8, right = 8, top = 4, bottom = 4},
				layoutDirection = .TopToBottom,
				childGap = u16(MSG_LINE_HEIGHT - MSG_FONT_SIZE),
			},
			backgroundColor = clay_color(eng.Engine_Color{15, 15, 20, 255}),
		},
		) {
			for i in 0 ..< visible_count {
				msg_offset := visible_count - 1 - i
				msg_idx := (log.head - 1 - msg_offset + MAX_MESSAGES * 2) % MAX_MESSAGES
				msg := &log.messages[msg_idx]
				clay.TextDynamic(
					string(msg.text[:msg.text_len]),
					{textColor = clay_color(msg.color), fontSize = CLAY_FONT_SMALL, lineHeight = u16(MSG_LINE_HEIGHT)},
				)
			}
		}
	}
}
