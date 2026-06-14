package gameplay

import eng "../engine"
import "base:runtime"
import "core:strings"

save_run_score :: proc(scores: ^Score_Manager, turns: ^eng.Turn_Manager, game: ^Game) {
	old_context := context
	context.allocator = runtime.default_allocator()
	defer {
		context = old_context
	}

	game.score_saved = true
	table := score_manager_load(scores)
	defer score_table_destroy(&table)
	cause := ""
	if len(game.death_cause) > 0 {
		cloned, clone_err := strings.clone(game.death_cause, context.allocator)
		if clone_err == nil {
			cause = cloned
		}
	}
	entry := Score_Entry {
		depth       = game.depth,
		kills       = game.kills,
		turns       = eng.turn_manager_current(turns),
		items_found = game.items_found,
		cause       = cause,
	}
	game.last_score_rank = insert_score(&table, entry)
	if game.last_score_rank < 0 && len(cause) > 0 {
		delete(cause, context.allocator)
	}
	// score_manager_save refreshes the manager's write-through cache, so the next
	// scores overlay sees this entry without re-reading disk.
	score_manager_save(scores, &table)
}
