package engine

Audio_Manager :: struct {
	backend: Engine_Audio_Backend,
}

audio_manager_make :: proc(backend: Engine_Audio_Backend) -> Audio_Manager {
	return Audio_Manager{backend = engine_audio_backend_or_default(backend)}
}

audio_manager_is_enabled :: proc(audio: ^Audio_Manager) -> bool {
	if audio == nil {
		return false
	}
	return engine_audio_backend_is_enabled(audio.backend)
}

audio_manager_set_enabled :: proc(audio: ^Audio_Manager, enabled: bool) -> bool {
	if audio == nil {
		return false
	}
	return engine_audio_backend_set_enabled(audio.backend, enabled)
}

audio_manager_toggle :: proc(audio: ^Audio_Manager) -> bool {
	if audio == nil {
		return false
	}
	return engine_audio_backend_toggle(audio.backend)
}

audio_manager_play :: proc(audio: ^Audio_Manager, sound_id: int) {
	if audio == nil {
		return
	}
	engine_audio_backend_play(audio.backend, sound_id)
}

audio_manager_stop :: proc(audio: ^Audio_Manager, sound_id: int) {
	if audio == nil {
		return
	}
	engine_audio_backend_stop(audio.backend, sound_id)
}

audio_manager_set_volume :: proc(audio: ^Audio_Manager, sound_id: int, volume: f32) {
	if audio == nil {
		return
	}
	engine_audio_backend_set_volume(audio.backend, sound_id, volume)
}

audio_manager_set_master_volume :: proc(audio: ^Audio_Manager, volume: f32) {
	if audio == nil {
		return
	}
	engine_audio_backend_set_master_volume(audio.backend, volume)
}

audio_manager_play_looped :: proc(audio: ^Audio_Manager, sound_id: int) {
	if audio == nil {
		return
	}
	engine_audio_backend_play_looped(audio.backend, sound_id)
}

audio_manager_update :: proc(audio: ^Audio_Manager) {
	if audio == nil {
		return
	}
	engine_audio_backend_update(audio.backend)
}
