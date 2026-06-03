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
	Water,
	Boss_Kill,
	Step_Rubble,
	Step_Stone,
}

Game_Audio :: struct {
	sounds:  [Sound_Type]rl.Sound,
	enabled: bool,
	looping: [Sound_Type]bool,
}

Generated_Wave :: struct {
	wave:    rl.Wave,
	samples: []i16,
}

g_audio: Game_Audio

@(private = "file")
generate_tone :: proc(
	frequency: f32,
	duration: f32,
	volume: f32,
	sample_rate: u32 = 44100,
) -> Generated_Wave {
	frame_count := u32(duration * f32(sample_rate))
	samples := make([]i16, frame_count)
	for i in 0 ..< frame_count {
		t := f32(i) / f32(sample_rate)
		envelope := 1.0 - f32(i) / f32(frame_count)
		sample := math.sin(2.0 * math.PI * frequency * t) * volume * envelope
		samples[i] = i16(sample * 32000.0)
	}
	return Generated_Wave {
		wave = rl.Wave {
			frameCount = u32(frame_count),
			sampleRate = u32(sample_rate),
			sampleSize = 16,
			channels = 1,
			data = rawptr(raw_data(samples)),
		},
		samples = samples,
	}
}

@(private = "file")
generate_noise :: proc(duration: f32, volume: f32, sample_rate: u32 = 44100) -> Generated_Wave {
	frame_count := u32(duration * f32(sample_rate))
	samples := make([]i16, frame_count)
	seed: u32 = 12345
	for i in 0 ..< frame_count {
		seed = seed * 1103515245 + 12345
		noise := f32(i16(seed >> 16)) / 32768.0
		envelope := 1.0 - f32(i) / f32(frame_count)
		samples[i] = i16(noise * volume * envelope * 32000.0)
	}
	return Generated_Wave {
		wave = rl.Wave {
			frameCount = u32(frame_count),
			sampleRate = u32(sample_rate),
			sampleSize = 16,
			channels = 1,
			data = rawptr(raw_data(samples)),
		},
		samples = samples,
	}
}

@(private = "file")
load_generated_sound :: proc(gw: Generated_Wave, volume: f32) -> rl.Sound {
	sound := rl.LoadSoundFromWave(gw.wave)
	delete(gw.samples)
	rl.SetSoundVolume(sound, volume)
	return sound
}

audio_init :: proc() {
	rl.InitAudioDevice()
	if !rl.IsAudioDeviceReady() {
		g_audio.enabled = false
		return
	}
	g_audio.enabled = true

	g_audio.sounds[.Footstep] = load_generated_sound(generate_noise(0.05, 0.15), 0.3)
	g_audio.sounds[.Hit] = load_generated_sound(generate_tone(200, 0.1, 0.5), 0.5)
	g_audio.sounds[.Mine] = load_generated_sound(generate_tone(800, 0.08, 0.4), 0.4)
	g_audio.sounds[.Pickup] = load_generated_sound(generate_tone(1200, 0.12, 0.3), 0.4)
	g_audio.sounds[.Death] = load_generated_sound(generate_tone(80, 0.5, 0.6), 0.6)
	g_audio.sounds[.Descent] = load_generated_sound(generate_tone(300, 0.3, 0.4), 0.5)

	// Water: bubbly low-frequency noise splash
	g_audio.sounds[.Water] = load_generated_sound(generate_noise(0.12, 0.25), 0.35)
	g_audio.sounds[.Boss_Kill] = load_generated_sound(generate_tone(440, 0.6, 0.7), 0.7)

	// Tile-specific footstep sounds
	g_audio.sounds[.Step_Rubble] = load_generated_sound(generate_noise(0.06, 0.25), 0.35)
	g_audio.sounds[.Step_Stone] = load_generated_sound(generate_tone(150, 0.04, 0.2), 0.25)
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

audio_set_master_volume :: proc(volume: f32) {
	if !rl.IsAudioDeviceReady() {return}
	rl.SetMasterVolume(clamp(volume, 0, 1))
}
