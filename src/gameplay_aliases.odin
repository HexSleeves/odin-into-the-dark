package main

import gp "./gameplay"

// ─── Generation ───────────────────────────────────────────────────────────────
generate_map :: gp.generate_map
compute_fov :: gp.compute_fov
spawn_items :: gp.spawn_items
can_place_item :: gp.can_place_item

// ─── Actions ──────────────────────────────────────────────────────────────────
handle_player_moved :: gp.handle_player_moved
handle_player_descended :: gp.handle_player_descended
descend :: gp.descend
start_mining_mode :: gp.start_mining_mode
advance_turn :: gp.advance_turn
trigger_enemy_rounds :: gp.trigger_enemy_rounds
footstep_sound_for_tile :: gp.footstep_sound_for_tile
consume_web_if_present :: gp.consume_web_if_present
apply_current_tile_effects :: gp.apply_current_tile_effects
collapse_unstable_previous_tile :: gp.collapse_unstable_previous_tile
announce_item_under_player :: gp.announce_item_under_player

// ─── Items & Equipment ───────────────────────────────────────────────────────
item_make :: gp.item_make
pickup_item :: gp.pickup_item
use_item :: gp.use_item
drop_item :: gp.drop_item
apply_item_effect :: gp.apply_item_effect
give_starter_gear :: gp.give_starter_gear
equip_item :: gp.equip_item
unequip_slot :: gp.unequip_slot

// ─── Mining ───────────────────────────────────────────────────────────────────
mine_wall :: gp.mine_wall
try_craft :: gp.try_craft
mineable_tile_type :: gp.mineable_tile_type
Recipe :: gp.Recipe
RECIPES :: gp.RECIPES

// ─── Status Effects ───────────────────────────────────────────────────────────
tick_timed_effects :: gp.tick_timed_effects

// ─── Score ────────────────────────────────────────────────────────────────────
save_run_score :: gp.save_run_score
