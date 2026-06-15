#+build !js
package gameio

import "core:hash"
import "core:mem"
import "core:testing"

// Legacy v2–v11 read support was intentionally dropped (pre-release; no shipped
// save contract). Any non-v12 version must be rejected cleanly rather than
// migrated, so a stale save can never be mem.copy'd into the current layout.
@(test)
load_save_data_rejects_unsupported_legacy_versions :: proc(t: ^testing.T) {
	for old_version in u32(0) ..= u32(11) {
		// Build a v12-sized buffer with a valid CRC, then stamp an old version.
		payload := new(Save_Data)
		defer free(payload)
		payload.depth = 3

		buf := make([]u8, size_of(Save_Header) + size_of(Save_Data))
		defer delete(buf)

		mem.copy(&buf[size_of(Save_Header)], payload, size_of(Save_Data))
		crc := hash.crc32(buf[size_of(Save_Header):])

		header := Save_Header {
			magic   = SAVE_MAGIC,
			version = old_version,
			crc32   = crc,
		}
		mem.copy(&buf[0], &header, size_of(Save_Header))

		data, ok := load_save_data(header, buf)
		testing.expect(t, !ok, "an unsupported legacy version must be rejected")
		testing.expect(t, data == nil, "no data must be returned for an unsupported version")
	}
}
