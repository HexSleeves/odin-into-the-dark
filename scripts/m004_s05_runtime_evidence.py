#!/usr/bin/env python3
"""Deterministic M004/S05 runtime evidence checker.

This script intentionally inspects only repo source files and the justfile. It does
not read .gsd/, .git/, save data, binaries, screenshots, or generated artifacts.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[1]
ALLOWED_INPUTS = (
    "justfile",
    "src/types.odin",
    "src/render_map.odin",
    "src/generation.odin",
    "src/main.odin",
    "src/map_utils.odin",
    "src/fov.odin",
    "src/render.odin",
    "src/render_minimap.odin",
    "src/render_hud.odin",
    "src/input.odin",
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
    if brace_start < 0:
        return ""
    brace_end = text.find("}", brace_start)
    if brace_end < 0:
        return ""
    return text[start : brace_end + 1]


def color_for_case(block: str, case_name: str) -> tuple[int, int, int, int] | None:
    pattern = rf"case\s+\.{re.escape(case_name)}\s*:\s*return\s+rl\.Color\s*\{{\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\}}"
    m = re.search(pattern, block)
    if not m:
        return None
    return tuple(int(part) for part in m.groups())  # type: ignore[return-value]


def regex(text: str, pattern: str) -> bool:
    return re.search(pattern, text, flags=re.DOTALL) is not None


def main() -> int:
    read_allowed_inputs()

    types = texts.get("src/types.odin", "")
    render_map_text = texts.get("src/render_map.odin", "")
    generation = texts.get("src/generation.odin", "")
    main_text = texts.get("src/main.odin", "")
    map_utils = texts.get("src/map_utils.odin", "")
    fov = texts.get("src/fov.odin", "")
    render = texts.get("src/render.odin", "")
    minimap = texts.get("src/render_minimap.odin", "")
    hud = texts.get("src/render_hud.odin", "")
    input_text = texts.get("src/input.odin", "")
    justfile = texts.get("justfile", "")

    tile_enum = enum_block("src/types.odin", "Tile_Type")
    ui_struct = types[types.find("UI_State :: struct") : types.find("Game_State :: enum")]
    game_struct = types[types.find("Game :: struct") :]
    base_color = proc_block("src/render_map.odin", "base_tile_color")
    render_map = proc_block("src/render_map.odin", "render_map")
    get_tile_color = proc_block("src/render_map.odin", "get_tile_color")
    generate_map = proc_block("src/generation.odin", "generate_map")
    spawn_hazards = proc_block("src/generation.odin", "spawn_hazards")
    is_walkable = proc_block("src/map_utils.odin", "is_walkable")
    is_opaque = proc_block("src/fov.odin", "is_opaque")
    advance_turn = proc_block("src/main.odin", "advance_turn")
    restart_game = proc_block("src/main.odin", "restart_game")
    handle_forced_turn = proc_block("src/main.odin", "handle_forced_turn")
    handle_playing_hotkeys = proc_block("src/main.odin", "handle_playing_hotkeys")
    handle_player_action = proc_block("src/main.odin", "handle_player_action")
    handle_player_moved = proc_block("src/main.odin", "handle_player_moved")
    apply_current_tile_effects = proc_block("src/main.odin", "apply_current_tile_effects")
    collapse_unstable_previous_tile = proc_block("src/main.odin", "collapse_unstable_previous_tile")
    update_game_over = proc_block("src/main.odin", "update_game_over")
    update_viewing_inventory = proc_block("src/main.odin", "update_viewing_inventory")
    render_game = proc_block("src/render.odin", "render_game")
    render_minimap = proc_block("src/render_minimap.odin", "render_minimap")
    input_handle = proc_block("src/input.odin", "handle_input")
    descend = proc_block("src/input.odin", "descend")
    render_hud = proc_block("src/render_hud.odin", "render_hud")

    require(
        "inputs.only_declared_source_and_justfile",
        bool(texts) and set(texts) == set(ALLOWED_INPUTS) and all(not p.startswith((".gsd/", ".git/")) for p in texts),
        "script must read exactly the declared source files and justfile, not .gsd/.git/generated artifacts",
    )
    require(
        "justfile.verify_keeps_check_and_build",
        regex(justfile, r"(?m)^verify:\s+check\s+build\b") and "odin check {{src}}" in justfile and "odin build {{src}}" in justfile,
        "justfile should expose verify: check build with Odin check/build recipes",
    )

    require(
        "hazard.enum_members_present",
        has_all(tile_enum, ["Water", "Gas_Vent", "Unstable", "Chasm"]),
        "Tile_Type enum must include Water, Gas_Vent, Unstable, and Chasm",
    )

    hazard_colors = {name: color_for_case(base_color, name) for name in ("Water", "Gas_Vent", "Unstable", "Chasm")}
    require(
        "hazard.main_map_colors_defined",
        all(color is not None for color in hazard_colors.values()),
        f"base_tile_color must define explicit rl.Color returns for all hazards; got {hazard_colors}",
    )
    require(
        "hazard.main_map_colors_distinct",
        all(color is not None for color in hazard_colors.values()) and len(set(hazard_colors.values())) == 4,
        f"Water/Gas_Vent/Unstable/Chasm colors must be distinct; got {hazard_colors}",
    )
    require(
        "hazard.visible_and_explored_use_base_tile_color",
        "base := base_tile_color(tile.type, palette)" in render_map
        and "if tile.visible" in render_map
        and "else" in render_map
        and "EXPLORED_DIM" in render_map
        and has_all(get_tile_color, ["tile.visible", "tile.explored", "base_tile_color(tile.type, palette)"]),
        "render_map/get_tile_color must derive visible and explored colors from base_tile_color(tile.type, palette)",
    )

    require(
        "hazard.generate_map_calls_spawn_hazards",
        "spawn_hazards(game)" in generate_map,
        "generate_map must call spawn_hazards(game)",
    )
    require(
        "hazard.depth_gates_water_gas_unstable",
        regex(spawn_hazards, r"if\s+depth\s*>=\s*1[^{]*\{.*?\.Water")
        and regex(spawn_hazards, r"if\s+depth\s*>=\s*3[^{]*\{.*?\.Gas_Vent")
        and regex(spawn_hazards, r"if\s+depth\s*>=\s*5[^{]*\{.*?\.Unstable"),
        "spawn_hazards must gate Water at depth >=1, Gas_Vent at >=3, and Unstable at >=5",
    )
    require(
        "hazard.walkability_and_opacity",
        has_all(is_walkable, [".Water", ".Gas_Vent", ".Unstable"])
        and ".Chasm" not in is_walkable
        and "t.type == .Wall || t.type == .Chasm" in compact(is_opaque),
        "Water/Gas_Vent/Unstable must be walkable while Chasm is non-walkable and opaque",
    )
    require(
        "hazard.water_slow_wiring",
        "water_slow_active: bool" in game_struct
        and has_all(apply_current_tile_effects, ["cur_tile.type == .Water", "game.water_slow_active = true", "You wade through water"])
        and has_all(handle_forced_turn, ["game.water_slow_active", "advance_turn(game, hp_before)", "You push through the water"]),
        "Water must set water_slow_active and the forced-turn handler must consume it with an extra advance_turn",
    )
    require(
        "hazard.gas_damage_message_wiring",
        has_all(apply_current_tile_effects, ["cur_tile.type == .Gas_Vent", "game.player.hp -= 3", "Toxic gas burns you! (-3 HP)", "Suffocated by toxic gas", ".Game_Over"]),
        "Gas_Vent must damage HP, message the player, and wire lethal gas to Game_Over/death cause",
    )
    require(
        "hazard.unstable_collapse_to_chasm_wiring",
        has_all(game_struct, ["prev_player_pos", "water_slow_active"])
        and has_all(collapse_unstable_previous_tile, ["prev_tile.type == .Unstable", "prev_tile.type = .Chasm", "The ground collapses behind you"]),
        "Unstable previous tile must collapse into Chasm with a player message",
    )
    require(
        "hazard.effects_before_advance_turn",
        in_order(handle_player_moved, ["consume_web_if_present(game)", "apply_current_tile_effects(game)", "collapse_unstable_previous_tile(game)", "advance_turn(game, hp_before)"]),
        "handle_player_moved must apply hazard effects/collapse before advance_turn",
    )

    require(
        "minimap.ui_state_exists",
        "show_minimap:  bool" in ui_struct,
        "UI_State must contain show_minimap",
    )
    require(
        "minimap.m_key_toggle_wired",
        has_all(handle_playing_hotkeys, ["rl.IsKeyPressed(.M)", "game.ui.show_minimap = !game.ui.show_minimap"]),
        "M key must toggle game.ui.show_minimap in playing hotkeys",
    )
    require(
        "minimap.render_gate_wired",
        has_all(render_game, ["game.ui.show_minimap", "game.state == .Playing", "render_minimap(game)"]),
        "render_game must gate render_minimap on show_minimap while Playing",
    )
    require(
        "minimap.top_right_placement",
        has_all(render_minimap, ["mm_w := i32(MAP_WIDTH) * MINIMAP_TILE_SIZE", "mm_x := i32(SCREEN_WIDTH) - mm_w - MINIMAP_MARGIN", "mm_y := MINIMAP_MARGIN"]),
        "render_minimap must place the overlay in the top-right corner",
    )
    require(
        "minimap.visible_explored_unseen_treatment",
        has_all(render_minimap, ["if tile.visible", "else if tile.explored", "Unseen tiles: don't draw"]),
        "render_minimap must distinguish visible, explored, and unseen tiles",
    )
    require(
        "minimap.enemy_red_dot",
        has_all(render_minimap, ["for &enemy in game.enemies", "!enemy.alive", "!tile.visible", "rl.Color{255, 60, 60, 255}"]),
        "render_minimap must draw alive enemies on visible tiles as red dots",
    )
    require(
        "minimap.player_yellow_dot",
        has_all(render_minimap, ["player_px", "player_py", "rl.Color{255, 255, 0, 255}"]),
        "render_minimap must draw the player as a yellow dot",
    )

    require(
        "core.render_order_connected",
        in_order(render_game, ["render_map(game)", "render_webs(game)", "render_items(game)", "render_enemies(game)", "render_player(game)", "render_particles()", "render_hud(game)", "render_messages(game)"]),
        "render_game must preserve map/web/item/enemy/player/particle/HUD/message order",
    )
    require(
        "core.advance_turn_fov_camera_connected",
        in_order(advance_turn, ["process_enemy_turns(game)", "process_enemy_abilities(game)", "remove_dead_enemies(game)", "tick_timed_effects(game)", "compute_fov(game)", "camera_update(game)"]),
        "advance_turn must process enemies/effects then recompute FOV and update camera",
    )
    require(
        "core.initial_restart_descent_fov_camera_connected",
        has_all(main_text, ["compute_fov(game)", "camera_update(game, snap = true)"])
        and has_all(restart_game, ["game_reinit(game)", "compute_fov(game)", "camera_update(game, snap = true)"])
        and has_all(descend, ["generate_map(game)", "compute_fov(game)", "camera_update(game, snap = true)"]),
        "main init, restart, and descent must recompute FOV and snap camera after map setup",
    )
    require(
        "core.movement_and_bump_attack_connected",
        has_all(input_handle, ["check_move_direction()", "is_walkable(game, target_x, target_y)", "enemy_at(game, target_x, target_y)", "resolve_attack_player_on_enemy(game, target_enemy)", "game.player.pos.x = target_x", "return .Moved"]),
        "handle_input must keep movement, walkability, bump attack, and moved result wiring",
    )
    require(
        "core.descent_connected",
        has_all(input_handle, ["t.type == .Descent", "descend(game)", "return .Descended"])
        and has_all(descend, ["game.depth += 1", "generate_map(game)", "You descend to depth"]),
        "descent tile handling must call descend and regenerate the next depth",
    )
    require(
        "core.hud_hint_connected",
        "G=Grab  I=Inv  X=Mine  M=Map  ?=Help" in render_hud,
        "HUD must continue advertising core gameplay hotkeys including minimap",
    )
    require(
        "core.inventory_hotkeys_connected",
        has_all(handle_playing_hotkeys, ["rl.IsKeyPressed(.I)", "game.state = .Viewing_Inventory", "game.ui.inspect_slot = 0"])
        and has_all(update_viewing_inventory, ["rl.IsKeyPressed(.I) || rl.IsKeyPressed(.ESCAPE)", "game.ui.dropping = !game.ui.dropping", "game.ui.equipping = !game.ui.equipping", "keys := [9]rl.KeyboardKey", "use_item(game, idx)"]),
        "Inventory open/close, drop/equip toggles, number hotkeys, and use_item path must remain wired",
    )
    require(
        "core.game_over_restart_connected",
        has_all(update_game_over, ["rl.IsKeyPressed(.R)", "death_sound_played = false", "restart_game(game)"]) and "restart_game(game)" in main_text,
        "Game-over R key must restart through restart_game",
    )
    require(
        "core.player_action_routes_results",
        has_all(handle_player_action, ["result := handle_input(game)", "case .Moved", "handle_player_moved(game, kills_before)", "case .Waited", "advance_turn(game, hp_before)", "case .Descended", "handle_player_descended(game)"]),
        "handle_player_action must route input results to move/wait/descent handlers",
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
