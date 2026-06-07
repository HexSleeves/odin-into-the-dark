package renderer

import "core:testing"

@(test)
light_glow_tint_endpoints :: proc(t: ^testing.T) {
	// No boost → faint warm ambient.
	amb := light_glow_tint(0)
	testing.expect_value(t, amb.r, 255)
	testing.expect_value(t, amb.g, 248)
	testing.expect_value(t, amb.b, 236)

	// Full fuel (>= LIGHT_GLOW_FULL) → lamp tint.
	full := light_glow_tint(LIGHT_GLOW_FULL)
	testing.expect_value(t, full.r, 255)
	testing.expect_value(t, full.g, 225)
	testing.expect_value(t, full.b, 190)

	// Very low fuel (1 turn) → close to ember tint, warmer/redder than full.
	low := light_glow_tint(1)
	testing.expect(t, low.b < full.b, "low fuel should be redder (less blue) than full")
}

@(test)
mul_color_scales :: proc(t: ^testing.T) {
	c := mul_color({200, 100, 50, 255}, {255, 128, 0, 255})
	testing.expect_value(t, c.r, 200) // *255/255
	testing.expect_value(t, c.g, 50) // *128/255 = 50.19 -> 50
	testing.expect_value(t, c.b, 0) // *0
	testing.expect_value(t, c.a, 255)
}
