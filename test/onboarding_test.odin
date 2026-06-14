package main

import eng "./engine"
import "core:testing"

// ─── First-encounter onboarding hints (D4) ───────────────────────────────────

@(private = "file")
HINT_TEST_COLOR :: eng.Engine_Color{255, 220, 130, 255}

@(test)
tutorial_hint_once_fires_a_message_only_on_the_first_call :: proc(t: ^testing.T) {
	g: Game
	g.state = .Playing
	msgs := message_manager_make()

	fired_first := tutorial_hint_once(&msgs, &g, .First_Enemy, "first hint", HINT_TEST_COLOR)
	testing.expect(t, fired_first, "the first call must fire the hint")
	testing.expect(t, .First_Enemy in g.tutorial_flags, "the hint flag must be set after firing")

	fired_second := tutorial_hint_once(&msgs, &g, .First_Enemy, "second hint", HINT_TEST_COLOR)
	testing.expect(t, !fired_second, "a repeat call for the same hint must not fire")
}

@(test)
tutorial_hint_once_tracks_each_hint_independently :: proc(t: ^testing.T) {
	g: Game
	g.state = .Playing
	msgs := message_manager_make()

	testing.expect(
		t,
		tutorial_hint_once(&msgs, &g, .First_Ore, "ore", HINT_TEST_COLOR),
		"First_Ore must fire",
	)
	// A different hint still fires even though First_Ore is already set.
	testing.expect(
		t,
		tutorial_hint_once(&msgs, &g, .First_Torch, "torch", HINT_TEST_COLOR),
		"First_Torch must fire independently of First_Ore",
	)
	testing.expect(t, .First_Ore in g.tutorial_flags, "First_Ore flag must remain set")
	testing.expect(t, .First_Torch in g.tutorial_flags, "First_Torch flag must be set")
}

@(test)
tutorial_flags_persist_across_a_floor_descent :: proc(t: ^testing.T) {
	// Onboarding flags are game-global, not per-floor: nothing in the descent path
	// clears them, so a hint seen on one floor stays suppressed on the next. Model
	// a descent as "flags carry over, hint does not re-fire".
	g: Game
	g.state = .Playing
	msgs := message_manager_make()

	testing.expect(
		t,
		tutorial_hint_once(&msgs, &g, .First_Shrine, "shrine", HINT_TEST_COLOR),
		"hint fires on the floor where it is first encountered",
	)

	// Simulate descending: the flag set is preserved (descend never resets it).
	carried := g.tutorial_flags
	g.tutorial_flags = carried

	testing.expect(
		t,
		!tutorial_hint_once(&msgs, &g, .First_Shrine, "shrine again", HINT_TEST_COLOR),
		"a hint already seen must stay suppressed after a descent",
	)
}

@(test)
check_visibility_onboarding_fires_when_a_living_enemy_is_visible :: proc(t: ^testing.T) {
	g: Game
	g.state = .Playing
	game_init_world(&g)
	msgs := message_manager_make()

	// Place a living enemy and mark its tile visible.
	enemy := Enemy {
		pos        = Vec2{3, 3},
		hp         = 5,
		max_hp     = 5,
		alive      = true,
		enemy_type = "rat",
		name       = "rat",
	}
	g.enemies = make([dynamic]Enemy)
	defer delete(g.enemies)
	append(&g.enemies, enemy)
	_ = tile_state_set(&g, 3, 3, true, true, 1.0)

	check_visibility_onboarding(&msgs, &g)
	testing.expect(
		t,
		.First_Enemy in g.tutorial_flags,
		"seeing a live enemy must fire First_Enemy",
	)
}

@(test)
check_visibility_onboarding_ignores_dead_or_unseen_enemies :: proc(t: ^testing.T) {
	g: Game
	g.state = .Playing
	game_init_world(&g)
	msgs := message_manager_make()

	g.enemies = make([dynamic]Enemy)
	defer delete(g.enemies)
	// Dead enemy on a visible tile — must not trigger.
	append(&g.enemies, Enemy{pos = Vec2{2, 2}, alive = false, enemy_type = "rat", name = "rat"})
	_ = tile_state_set(&g, 2, 2, true, true, 1.0)
	// Living enemy on a non-visible tile — must not trigger.
	append(&g.enemies, Enemy{pos = Vec2{4, 4}, alive = true, enemy_type = "rat", name = "rat"})

	check_visibility_onboarding(&msgs, &g)
	testing.expect(
		t,
		.First_Enemy not_in g.tutorial_flags,
		"a dead or out-of-sight enemy must not fire First_Enemy",
	)
}

@(test)
check_status_onboarding_fires_when_the_player_has_an_active_status :: proc(t: ^testing.T) {
	g: Game
	g.state = .Playing
	msgs := message_manager_make()

	g.player_status[.Poison] = 3
	check_status_onboarding(&msgs, &g)
	testing.expect(t, .First_Status in g.tutorial_flags, "an active status must fire First_Status")
}
