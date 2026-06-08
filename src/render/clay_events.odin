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

	if clay.UI(clay.ID("shrine-overlay"))(
		clay_menu_backdrop_decl(eng.Engine_Color{6, 5, 9, 140}, floating = true),
	) {
		if clay.UI(clay.ID("shrine-card"))(clay_menu_card_decl(560)) {
			clay_menu_title("SHRINE")
			clay_menu_accent_rule("shrine-rule")
			clay_menu_subtitle(
				fmt.tprintf("Sacrifice %d HP to receive a blessing", hp_cost),
				ui_pkg.SB_HEADER,
			)

			labels := SHRINE_BUFF_LABELS
			values := SHRINE_BUFF_VALUES
			for i in 0 ..< 3 {
				clay_menu_item(
					fmt.tprintf("shrine-item-%d", i),
					fmt.tprintf("+%d %s", values[i], labels[i]),
					fmt.tprintf("[%d]", i + 1),
					i == game.shrine_choice,
				)
			}

			clay_menu_footer("shrine-footer", "[ESC] Leave")
		}
	}
}

// ─── Merchant overlay ────────────────────────────────────────────────────────

clay_render_merchant_overlay :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	content := game_engine_content_manager(engine)

	if clay.UI(clay.ID("merchant-overlay"))(
		clay_menu_backdrop_decl(eng.Engine_Color{6, 5, 9, 140}, floating = true),
	) {
		if clay.UI(clay.ID("merchant-card"))(clay_menu_card_decl(560)) {
			clay_menu_title("MERCHANT")
			clay_menu_accent_rule("merchant-rule")
			clay_menu_subtitle("Trade materials for goods", ui_pkg.SB_HEADER)

			for i in 0 ..< 3 {
				offer := game.merchant_stock[i]
				if offer.item_id == "" {continue}

				def := gcore.content_manager_item_def(content, offer.item_id)
				item_name := offer.item_id
				if def != nil {item_name = def.name}

				row_id := fmt.tprintf("merchant-item-%d", i)
				hotkey := fmt.tprintf("[%d]", i + 1)

				if offer.sold {
					clay_menu_item(
						row_id,
						fmt.tprintf("%s — SOLD", item_name),
						hotkey,
						false,
						true,
					)
				} else {
					have := gcore.inventory_count_item_type(game, offer.cost_id)
					label := fmt.tprintf(
						"%s — %d %s (have %d)",
						item_name,
						offer.cost_qty,
						offer.cost_id,
						have,
					)
					// affordable rows render normally; unaffordable rows show dimmed (disabled)
					clay_menu_item(row_id, label, hotkey, false, have < offer.cost_qty)
				}
			}

			clay_menu_footer("merchant-footer", "[ESC] Leave")
		}
	}
}
