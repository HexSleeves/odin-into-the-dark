package main

import gcore "./core"
import "core:testing"

// ─── Helpers ──────────────────────────────────────────────────────────────────

// make_weapon returns a minimal weapon Item with the given stat_bonus.
make_weapon :: proc(bonus: int) -> Item {
	return gcore.Item{
		item_type      = "test_sword",
		name           = "Test Sword",
		equipment_slot = EQUIPMENT_SLOT_WEAPON,
		stat_bonus     = bonus,
		picked_up      = true,
		quantity       = 1,
	}
}

// make_armor returns a minimal armor Item with the given stat_bonus.
make_armor :: proc(bonus: int) -> Item {
	return gcore.Item{
		item_type      = "test_armor",
		name           = "Test Armor",
		equipment_slot = EQUIPMENT_SLOT_ARMOR,
		stat_bonus     = bonus,
		picked_up      = true,
		quantity       = 1,
	}
}

// make_helmet returns a minimal helmet Item with the given stat_bonus.
make_helmet :: proc(bonus: int) -> Item {
	return gcore.Item{
		item_type      = "test_helmet",
		name           = "Test Helmet",
		equipment_slot = EQUIPMENT_SLOT_HELMET,
		stat_bonus     = bonus,
		picked_up      = true,
		quantity       = 1,
	}
}

// minimal_game returns a zeroed Game on the heap (too large for stack).
minimal_game :: proc() -> ^Game {
	return new(Game)
}

// ─── equip_item places item in correct slot ───────────────────────────────────

@(test)
equip_item_places_weapon_in_weapon_slot :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)
	msgs := message_manager_make()

	sword := make_weapon(5)
	game.inventory[0] = Inventory_Slot{occupied = true, item = sword}

	ok := equip_item(&msgs, game, 0)

	testing.expect(t, ok, "equip_item should return true for a valid weapon")
	testing.expect(t, game.equipped_weapon.occupied, "weapon slot should be occupied after equip")
	testing.expect_value(t, game.equipped_weapon.item.stat_bonus, 5)
	testing.expect(t, !game.inventory[0].occupied, "inventory slot should be cleared after equip")
}

@(test)
equip_item_places_armor_in_armor_slot :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)
	msgs := message_manager_make()

	armor := make_armor(3)
	game.inventory[0] = Inventory_Slot{occupied = true, item = armor}

	ok := equip_item(&msgs, game, 0)

	testing.expect(t, ok, "equip_item should return true for valid armor")
	testing.expect(t, game.equipped_armor.occupied, "armor slot should be occupied after equip")
	testing.expect_value(t, game.equipped_armor.item.stat_bonus, 3)
}

@(test)
equip_item_places_helmet_in_helmet_slot :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)
	msgs := message_manager_make()

	helmet := make_helmet(2)
	game.inventory[0] = Inventory_Slot{occupied = true, item = helmet}

	ok := equip_item(&msgs, game, 0)

	testing.expect(t, ok, "equip_item should return true for valid helmet")
	testing.expect(t, game.equipped_helmet.occupied, "helmet slot should be occupied after equip")
	testing.expect_value(t, game.equipped_helmet.item.stat_bonus, 2)
}

// ─── equip fails when slot occupied and inventory full ────────────────────────

@(test)
equip_item_fails_when_slot_occupied_and_inventory_full :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)
	msgs := message_manager_make()

	// Fill every inventory slot with a dummy item
	dummy := gcore.Item{item_type = "junk", name = "Junk", equipment_slot = "", picked_up = true, quantity = 1}
	for i in 0 ..< MAX_INVENTORY {
		game.inventory[i] = Inventory_Slot{occupied = true, item = dummy}
	}

	// Slot 0 has the new weapon we want to equip
	new_sword := make_weapon(7)
	game.inventory[0] = Inventory_Slot{occupied = true, item = new_sword}

	// Pre-occupy the weapon slot with a different weapon
	old_sword := make_weapon(1)
	game.equipped_weapon = Equipment{occupied = true, item = old_sword}

	ok := equip_item(&msgs, game, 0)

	testing.expect(t, !ok, "equip_item should fail when slot is occupied and inventory is full")
	// Original weapon should remain equipped
	testing.expect_value(t, game.equipped_weapon.item.stat_bonus, 1)
}

@(test)
equip_item_returns_false_for_out_of_bounds_slot :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)
	msgs := message_manager_make()

	ok := equip_item(&msgs, game, MAX_INVENTORY)
	testing.expect(t, !ok, "equip_item should return false for out-of-bounds slot index")
}

@(test)
equip_item_returns_false_for_empty_inventory_slot :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)
	msgs := message_manager_make()

	// inventory[0] is zero-valued (not occupied)
	ok := equip_item(&msgs, game, 0)
	testing.expect(t, !ok, "equip_item should return false when inventory slot is empty")
}

@(test)
equip_item_returns_false_for_non_equippable_item :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)
	msgs := message_manager_make()

	non_equippable := Item{item_type = "potion", name = "Potion", equipment_slot = "", picked_up = true, quantity = 1}
	game.inventory[0] = Inventory_Slot{occupied = true, item = non_equippable}

	ok := equip_item(&msgs, game, 0)
	testing.expect(t, !ok, "equip_item should return false for items with no equipment slot")
}

// ─── unequip_slot moves item back to inventory ────────────────────────────────

@(test)
unequip_slot_moves_weapon_back_to_inventory :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)
	msgs := message_manager_make()

	sword := make_weapon(5)
	game.equipped_weapon = Equipment{occupied = true, item = sword}

	ok := unequip_slot(&msgs, game, EQUIPMENT_SLOT_WEAPON)

	testing.expect(t, ok, "unequip_slot should return true")
	testing.expect(t, !game.equipped_weapon.occupied, "weapon slot should be empty after unequip")

	found := false
	for i in 0 ..< MAX_INVENTORY {
		if game.inventory[i].occupied && game.inventory[i].item.stat_bonus == 5 {
			found = true
			break
		}
	}
	testing.expect(t, found, "unequipped weapon should appear in inventory")
}

@(test)
unequip_slot_fails_when_inventory_full :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)
	msgs := message_manager_make()

	dummy := Item{item_type = "junk", name = "Junk", equipment_slot = "", picked_up = true, quantity = 1}
	for i in 0 ..< MAX_INVENTORY {
		game.inventory[i] = Inventory_Slot{occupied = true, item = dummy}
	}

	sword := make_weapon(5)
	game.equipped_weapon = Equipment{occupied = true, item = sword}

	ok := unequip_slot(&msgs, game, EQUIPMENT_SLOT_WEAPON)

	testing.expect(t, !ok, "unequip_slot should fail when inventory is full")
	testing.expect(t, game.equipped_weapon.occupied, "weapon slot should still be occupied on failure")
}

@(test)
unequip_slot_returns_false_when_slot_not_occupied :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)
	msgs := message_manager_make()

	ok := unequip_slot(&msgs, game, EQUIPMENT_SLOT_WEAPON)
	testing.expect(t, !ok, "unequip_slot should return false when slot is not occupied")
}

// ─── effective_attack applies weapon stat_bonus ───────────────────────────────

@(test)
effective_attack_value_applies_weapon_bonus :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)

	game.player.attack = 10
	game.equipped_weapon = Equipment{occupied = true, item = make_weapon(4)}

	result := effective_attack(game)
	testing.expect_value(t, result, 14)
}

@(test)
effective_attack_value_without_weapon_equals_base_attack :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)

	game.player.attack = 7

	result := effective_attack(game)
	testing.expect_value(t, result, 7)
}

// ─── effective_defense applies armor stat_bonus ───────────────────────────────

@(test)
effective_defense_value_applies_armor_bonus :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)

	game.equipped_armor = Equipment{occupied = true, item = make_armor(6)}

	result := effective_defense(game)
	testing.expect_value(t, result, 6)
}

@(test)
effective_defense_value_is_zero_without_armor :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)

	result := effective_defense(game)
	testing.expect_value(t, result, 0)
}

// ─── effective_light_radius applies helmet stat_bonus ─────────────────────────

@(test)
effective_light_bonus_applies_helmet_stat_bonus :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)

	game.equipped_helmet = Equipment{occupied = true, item = make_helmet(3)}

	result := effective_light_bonus(game)
	testing.expect_value(t, result, 3)
}

@(test)
effective_light_bonus_is_zero_without_helmet :: proc(t: ^testing.T) {
	game := minimal_game()
	defer free(game)

	result := effective_light_bonus(game)
	testing.expect_value(t, result, 0)
}
