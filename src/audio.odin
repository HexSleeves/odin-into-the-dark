package main

import "core:math"
import rl "vendor:raylib"

Sound_Type :: enum {
	Footstep,
	Hit,
	Mine,
	Pickup,
	Death,
	Descent,
}

Game_Audio :: struct {
	sounds:  [Sound_Type]rl.Sound,
	enabled: bool,
}

g_audio: Game_Audio

@(private = "file")
generate_tone :: proc(
	frequency: f32,
	duration: f32,
	volume: f32,
	sample_rate: u32 = 44100,
) -> rl.Wave {
	frame_count := u32(duration * f32(sample_rate))
	samples := make([]i16, frame_count)
	for i in 0 ..< frame_count {
		t := f32(i) / f32(sample_rate)
		envelope := 1.0 - f32(i) / f32(frame_count)
		sample := math.sin(2.0 * math.PI * frequency * t) * volume * envelope
		samples[i] = i16(sample * 32000.0)
	}
	return rl.Wave {
		frameCount = u32(frame_count),
		sampleRate = u32(sample_rate),
		sampleSize = 16,
		channels = 1,
		data = rawptr(raw_data(samples)),
	}
}

@(private = "file")
generate_noise :: proc(duration: f32, volume: f32, sample_rate: u32 = 44100) -> rl.Wave {
	frame_count := u32(duration * f32(sample_rate))
	samples := make([]i16, frame_count)
	seed: u32 = 12345
	for i in 0 ..< frame_count {
		seed = seed * 1103515245 + 12345
		noise := f32(i16(seed >> 16)) / 32768.0
		envelope := 1.0 - f32(i) / f32(frame_count)
		samples[i] = i16(noise * volume * envelope * 32000.0)
	}
	return rl.Wave {
		frameCount = u32(frame_count),
		sampleRate = u32(sample_rate),
		sampleSize = 16,
		channels = 1,
		data = rawptr(raw_data(samples)),
	}
}

audio_init :: proc() {
	rl.InitAudioDevice()
	if !rl.IsAudioDeviceReady() {
		g_audio.enabled = false
		return
	}
	g_audio.enabled = true

	w := generate_noise(0.05, 0.15)
	g_audio.sounds[.Footstep] = rl.LoadSoundFromWave(w)
	rl.SetSoundVolume(g_audio.sounds[.Footstep], 0.3)

	w = generate_tone(200, 0.1, 0.5)
	g_audio.sounds[.Hit] = rl.LoadSoundFromWave(w)
	rl.SetSoundVolume(g_audio.sounds[.Hit], 0.5)

	w = generate_tone(800, 0.08, 0.4)
	g_audio.sounds[.Mine] = rl.LoadSoundFromWave(w)
	rl.SetSoundVolume(g_audio.sounds[.Mine], 0.4)

	w = generate_tone(1200, 0.12, 0.3)
	g_audio.sounds[.Pickup] = rl.LoadSoundFromWave(w)
	rl.SetSoundVolume(g_audio.sounds[.Pickup], 0.4)

	w = generate_tone(80, 0.5, 0.6)
	g_audio.sounds[.Death] = rl.LoadSoundFromWave(w)
	rl.SetSoundVolume(g_audio.sounds[.Death], 0.6)

	w = generate_tone(300, 0.3, 0.4)
	g_audio.sounds[.Descent] = rl.LoadSoundFromWave(w)
	rl.SetSoundVolume(g_audio.sounds[.Descent], 0.5)
}

audio_cleanup :: proc() {
	if !g_audio.enabled {return}
	for &s in g_audio.sounds {
		rl.UnloadSound(s)
	}
	rl.CloseAudioDevice()
}

play_sfx :: proc(stype: Sound_Type) {
	if !g_audio.enabled {return}
	rl.PlaySound(g_audio.sounds[stype])
}

audio_toggle :: proc() {
	if rl.IsAudioDeviceReady() {
		g_audio.enabled = !g_audio.enabled
	}
}
