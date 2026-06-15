package engine

import "base:runtime"

// Backend-agnostic orchestration for the web (localStorage) file system.
//
// The actual localStorage access happens in JS (see file_system_web.odin +
// file_system_web.js), but the read protocol — query the decoded length, then
// copy bytes into a WASM-allocated buffer — is pure slice logic. Keeping it here
// (with no build tag and no JS imports) lets the headless desktop test runner
// exercise it via fake shims, since `#+build js` files never compile under
// `odin test`.

// Web_FS_Read_Len returns the decoded byte length stored at path, or -1 when the
// key is absent (or cannot be decoded). `contextless` to match the JS foreign procs.
Web_FS_Read_Len :: #type proc "contextless" (path: string) -> int

// Web_FS_Read_Into decodes the value at path into buf and returns the number of
// bytes written, or -1 on failure (key vanished, buffer too small, bad decode).
Web_FS_Read_Into :: #type proc "contextless" (path: string, buf: []u8) -> int

// web_fs_read_with assembles a read result from the two-phase JS protocol.
// It allocates the destination buffer in `allocator` (i.e. WASM memory) so the
// caller owns the returned slice exactly like the desktop os.read_entire_file.
web_fs_read_with :: proc(
	path: string,
	read_len: Web_FS_Read_Len,
	read_into: Web_FS_Read_Into,
	allocator: runtime.Allocator,
) -> (
	[]u8,
	bool,
) {
	if read_len == nil || read_into == nil {
		return nil, false
	}
	n := read_len(path)
	if n < 0 {
		return nil, false
	}
	if n == 0 {
		// Empty payload: present but zero-length. Return a valid empty slice.
		return make([]u8, 0, allocator), true
	}
	buf, err := make([]u8, n, allocator)
	if err != nil {
		return nil, false
	}
	written := read_into(path, buf)
	if written != n {
		delete(buf, allocator)
		return nil, false
	}
	return buf, true
}
