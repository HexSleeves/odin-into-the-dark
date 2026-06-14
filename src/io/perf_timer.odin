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

// perf_begin records the start tick only when the Perf channel is enabled at
// Debug level. Returns an inactive timer otherwise.
perf_begin :: proc(label: string) -> Perf_Timer {
	if !logger_should_log(logger_state(), log.Level.Debug, .Perf) {
		return Perf_Timer{label = label, active = false}
	}
	return Perf_Timer{label = label, start = time.tick_now(), active = true}
}

// perf_end logs elapsed milliseconds if the timer is active.
perf_end :: proc(t: Perf_Timer) {
	if !t.active {return}
	ms := time.duration_milliseconds(time.tick_since(t.start))
	logger_debugf(.Perf, "%s: %.3f ms", t.label, ms)
}
