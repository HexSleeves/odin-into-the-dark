#+build !js
package main

import "core:os"
import "core:strings"
import "core:testing"

@(test)
saveload_does_not_depend_on_global_data_registry :: proc(t: ^testing.T) {
	source, read_err := os.read_entire_file("src/io/save_restore.odin", context.allocator)
	testing.expect(t, read_err == nil)
	if read_err != nil {
		return
	}
	defer delete(source, context.allocator)

	testing.expect(t, !strings.contains(string(source), "g_data"))
}
