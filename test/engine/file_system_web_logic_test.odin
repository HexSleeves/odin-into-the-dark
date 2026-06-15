#+build !js
package engine

import "core:testing"

// These tests exercise the web (localStorage) backend's read-assembly logic with
// fake JS shims. The real `#+build js` FFI wrappers (file_system_web.odin) are
// thin passthroughs to these procs, so the orchestration is what carries risk:
// missing keys, empty payloads, and short/over-large copies.

@(private = "file")
Fake_Web_FS :: struct {
	content:          []u8,
	present:          bool,
	read_len_calls:   int,
	read_into_call:   int,
	// When set, read_into reports this many bytes written instead of len(buf),
	// simulating a value that changed between the length query and the copy.
	override_written: int,
	use_override:     bool,
}

@(private = "file")
g_fake: Fake_Web_FS

@(private = "file")
fake_read_len :: proc "contextless" (path: string) -> int {
	g_fake.read_len_calls += 1
	if !g_fake.present {
		return -1
	}
	return len(g_fake.content)
}

@(private = "file")
fake_read_into :: proc "contextless" (path: string, buf: []u8) -> int {
	g_fake.read_into_call += 1
	if !g_fake.present {
		return -1
	}
	n := copy(buf, g_fake.content)
	if g_fake.use_override {
		return g_fake.override_written
	}
	return n
}

@(test)
web_fs_read_returns_stored_bytes :: proc(t: ^testing.T) {
	payload := [?]u8{'s', 'a', 'v', 'e', 0, 'd', 'a', 't', 'a'}
	g_fake = Fake_Web_FS {
		content = payload[:],
		present = true,
	}
	buf, ok := web_fs_read_with("save.dat", fake_read_len, fake_read_into, context.allocator)
	defer delete(buf, context.allocator)

	testing.expect(t, ok)
	testing.expect_value(t, len(buf), len(payload))
	for i in 0 ..< len(payload) {
		testing.expect_value(t, buf[i], payload[i])
	}
	testing.expect_value(t, g_fake.read_len_calls, 1)
	testing.expect_value(t, g_fake.read_into_call, 1)
}

@(test)
web_fs_read_reports_missing_key_as_not_found :: proc(t: ^testing.T) {
	g_fake = Fake_Web_FS {
		present = false,
	}
	buf, ok := web_fs_read_with("missing.dat", fake_read_len, fake_read_into, context.allocator)

	testing.expect(t, !ok)
	testing.expect_value(t, len(buf), 0)
	// Must not attempt the copy phase when the key is absent.
	testing.expect_value(t, g_fake.read_into_call, 0)
}

@(test)
web_fs_read_handles_empty_payload :: proc(t: ^testing.T) {
	g_fake = Fake_Web_FS {
		content = {},
		present = true,
	}
	buf, ok := web_fs_read_with("empty.dat", fake_read_len, fake_read_into, context.allocator)
	defer delete(buf, context.allocator)

	testing.expect(t, ok)
	testing.expect_value(t, len(buf), 0)
	// Zero-length value needs no copy phase.
	testing.expect_value(t, g_fake.read_into_call, 0)
}

@(test)
web_fs_read_fails_when_copy_is_short :: proc(t: ^testing.T) {
	payload := [?]u8{1, 2, 3, 4}
	g_fake = Fake_Web_FS {
		content          = payload[:],
		present          = true,
		use_override     = true,
		override_written = 2, // value shrank between length query and copy
	}
	buf, ok := web_fs_read_with("racey.dat", fake_read_len, fake_read_into, context.allocator)

	testing.expect(t, !ok)
	testing.expect_value(t, len(buf), 0)
}

@(test)
web_fs_read_rejects_nil_shims :: proc(t: ^testing.T) {
	buf, ok := web_fs_read_with("x", nil, nil, context.allocator)
	testing.expect(t, !ok)
	testing.expect_value(t, len(buf), 0)
}
