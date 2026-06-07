package audio

import gcore "../core"
import eng "../engine"
import "core:math"
import "core:mem"

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
	tracks:        [Music_Tier]eng.Engine_Music_Handle,
	wav_data:      [Music_Tier][]u8, // raw WAV bytes kept alive — backend streams from this pointer
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
	n := len(samples)
	data_size := u32(n * 2) // 16-bit = 2 bytes per sample
	file_size := 44 + data_size
	buf := make([]u8, file_size)

	// RIFF header
	buf[0] = 'R'; buf[1] = 'I'; buf[2] = 'F'; buf[3] = 'F'
	(cast(^u32)&buf[4])^ = file_size - 8
	buf[8] = 'W'; buf[9] = 'A'; buf[10] = 'V'; buf[11] = 'E'

	// fmt chunk
	buf[12] = 'f'; buf[13] = 'm'; buf[14] = 't'; buf[15] = ' '
	(cast(^u32)&buf[16])^ = 16 // chunk size
	(cast(^u16)&buf[20])^ = 1 // PCM
	(cast(^u16)&buf[22])^ = 1 // mono
	(cast(^u32)&buf[24])^ = sample_rate
	(cast(^u32)&buf[28])^ = sample_rate * 2 // byte rate
	(cast(^u16)&buf[32])^ = 2 // block align
	(cast(^u16)&buf[34])^ = 16 // bits per sample

	// data chunk
	buf[36] = 'd'; buf[37] = 'a'; buf[38] = 't'; buf[39] = 'a'
	(cast(^u32)&buf[40])^ = data_size
	mem.copy(&buf[44], raw_data(samples), int(data_size))

	return buf
}

// generate_drone synthesises a dark ambient drone by summing sine waves.
@(private = "file")
generate_drone :: proc(freqs: []f32, amps: []f32, master: f32) -> []u8 {
	frame_count := int(MUSIC_LOOP_SECS * f32(MUSIC_SAMPLE_RATE))
	samples := make([]i16, frame_count)
	for i in 0 ..< frame_count {
		t := f32(i) / f32(MUSIC_SAMPLE_RATE)
		val: f32
		for j in 0 ..< len(freqs) {
			val += math.sin(2.0 * math.PI * freqs[j] * t) * amps[j]
		}
		samples[i] = i16(clamp(val * master, -1, 1) * 32000.0)
	}
	wav := encode_wav(samples, MUSIC_SAMPLE_RATE)
	delete(samples)
	return wav
}

music_init :: proc() {
	if !g_audio.enabled {return}
	backend := g_audio.backend

	// Frequencies chosen so that freq * 4.0 is an integer (clean loop at 4s).
	g_music.wav_data[.Shallow] = generate_drone(
		[]f32{110, 165, 112, 220},
		[]f32{0.50, 0.25, 0.14, 0.08},
		0.85,
	)
	g_music.wav_data[.Mid] = generate_drone(
		[]f32{82.5, 110, 124, 165},
		[]f32{0.55, 0.28, 0.10, 0.05},
		0.85,
	)
	g_music.wav_data[.Deep] = generate_drone(
		[]f32{55, 57, 82.5, 41.25},
		[]f32{0.50, 0.18, 0.22, 0.18},
		0.85,
	)

	for tier in Music_Tier {
		d := g_music.wav_data[tier]
		g_music.tracks[tier] = eng.engine_audio_backend_load_music(
			backend,
			".wav",
			raw_data(d),
			i32(len(d)),
		)
		if !eng.engine_audio_backend_is_music_valid(backend, g_music.tracks[tier]) {
			for rollback in Music_Tier {
				if rollback <= tier {
					if g_music.tracks[rollback] != nil {
						eng.engine_audio_backend_unload_music(backend, g_music.tracks[rollback])
					}
				}
				delete(g_music.wav_data[rollback])
			}
			g_music = {}
			return
		}
		eng.engine_audio_backend_set_music_looping(backend, g_music.tracks[tier], true)
		eng.engine_audio_backend_set_music_volume(backend, g_music.tracks[tier], 0)
	}

	g_music.active = .Shallow
	g_music.pending = .Shallow
	g_music.volume = 0
	g_music.target_volume = MUSIC_MASTER_VOLUME
	g_music.enabled = true
	g_music.initialized = true

	eng.engine_audio_backend_play_music(backend, g_music.tracks[.Shallow])
}

music_cleanup :: proc() {
	if !g_music.initialized && !g_music.enabled {return}
	backend := g_audio.backend
	for tier in Music_Tier {
		eng.engine_audio_backend_unload_music(backend, g_music.tracks[tier])
		delete(g_music.wav_data[tier])
	}
	g_music = {}
}

// music_update must be called once per frame.
music_update :: proc(game: ^gcore.Game) {
	if !g_music.initialized || !g_music.enabled {return}
	backend := g_audio.backend

	dt := eng.engine_audio_backend_get_frame_time(backend)
	desired := music_tier_for_depth(game)

	if desired != g_music.pending {
		g_music.pending = desired
		if desired == g_music.active {
			g_music.target_volume = MUSIC_MASTER_VOLUME
		} else {
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
		eng.engine_audio_backend_stop_music(backend, g_music.tracks[g_music.active])
		g_music.active = g_music.pending
		g_music.target_volume = MUSIC_MASTER_VOLUME
		eng.engine_audio_backend_play_music(backend, g_music.tracks[g_music.active])
	}

	eng.engine_audio_backend_set_music_volume(
		backend,
		g_music.tracks[g_music.active],
		g_music.volume,
	)
	eng.engine_audio_backend_update_music(backend, g_music.tracks[g_music.active])
}

music_toggle :: proc() {
	if !g_music.initialized {return}
	backend := g_audio.backend
	g_music.enabled = !g_music.enabled
	if g_music.enabled {
		g_music.target_volume = MUSIC_MASTER_VOLUME
		eng.engine_audio_backend_resume_music(backend, g_music.tracks[g_music.active])
	} else {
		eng.engine_audio_backend_pause_music(backend, g_music.tracks[g_music.active])
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
music_tier_for_depth :: proc(game: ^gcore.Game) -> Music_Tier {
	#partial switch game.state {
	case .Playing, .Viewing_Inventory, .Viewing_Crafting, .Viewing_Help:
		if game.depth <= 3 do return .Shallow
		if game.depth <= 6 do return .Mid
		return .Deep
	}
	return .Shallow
}
