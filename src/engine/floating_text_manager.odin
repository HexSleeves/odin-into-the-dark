package engine

// ─── Floating combat text ────────────────────────────────────────────────────
// A small pooled set of short-lived text labels positioned in world-tile
// coordinates (e.g. rising damage numbers). The manager is backend-agnostic:
// it owns only data + lifetime; the renderer package draws the active entries.
// Zero raylib — runs headlessly in tests.

ENGINE_MAX_FLOATING_TEXTS :: 32
ENGINE_FLOATING_TEXT_MAX_LEN :: 15 // chars copied into the inline buffer
ENGINE_FLOATING_TEXT_LIFE :: 1.0 // initial life (decays toward 0)
ENGINE_FLOATING_TEXT_DECAY :: 0.02 // life lost per update tick
ENGINE_FLOATING_TEXT_RISE :: 0.4 // tiles risen per second of full life

Floating_Text :: struct {
	tile_x:   int,
	tile_y:   int,
	rise:     f32, // accumulated vertical offset in tiles (grows as it ages)
	color:    Engine_Color,
	life:     f32, // 1.0 = just spawned, <= 0 = expired
	len:      int, // valid bytes in text_buf
	text_buf: [ENGINE_FLOATING_TEXT_MAX_LEN]u8,
	active:   bool,
}

Floating_Text_Manager :: struct {
	pool: [ENGINE_MAX_FLOATING_TEXTS]Floating_Text,
}

floating_text_manager_make :: proc() -> Floating_Text_Manager {
	return Floating_Text_Manager{}
}

floating_text_manager_active_count :: proc(ft: ^Floating_Text_Manager) -> int {
	if ft == nil {return 0}
	count := 0
	for &entry in ft.pool {
		if entry.active {count += 1}
	}
	return count
}

floating_text_text :: proc(entry: ^Floating_Text) -> string {
	if entry == nil {return ""}
	return string(entry.text_buf[:entry.len])
}

// Spawn a floating label at a world-tile position. The string is copied into the
// entry's inline buffer (truncated to ENGINE_FLOATING_TEXT_MAX_LEN) so the
// manager never holds a borrowed pointer. Drops silently when the pool is full.
floating_text_manager_spawn :: proc(
	ft: ^Floating_Text_Manager,
	tile_x, tile_y: int,
	text: string,
	color: Engine_Color,
) {
	if ft == nil {return}
	for &entry in ft.pool {
		if entry.active {continue}
		n := min(len(text), ENGINE_FLOATING_TEXT_MAX_LEN)
		for i in 0 ..< n {
			entry.text_buf[i] = text[i]
		}
		entry.len = n
		entry.tile_x = tile_x
		entry.tile_y = tile_y
		entry.rise = 0
		entry.color = color
		entry.life = ENGINE_FLOATING_TEXT_LIFE
		entry.active = true
		return
	}
}

// Advance all active entries one tick: age them and drift them upward. Entries
// whose life reaches 0 are released back to the pool.
floating_text_manager_update :: proc(ft: ^Floating_Text_Manager) {
	if ft == nil {return}
	for &entry in ft.pool {
		if !entry.active {continue}
		entry.rise += ENGINE_FLOATING_TEXT_RISE * ENGINE_FLOATING_TEXT_DECAY
		entry.life -= ENGINE_FLOATING_TEXT_DECAY
		if entry.life <= 0 {
			entry = Floating_Text{}
		}
	}
}
