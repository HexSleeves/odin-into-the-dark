package engine

Engine_Audio_Backend :: struct {
	ctx: rawptr,
	play: proc(ctx: rawptr, sound_id: int),
	is_enabled: proc(ctx: rawptr) -> bool,
	set_enabled: proc(ctx: rawptr, enabled: bool) -> bool,
	toggle: proc(ctx: rawptr) -> bool,
}

engine_audio_backend_is_valid :: proc(audio: Engine_Audio_Backend) -> bool {
	return audio.play != nil &&
	       audio.is_enabled != nil &&
	       audio.set_enabled != nil &&
	       audio.toggle != nil
}

engine_audio_backend_or_default :: proc(audio: Engine_Audio_Backend) -> Engine_Audio_Backend {
	if engine_audio_backend_is_valid(audio) {
		return audio
	}
	return engine_audio_backend_nil()
}

engine_audio_backend_nil :: proc() -> Engine_Audio_Backend {
	return Engine_Audio_Backend {
		play = nil_audio_play,
		is_enabled = nil_audio_is_enabled,
		set_enabled = nil_audio_set_enabled,
		toggle = nil_audio_toggle,
	}
}

engine_audio_backend_play :: proc(audio: Engine_Audio_Backend, sound_id: int) {
	backend := engine_audio_backend_or_default(audio)
	if !backend.is_enabled(backend.ctx) {
		return
	}
	backend.play(backend.ctx, sound_id)
}

engine_audio_backend_is_enabled :: proc(audio: Engine_Audio_Backend) -> bool {
	backend := engine_audio_backend_or_default(audio)
	return backend.is_enabled(backend.ctx)
}

engine_audio_backend_set_enabled :: proc(audio: Engine_Audio_Backend, enabled: bool) -> bool {
	backend := engine_audio_backend_or_default(audio)
	return backend.set_enabled(backend.ctx, enabled)
}

engine_audio_backend_toggle :: proc(audio: Engine_Audio_Backend) -> bool {
	backend := engine_audio_backend_or_default(audio)
	return backend.toggle(backend.ctx)
}

@(private = "file")
nil_audio_play :: proc(ctx: rawptr, sound_id: int) {}

@(private = "file")
nil_audio_is_enabled :: proc(ctx: rawptr) -> bool {
	return false
}

@(private = "file")
nil_audio_set_enabled :: proc(ctx: rawptr, enabled: bool) -> bool {
	return false
}

@(private = "file")
nil_audio_toggle :: proc(ctx: rawptr) -> bool {
	return false
}
