package audio

import eng "../engine"

Sound_Type :: enum {
	Footstep,
	Hit,
	Mine,
	Pickup,
	Death,
	Descent,
	Water,
	Boss_Kill,
	Step_Rubble,
	Step_Stone,
}

Game_Audio :: struct {
	sounds:  [Sound_Type]int, // opaque sound IDs from backend
	enabled: bool,
	looping: [Sound_Type]bool,
	backend: eng.Engine_Audio_Backend,
}

g_audio: Game_Audio

// ─── Embedded sound assets ───────────────────────────────────────────────────
//
// CC0 sounds (Kenney RPG Audio + Interface Sounds), normalized to 16-bit mono
// 44100 PCM WAV. See assets/sounds/CREDITS.md. Embedded at compile time so the
// same data ships on desktop and web with no runtime file IO.

@(rodata)
WAV_FOOTSTEP := #load("../../assets/sounds/footstep.wav")
@(rodata)
WAV_HIT := #load("../../assets/sounds/hit.wav")
@(rodata)
WAV_MINE := #load("../../assets/sounds/mine.wav")
@(rodata)
WAV_PICKUP := #load("../../assets/sounds/pickup.wav")
@(rodata)
WAV_DEATH := #load("../../assets/sounds/death.wav")
@(rodata)
WAV_DESCENT := #load("../../assets/sounds/descent.wav")
@(rodata)
WAV_WATER := #load("../../assets/sounds/water.wav")
@(rodata)
WAV_BOSS_KILL := #load("../../assets/sounds/boss_kill.wav")
@(rodata)
WAV_STEP_RUBBLE := #load("../../assets/sounds/step_rubble.wav")
@(rodata)
WAV_STEP_STONE := #load("../../assets/sounds/step_stone.wav")

@(private = "file")
load_wav :: proc(backend: eng.Engine_Audio_Backend, data: []u8, volume: f32) -> int {
	wav, ok := parse_wav_pcm16(data)
	if !ok {return -1}
	desc := eng.Engine_Sound_Desc {
		samples     = rawptr(raw_data(wav.samples)),
		frame_count = wav.frame_count,
		sample_rate = wav.sample_rate,
		sample_size = 16,
		channels    = wav.channels,
		volume      = volume,
	}
	id := eng.engine_audio_backend_load_sound(backend, desc)
	delete(wav.samples)
	return id
}

audio_init :: proc(backend: eng.Engine_Audio_Backend) {
	g_audio.backend = backend
	if !eng.engine_audio_backend_init_audio(backend) {
		g_audio.enabled = false
		return
	}
	if !eng.engine_audio_backend_is_audio_ready(backend) {
		g_audio.enabled = false
		return
	}
	g_audio.enabled = true

	g_audio.sounds[.Footstep] = load_wav(backend, WAV_FOOTSTEP, 0.30)
	g_audio.sounds[.Hit] = load_wav(backend, WAV_HIT, 0.55)
	g_audio.sounds[.Mine] = load_wav(backend, WAV_MINE, 0.50)
	g_audio.sounds[.Pickup] = load_wav(backend, WAV_PICKUP, 0.50)
	g_audio.sounds[.Death] = load_wav(backend, WAV_DEATH, 0.70)
	g_audio.sounds[.Descent] = load_wav(backend, WAV_DESCENT, 0.55)
	g_audio.sounds[.Water] = load_wav(backend, WAV_WATER, 0.40)
	g_audio.sounds[.Boss_Kill] = load_wav(backend, WAV_BOSS_KILL, 0.70)
	g_audio.sounds[.Step_Rubble] = load_wav(backend, WAV_STEP_RUBBLE, 0.30)
	g_audio.sounds[.Step_Stone] = load_wav(backend, WAV_STEP_STONE, 0.30)
}

audio_cleanup :: proc() {
	if !g_audio.enabled {return}
	for &s in g_audio.sounds {
		eng.engine_audio_backend_unload_sound(g_audio.backend, s)
		s = -1
	}
	eng.engine_audio_backend_shutdown_audio(g_audio.backend)
}

play_sfx :: proc(stype: Sound_Type) {
	if !g_audio.enabled {return}
	eng.engine_audio_backend_play(g_audio.backend, g_audio.sounds[stype])
}

audio_toggle :: proc() {
	if eng.engine_audio_backend_is_audio_ready(g_audio.backend) {
		g_audio.enabled = !g_audio.enabled
	}
}

audio_set_master_volume :: proc(volume: f32) {
	if !eng.engine_audio_backend_is_audio_ready(g_audio.backend) {return}
	eng.engine_audio_backend_set_master_volume(g_audio.backend, clamp(volume, 0, 1))
}
