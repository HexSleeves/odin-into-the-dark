package main

import gcore "./core"
import eng "./engine"
import "core:testing"

// ─── helpers ──────────────────────────────────────────────────────────────────

// Build a minimal Game with zeroed inventory and the player at (0,0).
make_test_game :: proc() -> Game {
	g := Game{}
	g.player.pos = Vec2{0, 0}
	return g
}

// Build a non-stackable item sitting at position (0,0).
make_test_item :: proc(itype: string) -> Item {
	return Item {
		pos = Vec2{0, 0},
		item_type = itype,
		name = itype,
		glyph = '!',
		color = eng.Engine_Color{255, 255, 255, 255},
		picked_up = false,
		quantity = 1,
	}
}

// Build a Content_Manager with a single Item_Def entry (stack_limit controls stacking).
make_test_content :: proc(id: string, stack_limit: int) -> gcore.Content_Manager {
	def := gcore.Item_Def {
		id          = id,
		name        = id,
		stack_limit = stack_limit,
	}
	items := make([]gcore.Item_Def, 1)
	items[0] = def
	c := gcore.Content_Manager{}
	c.loaded = true
	c.registry.loaded = true
	c.registry.items.items = items
	return c
}

destroy_test_content :: proc(content: ^gcore.Content_Manager) {
	if content == nil {return}
	delete(content.registry.items.items)
	content.registry.items.items = nil
}

// ─── inventory_put_slot / pickup into empty slot ──────────────────────────────

@(test)
pickup_item_adds_item_to_empty_slot :: proc(t: ^testing.T) {
	g := make_test_game()
	item := make_test_item("health_potion")
	append(&g.items, item)

	msgs := message_manager_make()
	content := make_test_content("health_potion", 1) // stack_limit=1 → non-stackable
	defer destroy_test_content(&content)

	ok := pickup_item(&content, &msgs, &g)

	testing.expect(t, ok, "pickup_item should return true when slot is available")
	testing.expect(t, g.inventory[0].occupied, "slot 0 should be occupied after pickup")
	testing.expect_value(t, g.inventory[0].item.item_type, "health_potion")
	testing.expect_value(t, g.inventory[0].item.quantity, 1)
	testing.expect_value(t, g.items[0].picked_up, true)
	testing.expect_value(t, g.items_found, 1)

	delete(g.items)
}

// ─── stacking ─────────────────────────────────────────────────────────────────

@(test)
pickup_item_stacks_stackable_item_up_to_stack_max :: proc(t: ^testing.T) {
	g := make_test_game()
	content := make_test_content("torch", 5) // stack_limit=5
	defer destroy_test_content(&content)

	// Pre-seed inventory with 1 torch already held.
	existing := make_test_item("torch")
	existing.quantity = 1
	g.inventory[0] = Inventory_Slot {
		occupied = true,
		item     = existing,
	}

	// Place a second torch on the floor at player's position.
	floor_torch := make_test_item("torch")
	append(&g.items, floor_torch)

	msgs := message_manager_make()
	ok := pickup_item(&content, &msgs, &g)

	testing.expect(t, ok, "pickup of stackable item should succeed")
	testing.expect_value(t, g.inventory[0].item.quantity, 2)
	// No new slot should be occupied.
	testing.expect(t, !g.inventory[1].occupied, "slot 1 should remain empty after stack")
	testing.expect_value(t, g.items[0].picked_up, true)

	delete(g.items)
}

@(test)
pickup_item_opens_new_slot_when_existing_stack_is_full :: proc(t: ^testing.T) {
	g := make_test_game()
	content := make_test_content("torch", 5)
	defer destroy_test_content(&content)

	// Slot 0: torch already at max stack.
	full_stack := make_test_item("torch")
	full_stack.quantity = 5
	g.inventory[0] = Inventory_Slot {
		occupied = true,
		item     = full_stack,
	}

	// Floor torch.
	floor_torch := make_test_item("torch")
	append(&g.items, floor_torch)

	msgs := message_manager_make()
	ok := pickup_item(&content, &msgs, &g)

	testing.expect(t, ok, "pickup should succeed by opening a new slot")
	// The full slot is unchanged.
	testing.expect_value(t, g.inventory[0].item.quantity, 5)
	// A fresh slot should have been used.
	testing.expect(t, g.inventory[1].occupied, "slot 1 should be occupied with the overflow")
	testing.expect_value(t, g.inventory[1].item.quantity, 1)

	delete(g.items)
}

// ─── full inventory ───────────────────────────────────────────────────────────

@(test)
pickup_item_fails_when_inventory_full_and_item_non_stackable :: proc(t: ^testing.T) {
	g := make_test_game()
	content := make_test_content("sword", 1) // non-stackable
	defer destroy_test_content(&content)

	// Fill every slot.
	filler := make_test_item("filler")
	for i in 0 ..< MAX_INVENTORY {
		g.inventory[i] = Inventory_Slot {
			occupied = true,
			item     = filler,
		}
	}

	// Floor item.
	floor_item := make_test_item("sword")
	append(&g.items, floor_item)

	msgs := message_manager_make()
	ok := pickup_item(&content, &msgs, &g)

	testing.expect(t, !ok, "pickup_item should return false when inventory is full")
	testing.expect(t, !g.items[0].picked_up, "floor item should remain unpicked")
	testing.expect_value(t, g.items_found, 0)

	delete(g.items)
}

// ─── inventory_decrement_slot / consume_item ──────────────────────────────────

@(test)
consume_item_decrements_quantity :: proc(t: ^testing.T) {
	g := make_test_game()
	potion := make_test_item("health_potion")
	potion.quantity = 3
	g.inventory[0] = Inventory_Slot {
		occupied = true,
		item     = potion,
	}

	ok := inventory_decrement_slot(&g, 0, 1)

	testing.expect(t, ok, "inventory_decrement_slot should return true")
	testing.expect(
		t,
		g.inventory[0].occupied,
		"slot should still be occupied after partial consume",
	)
	testing.expect_value(t, g.inventory[0].item.quantity, 2)
}

@(test)
quantity_reaches_zero_removes_from_slot :: proc(t: ^testing.T) {
	g := make_test_game()
	potion := make_test_item("health_potion")
	potion.quantity = 1
	g.inventory[0] = Inventory_Slot {
		occupied = true,
		item     = potion,
	}

	ok := inventory_decrement_slot(&g, 0, 1)

	testing.expect(t, ok, "inventory_decrement_slot should return true")
	testing.expect(t, !g.inventory[0].occupied, "slot should be cleared when quantity hits zero")
	testing.expect_value(t, g.inventory[0].item.quantity, 0)
}

// ─── remove_item_from_inventory ───────────────────────────────────────────────

@(test)
remove_item_from_inventory_removes_by_type_string :: proc(t: ^testing.T) {
	g := make_test_game()
	key := make_test_item("vault_key")
	key.quantity = 1
	g.inventory[0] = Inventory_Slot {
		occupied = true,
		item     = key,
	}

	ok := remove_item_from_inventory(&g, "vault_key")

	testing.expect(t, ok, "remove_item_from_inventory should return true when item is present")
	testing.expect(t, !g.inventory[0].occupied, "slot should be cleared after removal")
}

@(test)
remove_item_from_inventory_returns_false_when_item_absent :: proc(t: ^testing.T) {
	g := make_test_game()

	ok := remove_item_from_inventory(&g, "nonexistent_item")

	testing.expect(t, !ok, "remove_item_from_inventory should return false when item is absent")
}

// ─── inventory_count_item_type ────────────────────────────────────────────────

@(test)
inventory_count_item_type_sums_across_all_slots :: proc(t: ^testing.T) {
	g := make_test_game()
	torch := make_test_item("torch")
	torch.quantity = 3
	g.inventory[0] = Inventory_Slot {
		occupied = true,
		item     = torch,
	}
	torch2 := make_test_item("torch")
	torch2.quantity = 2
	g.inventory[1] = Inventory_Slot {
		occupied = true,
		item     = torch2,
	}

	total := inventory_count_item_type(&g, "torch")
	testing.expect_value(t, total, 5)
}
