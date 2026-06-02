#!/usr/bin/env python3
"""Deterministic M005/S05 validation evidence checker.

This script inspects only source/data files needed to prove the mining and
crafting milestone contracts. It does not read .gsd/, .git/, save files,
binaries, screenshots, or generated artifacts.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[1]
ALLOWED_INPUTS = (
    "src/types.odin",
    "src/generation.odin",
    "src/mining.odin",
    "src/main.odin",
    "src/actions.odin",
    "src/input.odin",
    "src/items.odin",
    "src/equipment.odin",
    "src/render_map.odin",
    "src/render_hud.odin",
    "src/render_ui.odin",
    "src/render.odin",
    "src/map_utils.odin",
    "src/game.odin",
    "data/items.json5",
)

texts: dict[str, str] = {}
failures: list[str] = []
passes = 0


def fail(name: str, detail: str) -> None:
    failures.append(f"{name}: {detail}")


def require(name: str, condition: bool, detail: str) -> None:
    global passes
    if condition:
        passes += 1
        print(f"PASS {name}")
    else:
        fail(name, detail)


def read_allowed_inputs() -> None:
    for rel in ALLOWED_INPUTS:
        path = REPO_ROOT / rel
        if not path.exists():
            fail("input.exists", f"missing required input path: {rel}")
            texts[rel] = ""
            continue
        if not path.is_file():
            fail("input.file", f"required input is not a file: {rel}")
            texts[rel] = ""
            continue
        texts[rel] = path.read_text(encoding="utf-8")


def compact(s: str) -> str:
    return re.sub(r"\s+", " ", s)


def has_all(text: str, needles: Iterable[str]) -> bool:
    return all(needle in text for needle in needles)


def in_order(text: str, needles: Iterable[str]) -> bool:
    pos = -1
    for needle in needles:
        next_pos = text.find(needle, pos + 1)
        if next_pos < 0:
            return False
        pos = next_pos
    return True


def proc_block(rel: str, name: str) -> str:
    text = texts.get(rel, "")
    marker = f"{name} :: proc"
    start = text.find(marker)
    if start < 0:
        return ""
    brace_start = text.find("{", start)
    if brace_start < 0:
        return ""

    depth = 0
    for idx in range(brace_start, len(text)):
        ch = text[idx]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start : idx + 1]
    return ""


def enum_block(rel: str, name: str) -> str:
    text = texts.get(rel, "")
    marker = f"{name} :: enum"
    start = text.find(marker)
    if start < 0:
        return ""
    brace_start = text.find("{", start)
    brace_end = text.find("}", brace_start)
    if brace_start < 0 or brace_end < 0:
        return ""
    return text[start : brace_end + 1]


def struct_block(rel: str, name: str, next_marker: str | None = None) -> str:
    text = texts.get(rel, "")
    marker = f"{name} :: struct"
    start = text.find(marker)
    if start < 0:
        return ""
    if next_marker:
        end = text.find(next_marker, start)
        if end > start:
            return text[start:end]
    brace_start = text.find("{", start)
    if brace_start < 0:
        return ""
    depth = 0
    for idx in range(brace_start, len(text)):
        ch = text[idx]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start : idx + 1]
    return ""


def regex(text: str, pattern: str) -> bool:
    return re.search(pattern, text, flags=re.DOTALL) is not None


def main() -> int:
    read_allowed_inputs()

    types = texts.get("src/types.odin", "")
    generation = texts.get("src/generation.odin", "")
    mining = texts.get("src/mining.odin", "")
    main_text = texts.get("src/main.odin", "")
    input_text = texts.get("src/input.odin", "")
    items = texts.get("src/items.odin", "")
    equipment = texts.get("src/equipment.odin", "")
    render_map_text = texts.get("src/render_map.odin", "")
    render_hud_text = texts.get("src/render_hud.odin", "")
    render_ui_text = texts.get("src/render_ui.odin", "")
    render_text = texts.get("src/render.odin", "")
    map_utils = texts.get("src/map_utils.odin", "")
    game_text = texts.get("src/game.odin", "")
    item_data = texts.get("data/items.json5", "")

    tile_enum = enum_block("src/types.odin", "Tile_Type")
    game_state_enum = enum_block("src/types.odin", "Game_State")
    game_struct = struct_block("src/types.odin", "Game")
    ui_struct = struct_block("src/types.odin", "UI_State", "// ─── Game State")
    item_struct = struct_block("src/types.odin", "Item", "Inventory_Slot :: struct")
    ore_struct = struct_block("src/types.odin", "Ore_Vein", "// ─── VFX State")

    generate_map = proc_block("src/generation.odin", "generate_map")
    spawn_ore_veins = proc_block("src/generation.odin", "spawn_ore_veins")
    spawn_anvil = proc_block("src/generation.odin", "spawn_anvil")
    mine_wall = proc_block("src/mining.odin", "mine_wall")
    count_material = proc_block("src/mining.odin", "count_material")
    consume_material = proc_block("src/mining.odin", "consume_material")
    try_craft = proc_block("src/mining.odin", "try_craft")
    handle_mining_input = proc_block("src/input.odin", "handle_mining_input")
    read_cardinal_press = proc_block("src/input.odin", "read_cardinal_press")
    handle_playing_hotkeys = proc_block("src/input.odin", "handle_playing_hotkeys")
    start_mining_mode = proc_block("src/actions.odin", "start_mining_mode")
    update_viewing_crafting = proc_block("src/input.odin", "update_viewing_crafting")
    handle_player_action = proc_block("src/actions.odin", "handle_player_action")
    handle_player_moved = proc_block("src/actions.odin", "handle_player_moved")
    update_game_over = proc_block("src/input.odin", "update_game_over")
    handle_input = proc_block("src/input.odin", "handle_input")
    descend = proc_block("src/actions.odin", "descend")
    advance_turn = proc_block("src/actions.odin", "advance_turn")
    pickup_item = proc_block("src/items.odin", "pickup_item")
    use_item = proc_block("src/items.odin", "use_item")
    render_map = proc_block("src/render_map.odin", "render_map")
    base_tile_color = proc_block("src/render_map.odin", "base_tile_color")
    render_hud = proc_block("src/render_hud.odin", "render_hud")
    render_crafting = proc_block("src/render_ui.odin", "render_crafting")
    render_help = proc_block("src/render_ui.odin", "render_help")
    render_game = proc_block("src/render.odin", "render_game")
    is_walkable = proc_block("src/map_utils.odin", "is_walkable")
    game_init = proc_block("src/game.odin", "game_init")
    game_reinit = proc_block("src/game.odin", "game_reinit")
    give_starter_gear = proc_block("src/equipment.odin", "give_starter_gear")

    ore_ids = ("iron_ore", "copper_ore", "crystal_shard", "gold_nugget")
    crafted_ids = ("copper_shield", "crystal_torch", "golden_amulet")

    require(
        "inputs.only_declared_source_and_data",
        bool(texts) and set(texts) == set(ALLOWED_INPUTS) and all(not p.startswith((".gsd/", ".git/")) for p in texts),
        "script must read exactly declared source/data files, not .gsd/.git/generated artifacts",
    )

    # M005 success criteria: mining, ore, materials, crafting, anvil, durability.
    require(
        "mining.tile_and_state_fields_exist",
        has_all(tile_enum, ["Wall", "Rubble", "Anvil"]) and "ore_veins:" in game_struct and "Ore_Vein" in game_struct and "mining_mode:" in ui_struct,
        "Tile_Type/Game/UI_State must expose Wall/Rubble/Anvil, ore_veins, and mining_mode",
    )
    require(
        "mining.x_key_enters_directional_mining_mode",
        has_all(handle_playing_hotkeys, ["rl.IsKeyPressed(.X)", "start_mining_mode(game)"])
        and has_all(start_mining_mode, ["game.ui.mining_mode = true", "Mine which direction?", "equipped_weapon", "durability <= 0"])
        and has_all(read_cardinal_press, [".W", ".UP", ".S", ".DOWN", ".A", ".LEFT", ".D", ".RIGHT"]),
        "X must start mining mode, validate pickaxe state, and accept WASD/arrows direction input",
    )
    require(
        "mining.adjacent_wall_only_and_turn_cost",
        has_all(mine_wall, ["tx := game.player.pos.x + dx", "ty := game.player.pos.y + dy", "t.type != .Wall", "game.turn_count += 1", "return true"])
        and has_all(handle_mining_input, ["mine_wall(game, mdx, mdy)", "advance_turn(game, hp_before)", "game.ui.mining_mode = false"]),
        "mine_wall must target adjacent wall tiles, consume a turn, and advance the world after successful mining",
    )
    require(
        "mining.wall_becomes_rubble",
        "t.type = .Rubble" in mine_wall,
        "mining must convert a mined wall to Rubble",
    )
    require(
        "ore.vein_struct_and_distinct_visuals",
        has_all(ore_struct, ["ore_type", "color"])
        and has_all(spawn_ore_veins, ["iron_color := rl.Color{200, 120, 50, 255}", "copper_color := rl.Color{80, 180, 80, 255}", "crystal_color := rl.Color{100, 150, 255, 255}", "gold_color := rl.Color{255, 215, 0, 255}"])
        and has_all(render_map, ["Ore vein overlay on walls", "vein.ore_type != \"\"", "ore_tint := vein.color"]),
        "ore veins must carry ore_type/color and render a distinct wall overlay",
    )
    require(
        "ore.depth_weighted_rarity",
        has_all(spawn_ore_veins, ["if depth >= 8", "else if depth >= 5", "else if depth >= 3", "depth 1-2: only iron"])
        and has_all(spawn_ore_veins, list(ore_ids)),
        "ore selection must be depth-gated from iron-only shallow floors to gold on deep floors",
    )
    require(
        "ore.mining_spawns_material_items_and_clears_vein",
        has_all(mine_wall, ["vein := game.ore_veins[idx]", "find_item_def(vein.ore_type)", "item_make_from_def(def, Vec2{tx, ty})", "append(&game.items, ore_item)", "game.ore_veins[idx] = {}"]),
        "mining an ore vein must spawn data-defined material items and clear the vein",
    )
    require(
        "materials.defined_stackable_and_not_directly_usable",
        all(f'id: "{ore_id}"' in item_data for ore_id in ore_ids)
        and item_data.count('effect: { type: "material", value: 0 }') >= 4
        and has_all(use_item, ["def.effect.type == \"material\"", "Raw materials cannot be used directly", "return false"]),
        "four material items must exist in data and direct inventory use must be blocked",
    )
    require(
        "anvil.spawned_walkable_and_crafting_state_wired",
        "spawn_anvil(game)" in generate_map
        and has_all(spawn_anvil, ["game.tiles[idx].type = .Anvil", "enemy_at(game, x, y) != nil", "item_at(game, x, y) != nil"])
        and ".Anvil" in is_walkable
        and "Viewing_Crafting" in game_state_enum
        and has_all(handle_playing_hotkeys, ["rl.IsKeyPressed(.C)", "cur.type == .Anvil", "game.state = .Viewing_Crafting"]),
        "one anvil must spawn per map on walkable tiles and C must open crafting only while standing on it",
    )
    require(
        "crafting.recipes_consume_materials_and_create_results",
        has_all(mining, ["RECIPES :: [4]Recipe", "Repair Pickaxe", "Copper Shield", "Crystal Torch", "Golden Amulet"])
        and all(ore_id in mining for ore_id in ("iron_ore", "copper_ore", "crystal_shard", "gold_nugget"))
        and all(result_id in mining for result_id in crafted_ids)
        and has_all(count_material, ["game.inventory[i].occupied", "item.item_type == material_id", "item.quantity"])
        and has_all(consume_material, ["item.quantity -= take", "game.inventory[i] = {}"])
        and has_all(try_craft, ["have < recipe.material_qty", "consume_material(game, recipe.material_id, recipe.material_qty)", "find_item_def(recipe.result_id)", "game.inventory[slot_idx].item = crafted"]),
        "recipes must count/consume material stacks and create crafted inventory results",
    )
    require(
        "crafting.overlay_and_hotkeys_wired",
        has_all(update_viewing_crafting, ["rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.C)", "try_craft(game, 0)", "try_craft(game, 1)", "try_craft(game, 2)", "try_craft(game, 3)"])
        and has_all(render_crafting, ["CRAFTING", "Press 1-4 to craft", "count_material(game, recipe.material_id)", "can_craft"]),
        "crafting overlay must show recipe availability and wire number keys to recipe attempts",
    )
    require(
        "pickaxe.durability_decrements_breaks_and_blocks",
        has_all(item_struct, ["durability:", "max_durability:"])
        and has_all(mine_wall, ["wpn.max_durability > 0", "wpn.durability -= 1", "Your %s breaks!", "durability <= 0", "return false"])
        and has_all(start_mining_mode, ["max_durability > 0", "durability <= 0", "broken"]),
        "pickaxe durability must decrease, break at zero, and prevent further mining",
    )
    require(
        "pickaxe.repair_recipe_restores_durability",
        has_all(try_craft, ["recipe.is_repair", "equipped_weapon.item.max_durability", "durability = game.equipped_weapon.item.max_durability", "consume_material(game, recipe.material_id, recipe.material_qty)"]),
        "repair recipe must restore equipped pickaxe durability and consume iron ore",
    )
    require(
        "hud.pickaxe_and_contextual_crafting_feedback",
        has_all(render_hud, ["Pickaxe durability bar", "Pick: %d/%d", "Pick: BROKEN", "game.ui.mining_mode", "[MINING] Choose direction", "cur.type == .Anvil", "[C=Craft]"])
        and "G=Grab  I=Inv  X=Mine  M=Map  ?=Help" in render_hud,
        "HUD must show pickaxe durability, mining mode, anvil crafting hint, and existing core hotkeys",
    )
    require(
        "starter_pickaxe_available",
        has_all(give_starter_gear, ["find_item_def(\"rusty_pickaxe\")", "game.equipped_weapon", "occupied = true"])
        and 'id: "rusty_pickaxe"' in item_data and "durability: 20" in item_data,
        "player must start with a durable pickaxe so mining is available without relying on random drops",
    )

    # Cross-slice boundaries requested by validation round 1.
    require(
        "boundary.s01_ore_generation_to_s01_mining_drop",
        all(ore_id in spawn_ore_veins for ore_id in ore_ids) and "find_item_def(vein.ore_type)" in mine_wall,
        "S01 ore_type strings produced by spawn_ore_veins must be consumed by mine_wall item lookup",
    )
    require(
        "boundary.s01_s02_material_ids_match_data",
        all(ore_id in spawn_ore_veins and f'id: "{ore_id}"' in item_data for ore_id in ore_ids),
        "S01 ore_type ids must match S02 material item definitions",
    )
    require(
        "boundary.s02_s03_recipe_material_ids_match_data",
        all(ore_id in mining and f'id: "{ore_id}"' in item_data for ore_id in ore_ids),
        "S03 recipe material_ids must match S02 material definitions",
    )
    require(
        "boundary.s03_crafted_results_match_data",
        all(result_id in mining and f'id: "{result_id}"' in item_data for result_id in crafted_ids),
        "S03 recipe result_ids must match data item definitions",
    )
    require(
        "boundary.s01_s04_durability_fields_shared",
        has_all(mine_wall, ["wpn.durability -= 1", "wpn.max_durability"])
        and has_all(render_hud, ["game.equipped_weapon.item.max_durability", "wpn.durability", "wpn.max_durability"]),
        "S01 writes the same durability fields that S04 HUD reads",
    )
    require(
        "boundary.s03_anvil_to_input_and_hud",
        "game.tiles[idx].type = .Anvil" in spawn_anvil
        and "cur.type == .Anvil" in handle_playing_hotkeys
        and "cur.type == .Anvil" in render_hud,
        "S03 anvil tile must be consumed by input and HUD hint logic",
    )
    require(
        "boundary.s01_mining_mode_to_s04_hud",
        "game.ui.mining_mode = true" in start_mining_mode and "game.ui.mining_mode" in render_hud,
        "S01 mining_mode producer must be consumed by S04 HUD indicator",
    )
    require(
        "boundary.repair_flow_unblocks_mining_and_hud",
        "durability = game.equipped_weapon.item.max_durability" in try_craft
        and "durability <= 0" in start_mining_mode
        and "Pick: BROKEN" in render_hud,
        "S03 repair must update the same weapon durability state used by mining block and HUD display",
    )

    # Existing-feature regression signals: representative prior requirements still wired.
    require(
        "regression.r001_tile_array_and_tile_state_preserved",
        "tiles:" in game_struct and "[MAP_WIDTH * MAP_HEIGHT]Tile" in game_struct and has_all(types, ["visible:", "explored:", "light_level:"])
        and has_all(tile_enum, ["Wall", "Floor", "Rubble", "Descent"]),
        "R001 tile array and tile state fields must remain present",
    )
    require(
        "regression.r002_r015_movement_quit_restart_preserved",
        has_all(handle_input, [".ESCAPE", "check_move_direction()", "is_walkable(game, target_x, target_y)", "return .Moved"])
        and has_all(input_text, [".W", ".UP", ".A", ".LEFT", ".S", ".DOWN", ".D", ".RIGHT"])
        and has_all(update_game_over, ["rl.IsKeyPressed(.R)", "restart_game(game)"]),
        "movement, wall blocking, Escape quit, and game-over R restart must remain wired",
    )
    require(
        "regression.r003_render_order_and_visibility_preserved",
        in_order(render_game, ["render_map(game)", "render_webs(game)", "render_items(game)", "render_enemies(game)", "render_player(game)", "render_particles()", "render_hud(game)", "render_messages(game)"])
        and has_all(render_map, ["tile.visible", "tile.explored", "UNSEEN_COLOR"]),
        "visibility-aware rendering and render order must remain intact",
    )
    require(
        "regression.r004_generation_rooms_and_descent_preserved",
        has_all(generation, ["generate_rooms(game)", "generate_mixed(game)", "generate_cave(game)", "game.player.pos = room_center(game.rooms[0])", ".Descent"])
        and has_all(generate_map, ["spawn_enemies(game)", "spawn_items(game)", "spawn_hazards(game)", "spawn_ore_veins(game)", "spawn_anvil(game)"]),
        "map generation must preserve room/cave dispatch, player/descent placement, and spawn ordering",
    )
    require(
        "regression.r005_r006_fov_and_explored_memory_preserved",
        has_all(advance_turn, ["compute_fov(game)", "camera_update(game)"])
        and has_all(descend, ["compute_fov(game)", "camera_update(game, snap = true)"])
        and has_all(render_map, ["tile.visible", "tile.explored", "EXPLORED_DIM"]),
        "FOV recompute and explored dim rendering must remain wired",
    )
    require(
        "regression.r007_r008_enemy_ai_and_combat_preserved",
        has_all(advance_turn, ["process_enemy_turns(game)", "process_enemy_abilities(game)", "remove_dead_enemies(game)"])
        and has_all(handle_input, ["enemy_at(game, target_x, target_y)", "resolve_attack_player_on_enemy(game, target_enemy)", "game.turn_count += 1"]),
        "enemy turn processing and bump-to-attack must remain wired",
    )
    require(
        "regression.r010_descent_depth_progression_preserved",
        has_all(handle_input, ["t.type == .Descent", "descend(game)", "return .Descended"])
        and has_all(descend, ["game.depth += 1", "generate_map(game)", "game.player.light_radius", "You descend to depth"]),
        "descent tile must still advance depth, regenerate map, and update light radius",
    )
    require(
        "regression.r011_hud_core_stats_preserved",
        has_all(render_hud, ["HP: %d/%d", "Depth: %d", "Light: %d", "Enemies: %d", "Turn: %d"]),
        "baseline HUD stats must remain visible alongside mining HUD additions",
    )
    require(
        "regression.r012_game_over_restart_preserved",
        has_all(update_game_over, ["save_run_score(game)", "rl.IsKeyPressed(.R)", "restart_game(game)", "rl.IsKeyPressed(.ESCAPE)"])
        and has_all(render_ui_text, ["GAME OVER", "Press R to restart"]),
        "game-over scoring, R restart, Escape quit, and rendered instructions must remain intact",
    )
    require(
        "regression.r014_seeded_rng_preserved",
        has_all(game_init, ["seed := u64", "rand.reset(seed)", "game.seed = seed"])
        and has_all(game_reinit, ["rand.reset(seed)", "game.seed = seed"]),
        "Game initialization/restart must preserve stored seeded RNG wiring",
    )
    require(
        "regression.r016_inventory_pickup_stack_use_preserved",
        has_all(game_struct, ["inventory:", "[MAX_INVENTORY]Inventory_Slot"])
        and has_all(handle_playing_hotkeys, ["rl.IsKeyPressed(.G)", "pickup_item(game)", "rl.IsKeyPressed(.I)", "game.state = .Viewing_Inventory"])
        and has_all(pickup_item, ["item_is_stackable", "slot.item.quantity += 1", "game.inventory[slot_idx].occupied = true"])
        and has_all(use_item, ["apply_item_effect(game, def)", "item.quantity -= 1"]),
        "inventory pickup, stacking, open, and use paths must remain wired",
    )
    require(
        "regression.r017_light_item_paths_preserved_and_extended",
        all(token in item_data for token in ('id: "torch"', 'type: "light_boost"', 'id: "lantern_oil"', 'type: "timed_light_boost"', 'id: "crystal_torch"'))
        and has_all(use_item, ["apply_item_effect(game, def)"])
        and "crystal_torch" in mining,
        "existing light-source item paths must remain and M005 crystal_torch must extend them",
    )
    require(
        "regression.help_documents_mining_and_anvil",
        has_all(render_help, ["MINING", "X + direction", "C  (on anvil)", "Mine walls to find ores!", "Craft at anvils with materials."]),
        "help overlay must document new mining/crafting controls",
    )

    if failures:
        print("\nFAILURES:")
        for item in failures:
            print(f"FAIL {item}")
        print(f"\nSUMMARY: {passes} passed, {len(failures)} failed")
        return 1

    print(f"TOTAL PASS {passes} checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
