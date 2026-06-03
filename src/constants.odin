package main

import eng "./engine"

// ─── Constants ────────────────────────────────────────────────────────────────

TILE_SIZE :: 32 // render size (sprites are 16x16, drawn at 32x32)
SPRITE_SIZE :: 16 // source sprite size in spritesheet
SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 900
MAP_WIDTH :: 80
MAP_HEIGHT :: 50

// ─── UI Layout ────────────────────────────────────────────────────────────────
// Sidebar replaces the cramped HUD bar. Map occupies left region; sidebar right.
SIDEBAR_WIDTH     :: 256
HUD_REGION_HEIGHT :: 0   // kept for legacy; sidebar does all stat display now
MSG_REGION_HEIGHT :: 120
MAP_VIEW_WIDTH    :: SCREEN_WIDTH - SIDEBAR_WIDTH     // 1024
MAP_VIEW_HEIGHT   :: SCREEN_HEIGHT - MSG_REGION_HEIGHT // 780

// ─── Message Log ──────────────────────────────────────────────────────────────

MAX_MESSAGES :: eng.ENGINE_MAX_MESSAGES
MAX_MSG_LEN :: eng.ENGINE_MAX_MESSAGE_LEN

// ─── Inventory ────────────────────────────────────────────────────────────────

MAX_INVENTORY :: 9

// ─── Dijkstra ─────────────────────────────────────────────────────────────────

DMAP_UNREACHABLE :: 9999

// ─── Turn scheduling (AP system) ─────────────────────────────────────────────────

BASE_ACTION_COST  :: 1000 // default AP cost for any action
BASE_MOVE_COST    :: 1000 // base AP cost to move one tile (scaled by move_speed)
BASE_AP_PER_ROUND :: 1000 // AP a QN=100 actor generates per round
