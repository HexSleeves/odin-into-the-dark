package ui

import gcore "../core"
import eng "../engine"

// Sidebar palette shared by Clay HUD and UI theme helpers.
SB_BG :: eng.Engine_Color{12, 12, 20, 255}
SB_DIVIDER :: eng.Engine_Color{35, 35, 52, 255}
SB_TITLE :: eng.Engine_Color{200, 175, 90, 255}
SB_HEADER :: eng.Engine_Color{130, 130, 155, 255}
SB_TEXT :: eng.Engine_Color{195, 195, 210, 255}
SB_DIM :: eng.Engine_Color{75, 75, 90, 255}
SB_HP_BG :: eng.Engine_Color{70, 15, 15, 255}
SB_HP_FG :: eng.Engine_Color{45, 185, 55, 255}
SB_HP_LOW :: eng.Engine_Color{200, 55, 40, 255}
SB_PICK_BG :: eng.Engine_Color{35, 25, 15, 255}
SB_PICK_OK :: eng.Engine_Color{75, 170, 75, 255}
SB_PICK_WARN :: eng.Engine_Color{195, 175, 45, 255}
SB_PICK_CRIT :: eng.Engine_Color{200, 55, 40, 255}
SB_WPN :: eng.Engine_Color{195, 145, 70, 255}
SB_ARM :: eng.Engine_Color{90, 155, 205, 255}
SB_HLM :: eng.Engine_Color{195, 195, 50, 255}
SB_OIL :: eng.Engine_Color{250, 195, 70, 255}
SB_POISON :: eng.Engine_Color{115, 200, 40, 255}
SB_BOSS :: eng.Engine_Color{210, 45, 45, 255}
SB_KEY :: eng.Engine_Color{120, 180, 255, 255}

// Sidebar geometry shared by Clay HUD layout.
SB_X :: i32(gcore.MAP_VIEW_WIDTH)
SB_W :: i32(gcore.SIDEBAR_WIDTH)
SB_H :: i32(gcore.MAP_VIEW_HEIGHT)
SB_PX :: i32(8)
SB_IW :: SB_W - SB_PX * 2
