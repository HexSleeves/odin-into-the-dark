package main

import eng "./engine"

// ─── Constants ────────────────────────────────────────────────────────────────

TILE_SIZE :: 32       // render size (sprites are 16x16, drawn at 32x32)
SPRITE_SIZE :: 16     // source sprite size in spritesheet
SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 900
MAP_WIDTH :: 80
MAP_HEIGHT :: 50

// ─── UI Layout ────────────────────────────────────────────────────────────────
// Screen is split top-to-bottom: map viewport → HUD → message log.
HUD_REGION_HEIGHT :: 44
MSG_REGION_HEIGHT :: 120
MAP_VIEW_HEIGHT :: SCREEN_HEIGHT - HUD_REGION_HEIGHT - MSG_REGION_HEIGHT

// ─── Message Log ──────────────────────────────────────────────────────────────

MAX_MESSAGES :: eng.ENGINE_MAX_MESSAGES
MAX_MSG_LEN :: eng.ENGINE_MAX_MESSAGE_LEN

// ─── Inventory ────────────────────────────────────────────────────────────────

MAX_INVENTORY :: 9

// ─── Dijkstra ─────────────────────────────────────────────────────────────────

DMAP_UNREACHABLE :: 9999
