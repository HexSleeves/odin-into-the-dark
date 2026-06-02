package main

import "core:os"
import "core:testing"
import eng "./engine"

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

@(test)
save_manager_load_accepts_message_manager_context :: proc(t: ^testing.T) {
	save_handler: proc(saves: ^Save_Manager, turns: ^eng.Turn_Manager, game: ^Game) -> bool = save_manager_save_game
	load_handler: proc(saves: ^Save_Manager, content: ^Content_Manager, turns: ^eng.Turn_Manager, camera: ^eng.Camera_Manager, vfx: ^eng.Vfx_Manager, messages: ^Message_Manager, game: ^Game) -> bool = save_manager_load_game

	testing.expect(t, save_handler != nil)
	testing.expect(t, load_handler != nil)
}
