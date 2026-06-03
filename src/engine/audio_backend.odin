package engine

// PCM sample descriptor passed from game layer to backend for sound loading.
// The backend owns the loaded sound after this call; the caller owns the sample memory.
Engine_Sound_Desc :: struct {
	samples:     rawptr, // pointer to i16 PCM data
	frame_count: u32,
	sample_rate: u32,
	sample_size: u32, // bits per sample (e.g. 16)
	channels:    u32,
	volume:      f32, // initial volume
}

// Opaque music handle returned by load_music.
Engine_Music_Handle :: rawptr

Engine_Audio_Backend :: struct {
	ctx:               rawptr,
	// ── Device lifecycle ──
	init_audio:        proc(ctx: rawptr) -> bool,
	shutdown_audio:    proc(ctx: rawptr),
	is_audio_ready:    proc(ctx: rawptr) -> bool,
	// ── Sound (SFX) ──
	load_sound:        proc(ctx: rawptr, desc: Engine_Sound_Desc) -> int, // returns sound_id or -1
	unload_sound:      proc(ctx: rawptr, sound_id: int),
	play:              proc(ctx: rawptr, sound_id: int),
	stop:              proc(ctx: rawptr, sound_id: int),
	set_volume:        proc(ctx: rawptr, sound_id: int, volume: f32),
	play_looped:       proc(ctx: rawptr, sound_id: int),
	is_playing:        proc(ctx: rawptr, sound_id: int) -> bool,
	// ── Global ──
	is_enabled:        proc(ctx: rawptr) -> bool,
	set_enabled:       proc(ctx: rawptr, enabled: bool) -> bool,
	toggle:            proc(ctx: rawptr) -> bool,
	set_master_volume: proc(ctx: rawptr, volume: f32),
	update:            proc(ctx: rawptr),
	// ── Music (streaming) ──
	load_music:        proc(
		ctx: rawptr,
		format: string,
		data: rawptr,
		data_len: i32,
	) -> Engine_Music_Handle,
	unload_music:      proc(ctx: rawptr, handle: Engine_Music_Handle),
	play_music:        proc(ctx: rawptr, handle: Engine_Music_Handle),
	stop_music:        proc(ctx: rawptr, handle: Engine_Music_Handle),
	pause_music:       proc(ctx: rawptr, handle: Engine_Music_Handle),
	resume_music:      proc(ctx: rawptr, handle: Engine_Music_Handle),
	set_music_volume:  proc(ctx: rawptr, handle: Engine_Music_Handle, volume: f32),
	update_music:      proc(ctx: rawptr, handle: Engine_Music_Handle),
	is_music_valid:    proc(ctx: rawptr, handle: Engine_Music_Handle) -> bool,
	set_music_looping: proc(ctx: rawptr, handle: Engine_Music_Handle, looping: bool),
	get_frame_time:    proc(ctx: rawptr) -> f32,
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
		init_audio = nil_audio_init,
		shutdown_audio = nil_audio_shutdown,
		is_audio_ready = nil_audio_is_ready,
		load_sound = nil_audio_load_sound,
		unload_sound = nil_audio_unload_sound,
		play = nil_audio_play,
		is_enabled = nil_audio_is_enabled,
		set_enabled = nil_audio_set_enabled,
		toggle = nil_audio_toggle,
		stop = nil_audio_stop,
		set_volume = nil_audio_set_volume,
		set_master_volume = nil_audio_set_master_volume,
		play_looped = nil_audio_play,
		is_playing = nil_audio_is_playing,
		update = nil_audio_update,
		load_music = nil_audio_load_music,
		unload_music = nil_audio_unload_music,
		play_music = nil_audio_play_music,
		stop_music = nil_audio_stop_music,
		pause_music = nil_audio_pause_music,
		resume_music = nil_audio_resume_music,
		set_music_volume = nil_audio_set_music_volume,
		update_music = nil_audio_update_music,
		is_music_valid = nil_audio_is_music_valid,
		set_music_looping = nil_audio_set_music_looping,
		get_frame_time = nil_audio_get_frame_time,
	}
}

// ─── Engine-level dispatch procs ─────────────────────────────────────────────

engine_audio_backend_init_audio :: proc(audio: Engine_Audio_Backend) -> bool {
	backend := engine_audio_backend_or_default(audio)
	if backend.init_audio == nil {return false}
	return backend.init_audio(backend.ctx)
}

engine_audio_backend_shutdown_audio :: proc(audio: Engine_Audio_Backend) {
	backend := engine_audio_backend_or_default(audio)
	if backend.shutdown_audio != nil {
		backend.shutdown_audio(backend.ctx)
	}
}

engine_audio_backend_is_audio_ready :: proc(audio: Engine_Audio_Backend) -> bool {
	backend := engine_audio_backend_or_default(audio)
	if backend.is_audio_ready == nil {return false}
	return backend.is_audio_ready(backend.ctx)
}

engine_audio_backend_load_sound :: proc(
	audio: Engine_Audio_Backend,
	desc: Engine_Sound_Desc,
) -> int {
	backend := engine_audio_backend_or_default(audio)
	if backend.load_sound == nil {return -1}
	return backend.load_sound(backend.ctx, desc)
}

engine_audio_backend_unload_sound :: proc(audio: Engine_Audio_Backend, sound_id: int) {
	backend := engine_audio_backend_or_default(audio)
	if backend.unload_sound != nil {
		backend.unload_sound(backend.ctx, sound_id)
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

engine_audio_backend_is_playing :: proc(audio: Engine_Audio_Backend, sound_id: int) -> bool {
	backend := engine_audio_backend_or_default(audio)
	if backend.is_playing == nil {return false}
	return backend.is_playing(backend.ctx, sound_id)
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

// ─── Music dispatch procs ────────────────────────────────────────────────────

engine_audio_backend_load_music :: proc(
	audio: Engine_Audio_Backend,
	format: string,
	data: rawptr,
	data_len: i32,
) -> Engine_Music_Handle {
	backend := engine_audio_backend_or_default(audio)
	if backend.load_music == nil {return nil}
	return backend.load_music(backend.ctx, format, data, data_len)
}

engine_audio_backend_unload_music :: proc(
	audio: Engine_Audio_Backend,
	handle: Engine_Music_Handle,
) {
	backend := engine_audio_backend_or_default(audio)
	if backend.unload_music != nil {
		backend.unload_music(backend.ctx, handle)
	}
}

engine_audio_backend_play_music :: proc(audio: Engine_Audio_Backend, handle: Engine_Music_Handle) {
	backend := engine_audio_backend_or_default(audio)
	if backend.play_music != nil {
		backend.play_music(backend.ctx, handle)
	}
}

engine_audio_backend_stop_music :: proc(audio: Engine_Audio_Backend, handle: Engine_Music_Handle) {
	backend := engine_audio_backend_or_default(audio)
	if backend.stop_music != nil {
		backend.stop_music(backend.ctx, handle)
	}
}

engine_audio_backend_pause_music :: proc(
	audio: Engine_Audio_Backend,
	handle: Engine_Music_Handle,
) {
	backend := engine_audio_backend_or_default(audio)
	if backend.pause_music != nil {
		backend.pause_music(backend.ctx, handle)
	}
}

engine_audio_backend_resume_music :: proc(
	audio: Engine_Audio_Backend,
	handle: Engine_Music_Handle,
) {
	backend := engine_audio_backend_or_default(audio)
	if backend.resume_music != nil {
		backend.resume_music(backend.ctx, handle)
	}
}

engine_audio_backend_set_music_volume :: proc(
	audio: Engine_Audio_Backend,
	handle: Engine_Music_Handle,
	volume: f32,
) {
	backend := engine_audio_backend_or_default(audio)
	if backend.set_music_volume != nil {
		backend.set_music_volume(backend.ctx, handle, volume)
	}
}

engine_audio_backend_update_music :: proc(
	audio: Engine_Audio_Backend,
	handle: Engine_Music_Handle,
) {
	backend := engine_audio_backend_or_default(audio)
	if backend.update_music != nil {
		backend.update_music(backend.ctx, handle)
	}
}

engine_audio_backend_is_music_valid :: proc(
	audio: Engine_Audio_Backend,
	handle: Engine_Music_Handle,
) -> bool {
	backend := engine_audio_backend_or_default(audio)
	if backend.is_music_valid == nil {return false}
	return backend.is_music_valid(backend.ctx, handle)
}

engine_audio_backend_set_music_looping :: proc(
	audio: Engine_Audio_Backend,
	handle: Engine_Music_Handle,
	looping: bool,
) {
	backend := engine_audio_backend_or_default(audio)
	if backend.set_music_looping != nil {
		backend.set_music_looping(backend.ctx, handle, looping)
	}
}

engine_audio_backend_get_frame_time :: proc(audio: Engine_Audio_Backend) -> f32 {
	backend := engine_audio_backend_or_default(audio)
	if backend.get_frame_time == nil {return 0}
	return backend.get_frame_time(backend.ctx)
}

// ─── Nil implementations ─────────────────────────────────────────────────────

@(private = "file")
nil_audio_init :: proc(ctx: rawptr) -> bool {return false}

@(private = "file")
nil_audio_shutdown :: proc(ctx: rawptr) {}

@(private = "file")
nil_audio_is_ready :: proc(ctx: rawptr) -> bool {return false}

@(private = "file")
nil_audio_load_sound :: proc(ctx: rawptr, desc: Engine_Sound_Desc) -> int {return -1}

@(private = "file")
nil_audio_unload_sound :: proc(ctx: rawptr, sound_id: int) {}

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

@(private = "file")
nil_audio_is_playing :: proc(ctx: rawptr, sound_id: int) -> bool {return false}

@(private = "file")
nil_audio_load_music :: proc(
	ctx: rawptr,
	format: string,
	data: rawptr,
	data_len: i32,
) -> Engine_Music_Handle {return nil}

@(private = "file")
nil_audio_unload_music :: proc(ctx: rawptr, handle: Engine_Music_Handle) {}

@(private = "file")
nil_audio_play_music :: proc(ctx: rawptr, handle: Engine_Music_Handle) {}

@(private = "file")
nil_audio_stop_music :: proc(ctx: rawptr, handle: Engine_Music_Handle) {}

@(private = "file")
nil_audio_pause_music :: proc(ctx: rawptr, handle: Engine_Music_Handle) {}

@(private = "file")
nil_audio_resume_music :: proc(ctx: rawptr, handle: Engine_Music_Handle) {}

@(private = "file")
nil_audio_set_music_volume :: proc(ctx: rawptr, handle: Engine_Music_Handle, volume: f32) {}

@(private = "file")
nil_audio_update_music :: proc(ctx: rawptr, handle: Engine_Music_Handle) {}

@(private = "file")
nil_audio_is_music_valid :: proc(ctx: rawptr, handle: Engine_Music_Handle) -> bool {return false}

@(private = "file")
nil_audio_set_music_looping :: proc(ctx: rawptr, handle: Engine_Music_Handle, looping: bool) {}

@(private = "file")
nil_audio_get_frame_time :: proc(ctx: rawptr) -> f32 {return 0}
