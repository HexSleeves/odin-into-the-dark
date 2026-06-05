package audio

import eng "../engine"
import "core:math"

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

@(private = "file")
generate_tone_samples :: proc(
	frequency: f32,
	duration: f32,
	volume: f32,
	sample_rate: u32 = 44100,
) -> (
	samples: []i16,
	frame_count: u32,
) {
	frame_count = u32(duration * f32(sample_rate))
	samples = make([]i16, frame_count)
	for i in 0 ..< frame_count {
		t := f32(i) / f32(sample_rate)
		envelope := 1.0 - f32(i) / f32(frame_count)
		sample := math.sin(2.0 * math.PI * frequency * t) * volume * envelope
		samples[i] = i16(sample * 32000.0)
	}
	return
}

@(private = "file")
generate_noise_samples :: proc(
	duration: f32,
	volume: f32,
	sample_rate: u32 = 44100,
) -> (
	samples: []i16,
	frame_count: u32,
) {
	frame_count = u32(duration * f32(sample_rate))
	samples = make([]i16, frame_count)
	seed: u32 = 12345
	for i in 0 ..< frame_count {
		seed = seed * 1103515245 + 12345
		noise := f32(i16(seed >> 16)) / 32768.0
		envelope := 1.0 - f32(i) / f32(frame_count)
		samples[i] = i16(noise * volume * envelope * 32000.0)
	}
	return
}

@(private = "file")
load_generated_sound :: proc(
	backend: eng.Engine_Audio_Backend,
	samples: []i16,
	frame_count: u32,
	volume: f32,
) -> int {
	desc := eng.Engine_Sound_Desc {
		samples     = rawptr(raw_data(samples)),
		frame_count = frame_count,
		sample_rate = 44100,
		sample_size = 16,
		channels    = 1,
		volume      = volume,
	}
	id := eng.engine_audio_backend_load_sound(backend, desc)
	delete(samples)
	return id
}

@(private = "file")
load_tone :: proc(
	backend: eng.Engine_Audio_Backend,
	frequency: f32,
	duration: f32,
	volume: f32,
	final_volume: f32,
) -> int {
	samples, frame_count := generate_tone_samples(frequency, duration, volume)
	return load_generated_sound(backend, samples, frame_count, final_volume)
}

@(private = "file")
load_noise :: proc(
	backend: eng.Engine_Audio_Backend,
	duration: f32,
	volume: f32,
	final_volume: f32,
) -> int {
	samples, frame_count := generate_noise_samples(duration, volume)
	return load_generated_sound(backend, samples, frame_count, final_volume)
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

	g_audio.sounds[.Footstep] = load_noise(backend, 0.05, 0.15, 0.3)
	g_audio.sounds[.Hit] = load_tone(backend, 200, 0.1, 0.5, 0.5)
	g_audio.sounds[.Mine] = load_tone(backend, 800, 0.08, 0.4, 0.4)
	g_audio.sounds[.Pickup] = load_tone(backend, 1200, 0.12, 0.3, 0.4)
	g_audio.sounds[.Death] = load_tone(backend, 80, 0.5, 0.6, 0.6)
	g_audio.sounds[.Descent] = load_tone(backend, 300, 0.3, 0.4, 0.5)
	g_audio.sounds[.Water] = load_noise(backend, 0.12, 0.25, 0.35)
	g_audio.sounds[.Boss_Kill] = load_tone(backend, 440, 0.6, 0.7, 0.7)
	g_audio.sounds[.Step_Rubble] = load_noise(backend, 0.06, 0.25, 0.35)
	g_audio.sounds[.Step_Stone] = load_tone(backend, 150, 0.04, 0.2, 0.25)
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
