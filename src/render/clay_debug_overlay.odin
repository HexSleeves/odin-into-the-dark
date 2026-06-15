package renderer

import ui_pkg "../ui"

import gcore "../core"

import eng "../engine"
import gameio "../io"
import "core:fmt"
import clay "libs:clay"

@(private = "file")
_debug_overlay_import_anchor :: proc() {
	_ = ui_pkg.SB_TITLE
	_ = gameio.perf_stats_snapshot
	_ = fmt.tprintf
	_ = clay.ElementDeclaration{}
}

// ─── Debug / perf overlay ─────────────────────────────────────────────────────
//
// A toggleable (F3) floating panel showing FPS / frame-ms, live entity counts,
// the Dijkstra recompute count, per-channel perf_timer timings, and — in builds
// that install the tracking allocator — per-frame heap alloc/free deltas.
//
// Compiled only when DEBUG_OVERLAY is set; release builds never see this code.
// Reads game state and the perf-stats snapshot read-only; no gameplay effect.

when DEBUG_OVERLAY {

	@(private = "file")
	debug_panel_decl :: proc() -> clay.ElementDeclaration {
		return clay.ElementDeclaration {
			layout = {
				sizing = {width = clay.SizingFixed(300), height = clay.SizingFit()},
				padding = {12, 12, 10, 10},
				childGap = 3,
				layoutDirection = .TopToBottom,
			},
			backgroundColor = clay_color(eng.Engine_Color{14, 12, 9, 235}),
			cornerRadius = {6, 6, 6, 6},
			floating = {
				offset = {8, 8},
				attachTo = .Root,
				attachment = {element = .LeftTop, parent = .LeftTop},
				pointerCaptureMode = .Passthrough,
			},
		}
	}

	clay_render_debug_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
		ui := ui_pkg.ui_manager_state(game_engine_ui_manager(engine))
		if ui == nil || !ui.debug_overlay {return}

		delta_ms := f32(0)
		frame_index := 0
		frames := game_engine_frame_manager(engine)
		if frames != nil {
			delta_ms = eng.frame_manager_delta_time(frames^) * 1000.0
			frame_index = eng.frame_manager_index(frames^)
		}
		fps := delta_ms > 0.0001 ? 1000.0 / delta_ms : 0.0

		stats := gameio.perf_stats_snapshot()

		if clay.UI(clay.ID("debug-overlay"))(debug_panel_decl()) {
			clay_text("DEBUG (F3)", 16, ui_pkg.SB_TITLE, CLAY_FONT_ID_BODY)
			clay_debug_line("FPS", fmt.tprintf("%.0f  (%.2f ms)", fps, delta_ms))
			clay_debug_line("Frame", fmt.tprintf("%d", frame_index))
			clay_debug_line(
				"Entities",
				fmt.tprintf("E:%d  I:%d", len(game.enemies), len(game.items)),
			)
			clay_debug_line("Dijkstra", fmt.tprintf("%d recomputes", stats.dijkstra_recomputes))
			clay_debug_line(
				"Heap/frame",
				fmt.tprintf(
					"+%d/-%d  live:%d",
					stats.frame_allocs,
					stats.frame_frees,
					stats.live_allocations,
				),
			)

			any_channel := false
			for i in 0 ..< gameio.PERF_STATS_MAX_CHANNELS {
				if stats.channels[i].used {any_channel = true; break}
			}
			if any_channel {
				clay_debug_section("PERF TIMERS (ms)")
				for i in 0 ..< gameio.PERF_STATS_MAX_CHANNELS {
					c := stats.channels[i]
					if !c.used {continue}
					clay_debug_line(c.label, fmt.tprintf("%.3f  (max %.3f)", c.last_ms, c.max_ms))
				}
			}
		}
	}

	@(private = "file")
	clay_debug_line :: proc(label, value: string) {
		if clay.UI(clay.ID_LOCAL("debug-row"))(
		clay.ElementDeclaration {
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
				layoutDirection = .LeftToRight,
				childGap = 6,
			},
		},
		) {
			if clay.UI(clay.ID_LOCAL("debug-row-label"))(
			clay.ElementDeclaration {
				layout = {sizing = {width = clay.SizingFixed(96), height = clay.SizingFit()}},
			},
			) {clay_text(label, 13, ui_pkg.SB_DIM, CLAY_FONT_ID_BODY)}
			if clay.UI(clay.ID_LOCAL("debug-row-value"))(
			clay.ElementDeclaration {
				layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFit()}},
			},
			) {clay_text(value, 13, ui_pkg.SB_TEXT, CLAY_FONT_ID_BODY)}
		}
	}

	@(private = "file")
	clay_debug_section :: proc(title: string) {
		if clay.UI(clay.ID_LOCAL("debug-section"))(
		clay.ElementDeclaration {
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
				padding = {0, 0, 6, 2},
			},
		},
		) {clay_text(title, 12, ui_pkg.SB_HEADER, CLAY_FONT_ID_BODY)}
	}

} else {

	// No-op stub so callers compile unchanged in release builds.
	clay_render_debug_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
		_ = engine
		_ = game
	}
}
