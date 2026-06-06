package main

CHEATS_ENABLED :: #config(CHEATS, false)
PUBLIC_BUILD :: #config(PUBLIC_BUILD, false)
when PUBLIC_BUILD {
	#assert(!CHEATS_ENABLED, "Public builds must not enable CHEATS")
}
NO_AUDIO :: #config(NO_AUDIO, false)
NO_SPRITES :: #config(NO_SPRITES, false)
SPRITES_REQUESTED :: #config(SPRITES, false)
SKIP_TITLE :: #config(SKIP_TITLE, false)
FIXED_SEED :: #config(FIXED_SEED, 0)
// Sprites disabled until sprite mapping is redone. SPRITES=true has no effect.
DEFAULT_USE_SPRITES :: false
