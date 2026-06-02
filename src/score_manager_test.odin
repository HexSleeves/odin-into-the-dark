package main

import "core:testing"
import eng "./engine"

@(test)
score_manager_make_uses_current_score_file :: proc(t: ^testing.T) {
	scores := score_manager_make()

	testing.expect_value(t, scores.file_path, SCORES_FILE)
}

@(test)
score_handlers_accept_manager_or_engine_context :: proc(t: ^testing.T) {
	load_handler: proc(scores: ^Score_Manager) -> Score_Table = score_manager_load
	save_handler: proc(scores: ^Score_Manager, table: ^Score_Table) = score_manager_save
	submit_handler: proc(scores: ^Score_Manager, turns: ^eng.Turn_Manager, game: ^Game) = save_run_score
	rows_handler: proc(engine: ^eng.Engine, scores: ^Score_Manager, base_y, row_size, row_h: i32, highlight_rank: int) = draw_score_rows
	game_over_render: proc(engine: ^eng.Engine, game: ^Game) = render_game_over
	victory_render: proc(engine: ^eng.Engine, game: ^Game) = render_victory
	high_scores_render: proc(engine: ^eng.Engine, game: ^Game) = render_high_scores
	victory_update: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) -> bool = update_victory

	testing.expect(t, load_handler != nil)
	testing.expect(t, save_handler != nil)
	testing.expect(t, submit_handler != nil)
	testing.expect(t, rows_handler != nil)
	testing.expect(t, game_over_render != nil)
	testing.expect(t, victory_render != nil)
	testing.expect(t, high_scores_render != nil)
	testing.expect(t, victory_update != nil)
}
