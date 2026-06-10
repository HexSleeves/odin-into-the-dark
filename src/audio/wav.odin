package audio

// Minimal RIFF/WAVE parser for the canonical format we ship in assets/sounds/:
// 16-bit signed little-endian PCM, mono, 44100 Hz. Chunks are walked so an
// optional LIST/fact chunk from the encoder does not break parsing.

Wav_Pcm :: struct {
	samples:     []i16, // caller owns; delete after handing to the backend
	frame_count: u32,
	sample_rate: u32,
	channels:    u32,
}

@(private = "file")
read_u32_le :: proc(b: []u8, off: int) -> u32 {
	return u32(b[off]) | (u32(b[off + 1]) << 8) | (u32(b[off + 2]) << 16) | (u32(b[off + 3]) << 24)
}

@(private = "file")
read_u16_le :: proc(b: []u8, off: int) -> u16 {
	return u16(b[off]) | (u16(b[off + 1]) << 8)
}

// Parses a 16-bit PCM WAV. Returns ok=false on any malformed/unsupported input.
parse_wav_pcm16 :: proc(data: []u8) -> (wav: Wav_Pcm, ok: bool) {
	if len(data) < 12 {return {}, false}
	if string(data[0:4]) != "RIFF" || string(data[8:12]) != "WAVE" {return {}, false}

	sample_rate: u32 = 0
	channels: u16 = 0
	bits: u16 = 0

	pos := 12
	for pos + 8 <= len(data) {
		id := string(data[pos:pos + 4])
		size := int(read_u32_le(data, pos + 4))
		body := pos + 8
		if body + size > len(data) {size = len(data) - body}

		switch id {
		case "fmt ":
			if size >= 16 {
				channels = read_u16_le(data, body + 2)
				sample_rate = read_u32_le(data, body + 4)
				bits = read_u16_le(data, body + 14)
			}
		case "data":
			if bits != 16 || channels == 0 || sample_rate == 0 {return {}, false}
			n := size / 2
			if n <= 0 {return {}, false}
			samples := make([]i16, n)
			for i in 0 ..< n {
				samples[i] = i16(read_u16_le(data, body + i * 2))
			}
			wav.samples = samples
			wav.frame_count = u32(n) / u32(channels)
			wav.sample_rate = sample_rate
			wav.channels = u32(channels)
			return wav, true
		}

		pos = body + size
		if size % 2 == 1 {pos += 1} 	// RIFF chunks are word-aligned
	}

	return {}, false
}
