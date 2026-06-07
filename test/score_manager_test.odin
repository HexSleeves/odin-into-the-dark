#+build !js
package main

import eng "./engine"
import "base:runtime"
import "core:testing"

@(test)
score_manager_make_uses_current_score_file :: proc(t: ^testing.T) {
	scores := score_manager_make()

	testing.expect_value(t, scores.file_path, SCORES_FILE)
}

@(test)
score_manager_load_and_save_use_configured_storage :: proc(t: ^testing.T) {
	state := Score_Test_File_System_State {
		read_content = "{\"scores\":[{\"depth\":3,\"kills\":2,\"turns\":10,\"cause\":\"test\"}],\"count\":1}",
	}
	fs := eng.Engine_File_System {
		ctx               = &state,
		read_entire_file  = score_test_file_system_read_entire_file,
		write_entire_file = score_test_file_system_write_entire_file,
		exists            = score_test_file_system_exists,
		remove            = score_test_file_system_remove,
	}
	scores := score_manager_make()
	scores.file_path = "virtual-scores.json"
	scores.storage = eng.storage_manager_make(fs)

	table := score_manager_load(&scores)
	defer score_table_destroy(&table)
	testing.expect_value(t, state.read_count, 1)
	testing.expect_value(t, state.last_path, "virtual-scores.json")
	testing.expect_value(t, table.count, 1)
	testing.expect_value(t, table.scores[0].depth, 3)

	score_manager_save(&scores, &table)
	testing.expect_value(t, state.write_count, 1)
	testing.expect_value(t, state.last_path, "virtual-scores.json")
	testing.expect(t, state.last_write_len > 0)
}

@(test)
score_handlers_accept_manager_or_engine_context :: proc(t: ^testing.T) {
	load_handler: proc(scores: ^Score_Manager) -> Score_Table = score_manager_load
	save_handler: proc(scores: ^Score_Manager, table: ^Score_Table) = score_manager_save
	submit_handler: proc(scores: ^Score_Manager, turns: ^eng.Turn_Manager, game: ^Game) =
		save_run_score
	victory_update: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) -> bool =
		update_victory

	testing.expect(t, load_handler != nil)
	testing.expect(t, save_handler != nil)
	testing.expect(t, submit_handler != nil)
	testing.expect(t, victory_update != nil)
}

Score_Test_File_System_State :: struct {
	read_content:   string,
	last_path:      string,
	last_write_len: int,
	read_count:     int,
	write_count:    int,
}

score_test_file_system_read_entire_file :: proc(
	ctx: rawptr,
	path: string,
	allocator: runtime.Allocator,
) -> (
	[]u8,
	bool,
) {
	state := cast(^Score_Test_File_System_State)ctx
	state.read_count += 1
	state.last_path = path
	buf := make([]u8, len(state.read_content), allocator)
	for i in 0 ..< len(state.read_content) {
		buf[i] = state.read_content[i]
	}
	return buf, true
}

score_test_file_system_write_entire_file :: proc(ctx: rawptr, path: string, data: []u8) -> bool {
	state := cast(^Score_Test_File_System_State)ctx
	state.write_count += 1
	state.last_path = path
	state.last_write_len = len(data)
	return true
}

score_test_file_system_exists :: proc(ctx: rawptr, path: string) -> bool {
	return false
}

score_test_file_system_remove :: proc(ctx: rawptr, path: string) -> bool {
	return false
}

@(test)
save_run_score_works_with_frame_like_context_and_persists_scores :: proc(t: ^testing.T) {
	state := Score_Test_File_System_State{}
	fs := eng.Engine_File_System {
		ctx               = &state,
		read_entire_file  = score_test_file_system_read_entire_file,
		write_entire_file = score_test_file_system_write_entire_file,
		exists            = score_test_file_system_exists,
		remove            = score_test_file_system_remove,
	}
	scores := score_manager_make()
	scores.file_path = "virtual-scores.json"
	scores.storage = eng.storage_manager_make(fs)
	turns := eng.turn_manager_make()
	eng.turn_manager_set(&turns, 12)
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))
	game := game_init(&content)
	defer game_destroy(game)
	game.depth = 2
	game.kills = 3
	game.items_found = 4
	game.death_cause = "allocator test"

	arena: runtime.Arena
	_ = runtime.arena_init(&arena, 1 << 12, runtime.default_allocator())
	defer runtime.arena_destroy(&arena)
	old_context := context
	context.allocator = runtime.arena_allocator(&arena)
	save_run_score(&scores, &turns, game)
	context = old_context

	testing.expect(t, game.score_saved)
	testing.expect_value(t, state.write_count, 1)
	testing.expect(t, state.last_write_len > 0)
}
