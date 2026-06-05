#+build !js
package main

import "core:testing"

@(test)
using_item_with_missing_definition_preserves_inventory_stack :: proc(t: ^testing.T) {
	content := content_manager_make()
	messages := message_manager_make()
	game: Game
	game.inventory[0] = Inventory_Slot {
		occupied = true,
		item = Item{item_type = "missing_item", name = "Mystery Item", quantity = 2},
	}

	used := use_item(&content, &messages, &game, 0)

	testing.expect(t, !used)
	testing.expect(t, game.inventory[0].occupied)
	testing.expect_value(t, game.inventory[0].item.quantity, 2)
}
