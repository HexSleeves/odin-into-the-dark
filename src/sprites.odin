package main

import "core:fmt"
import rl "vendor:raylib"

Sprite :: struct {
	src: rl.Rectangle,
}

Sprite_Atlas :: struct {
	texture: rl.Texture2D,

	// Tile sprites
	spr_wall:     Sprite,
	spr_floor:    Sprite,
	spr_rubble:   Sprite,
	spr_descent:  Sprite,
	spr_water:    Sprite,
	spr_gas_vent: Sprite,
	spr_unstable: Sprite,
	spr_chasm:    Sprite,
	spr_anvil:    Sprite,
	spr_web:      Sprite,
	spr_ore_vein: Sprite,

	// Character sprites
	spr_player:         Sprite,
	spr_rat:            Sprite,
	spr_miner_husk:     Sprite,
	spr_cave_crawler:   Sprite,
	spr_deep_watcher:   Sprite,
	spr_toxic_spore:    Sprite,
	spr_shadow_stalker: Sprite,
	spr_mine_guardian:  Sprite,
	spr_abyssal_lord:   Sprite,

	// Item sprites
	spr_health_potion: Sprite,
	spr_bandage:       Sprite,
	spr_torch:         Sprite,
	spr_lantern_oil:   Sprite,
	spr_rusty_pickaxe: Sprite,
	spr_steel_pickaxe: Sprite,
	spr_leather_vest:  Sprite,
	spr_chainmail:     Sprite,
	spr_miners_helmet: Sprite,
	spr_crystal_lamp:  Sprite,
	spr_copper_shield: Sprite,
	spr_crystal_torch: Sprite,
	spr_golden_amulet: Sprite,
	spr_iron_ore:      Sprite,
	spr_copper_ore:    Sprite,
	spr_crystal_shard: Sprite,
	spr_gold_nugget:   Sprite,

	loaded: bool,
}

g_sprites: Sprite_Atlas

sprite_at :: proc(col, row: int) -> Sprite {
	return Sprite {
		src = rl.Rectangle {
			x      = f32(col * SPRITE_SIZE),
			y      = f32(row * SPRITE_SIZE),
			width  = f32(SPRITE_SIZE),
			height = f32(SPRITE_SIZE),
		},
	}
}

sprites_init :: proc() {
	g_sprites.texture = rl.LoadTexture("assets/kenney_1bit.png")
	if g_sprites.texture.id == 0 {
		fmt.eprintln("[sprites] ERROR: failed to load kenney_1bit.png")
		return
	}

	// Tiles
	g_sprites.spr_wall     = sprite_at(1, 10)
	g_sprites.spr_floor    = sprite_at(0, 12)
	g_sprites.spr_rubble   = sprite_at(16, 5)
	g_sprites.spr_descent  = sprite_at(29, 10)
	g_sprites.spr_water    = sprite_at(7, 5)
	g_sprites.spr_gas_vent = sprite_at(35, 0)
	g_sprites.spr_unstable = sprite_at(25, 10)
	g_sprites.spr_chasm    = sprite_at(30, 10)
	g_sprites.spr_anvil    = sprite_at(9, 8)
	g_sprites.spr_web      = sprite_at(6, 4)
	g_sprites.spr_ore_vein = sprite_at(17, 5)

	// Characters
	g_sprites.spr_player         = sprite_at(25, 2)
	g_sprites.spr_rat            = sprite_at(23, 3)
	g_sprites.spr_miner_husk     = sprite_at(26, 2)
	g_sprites.spr_cave_crawler   = sprite_at(23, 4)
	g_sprites.spr_deep_watcher   = sprite_at(25, 4)
	g_sprites.spr_toxic_spore    = sprite_at(3, 0)
	g_sprites.spr_shadow_stalker = sprite_at(27, 2)
	g_sprites.spr_mine_guardian  = sprite_at(28, 2)
	g_sprites.spr_abyssal_lord   = sprite_at(29, 2)

	// Items
	g_sprites.spr_health_potion = sprite_at(36, 7)
	g_sprites.spr_bandage       = sprite_at(37, 7)
	g_sprites.spr_torch         = sprite_at(33, 7)
	g_sprites.spr_lantern_oil   = sprite_at(34, 7)
	g_sprites.spr_rusty_pickaxe = sprite_at(36, 4)
	g_sprites.spr_steel_pickaxe = sprite_at(37, 4)
	g_sprites.spr_leather_vest  = sprite_at(40, 7)
	g_sprites.spr_chainmail     = sprite_at(41, 7)
	g_sprites.spr_miners_helmet = sprite_at(38, 7)
	g_sprites.spr_crystal_lamp  = sprite_at(35, 7)
	g_sprites.spr_copper_shield = sprite_at(39, 7)
	g_sprites.spr_crystal_torch = sprite_at(33, 7)
	g_sprites.spr_golden_amulet = sprite_at(42, 7)
	g_sprites.spr_iron_ore      = sprite_at(17, 5)
	g_sprites.spr_copper_ore    = sprite_at(18, 5)
	g_sprites.spr_crystal_shard = sprite_at(19, 5)
	g_sprites.spr_gold_nugget   = sprite_at(20, 5)

	g_sprites.loaded = true
	fmt.printfln("[sprites] loaded kenney 1-bit tileset (%dx%d)", g_sprites.texture.width, g_sprites.texture.height)
}

sprites_cleanup :: proc() {
	if !g_sprites.loaded {return}
	rl.UnloadTexture(g_sprites.texture)
}

draw_sprite :: proc(spr: Sprite, x, y: i32, tint: rl.Color = rl.WHITE) {
	if !g_sprites.loaded {return}
	dest := rl.Rectangle {
		x      = f32(x),
		y      = f32(y),
		width  = f32(TILE_SIZE),
		height = f32(TILE_SIZE),
	}
	rl.DrawTexturePro(g_sprites.texture, spr.src, dest, {0, 0}, 0, tint)
}

get_tile_sprite :: proc(tile_type: Tile_Type) -> Sprite {
	#partial switch tile_type {
	case .Wall:     return g_sprites.spr_wall
	case .Floor:    return g_sprites.spr_floor
	case .Rubble:   return g_sprites.spr_rubble
	case .Descent:  return g_sprites.spr_descent
	case .Water:    return g_sprites.spr_water
	case .Gas_Vent: return g_sprites.spr_gas_vent
	case .Unstable: return g_sprites.spr_unstable
	case .Chasm:    return g_sprites.spr_chasm
	case .Anvil:    return g_sprites.spr_anvil
	}
	return g_sprites.spr_floor
}

get_enemy_sprite :: proc(enemy_type: string) -> Sprite {
	if enemy_type == "rat"            { return g_sprites.spr_rat }
	if enemy_type == "miner_husk"     { return g_sprites.spr_miner_husk }
	if enemy_type == "cave_crawler"   { return g_sprites.spr_cave_crawler }
	if enemy_type == "deep_watcher"   { return g_sprites.spr_deep_watcher }
	if enemy_type == "toxic_spore"    { return g_sprites.spr_toxic_spore }
	if enemy_type == "shadow_stalker" { return g_sprites.spr_shadow_stalker }
	if enemy_type == "mine_guardian"  { return g_sprites.spr_mine_guardian }
	if enemy_type == "abyssal_lord"   { return g_sprites.spr_abyssal_lord }
	return g_sprites.spr_rat
}

get_item_sprite :: proc(item_type: string) -> Sprite {
	if item_type == "health_potion"   { return g_sprites.spr_health_potion }
	if item_type == "bandage"         { return g_sprites.spr_bandage }
	if item_type == "torch"           { return g_sprites.spr_torch }
	if item_type == "lantern_oil"     { return g_sprites.spr_lantern_oil }
	if item_type == "rusty_pickaxe"   { return g_sprites.spr_rusty_pickaxe }
	if item_type == "steel_pickaxe"   { return g_sprites.spr_steel_pickaxe }
	if item_type == "leather_vest"    { return g_sprites.spr_leather_vest }
	if item_type == "chainmail"       { return g_sprites.spr_chainmail }
	if item_type == "miners_helmet"   { return g_sprites.spr_miners_helmet }
	if item_type == "crystal_lamp"    { return g_sprites.spr_crystal_lamp }
	if item_type == "copper_shield"   { return g_sprites.spr_copper_shield }
	if item_type == "crystal_torch"   { return g_sprites.spr_crystal_torch }
	if item_type == "golden_amulet"   { return g_sprites.spr_golden_amulet }
	if item_type == "iron_ore"        { return g_sprites.spr_iron_ore }
	if item_type == "copper_ore"      { return g_sprites.spr_copper_ore }
	if item_type == "crystal_shard"   { return g_sprites.spr_crystal_shard }
	if item_type == "gold_nugget"     { return g_sprites.spr_gold_nugget }
	return g_sprites.spr_health_potion
}
