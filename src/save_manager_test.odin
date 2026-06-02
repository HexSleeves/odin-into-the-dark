package main

import "core:os"
import "core:testing"

@(test)
save_manager_make_uses_current_save_file :: proc(t: ^testing.T) {
	saves := save_manager_make()

	testing.expect_value(t, saves.file_path, SAVE_FILE)
}

@(test)
save_manager_save_exists_uses_configured_path :: proc(t: ^testing.T) {
	saves := Save_Manager{file_path = "/tmp/itd-save-manager-missing.dat"}
	os.remove(saves.file_path)

	testing.expect(t, !save_manager_save_exists(&saves))
}
