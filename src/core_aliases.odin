package main

// Re-export of the `core` package symbols into `package main`.
//
// `core` holds the pure data layer (game types, constants, build flags) that
// every other package depends on. Re-exporting here lets the existing game-layer
// files reference `Game`, `MAP_WIDTH`, etc. unqualified — the same `X :: eng.X`
// pattern already used for the engine package. New code may also use `core.X`.
import gcore "./core"

// ─── types.odin ───────────────────────────────────────────────────────────────
Vec2 :: gcore.Vec2
Room :: gcore.Room
Tile_Type :: gcore.Tile_Type
Tile :: gcore.Tile
Player :: gcore.Player
Enemy :: gcore.Enemy
Item :: gcore.Item
Inventory_Slot :: gcore.Inventory_Slot
Equipment_Slot :: gcore.Equipment_Slot
Equipment :: gcore.Equipment
Light_Source :: gcore.Light_Source
Floor_Palette :: gcore.Floor_Palette
Ore_Vein :: gcore.Ore_Vein
UI_State :: gcore.UI_State
Game_State :: gcore.Game_State
Game :: gcore.Game
Message :: gcore.Message
MessageLog :: gcore.MessageLog
DEATH_CAUSE_MAX_LEN :: gcore.DEATH_CAUSE_MAX_LEN

// ─── constants.odin ───────────────────────────────────────────────────────────
MAX_MESSAGES :: gcore.MAX_MESSAGES
MAX_MSG_LEN :: gcore.MAX_MSG_LEN

// ─── gameplay_tuning.odin ─────────────────────────────────────────────────────
MAX_INVENTORY :: gcore.MAX_INVENTORY
DMAP_UNREACHABLE :: gcore.DMAP_UNREACHABLE
BASE_ACTION_COST :: gcore.BASE_ACTION_COST
BASE_MOVE_COST :: gcore.BASE_MOVE_COST
BASE_AP_PER_ROUND :: gcore.BASE_AP_PER_ROUND
MAX_DEPTH :: gcore.MAX_DEPTH
LIGHT_DRAIN_INTERVAL :: gcore.LIGHT_DRAIN_INTERVAL
LIGHT_DRAIN_MIN :: gcore.LIGHT_DRAIN_MIN

// ─── screen_layout.odin ───────────────────────────────────────────────────────
TILE_SIZE :: gcore.TILE_SIZE
SPRITE_SIZE :: gcore.SPRITE_SIZE
SCREEN_WIDTH :: gcore.SCREEN_WIDTH
SCREEN_HEIGHT :: gcore.SCREEN_HEIGHT
MAP_WIDTH :: gcore.MAP_WIDTH
MAP_HEIGHT :: gcore.MAP_HEIGHT
SIDEBAR_WIDTH :: gcore.SIDEBAR_WIDTH
MSG_REGION_HEIGHT :: gcore.MSG_REGION_HEIGHT
MAP_VIEW_WIDTH :: gcore.MAP_VIEW_WIDTH
MAP_VIEW_HEIGHT :: gcore.MAP_VIEW_HEIGHT

// ─── directions.odin ──────────────────────────────────────────────────────────
CARDINAL_DX :: gcore.CARDINAL_DX
CARDINAL_DY :: gcore.CARDINAL_DY
CARDINAL_DIRS :: gcore.CARDINAL_DIRS

// ─── ui_constants.odin ────────────────────────────────────────────────────────
TITLE_OPTION_COUNT :: gcore.TITLE_OPTION_COUNT
TITLE_NEW_GAME :: gcore.TITLE_NEW_GAME
TITLE_CONTINUE :: gcore.TITLE_CONTINUE
TITLE_HIGH_SCORES :: gcore.TITLE_HIGH_SCORES
TITLE_HELP :: gcore.TITLE_HELP
TITLE_QUIT :: gcore.TITLE_QUIT

// build_config.odin (build flags) stays in `package main`: top-level `when`
// conditions can't resolve cross-package constant aliases.
