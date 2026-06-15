package ai

import gameaudio "../audio"
import gcore "../core"
import eng "../engine"
import gameio "../io"
import renderer "../render"
import gameui "../ui"

Game :: gcore.Game
Enemy :: gcore.Enemy
Vec2 :: gcore.Vec2
Content_Manager :: gcore.Content_Manager
Message_Manager :: gameui.Message_Manager
Engine :: eng.Engine

MAP_WIDTH :: gcore.MAP_WIDTH
MAP_HEIGHT :: gcore.MAP_HEIGHT
BASE_ACTION_COST :: gcore.BASE_ACTION_COST
BASE_MOVE_COST :: gcore.BASE_MOVE_COST
DMAP_UNREACHABLE :: gcore.DMAP_UNREACHABLE
DEATH_CAUSE_MAX_LEN :: gcore.DEATH_CAUSE_MAX_LEN
CARDINAL_DX :: gcore.CARDINAL_DX
CARDINAL_DY :: gcore.CARDINAL_DY

ENEMY_BEHAVIOR_LURKER :: gcore.ENEMY_BEHAVIOR_LURKER
ENEMY_ABILITY_WEB :: gcore.ENEMY_ABILITY_WEB
ENEMY_ABILITY_PULL :: gcore.ENEMY_ABILITY_PULL
ENEMY_ABILITY_POISON_CLOUD :: gcore.ENEMY_ABILITY_POISON_CLOUD
ENEMY_ABILITY_TELEPORT :: gcore.ENEMY_ABILITY_TELEPORT
ENEMY_ABILITY_SLAM :: gcore.ENEMY_ABILITY_SLAM
ENEMY_ABILITY_DARKNESS :: gcore.ENEMY_ABILITY_DARKNESS
ENEMY_ABILITY_RANGED_SHOOT :: gcore.ENEMY_ABILITY_RANGED_SHOOT
ENEMY_ABILITY_FREEZE :: gcore.ENEMY_ABILITY_FREEZE

enemy_make_from_def :: gcore.enemy_make_from_def
content_manager_enemy_def :: gcore.content_manager_enemy_def
content_manager_enemy_def_for_depth :: gcore.content_manager_enemy_def_for_depth
is_walkable :: gcore.is_walkable
tile_at :: gcore.tile_at
logger_warnf :: gameio.logger_warnf
spawn_death_particles :: renderer.spawn_death_particles
web_tile_at :: gcore.web_tile_at
web_tile_set :: gcore.web_tile_set
pos_to_idx :: gcore.pos_to_idx
enemy_display_name :: gcore.enemy_display_name
game_grid :: gcore.game_grid
add_message :: gameui.add_message
play_sfx :: gameaudio.play_sfx
game_engine_vfx_manager :: gcore.game_engine_vfx_manager
game_engine_floating_text_manager :: gcore.game_engine_floating_text_manager
logger_debugf :: gameio.logger_debugf

effective_attack :: gcore.effective_attack
apply_kill_milestone_buff :: gcore.apply_kill_milestone_buff
effective_defense :: gcore.effective_defense
rand_room_interior :: gcore.rand_room_interior
player_effective_light_radius :: gcore.player_effective_light_radius
DETECTION_HEARING_RADIUS :: gcore.DETECTION_HEARING_RADIUS

damage_roll :: gcore.damage_roll
crit_roll :: gcore.crit_roll
chance_roll :: gcore.chance_roll
effective_crit_chance :: gcore.effective_crit_chance
CRIT_DAMAGE_MULT_PCT :: gcore.CRIT_DAMAGE_MULT_PCT
FROZEN_SKIP_ATTACK_CHANCE_PCT :: gcore.FROZEN_SKIP_ATTACK_CHANCE_PCT
FROZEN_DAMAGE_PCT :: gcore.FROZEN_DAMAGE_PCT
SLAM_BASE_DAMAGE :: gcore.SLAM_BASE_DAMAGE

status_apply :: gcore.status_apply
status_active :: gcore.status_active

enemy_at :: proc(game: ^Game, x, y: int) -> ^Enemy {
	return gcore.enemy_at(game, x, y)
}

enemy_occupancy_mark_dirty :: gcore.enemy_occupancy_mark_dirty

can_place_enemy :: proc(game: ^Game, x, y: int) -> bool {
	if !is_walkable(game, x, y) {return false}
	if x == game.player.pos.x && y == game.player.pos.y {return false}
	if enemy_at(game, x, y) != nil {return false}
	if t := tile_at(game, x, y); t != nil && t.type == .Descent {return false}
	return true
}

// is_sight_blocking returns true if tile (x,y) blocks line-of-sight.
// Matches the FOV opaque check in gcore.fov_is_opaque: Wall and Locked_Door.
@(private = "package")
is_sight_blocking :: proc(game: ^Game, x, y: int) -> bool {
	t := tile_at(game, x, y)
	if t == nil {return true}
	#partial switch t.type {
	case .Wall, .Locked_Door:
		return true
	}
	return false
}

// enemy_has_los_to_player walks a Bresenham line from `from` to the player
// position and returns false if any intermediate tile blocks sight.
// The origin tile and destination tile are not checked (an enemy in a wall
// is an invalid state; destination is the player, not a wall).
@(private = "package")
enemy_has_los_to_player :: proc(game: ^Game, from: Vec2) -> bool {
	x0, y0 := from.x, from.y
	x1, y1 := game.player.pos.x, game.player.pos.y

	dx := x1 - x0
	dy := y1 - y0
	if dx < 0 {dx = -dx}
	if dy < 0 {dy = -dy}

	sx := 1 if x0 < x1 else -1
	sy := 1 if y0 < y1 else -1

	err := dx - dy

	cx, cy := x0, y0
	for {
		// Reached the player tile — LOS is clear.
		if cx == x1 && cy == y1 {return true}

		// Check intermediate tiles only (skip origin).
		if !(cx == x0 && cy == y0) {
			if is_sight_blocking(game, cx, cy) {return false}
		}

		e2 := 2 * err
		if e2 > -dy {
			err -= dy
			cx += sx
		}
		if e2 < dx {
			err += dx
			cy += sy
		}
	}
}
