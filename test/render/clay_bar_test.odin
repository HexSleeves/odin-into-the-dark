package renderer

import "core:testing"

@(test)
bar_segment_fill_count_rounds_and_clamps :: proc(t: ^testing.T) {
	testing.expect_value(t, bar_segment_fill_count(0.0, 10), 0)
	testing.expect_value(t, bar_segment_fill_count(1.0, 10), 10)
	testing.expect_value(t, bar_segment_fill_count(0.5, 10), 5)
	testing.expect_value(t, bar_segment_fill_count(0.54, 10), 5) // rounds down
	testing.expect_value(t, bar_segment_fill_count(0.55, 10), 6) // rounds up
	testing.expect_value(t, bar_segment_fill_count(-0.3, 10), 0) // clamp low
	testing.expect_value(t, bar_segment_fill_count(2.0, 10), 10) // clamp high
	testing.expect_value(t, bar_segment_fill_count(0.1, 5), 1)
}
