#+build js
package main

// JS-only re-exports: the karl2d platform backends live in `io`'s `#+build js`
// file (karl2d_backend.odin) and are wired into the engine config on web.
import gameio "./io"

karl2d_render_backend :: gameio.karl2d_render_backend
karl2d_input_backend :: gameio.karl2d_input_backend
karl2d_texture_backend :: gameio.karl2d_texture_backend
karl2d_platform_backend :: gameio.karl2d_platform_backend
