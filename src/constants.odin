package main

import eng "./engine"

// ─── Constants ────────────────────────────────────────────────────────────────
CHEATS_ENABLED :: #config(CHEATS, false)
NO_AUDIO :: #config(NO_AUDIO, false)
NO_SPRITES :: #config(NO_SPRITES, false)
SPRITES_REQUESTED :: #config(SPRITES, false)
SKIP_TITLE :: #config(SKIP_TITLE, false)
FIXED_SEED :: #config(FIXED_SEED, 0)


TILE_SIZE :: 32 // render size (sprites are 16x16, drawn at 32x32)
SPRITE_SIZE :: 16 // source sprite size in spritesheet
SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 900
MAP_WIDTH :: 80
MAP_HEIGHT :: 50

// ─── UI Layout ────────────────────────────────────────────────────────────────
// Sidebar replaces the cramped HUD bar. Map occupies left region; sidebar right.
SIDEBAR_WIDTH :: 256
HUD_REGION_HEIGHT :: 0 // kept for legacy; sidebar does all stat display now
MSG_REGION_HEIGHT :: 120
MAP_VIEW_WIDTH :: SCREEN_WIDTH - SIDEBAR_WIDTH // 1024
MAP_VIEW_HEIGHT :: SCREEN_HEIGHT - MSG_REGION_HEIGHT // 780

// ─── Message Log ──────────────────────────────────────────────────────────────

MAX_MESSAGES :: eng.ENGINE_MAX_MESSAGES
MAX_MSG_LEN :: eng.ENGINE_MAX_MESSAGE_LEN

// ─── Inventory ────────────────────────────────────────────────────────────────

DEFAULT_USE_SPRITES :: SPRITES_REQUESTED && !NO_SPRITES
MAX_INVENTORY :: 9

// ─── Dijkstra ─────────────────────────────────────────────────────────────────

DMAP_UNREACHABLE :: 9999

// ─── Turn scheduling (AP system) ─────────────────────────────────────────────────

BASE_ACTION_COST :: 1000 // default AP cost for any action
BASE_MOVE_COST :: 1000 // base AP cost to move one tile (scaled by move_speed)
BASE_AP_PER_ROUND :: 1000 // AP a QN=100 actor generates per round

// ─── Depth ────────────────────────────────────────────────────────────────────
MAX_DEPTH :: 12

// ─── Light drain ──────────────────────────────────────────────────────────────
LIGHT_DRAIN_INTERVAL :: 30 // rounds between passive light radius loss
LIGHT_DRAIN_MIN :: 2 // minimum light radius from drain
