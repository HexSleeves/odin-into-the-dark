package main

import ui "./ui"

// ─── ui_manager.odin ──────────────────────────────────────────────────────────
UI_Manager :: ui.UI_Manager
ui_manager_make :: ui.ui_manager_make
ui_manager_state :: ui.ui_manager_state
ui_manager_reset_for_new_game :: ui.ui_manager_reset_for_new_game
ui_manager_reset_transient :: ui.ui_manager_reset_transient
ui_manager_use_sprites :: ui.ui_manager_use_sprites

// ─── ui_text.odin ─────────────────────────────────────────────────────────────
UI_APP_TITLE :: ui.UI_APP_TITLE
UI_APP_NAME :: ui.UI_APP_NAME
UI_APP_VERSION :: ui.UI_APP_VERSION
UI_TITLE_SUBTITLE :: ui.UI_TITLE_SUBTITLE
UI_TITLE_CONTINUE_DISABLED :: ui.UI_TITLE_CONTINUE_DISABLED
UI_TITLE_FOOTER :: ui.UI_TITLE_FOOTER
UI_TITLE_OPTIONS :: ui.UI_TITLE_OPTIONS
UI_HELP_LINES :: ui.UI_HELP_LINES
UI_HINT_MINING :: ui.UI_HINT_MINING
UI_HINT_ANVIL :: ui.UI_HINT_ANVIL
UI_HINT_FOUNTAIN :: ui.UI_HINT_FOUNTAIN
UI_INVENTORY_TITLE :: ui.UI_INVENTORY_TITLE
UI_INVENTORY_HELP :: ui.UI_INVENTORY_HELP
UI_INVENTORY_DROP_MODE :: ui.UI_INVENTORY_DROP_MODE
UI_INVENTORY_EQUIP_MODE :: ui.UI_INVENTORY_EQUIP_MODE
UI_CRAFTING_TITLE :: ui.UI_CRAFTING_TITLE
UI_CRAFTING_HELP :: ui.UI_CRAFTING_HELP
UI_HELP_TITLE :: ui.UI_HELP_TITLE
UI_HELP_FOOTER :: ui.UI_HELP_FOOTER
UI_SCORES_TITLE :: ui.UI_SCORES_TITLE
UI_SCORES_EMPTY :: ui.UI_SCORES_EMPTY
UI_SCORES_FOOTER :: ui.UI_SCORES_FOOTER
UI_GAME_OVER_TITLE :: ui.UI_GAME_OVER_TITLE
UI_GAME_OVER_FOOTER :: ui.UI_GAME_OVER_FOOTER
UI_VICTORY_TITLE :: ui.UI_VICTORY_TITLE
UI_VICTORY_SUBTITLE :: ui.UI_VICTORY_SUBTITLE
UI_VICTORY_FOOTER :: ui.UI_VICTORY_FOOTER
UI_CHEATS_TITLE :: ui.UI_CHEATS_TITLE
UI_CHEATS_HELP :: ui.UI_CHEATS_HELP

// ─── ui_theme.odin ────────────────────────────────────────────────────────────
SB_BG :: ui.SB_BG
SB_DIVIDER :: ui.SB_DIVIDER
SB_TITLE :: ui.SB_TITLE
SB_HEADER :: ui.SB_HEADER
SB_TEXT :: ui.SB_TEXT
SB_DIM :: ui.SB_DIM
SB_HP_BG :: ui.SB_HP_BG
SB_HP_FG :: ui.SB_HP_FG
SB_HP_LOW :: ui.SB_HP_LOW
SB_PICK_BG :: ui.SB_PICK_BG
SB_PICK_OK :: ui.SB_PICK_OK
SB_PICK_WARN :: ui.SB_PICK_WARN
SB_PICK_CRIT :: ui.SB_PICK_CRIT
SB_WPN :: ui.SB_WPN
SB_ARM :: ui.SB_ARM
SB_HLM :: ui.SB_HLM
SB_OIL :: ui.SB_OIL
SB_POISON :: ui.SB_POISON
SB_BOSS :: ui.SB_BOSS
SB_KEY :: ui.SB_KEY
SB_X :: ui.SB_X
SB_W :: ui.SB_W
SB_H :: ui.SB_H
SB_PX :: ui.SB_PX
SB_IW :: ui.SB_IW


// ─── messages.odin ─────────────────────────────────────────────────────────────
Message_Manager :: ui.Message_Manager
message_manager_make :: ui.message_manager_make
message_manager_bind_turns :: ui.message_manager_bind_turns
add_message :: ui.add_message
clear_messages :: ui.clear_messages
