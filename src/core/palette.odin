package core

import eng "../engine"

PALETTE_MINE :: Floor_Palette {
	wall    = eng.Engine_Color{40, 40, 45, 255},
	floor   = eng.Engine_Color{139, 90, 43, 255},
	rubble  = eng.Engine_Color{180, 160, 100, 255},
	descent = eng.Engine_Color{0, 200, 200, 255},
}

PALETTE_STONE :: Floor_Palette {
	wall    = eng.Engine_Color{50, 50, 55, 255},
	floor   = eng.Engine_Color{100, 100, 110, 255},
	rubble  = eng.Engine_Color{130, 130, 120, 255},
	descent = eng.Engine_Color{0, 200, 200, 255},
}

PALETTE_CRYSTAL :: Floor_Palette {
	wall    = eng.Engine_Color{30, 45, 60, 255},
	floor   = eng.Engine_Color{50, 90, 100, 255},
	rubble  = eng.Engine_Color{80, 140, 130, 255},
	descent = eng.Engine_Color{0, 255, 200, 255},
}

PALETTE_FLOODED :: Floor_Palette {
	wall    = eng.Engine_Color{25, 40, 55, 255},
	floor   = eng.Engine_Color{35, 65, 80, 255},
	rubble  = eng.Engine_Color{50, 90, 85, 255},
	descent = eng.Engine_Color{0, 200, 255, 255},
}

PALETTE_DEEP :: Floor_Palette {
	wall    = eng.Engine_Color{35, 20, 45, 255},
	floor   = eng.Engine_Color{70, 40, 80, 255},
	rubble  = eng.Engine_Color{110, 60, 120, 255},
	descent = eng.Engine_Color{200, 100, 255, 255},
}

palette_for_depth :: proc(depth: int) -> Floor_Palette {
	if depth <= 2 {return PALETTE_MINE}
	if depth <= 4 {return PALETTE_STONE}
	if depth == 5 {return PALETTE_CRYSTAL}
	if depth <= 7 {return PALETTE_FLOODED}
	return PALETTE_DEEP
}
