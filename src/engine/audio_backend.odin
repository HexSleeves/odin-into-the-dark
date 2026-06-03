package engine

Engine_Audio_Backend :: struct {
	ctx:               rawptr,
	play:              proc(ctx: rawptr, sound_id: int),
	is_enabled:        proc(ctx: rawptr) -> bool,
	set_enabled:       proc(ctx: rawptr, enabled: bool) -> bool,
	toggle:            proc(ctx: rawptr) -> bool,
	stop:              proc(ctx: rawptr, sound_id: int),
	set_volume:        proc(ctx: rawptr, sound_id: int, volume: f32),
	set_master_volume: proc(ctx: rawptr, volume: f32),
	play_looped:       proc(ctx: rawptr, sound_id: int),
	update:            proc(ctx: rawptr),
}

engine_audio_backend_is_valid :: proc(audio: Engine_Audio_Backend) -> bool {
	return(
		audio.play != nil &&
		audio.is_enabled != nil &&
		audio.set_enabled != nil &&
		audio.toggle != nil \
	)
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
		stop = nil_audio_stop,
		set_volume = nil_audio_set_volume,
		set_master_volume = nil_audio_set_master_volume,
		play_looped = nil_audio_play,
		update = nil_audio_update,
	}
}

engine_audio_backend_play :: proc(audio: Engine_Audio_Backend, sound_id: int) {
	backend := engine_audio_backend_or_default(audio)
	if !backend.is_enabled(backend.ctx) {
		return
	}
	backend.play(backend.ctx, sound_id)
}

engine_audio_backend_stop :: proc(audio: Engine_Audio_Backend, sound_id: int) {
	backend := engine_audio_backend_or_default(audio)
	if backend.stop == nil {
		return
	}
	backend.stop(backend.ctx, sound_id)
}

engine_audio_backend_set_volume :: proc(audio: Engine_Audio_Backend, sound_id: int, volume: f32) {
	backend := engine_audio_backend_or_default(audio)
	if backend.set_volume == nil {
		return
	}
	backend.set_volume(backend.ctx, sound_id, volume)
}

engine_audio_backend_set_master_volume :: proc(audio: Engine_Audio_Backend, volume: f32) {
	backend := engine_audio_backend_or_default(audio)
	if backend.set_master_volume == nil {
		return
	}
	backend.set_master_volume(backend.ctx, volume)
}

engine_audio_backend_play_looped :: proc(audio: Engine_Audio_Backend, sound_id: int) {
	backend := engine_audio_backend_or_default(audio)
	if !backend.is_enabled(backend.ctx) || backend.play_looped == nil {
		return
	}
	backend.play_looped(backend.ctx, sound_id)
}

engine_audio_backend_update :: proc(audio: Engine_Audio_Backend) {
	backend := engine_audio_backend_or_default(audio)
	if backend.update == nil {
		return
	}
	backend.update(backend.ctx)
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

@(private = "file")
nil_audio_stop :: proc(ctx: rawptr, sound_id: int) {}

@(private = "file")
nil_audio_set_volume :: proc(ctx: rawptr, sound_id: int, volume: f32) {}

@(private = "file")
nil_audio_set_master_volume :: proc(ctx: rawptr, volume: f32) {}

@(private = "file")
nil_audio_update :: proc(ctx: rawptr) {}
