package main

victory_boss_status_text :: proc(game: ^Game) -> cstring {
	if game != nil && game.boss_killed_this_turn {
		return cstring("Defeated")
	}
	return cstring("Not defeated")
}
