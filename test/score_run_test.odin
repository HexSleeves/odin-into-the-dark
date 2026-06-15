#+build !js
package main

import eng "./engine"
import "core:encoding/json"
import "core:testing"

// ─── D7: numeric run score + victory multiplier ──────────────────────────────

@(test)
compute_run_score_awards_victory_multiplier_and_bonus :: proc(t: ^testing.T) {
	depth := 5
	kills := 12
	items := 4

	base := depth * SCORE_PER_DEPTH + kills * SCORE_PER_KILL + items * SCORE_PER_ITEM

	death_score := compute_run_score(depth, kills, items, false)
	testing.expect_value(t, death_score, base)

	victory_score := compute_run_score(depth, kills, items, true)
	testing.expect_value(t, victory_score, base * VICTORY_MULTIPLIER + VICTORY_BONUS)
	testing.expect(t, victory_score > death_score)
}

@(test)
score_weights_are_tuned_depth_dominant :: proc(t: ^testing.T) {
	// D7: tuned weights. Depth is the dominant scoring axis — one extra floor must
	// outweigh both a single kill and a single picked-up item by a wide margin.
	testing.expect(t, SCORE_PER_DEPTH > SCORE_PER_KILL)
	testing.expect(t, SCORE_PER_KILL >= SCORE_PER_ITEM)
	testing.expect(t, SCORE_PER_DEPTH >= SCORE_PER_KILL * 10)

	// One floor deeper is worth more than a whole inventory of items (12 slots).
	one_floor := compute_run_score(2, 0, 0, false) - compute_run_score(1, 0, 0, false)
	full_inventory := compute_run_score(1, 0, 12, false) - compute_run_score(1, 0, 0, false)
	testing.expect_value(t, one_floor, SCORE_PER_DEPTH)
	testing.expect(t, one_floor > full_inventory)

	// Victory on the same run stats must beat the death score by more than just the
	// flat bonus (the multiplier matters), and all weights stay positive.
	stats_depth, stats_kills, stats_items := 8, 10, 5
	death := compute_run_score(stats_depth, stats_kills, stats_items, false)
	win := compute_run_score(stats_depth, stats_kills, stats_items, true)
	testing.expect(t, death > 0)
	testing.expect(t, win > death + VICTORY_BONUS)
}

@(test)
insert_score_ranks_victory_run_above_deeper_death :: proc(t: ^testing.T) {
	table: Score_Table

	// A deep death run...
	deep_death := Score_Entry {
		depth   = 10,
		kills   = 5,
		victory = false,
		score   = compute_run_score(10, 5, 0, false),
	}
	// ...and a shallower victory run that should still outrank it on score.
	shallow_victory := Score_Entry {
		depth   = 6,
		kills   = 8,
		victory = true,
		score   = compute_run_score(6, 8, 0, true),
	}

	rank_death := insert_score(&table, deep_death)
	rank_victory := insert_score(&table, shallow_victory)

	testing.expect_value(t, rank_death, 0)
	// Victory run scores higher, so it inserts ahead of the death at rank 0.
	testing.expect_value(t, rank_victory, 0)
	testing.expect_value(t, table.scores[0].victory, true)
	testing.expect_value(t, table.scores[1].victory, false)
}

@(test)
score_table_loads_legacy_json_without_score_field :: proc(t: ^testing.T) {
	// Legacy scores.json predates the score/victory fields — json.unmarshal must
	// tolerate their absence (zero value), so no migration is required.
	legacy := `{"scores":[{"depth":3,"kills":2,"turns":10,"items_found":1,"cause":"old"}],"count":1}`

	table: Score_Table
	err := json.unmarshal(transmute([]u8)legacy, &table)
	defer score_table_destroy(&table)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, table.count, 1)
	testing.expect_value(t, table.scores[0].depth, 3)
	testing.expect_value(t, table.scores[0].score, 0)
	testing.expect_value(t, table.scores[0].victory, false)
}

@(test)
save_run_score_records_victory_flag_on_victory_state :: proc(t: ^testing.T) {
	// save_run_score reads game.state to set the victory flag + numeric score.
	g: Game
	game_init_world(&g)
	g.state = .Victory
	g.depth = 12
	g.kills = 20
	g.items_found = 6

	expected := compute_run_score(g.depth, g.kills, g.items_found, true)

	scores := score_manager_make()
	turns := eng.turn_manager_make()
	save_run_score(&scores, &turns, &g)

	// The write-through cache holds the just-saved table; the top entry is this run.
	loaded := score_manager_load(&scores)
	defer score_table_destroy(&loaded)
	testing.expect(t, loaded.count >= 1)
	testing.expect_value(t, loaded.scores[0].victory, true)
	testing.expect_value(t, loaded.scores[0].score, expected)

	score_manager_cache_destroy(&scores)
}
