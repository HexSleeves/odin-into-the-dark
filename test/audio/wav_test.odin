#+build !js
package audio

import "core:testing"

@(test)
parse_wav_pcm16_reads_embedded_asset :: proc(t: ^testing.T) {
	wav, ok := parse_wav_pcm16(WAV_HIT)
	defer if ok {delete(wav.samples)}

	testing.expect(t, ok)
	testing.expect_value(t, wav.sample_rate, u32(44100))
	testing.expect_value(t, wav.channels, u32(1))
	testing.expect(t, wav.frame_count > 0)
	testing.expect_value(t, len(wav.samples), int(wav.frame_count))
}

@(test)
parse_wav_pcm16_decodes_known_samples :: proc(t: ^testing.T) {
	// Hand-built 16-bit mono 8000 Hz WAV with two samples: 0x1234, -1 (0xFFFF).
	data := []u8 {
		'R',
		'I',
		'F',
		'F',
		40,
		0,
		0,
		0,
		'W',
		'A',
		'V',
		'E',
		'f',
		'm',
		't',
		' ',
		16,
		0,
		0,
		0,
		1,
		0, // PCM
		1,
		0, // mono
		0x40,
		0x1F,
		0,
		0, // 8000 Hz
		0,
		0x3E,
		0,
		0, // byte rate (unused by parser)
		2,
		0, // block align
		16,
		0, // bits
		'd',
		'a',
		't',
		'a',
		4,
		0,
		0,
		0,
		0x34,
		0x12, // 0x1234
		0xFF,
		0xFF, // -1
	}
	wav, ok := parse_wav_pcm16(data)
	defer if ok {delete(wav.samples)}

	testing.expect(t, ok)
	testing.expect_value(t, wav.sample_rate, u32(8000))
	testing.expect_value(t, wav.channels, u32(1))
	testing.expect_value(t, len(wav.samples), 2)
	testing.expect_value(t, wav.samples[0], i16(0x1234))
	testing.expect_value(t, wav.samples[1], i16(-1))
}

@(test)
parse_wav_pcm16_rejects_non_riff :: proc(t: ^testing.T) {
	_, ok := parse_wav_pcm16([]u8{'N', 'O', 'P', 'E', 0, 0, 0, 0, 'X', 'X', 'X', 'X'})
	testing.expect(t, !ok)
}
