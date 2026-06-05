package main

// Re-export of the `audio` package public API into `package main`, so existing
// game-layer call sites can use `play_sfx`, `audio_manager_make`, etc. unqualified.
import audio "./audio"

// ─── Types ────────────────────────────────────────────────────────────────────
Sound_Type :: audio.Sound_Type
Audio_Manager :: audio.Audio_Manager
Music_Manager :: audio.Music_Manager
Music_Tier :: audio.Music_Tier
Game_Audio :: audio.Game_Audio

// ─── Lifecycle / SFX ──────────────────────────────────────────────────────────
audio_init :: audio.audio_init
audio_cleanup :: audio.audio_cleanup
audio_toggle :: audio.audio_toggle
audio_set_master_volume :: audio.audio_set_master_volume
play_sfx :: audio.play_sfx
game_audio_backend :: audio.game_audio_backend

// ─── Music ────────────────────────────────────────────────────────────────────
music_init :: audio.music_init
music_cleanup :: audio.music_cleanup
music_update :: audio.music_update
music_toggle :: audio.music_toggle
music_set_tier_by_depth :: audio.music_set_tier_by_depth
music_set_volume :: audio.music_set_volume

// ─── Global state accessors ───────────────────────────────────────────────────
audio_state :: audio.audio_state
raylib_audio_state_ptr :: audio.raylib_audio_state_ptr

// ─── Audio_Manager accessors ──────────────────────────────────────────────────
audio_manager_make :: audio.audio_manager_make
audio_manager_is_enabled :: audio.audio_manager_is_enabled
audio_manager_play_sfx :: audio.audio_manager_play_sfx
audio_manager_play_sfx_looped :: audio.audio_manager_play_sfx_looped
audio_manager_stop_sfx :: audio.audio_manager_stop_sfx
audio_manager_set_sfx_volume :: audio.audio_manager_set_sfx_volume
audio_manager_set_master_volume :: audio.audio_manager_set_master_volume
audio_manager_toggle :: audio.audio_manager_toggle
