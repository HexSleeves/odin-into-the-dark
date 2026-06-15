#+build js
package engine

import "base:runtime"

// WASM file system backed by the browser's localStorage.
//
// Save blobs (~MB) are base64-encoded on the JS side and stored under their path
// as the localStorage key. The JS half lives in file_system_web.js, merged into
// the WebAssembly import object by the page (see scripts/build_karl2d_web.sh and
// the index template). Engine code stays raylib-free; this file imports only the
// foreign "itd_storage" module.
//
// Read uses a two-phase protocol (length, then copy) so the decoded bytes land
// in a WASM-allocated buffer the caller owns — see web_fs_read_with in
// file_system_web_logic.odin for the (headlessly tested) orchestration.

foreign import itd_storage "itd_storage"

@(default_calling_convention = "contextless")
foreign itd_storage {
	// Returns the decoded byte length stored at `path`, or -1 if absent.
	@(link_name = "itd_ls_read_len")
	js_ls_read_len :: proc(path: string) -> int ---
	// Decodes the value at `path` into `buf`; returns bytes written or -1.
	@(link_name = "itd_ls_read_into")
	js_ls_read_into :: proc(path: string, buf: []u8) -> int ---
	// base64-encodes `data` and stores it at key `path`; returns success.
	@(link_name = "itd_ls_write")
	js_ls_write :: proc(path: string, data: []u8) -> bool ---
	@(link_name = "itd_ls_exists")
	js_ls_exists :: proc(path: string) -> bool ---
	@(link_name = "itd_ls_remove")
	js_ls_remove :: proc(path: string) -> bool ---
	@(link_name = "itd_ls_rename")
	js_ls_rename :: proc(old_path, new_path: string) -> bool ---
}

engine_file_system_default :: proc() -> Engine_File_System {
	return Engine_File_System {
		read_entire_file = web_read_entire_file,
		write_entire_file = web_write_entire_file,
		exists = web_exists,
		remove = web_remove,
		rename = web_rename,
	}
}

@(private = "file")
web_read_entire_file :: proc(
	ctx: rawptr,
	path: string,
	allocator: runtime.Allocator,
) -> (
	[]u8,
	bool,
) {
	return web_fs_read_with(path, js_ls_read_len, js_ls_read_into, allocator)
}

@(private = "file")
web_write_entire_file :: proc(ctx: rawptr, path: string, data: []u8) -> bool {
	return js_ls_write(path, data)
}

@(private = "file")
web_exists :: proc(ctx: rawptr, path: string) -> bool {
	return js_ls_exists(path)
}

@(private = "file")
web_remove :: proc(ctx: rawptr, path: string) -> bool {
	return js_ls_remove(path)
}

@(private = "file")
web_rename :: proc(ctx: rawptr, old_path, new_path: string) -> bool {
	return js_ls_rename(old_path, new_path)
}
