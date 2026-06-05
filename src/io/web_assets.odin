#+build js
package gameio

// Compile-time embedded assets for web builds.
// On WASM there's no filesystem — all runtime-loaded assets must be #load'd.
// The texture backend and content manager look up paths in this registry.

@(private = "file")
EMBEDDED_TILESET :: #load("../assets/kenney_1bit.png")

@(private = "file")
Web_Asset_Entry :: struct {
	path: string,
	data: []u8,
}

@(private = "file")
WEB_ASSETS := []Web_Asset_Entry{{"assets/kenney_1bit.png", EMBEDDED_TILESET}}

web_asset_lookup :: proc(path: string) -> ([]u8, bool) {
	for &entry in WEB_ASSETS {
		if entry.path == path {return entry.data, true}
	}
	return nil, false
}
