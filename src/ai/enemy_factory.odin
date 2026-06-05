package ai

import eng "../engine"

// ─── Enemy factory (data-driven) ─────────────────────────────────────────────

enemy_make :: proc(content: ^Content_Manager, id: string, pos: Vec2) -> Enemy {
	def := content_manager_enemy_def(content, id)
	if def != nil {
		return enemy_make_from_def(def, pos)
	}
	// Fallback: unknown enemy
	logger_warnf(.Enemy, "unknown enemy id '%s'", id)
	return Enemy {
		pos = pos,
		hp = 1,
		max_hp = 1,
		attack = 1,
		enemy_type = id,
		name = id,
		glyph = '?',
		color = eng.Engine_Color{230, 41, 55, 255},
		alive = true,
	}
}

// ─── Spawn enemies into rooms ────────────────────────────────────────────────
