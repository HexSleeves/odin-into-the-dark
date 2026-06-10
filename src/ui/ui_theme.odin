package ui

import gcore "../core"
import eng "../engine"

// Sidebar palette — "Lamplit Mine". Gold (SB_TITLE) is reserved for treasure/title only.
SB_BG :: eng.Engine_Color{11, 10, 15, 255} // #0B0A0F screen void / sidebar base
SB_PANEL :: eng.Engine_Color{22, 19, 15, 255} // #16130F readout panel background (warm coal)
SB_DIVIDER :: eng.Engine_Color{84, 68, 40, 255} // #544428 gold-tinted panel border / divider
SB_RULE_GOLD :: eng.Engine_Color{122, 95, 32, 255} // #7A5F20 ornate rule under the title
SB_TITLE :: eng.Engine_Color{245, 182, 56, 255} // #F5B638 gold accent (treasure/title)
SB_HEADER :: eng.Engine_Color{176, 167, 145, 255} // #B0A791 panel header labels
SB_TEXT :: eng.Engine_Color{232, 223, 200, 255} // #E8DFC8 primary text
SB_DIM :: eng.Engine_Color{140, 133, 113, 255} // #8C8571 passive/secondary
SB_HP_BG :: eng.Engine_Color{30, 20, 20, 255} // HP bar empty cell
SB_HP_FG :: eng.Engine_Color{111, 191, 115, 255} // #6FBF73 HP healthy
SB_HP_LOW :: eng.Engine_Color{216, 69, 62, 255} // #D8453E HP danger
SB_PICK_BG :: eng.Engine_Color{36, 31, 16, 255} // PICK bar empty cell
SB_PICK_OK :: eng.Engine_Color{232, 163, 61, 255} // #E8A33D pick healthy (amber)
SB_PICK_WARN :: eng.Engine_Color{245, 182, 56, 255} // pick warn
SB_PICK_CRIT :: eng.Engine_Color{216, 69, 62, 255} // pick crit
SB_WPN :: eng.Engine_Color{255, 158, 61, 255} // warm — weapon
SB_ARM :: eng.Engine_Color{138, 158, 168, 255} // cool steel — armor
SB_HLM :: eng.Engine_Color{200, 180, 120, 255} // brass — helmet
SB_OIL :: eng.Engine_Color{255, 158, 61, 255} // #FF9E3D lamp / oil / fuel
SB_LAMP_LOW :: eng.Engine_Color{122, 74, 28, 255} // #7A4A1C ember (low fuel)
SB_POISON :: eng.Engine_Color{115, 200, 40, 255} // poison
SB_BOSS :: eng.Engine_Color{216, 69, 62, 255} // #D8453E boss
SB_KEY :: eng.Engine_Color{138, 130, 112, 255} // control keys (de-emphasized)
SB_SELECT_BG :: eng.Engine_Color{245, 182, 56, 38} // translucent gold selection tint
SB_BACKDROP :: eng.Engine_Color{4, 3, 6, 242} // full-screen dim backdrop
SB_CARD :: eng.Engine_Color{32, 27, 19, 255} // #201B13 menu card panel (lifts off backdrop)
SB_ACCENT :: SB_TITLE // gold accent (semantic alias)

// Sidebar geometry shared by Clay HUD layout.
SB_X :: i32(gcore.MAP_VIEW_WIDTH)
SB_W :: i32(gcore.SIDEBAR_WIDTH)
SB_H :: i32(gcore.MAP_VIEW_HEIGHT)
SB_PX :: i32(8)
SB_IW :: SB_W - SB_PX * 2
