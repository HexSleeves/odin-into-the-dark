package gameplay

import gcore "../core"
import gameio "../io"
import "core:log"

compute_fov :: proc(game: ^Game) {
	gcore.compute_fov(game)
	if gameio.logger_should_log(gameio.logger_state(), log.Level.Debug, .Fov) {
		visible_count := 0
		for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
			if gcore.tile_visible_idx(game, i) {visible_count += 1}
		}
		logger_debugf(
			.Fov,
			"recomputed: %v tiles visible (radius=%v)",
			visible_count,
			game.player.light_radius + game.light_boost_bonus + effective_light_bonus(game),
		)
	}
}
