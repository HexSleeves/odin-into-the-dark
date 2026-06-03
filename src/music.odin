package main

import "core:math"
import rl "vendor:raylib"

Music_Tier :: enum u8 {
	Shallow = 0, // depth 1–3  (A2 root, lighter harmonics)
	Mid     = 1, // depth 4–6  (E2 root, darker)
	Deep    = 2, // depth 7+   (A1 root, sub-bass, unsettling beating)
}

MUSIC_MASTER_VOLUME :: f32(0.30)
MUSIC_FADE_SPEED :: f32(1.5) // volume units per second
MUSIC_SAMPLE_RATE :: u32(44100)
MUSIC_LOOP_SECS :: f32(4.0) // all frequencies chosen to complete integer cycles in 4s

Music_Manager :: struct {
	tracks:        [Music_Tier]rl.Music,
	wav_data:      [Music_Tier][]u8, // raw WAV bytes kept alive — Raylib streams from this pointer
	active:        Music_Tier,
	pending:       Music_Tier,
	volume:        f32,
	target_volume: f32,
	enabled:       bool,
	initialized:   bool,
}

g_music: Music_Manager

// encode_wav builds a complete PCM WAV file in memory from mono i16 samples.
// The returned slice is heap-allocated and caller owns it.
@(private = "file")
encode_wav :: proc(samples: []i16, sample_rate: u32) -> []u8 {
	data_size := len(samples) * 2
	total_size := 44 + data_size
	wav := make([]u8, total_size)

	b := wav
	copy(b[0:4], "RIFF")
	riff_size := u32(total_size - 8)
	b[4] = u8(riff_size); b[5] = u8(riff_size >> 8)
	b[6] = u8(riff_size >> 16); b[7] = u8(riff_size >> 24)
	copy(b[8:12], "WAVE")
	copy(b[12:16], "fmt ")
	b[16] = 16; b[17] = 0; b[18] = 0; b[19] = 0 // fmt chunk size = 16
	b[20] = 1; b[21] = 0 // PCM format
	b[22] = 1; b[23] = 0 // mono
	b[24] = u8(sample_rate); b[25] = u8(sample_rate >> 8)
	b[26] = u8(sample_rate >> 16); b[27] = u8(sample_rate >> 24)
	byte_rate := sample_rate * 2
	b[28] = u8(byte_rate); b[29] = u8(byte_rate >> 8)
	b[30] = u8(byte_rate >> 16); b[31] = u8(byte_rate >> 24)
	b[32] = 2; b[33] = 0 // block align = channels * bytes-per-sample
	b[34] = 16; b[35] = 0 // bits per sample
	copy(b[36:40], "data")
	b[40] = u8(data_size); b[41] = u8(data_size >> 8)
	b[42] = u8(data_size >> 16); b[43] = u8(data_size >> 24)

	for i, s in samples {
		u := u16(s)
		wav[44 + i * 2] = u8(u)
		wav[44 + i * 2 + 1] = u8(u >> 8)
	}
	return wav
}

// generate_drone synthesises a dark ambient drone by summing sine waves.
//
// All frequencies MUST complete integer cycles in MUSIC_LOOP_SECS so the
// loop point is seamless (no discontinuity at the wraparound).
//
// freqs/amps are parallel slices — caller passes stack literals.
// Returns WAV bytes (heap-allocated, caller owns).
@(private = "file")
generate_drone :: proc(freqs: []f32, amps: []f32, master: f32) -> []u8 {
	n_samples := int(MUSIC_LOOP_SECS * f32(MUSIC_SAMPLE_RATE))
	samples := make([]i16, n_samples)
	defer delete(samples)

	for i in 0 ..< n_samples {
		t := f32(i) / f32(MUSIC_SAMPLE_RATE)
		s := f32(0)
		for j in 0 ..< len(freqs) {
			s += math.sin(2 * math.PI * freqs[j] * t) * amps[j]
		}
		samples[i] = i16(clamp(s * master, -1.0, 1.0) * 32000.0)
	}
	return encode_wav(samples, MUSIC_SAMPLE_RATE)
}

music_init :: proc() {
	if !g_audio.enabled {return}

	// Frequencies chosen so that freq * 4.0 is an integer (clean loop at 4s).
	//
	// Shallow — A2(110) root, E3(165) fifth, A2+2Hz(112) for 2Hz beating, A3(220) octave.
	// The 112Hz component creates a slow 2Hz tremor against 110Hz — subtle and unsettling.
	g_music.wav_data[.Shallow] = generate_drone(
		[]f32{110, 165, 112, 220},
		[]f32{0.50, 0.25, 0.14, 0.08},
		0.85,
	)

	// Mid — E2(82.5) root, A2(110) fourth, B2-ish(124) tritone colour, E3(165) octave.
	// 124 * 4 = 496 (integer). Lower centre of gravity than Shallow.
	g_music.wav_data[.Mid] = generate_drone(
		[]f32{82.5, 110, 124, 165},
		[]f32{0.55, 0.28, 0.10, 0.05},
		0.85,
	)

	// Deep — A1(55) root, A1+2Hz(57) beating, E2(82.5) fifth, E1 sub(41.25).
	// 57 * 4 = 228 (integer). 41.25 * 4 = 165 (integer). Sub-bass rumble.
	g_music.wav_data[.Deep] = generate_drone(
		[]f32{55, 57, 82.5, 41.25},
		[]f32{0.50, 0.18, 0.22, 0.18},
		0.85,
	)

	for tier in Music_Tier {
		d := g_music.wav_data[tier]
		g_music.tracks[tier] = rl.LoadMusicStreamFromMemory(".wav", raw_data(d), i32(len(d)))
		if !rl.IsMusicValid(g_music.tracks[tier]) {
			g_music.enabled = false
			return
		}
		g_music.tracks[tier].looping = true
		rl.SetMusicVolume(g_music.tracks[tier], 0)
	}

	g_music.active = .Shallow
	g_music.pending = .Shallow
	g_music.volume = 0
	g_music.target_volume = MUSIC_MASTER_VOLUME
	g_music.enabled = true
	g_music.initialized = true

	rl.PlayMusicStream(g_music.tracks[.Shallow])
}

music_cleanup :: proc() {
	if !g_music.initialized {return}
	for tier in Music_Tier {
		rl.UnloadMusicStream(g_music.tracks[tier])
		delete(g_music.wav_data[tier])
	}
	g_music = {}
}

// music_update must be called once per frame.  It handles:
//   • Tier selection based on game state and dungeon depth
//   • Crossfade: fade out → switch → fade in
//   • rl.UpdateMusicStream to keep Raylib's streaming buffer filled
music_update :: proc(game: ^Game) {
	if !g_music.initialized || !g_music.enabled {return}

	dt := rl.GetFrameTime()
	desired := music_tier_for_depth(game)

	if desired != g_music.pending {
		g_music.pending = desired
		if desired == g_music.active {
			// Crossfade cancelled — fade back in to the active track
			g_music.target_volume = MUSIC_MASTER_VOLUME
		} else {
			// Begin fade-out so we can switch
			g_music.target_volume = 0
		}
	}

	// Lerp volume toward target
	diff := g_music.target_volume - g_music.volume
	step := MUSIC_FADE_SPEED * dt
	if abs(diff) <= step {
		g_music.volume = g_music.target_volume
	} else {
		g_music.volume += (1 if diff > 0 else -1) * step
	}

	// Switch tracks once fully silent
	if g_music.volume <= 0 && g_music.pending != g_music.active {
		rl.StopMusicStream(g_music.tracks[g_music.active])
		g_music.active = g_music.pending
		g_music.target_volume = MUSIC_MASTER_VOLUME
		rl.PlayMusicStream(g_music.tracks[g_music.active])
	}

	rl.SetMusicVolume(g_music.tracks[g_music.active], g_music.volume)
	rl.UpdateMusicStream(g_music.tracks[g_music.active])
}

music_toggle :: proc() {
	if !g_music.initialized {return}
	g_music.enabled = !g_music.enabled
	if g_music.enabled {
		g_music.target_volume = MUSIC_MASTER_VOLUME
		rl.ResumeMusicStream(g_music.tracks[g_music.active])
	} else {
		rl.PauseMusicStream(g_music.tracks[g_music.active])
	}
}

music_set_tier_by_depth :: proc(depth: int) {
	if !g_music.initialized || !g_music.enabled {return}
	tier: Music_Tier
	if depth <= 3 {tier = .Shallow} else if depth <= 6 {tier = .Mid} else {tier = .Deep}
	if tier == g_music.pending {return}
	g_music.pending = tier
	if tier == g_music.active {
		g_music.target_volume = MUSIC_MASTER_VOLUME
	} else {
		g_music.target_volume = 0
	}
}

music_set_volume :: proc(volume: f32) {
	if !g_music.initialized {return}
	g_music.target_volume = clamp(volume, 0, 1)
}

@(private = "file")
music_tier_for_depth :: proc(game: ^Game) -> Music_Tier {
	#partial switch game.state {
	case .Playing, .Viewing_Inventory, .Viewing_Crafting, .Viewing_Help:
		if game.depth <= 3 do return .Shallow
		if game.depth <= 6 do return .Mid
		return .Deep
	}
	return .Shallow
}
