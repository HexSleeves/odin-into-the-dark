package main

import renderer "./render"

// ─── Score ────────────────────────────────────────────────────────────────────

Score_Entry :: renderer.Score_Entry
Score_Table :: renderer.Score_Table
Score_Manager :: renderer.Score_Manager
SCORES_FILE :: renderer.SCORES_FILE
score_manager_make :: renderer.score_manager_make
score_manager_load :: renderer.score_manager_load
score_manager_save :: renderer.score_manager_save
score_table_destroy :: renderer.score_table_destroy
insert_score :: renderer.insert_score

// ─── Sprites ─────────────────────────────────────────────────────────────────

Sprite_Manager :: renderer.Sprite_Manager
sprites_init :: renderer.sprites_init
sprites_cleanup :: renderer.sprites_cleanup
sprite_manager_make :: renderer.sprite_manager_make

// ─── Particles ────────────────────────────────────────────────────────────────

Particle_Manager :: renderer.Particle_Manager
particle_manager_make :: renderer.particle_manager_make
particle_manager_active_count :: renderer.particle_manager_active_count
particle_manager_spawn :: renderer.particle_manager_spawn
update_particles :: renderer.update_particles
render_particles :: renderer.render_particles
spawn_hit_particles :: renderer.spawn_hit_particles
spawn_mine_particles :: renderer.spawn_mine_particles
spawn_pickup_particles :: renderer.spawn_pickup_particles
spawn_death_particles :: renderer.spawn_death_particles

// ─── Clay UI ─────────────────────────────────────────────────────────────────

clay_ui_init :: renderer.clay_ui_init
clay_ui_destroy :: renderer.clay_ui_destroy
clay_ui_begin_frame :: renderer.clay_ui_begin_frame
clay_ui_end_frame :: renderer.clay_ui_end_frame
clay_render_commands :: renderer.clay_render_commands
clay_render_screen_ui :: renderer.clay_render_screen_ui
clay_render_messages :: renderer.clay_render_messages
clay_render_minimap :: renderer.clay_render_minimap
minimap_should_draw_enemy_dot :: renderer.minimap_should_draw_enemy_dot

// ─── Render ───────────────────────────────────────────────────────────────────

render_game :: renderer.render_game
palette_for_depth :: renderer.palette_for_depth
