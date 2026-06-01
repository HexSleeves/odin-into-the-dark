package main

// ─── Constants ────────────────────────────────────────────────────────────────

TILE_SIZE :: 16
SCREEN_WIDTH :: 1080
SCREEN_HEIGHT :: 720
MAP_WIDTH :: 80
MAP_HEIGHT :: 50

// ─── UI Layout ────────────────────────────────────────────────────────────────
// Screen is split top-to-bottom: map viewport → HUD → message log.
HUD_REGION_HEIGHT :: 44
MSG_REGION_HEIGHT :: 120
MAP_VIEW_HEIGHT :: SCREEN_HEIGHT - HUD_REGION_HEIGHT - MSG_REGION_HEIGHT

// ─── Message Log ──────────────────────────────────────────────────────────────

MAX_MESSAGES :: 64
MAX_MSG_LEN :: 256

// ─── Inventory ────────────────────────────────────────────────────────────────

MAX_INVENTORY :: 9

// ─── Dijkstra ─────────────────────────────────────────────────────────────────

DMAP_UNREACHABLE :: 9999
