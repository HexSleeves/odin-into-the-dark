package gameio

import "core:log"
import "core:time"

// ─── Lightweight profiling helpers ───────────────────────────────────────────
//
// Usage:
//   t := perf_begin("my_proc")
//   defer perf_end(t)
//
// Zero-cost when the Perf channel is disabled: perf_begin returns an inactive
// timer (active=false, no clock read), and perf_end is a no-op on inactive timers.

Perf_Timer :: struct {
	label:  string,
	start:  time.Tick,
	active: bool,
}

// perf_begin records the start tick when the Perf channel is enabled at Debug
// level OR when the debug overlay is capturing stats. Returns an inactive timer
// otherwise.
perf_begin :: proc(label: string) -> Perf_Timer {
	if !g_perf_capture && !logger_should_log(logger_state(), log.Level.Debug, .Perf) {
		return Perf_Timer{label = label, active = false}
	}
	return Perf_Timer{label = label, start = time.tick_now(), active = true}
}

// perf_end logs elapsed milliseconds if the timer is active, and records the
// timing into the perf-stats table when capture is enabled.
perf_end :: proc(t: Perf_Timer) {
	if !t.active {return}
	ms := time.duration_milliseconds(time.tick_since(t.start))
	if g_perf_capture {
		perf_stats_record(t.label, ms)
	}
	logger_debugf(.Perf, "%s: %.3f ms", t.label, ms)
}

// ─── Debug overlay stats accumulator ─────────────────────────────────────────
//
// A fixed-size, allocation-free table of named channel timings, plus a few
// counters (Dijkstra recomputes, per-frame heap alloc/free deltas). The debug
// overlay reads a snapshot of this each frame. Recording is gated by
// `g_perf_capture` so it stays zero-cost unless the overlay is enabled.

PERF_STATS_MAX_CHANNELS :: 16

Perf_Channel_Stat :: struct {
	label:   string,
	last_ms: f64,
	max_ms:  f64,
	calls:   int,
	used:    bool,
}

Perf_Stats :: struct {
	channels:            [PERF_STATS_MAX_CHANNELS]Perf_Channel_Stat,
	dijkstra_recomputes: int,
	// Per-frame heap allocator deltas, surfaced by the tracking allocator wrapper
	// in debug builds. Zero when no tracking allocator is installed.
	frame_allocs:        int,
	frame_frees:         int,
	live_allocations:    int,
}

@(private = "file")
g_perf_stats: Perf_Stats

// g_perf_capture gates all stats recording. The debug overlay sets it on toggle;
// it defaults to false so non-debug builds and normal play pay nothing.
@(private = "file")
g_perf_capture: bool

// perf_capture_set enables or disables stats recording.
perf_capture_set :: proc(enabled: bool) {
	g_perf_capture = enabled
}

// perf_capture_enabled reports whether stats recording is active.
perf_capture_enabled :: proc() -> bool {
	return g_perf_capture
}

// perf_stats_record folds a single timing into the per-channel table. Channels
// are matched by label; the first free slot is claimed for new labels. Excess
// labels beyond the table capacity are dropped silently.
perf_stats_record :: proc(label: string, ms: f64) {
	free_idx := -1
	for i in 0 ..< PERF_STATS_MAX_CHANNELS {
		c := &g_perf_stats.channels[i]
		if c.used && c.label == label {
			c.last_ms = ms
			c.calls += 1
			if ms > c.max_ms {c.max_ms = ms}
			return
		}
		if !c.used && free_idx < 0 {free_idx = i}
	}
	if free_idx >= 0 {
		g_perf_stats.channels[free_idx] = Perf_Channel_Stat {
			label   = label,
			last_ms = ms,
			max_ms  = ms,
			calls   = 1,
			used    = true,
		}
	}
}

// perf_count_dijkstra_recompute bumps the Dijkstra recompute counter. Always
// cheap; callers may invoke it unconditionally.
perf_count_dijkstra_recompute :: proc() {
	g_perf_stats.dijkstra_recomputes += 1
}

// perf_stats_set_alloc_deltas records per-frame heap allocator activity for the
// overlay. Called by the debug tracking-allocator wrapper.
perf_stats_set_alloc_deltas :: proc(allocs, frees, live: int) {
	g_perf_stats.frame_allocs = allocs
	g_perf_stats.frame_frees = frees
	g_perf_stats.live_allocations = live
}

// perf_stats_snapshot returns a copy of the current stats for read-only display.
perf_stats_snapshot :: proc() -> Perf_Stats {
	return g_perf_stats
}

// perf_stats_reset clears all accumulated timings and counters.
perf_stats_reset :: proc() {
	g_perf_stats = Perf_Stats{}
}
