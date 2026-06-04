package main

import eng "./engine"
import clay "./vendor/clay"
@(private = "file")
clay_renderer_import_anchor :: proc() {
	_ = clay.RenderCommand{}
	_ = eng.Engine{}
}


when USE_CLAY {
	clay_render_commands :: proc(
		engine: ^eng.Engine,
		commands: clay.ClayArray(clay.RenderCommand),
	) {
		overlay_stack: [8]clay.Color
		overlay_count := 0
		command_array := commands

		for i: i32 = 0; i < command_array.length; i += 1 {
			command := clay.RenderCommandArray_Get(&command_array, i)
			if command == nil {
				continue
			}

			box := command.boundingBox
			switch command.commandType {
			case .Rectangle:
				color := clay_color_to_engine(command.renderData.rectangle.backgroundColor)
				color = clay_apply_overlay(color, overlay_stack[:], overlay_count)
				render_draw_rectangle(
					engine,
					i32(box.x),
					i32(box.y),
					i32(box.width),
					i32(box.height),
					color,
				)
			case .Text:
				text := command.renderData.text
				color := clay_color_to_engine(text.textColor)
				color = clay_apply_overlay(color, overlay_stack[:], overlay_count)
				allocator := context.allocator
				frames := eng.engine_frame_manager(engine)
				if frames != nil {
					allocator = eng.frame_manager_allocator(frames)
				}
				c_text := clay_string_slice_to_cstring(text.stringContents, allocator)
				render_draw_text(engine, c_text, i32(box.x), i32(box.y), i32(text.fontSize), color)
			case .ScissorStart:
				eng.engine_render_begin_scissor(
					engine,
					i32(box.x),
					i32(box.y),
					i32(box.width),
					i32(box.height),
				)
			case .ScissorEnd:
				eng.engine_render_end_scissor(engine)
			case .Border:
				clay_render_border(
					engine,
					box,
					command.renderData.border,
					overlay_stack[:],
					overlay_count,
				)
			case .OverlayColorStart:
				if overlay_count < len(overlay_stack) {
					overlay_stack[overlay_count] = command.renderData.overlayColor.color
					overlay_count += 1
				}
			case .OverlayColorEnd:
				if overlay_count > 0 {
					overlay_count -= 1
				}
			case .Image, .Custom, .None:
				continue
			}
		}
	}

	@(private = "file")
	clay_color_to_engine :: proc(color: clay.Color) -> eng.Engine_Color {
		return eng.engine_color_make(
			u8(clamp(color[0], 0, 255)),
			u8(clamp(color[1], 0, 255)),
			u8(clamp(color[2], 0, 255)),
			u8(clamp(color[3], 0, 255)),
		)
	}

	@(private = "file")
	clay_apply_overlay :: proc(
		color: eng.Engine_Color,
		overlays: []clay.Color,
		overlay_count: int,
	) -> eng.Engine_Color {
		if overlay_count <= 0 {
			return color
		}
		overlay := overlays[overlay_count - 1]
		return eng.engine_color_make(
			u8((u16(color.r) * u16(clamp(overlay[0], 0, 255))) / 255),
			u8((u16(color.g) * u16(clamp(overlay[1], 0, 255))) / 255),
			u8((u16(color.b) * u16(clamp(overlay[2], 0, 255))) / 255),
			u8((u16(color.a) * u16(clamp(overlay[3], 0, 255))) / 255),
		)
	}

	@(private = "file")
	clay_render_border :: proc(
		engine: ^eng.Engine,
		box: clay.BoundingBox,
		border: clay.BorderRenderData,
		overlays: []clay.Color,
		overlay_count: int,
	) {
		color := clay_color_to_engine(border.color)
		color = clay_apply_overlay(color, overlays, overlay_count)
		left := i32(border.width.left)
		right := i32(border.width.right)
		top := i32(border.width.top)
		bottom := i32(border.width.bottom)
		x := i32(box.x)
		y := i32(box.y)
		w := i32(box.width)
		h := i32(box.height)

		if top > 0 {render_draw_rectangle(engine, x, y, w, top, color)}
		if bottom > 0 {render_draw_rectangle(engine, x, y + h - bottom, w, bottom, color)}
		if left > 0 {render_draw_rectangle(engine, x, y, left, h, color)}
		if right > 0 {render_draw_rectangle(engine, x + w - right, y, right, h, color)}
	}
}
