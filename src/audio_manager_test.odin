package main

import "core:testing"

@(test)
audio_manager_make_wraps_current_audio_backend :: proc(t: ^testing.T) {
	audio := audio_manager_make()

	testing.expect(t, audio.backend == &g_audio)
}

@(test)
audio_manager_reports_enabled_state_from_backend :: proc(t: ^testing.T) {
	audio := audio_manager_make()
	was_enabled := g_audio.enabled
	defer g_audio.enabled = was_enabled

	g_audio.enabled = false
	testing.expect(t, !audio_manager_is_enabled(&audio))

	g_audio.enabled = true
	testing.expect(t, audio_manager_is_enabled(&audio))
}

