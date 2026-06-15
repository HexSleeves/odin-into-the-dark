#+build !js
package gameio

import "core:testing"

// Covers the perf/debug-overlay stats accumulator added in P8: capture toggle,
// per-channel timing folding, the Dijkstra recompute counter, and the alloc
// deltas surfaced by the tracking allocator.
//
// All assertions live in one test proc because the accumulator is a process
// global; the parallel test runner would otherwise let separate procs race on
// shared state. Within a single proc the calls are strictly sequential.

@(test)
perf_stats_accumulator_behaves :: proc(t: ^testing.T) {
	defer perf_capture_set(false)

	// ── capture toggle round-trips ──
	perf_capture_set(false)
	testing.expect(t, !perf_capture_enabled(), "capture should start disabled")
	perf_capture_set(true)
	testing.expect(t, perf_capture_enabled(), "capture should report enabled after set")
	perf_capture_set(false)
	testing.expect(t, !perf_capture_enabled(), "capture should report disabled after clear")

	// ── repeated labels fold into one channel ──
	perf_stats_reset()
	perf_stats_record("alpha", 1.0)
	perf_stats_record("alpha", 3.0)
	perf_stats_record("beta", 2.0)
	{
		stats := perf_stats_snapshot()
		alpha_seen, beta_seen, used := false, false, 0
		for c in stats.channels {
			if !c.used {continue}
			used += 1
			switch c.label {
			case "alpha":
				alpha_seen = true
				testing.expect(t, c.calls == 2, "alpha should have folded two calls")
				testing.expectf(t, c.last_ms == 3.0, "alpha last_ms = %v", c.last_ms)
				testing.expectf(t, c.max_ms == 3.0, "alpha max_ms = %v", c.max_ms)
			case "beta":
				beta_seen = true
				testing.expect(t, c.calls == 1, "beta should have one call")
			}
		}
		testing.expect(t, alpha_seen && beta_seen, "both channels should be present")
		testing.expect(t, used == 2, "exactly two channels should be used")
	}

	// ── overflow labels are dropped at capacity ──
	perf_stats_reset()
	fillers := [PERF_STATS_MAX_CHANNELS]string {
		"c00",
		"c01",
		"c02",
		"c03",
		"c04",
		"c05",
		"c06",
		"c07",
		"c08",
		"c09",
		"c10",
		"c11",
		"c12",
		"c13",
		"c14",
		"c15",
	}
	for label, i in fillers {
		perf_stats_record(label, f64(i))
	}
	perf_stats_record("overflow", 99.0)
	{
		stats := perf_stats_snapshot()
		used, overflow_seen := 0, false
		for c in stats.channels {
			if c.used {used += 1}
			if c.used && c.label == "overflow" {overflow_seen = true}
		}
		testing.expect(t, used == PERF_STATS_MAX_CHANNELS, "table should stay at capacity")
		testing.expect(t, !overflow_seen, "overflow label should be dropped")
	}

	// ── dijkstra counter + alloc deltas accumulate ──
	perf_stats_reset()
	perf_count_dijkstra_recompute()
	perf_count_dijkstra_recompute()
	perf_count_dijkstra_recompute()
	perf_stats_set_alloc_deltas(12, 5, 7)
	{
		stats := perf_stats_snapshot()
		testing.expect(t, stats.dijkstra_recomputes == 3, "three recomputes expected")
		testing.expect(t, stats.frame_allocs == 12, "frame_allocs mismatch")
		testing.expect(t, stats.frame_frees == 5, "frame_frees mismatch")
		testing.expect(t, stats.live_allocations == 7, "live_allocations mismatch")
	}

	// ── reset clears everything ──
	perf_stats_record("x", 1.0)
	perf_count_dijkstra_recompute()
	perf_stats_set_alloc_deltas(1, 1, 1)
	perf_stats_reset()
	{
		stats := perf_stats_snapshot()
		testing.expect(t, stats.dijkstra_recomputes == 0, "recomputes should reset")
		testing.expect(t, stats.frame_allocs == 0, "allocs should reset")
		for c in stats.channels {
			testing.expect(t, !c.used, "no channel should remain used after reset")
		}
	}

	// ── perf_begin/perf_end record while capturing ──
	perf_stats_reset()
	perf_capture_set(true)
	timer := perf_begin("captured")
	testing.expect(t, timer.active, "perf_begin should be active while capturing")
	perf_end(timer)
	{
		stats := perf_stats_snapshot()
		found := false
		for c in stats.channels {
			if c.used && c.label == "captured" {found = true}
		}
		testing.expect(t, found, "perf_end should record the captured timing")
	}
}
