#+build !js
package main

import "core:os"
import "core:strings"

// When launched from a macOS .app bundle, the working directory is "/" —
// assets won't be found. Detect the bundle and chdir to Contents/Resources.
_set_bundle_working_dir :: proc() {
	exe_dir, err := os.get_executable_directory(context.temp_allocator)
	if err != nil {return}

	if strings.contains(exe_dir, ".app/Contents/MacOS") {
		resources := strings.concatenate({exe_dir, "/../Resources"}, context.temp_allocator)
		os.set_working_directory(resources)
	}
}
