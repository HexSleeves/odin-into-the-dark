package audio

// Accessors for package-global audio state, so other packages can wire the
// audio backend without taking the address of these globals directly.

audio_state :: proc() -> ^Game_Audio {
	return &g_audio
}

