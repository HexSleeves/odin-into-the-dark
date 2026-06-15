package main

import gameio "./io"
import "core:mem"

@(private = "file")
_debug_tracking_import_anchor :: proc() {
	_ = mem.Tracking_Allocator{}
	_ = gameio.perf_stats_set_alloc_deltas
}

// ─── Debug tracking allocator ─────────────────────────────────────────────────
//
// Wraps the process heap allocator with a mem.Tracking_Allocator so the debug
// overlay can surface per-frame allocation/free counts and a live-allocation
// total (a coarse leak gauge). Compiled only under DEBUG_OVERLAY; release builds
// run on the unwrapped allocator with zero overhead.
//
// Lifecycle: debug_tracking_install (in main) swaps context.allocator before the
// game loop, debug_tracking_sample runs once per frame from game_app_update to
// fold deltas into the perf stats, and debug_tracking_report dumps any leaks at
// shutdown.

when DEBUG_OVERLAY {

	@(private = "file")
	g_track: mem.Tracking_Allocator

	@(private = "file")
	g_track_installed: bool

	@(private = "file")
	g_prev_allocs: i64

	@(private = "file")
	g_prev_frees: i64

	// debug_tracking_install wraps the current context allocator with a tracking
	// allocator and returns it. Call from main() and assign context.allocator =
	// debug_tracking_install() for the duration of the game loop.
	debug_tracking_install :: proc() -> mem.Allocator {
		mem.tracking_allocator_init(&g_track, context.allocator)
		g_track_installed = true
		return mem.tracking_allocator(&g_track)
	}

	// debug_tracking_sample folds per-frame allocator activity into the perf stats
	// for the overlay: allocs and frees since the previous sample plus the current
	// live-allocation count.
	debug_tracking_sample :: proc() {
		if !g_track_installed {return}
		allocs := g_track.total_allocation_count
		frees := g_track.total_free_count
		gameio.perf_stats_set_alloc_deltas(
			int(allocs - g_prev_allocs),
			int(frees - g_prev_frees),
			len(g_track.allocation_map),
		)
		g_prev_allocs = allocs
		g_prev_frees = frees
	}

	// debug_tracking_report logs any leaked allocations and tears down the
	// tracking allocator. Call once after the game loop exits.
	debug_tracking_report :: proc() {
		if !g_track_installed {return}
		for _, entry in g_track.allocation_map {
			gameio.logger_warnf(.App, "leak: %d bytes @ %v", entry.size, entry.location)
		}
		if len(g_track.bad_free_array) > 0 {
			for bf in g_track.bad_free_array {
				gameio.logger_warnf(.App, "bad free @ %v", bf.location)
			}
		}
		mem.tracking_allocator_destroy(&g_track)
		g_track_installed = false
	}

} else {

	// Release stubs: zero cost, never installed.
	debug_tracking_sample :: proc() {}
	debug_tracking_report :: proc() {}
}
