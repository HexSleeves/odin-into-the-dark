package renderer

import gcore "../core"
import eng "../engine"
import ui_pkg "../ui"
import "core:fmt"
import clay "libs:clay"

// ─── Shrine overlay ──────────────────────────────────────────────────────────

SHRINE_BUFF_LABELS :: [3]string{"Max HP", "Attack", "Light Radius"}

SHRINE_BUFF_VALUES :: [3]int {
	gcore.SHRINE_BUFF_MAX_HP,
	gcore.SHRINE_BUFF_ATTACK,
	gcore.SHRINE_BUFF_LIGHT,
}

clay_render_shrine_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	hp_cost := max(1, game.player.hp * gcore.SHRINE_HP_COST_PERCENT / 100)

	if clay.UI(clay.ID("shrine-overlay"))(clay_overlay_decl(eng.Engine_Color{10, 20, 40, 220})) {
		clay_text("=== SHRINE ===", CLAY_FONT_TITLE, ui_pkg.SB_TITLE)
		clay_text(
			fmt.tprintf("Sacrifice %d HP to receive a blessing:", hp_cost),
			CLAY_HUD_ROW_FONT,
			ui_pkg.SB_TEXT,
		)

		labels := SHRINE_BUFF_LABELS
		values := SHRINE_BUFF_VALUES
		for i in 0 ..< 3 {
			color := ui_pkg.SB_TEXT
			if i == game.shrine_choice {
				color = ui_pkg.SB_TITLE
			}
			clay_text(
				fmt.tprintf(
					"[%d] +%d %s%s",
					i + 1,
					values[i],
					labels[i],
					i == game.shrine_choice ? " <" : "",
				),
				CLAY_HUD_ROW_FONT,
				color,
			)
		}

		clay_text("[ESC] Leave", CLAY_HUD_ROW_FONT, ui_pkg.SB_DIM)
	}
}

// ─── Merchant overlay ────────────────────────────────────────────────────────

clay_render_merchant_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	content := game_engine_content_manager(engine)

	if clay.UI(clay.ID("merchant-overlay"))(clay_overlay_decl(eng.Engine_Color{10, 30, 20, 220})) {
		clay_text("=== MERCHANT ===", CLAY_FONT_TITLE, ui_pkg.SB_TITLE)
		clay_text("Trade materials for goods:", CLAY_HUD_ROW_FONT, ui_pkg.SB_TEXT)

		for i in 0 ..< 3 {
			offer := game.merchant_stock[i]
			if offer.item_id == "" {continue}

			def := gcore.content_manager_item_def(content, offer.item_id)
			item_name := offer.item_id
			if def != nil {item_name = def.name}

			if offer.sold {
				clay_text(fmt.tprintf("[%d] SOLD", i + 1), CLAY_HUD_ROW_FONT, ui_pkg.SB_DIM)
			} else {
				have := gcore.inventory_count_item_type(game, offer.cost_id)
				color := ui_pkg.SB_TITLE // cost shown inline — gold = currency
				if have < offer.cost_qty {color = ui_pkg.SB_HP_LOW}
				clay_text(
					fmt.tprintf(
						"[%d] %s — %d %s (have %d)",
						i + 1,
						item_name,
						offer.cost_qty,
						offer.cost_id,
						have,
					),
					CLAY_HUD_ROW_FONT,
					color,
				)
			}
		}

		clay_text("[ESC] Leave", CLAY_HUD_ROW_FONT, ui_pkg.SB_DIM)
	}
}
