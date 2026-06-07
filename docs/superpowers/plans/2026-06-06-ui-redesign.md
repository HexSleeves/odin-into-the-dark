# Into the Depths UI Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin the entire game UI to a Cogmind-style "dense tech readout" with the Lamplit Mine palette, bordered header panels, segmented bars, and a fuel-reactive light glow.

**Architecture:** Pure design tokens + two reusable Clay helpers (`clay_panel_begin`, `clay_bar_segmented`) drive every surface. HUD, message log, overlays, tooltip, and minimap consume them. One pure color helper (`light_glow_tint`) drives a warm ambient + fuel-reactive map glow. Engine layer (`src/engine/`) is untouched.

**Tech Stack:** Odin, Clay immediate-mode UI (`src/vendor/clay`), custom render backend. Tests via `python3 scripts/run_odin_tests.py` (overlays `test/**/*_test.odin` into the matching `src` package).

**Conventions:**
- Pure helpers live in `package renderer` (`src/render/`). Their tests go in `test/render/*_test.odin` as `package renderer`.
- Run a single test: `python3 scripts/run_odin_tests.py -define:ODIN_TEST_NAMES=renderer.<name>`. If the name filter misbehaves, fall back to `just test`.
- Type-check fast with `just check`. Full gate is `just verify`. Format with `just fmt` before any commit.
- Visual tasks have no unit test — verify with `just check` (must compile) and note a `just run` visual check.

---

## Task 1: Lamplit Mine palette tokens

**Files:**
- Modify: `src/ui/ui_theme.odin:7-26`

- [ ] **Step 1: Retune the palette + add two constants**

Replace the `SB_*` color block (`src/ui/ui_theme.odin:7-26`) with:

```odin
// Sidebar palette — "Lamplit Mine". Gold (SB_TITLE) is reserved for treasure/title only.
SB_BG :: eng.Engine_Color{11, 10, 15, 255} // #0B0A0F screen void / sidebar base
SB_PANEL :: eng.Engine_Color{21, 19, 28, 255} // #15131C readout panel background
SB_DIVIDER :: eng.Engine_Color{58, 53, 80, 255} // #3A3550 panel border / divider
SB_TITLE :: eng.Engine_Color{245, 182, 56, 255} // #F5B638 gold accent (treasure/title)
SB_HEADER :: eng.Engine_Color{138, 130, 112, 255} // #8A8270 panel header labels
SB_TEXT :: eng.Engine_Color{232, 223, 200, 255} // #E8DFC8 primary text
SB_DIM :: eng.Engine_Color{90, 86, 72, 255} // #5A5648 passive/secondary
SB_HP_BG :: eng.Engine_Color{30, 20, 20, 255} // HP bar empty cell
SB_HP_FG :: eng.Engine_Color{111, 191, 115, 255} // #6FBF73 HP healthy
SB_HP_LOW :: eng.Engine_Color{216, 69, 62, 255} // #D8453E HP danger
SB_PICK_BG :: eng.Engine_Color{36, 31, 16, 255} // PICK bar empty cell
SB_PICK_OK :: eng.Engine_Color{232, 163, 61, 255} // #E8A33D pick healthy (amber)
SB_PICK_WARN :: eng.Engine_Color{245, 182, 56, 255} // pick warn
SB_PICK_CRIT :: eng.Engine_Color{216, 69, 62, 255} // pick crit
SB_WPN :: eng.Engine_Color{255, 158, 61, 255} // warm — weapon
SB_ARM :: eng.Engine_Color{138, 158, 168, 255} // cool steel — armor
SB_HLM :: eng.Engine_Color{200, 180, 120, 255} // brass — helmet
SB_OIL :: eng.Engine_Color{255, 158, 61, 255} // #FF9E3D lamp / oil / fuel
SB_LAMP_LOW :: eng.Engine_Color{122, 74, 28, 255} // #7A4A1C ember (low fuel)
SB_POISON :: eng.Engine_Color{115, 200, 40, 255} // poison
SB_BOSS :: eng.Engine_Color{216, 69, 62, 255} // #D8453E boss
SB_KEY :: eng.Engine_Color{138, 130, 112, 255} // control keys (de-emphasized)
```

- [ ] **Step 2: Type-check**

Run: `just check`
Expected: PASS (no errors). New names `SB_PANEL`, `SB_LAMP_LOW` compile; all old names still exist.

- [ ] **Step 3: Commit**

```bash
git add src/ui/ui_theme.odin
git commit -m "feat(ui): Lamplit Mine palette tokens"
```

---

## Task 2: Segmented-bar fill math (pure, TDD)

**Files:**
- Modify: `src/render/clay_theme.odin`
- Test: `test/render/clay_bar_test.odin` (create)

- [ ] **Step 1: Write the failing test**

Create `test/render/clay_bar_test.odin`:

```odin
package renderer

import "core:testing"

@(test)
bar_segment_fill_count_rounds_and_clamps :: proc(t: ^testing.T) {
	testing.expect_value(t, bar_segment_fill_count(0.0, 10), 0)
	testing.expect_value(t, bar_segment_fill_count(1.0, 10), 10)
	testing.expect_value(t, bar_segment_fill_count(0.5, 10), 5)
	testing.expect_value(t, bar_segment_fill_count(0.54, 10), 5) // rounds down
	testing.expect_value(t, bar_segment_fill_count(0.55, 10), 6) // rounds up
	testing.expect_value(t, bar_segment_fill_count(-0.3, 10), 0) // clamp low
	testing.expect_value(t, bar_segment_fill_count(2.0, 10), 10) // clamp high
	testing.expect_value(t, bar_segment_fill_count(0.1, 5), 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 scripts/run_odin_tests.py -define:ODIN_TEST_NAMES=renderer.bar_segment_fill_count_rounds_and_clamps`
Expected: FAIL — `bar_segment_fill_count` undefined.

- [ ] **Step 3: Implement the helper**

Add to `src/render/clay_theme.odin` (after the `import` block; add `import "core:math"` at top if not present):

```odin
// Number of filled cells for a segmented bar of `segments` cells at `ratio` (0..1).
bar_segment_fill_count :: proc(ratio: f32, segments: int) -> int {
	r := clamp(ratio, 0, 1)
	return clamp(int(math.round(r * f32(segments))), 0, segments)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 scripts/run_odin_tests.py -define:ODIN_TEST_NAMES=renderer.bar_segment_fill_count_rounds_and_clamps`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/render/clay_theme.odin test/render/clay_bar_test.odin
git commit -m "feat(ui): segmented-bar fill math"
```

---

## Task 3: Panel + segmented-bar Clay helpers

**Files:**
- Modify: `src/render/clay_theme.odin` (add `CLAY_PANEL_PAD`, `clay_panel_begin`)
- Modify: `src/render/clay_hud.odin` (add `clay_bar_segmented`)

- [ ] **Step 1: Add panel constant + helper to `clay_theme.odin`**

Add after `CLAY_SPACE_LG`:

```odin
CLAY_PANEL_PAD :: u16(6)
```

Add a panel-open helper (mirrors the existing `clay.UI` block idiom — used as `if clay_panel_begin(id, "VITALS") { ...children... }`):

```odin
// Bordered readout panel with an inset uppercase header. Use as:
//   if clay_panel_begin("hud-vitals", "VITALS") { ...child elements... }
clay_panel_begin :: proc(id: string, header: string) -> bool {
	open := clay.UI(clay.ID(id))(
	clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
			padding = {
				left = CLAY_PANEL_PAD,
				right = CLAY_PANEL_PAD,
				top = CLAY_PANEL_PAD,
				bottom = CLAY_PANEL_PAD,
			},
			layoutDirection = .TopToBottom,
			childGap = CLAY_SPACE_XS,
		},
		backgroundColor = clay_color(ui_pkg.SB_PANEL),
		cornerRadius = {2, 2, 2, 2},
		border = {color = clay_color(ui_pkg.SB_DIVIDER), width = {1, 1, 1, 1, 0}},
	},
	)
	if open {
		clay_text(header, CLAY_FONT_SMALL, ui_pkg.SB_HEADER)
	}
	return open
}
```

NOTE: the `border` and `cornerRadius` field shapes depend on the vendored Clay binding. If `just check` errors on those fields, open `src/vendor/clay/clay.odin`, find `BorderElementConfig` / `CornerRadius` / `ElementDeclaration.border`, and match the literal shape (e.g. `border = clay.BorderElementConfig{...}`). The 5th border width value is `betweenChildren` in upstream Clay — drop it if the binding's `BorderWidth` has only 4 fields. Borders are already rendered by `clay_render_border` (`src/render/clay_renderer.odin:108`), so this only needs to compile and emit the command.

- [ ] **Step 2: Add `clay_bar_segmented` to `clay_hud.odin`**

Add next to `clay_bar` (`src/render/clay_hud.odin:302`):

```odin
clay_bar_segmented :: proc(
	id: string,
	ratio: f32,
	segments: int,
	height: u16,
	bg, fg: eng.Engine_Color,
) {
	filled := bar_segment_fill_count(ratio, segments)
	if clay.UI(clay.ID(id))(
	clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(f32(height))},
			layoutDirection = .LeftToRight,
			childGap = 1,
		},
	},
	) {
		for i in 0 ..< segments {
			cell_color := bg
			if i < filled {cell_color = fg}
			if clay.UI(clay.ID_LOCAL("seg"))(
			clay.ElementDeclaration {
				layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}},
				backgroundColor = clay_color(cell_color),
			},
			) {}
		}
	}
}
```

- [ ] **Step 3: Type-check**

Run: `just check`
Expected: PASS. (Helpers unused yet — Odin allows unused package-level procs.)

- [ ] **Step 4: Commit**

```bash
git add src/render/clay_theme.odin src/render/clay_hud.odin
git commit -m "feat(ui): panel + segmented-bar Clay helpers"
```

---

## Task 4: Rewrite the gameplay HUD into readout panels

**Files:**
- Modify: `src/render/clay_hud.odin:21-264` (`clay_render_hud`)

Preserve ALL existing conditionals/logic (HP ratio, attack-cost thresholds, pick durability states, boss loop, status flags). Only change the visual wrapping: group rows into `clay_panel_begin` blocks and swap `clay_bar` → `clay_bar_segmented` for HP and PICK. Quest text color moves to `ui_pkg.SB_OIL` (amber), NOT gold.

- [ ] **Step 1: Replace the sidebar body**

Inside the `hud-sidebar` block, replace everything from the title line through the controls (currently `src/render/clay_hud.odin:55-261`) with panel-grouped content. Keep `childGap = CLAY_SPACE_SM` on the sidebar so panels are spaced. Structure:

```odin
clay_text_centered("INTO THE DEPTHS", CLAY_FONT_TITLE, ui_pkg.SB_TITLE)

// VITALS panel
if clay_panel_begin("hud-vitals", "VITALS") {
	hp_ratio := f32(max(game.player.hp, 0)) / f32(max(game.player.max_hp, 1))
	hp_fg := ui_pkg.SB_HP_FG if hp_ratio > 0.3 else ui_pkg.SB_HP_LOW
	clay_row("hud-hp-row", "HP", fmt.tprintf("%d / %d", i32(game.player.hp), i32(game.player.max_hp)), CLAY_HUD_FONT, ui_pkg.SB_HEADER, ui_pkg.SB_TEXT)
	clay_bar_segmented("hud-hp-bar", hp_ratio, 10, ui_pkg.SB_HP_BG, hp_fg)

	cost := gcore.effective_attack_cost(game)
	spd_label: string
	spd_color: eng.Engine_Color
	if cost <= 700 {
		spd_label = "Fast";    spd_color = ui_pkg.SB_HP_FG
	} else if cost <= 1100 {
		spd_label = "Normal";  spd_color = ui_pkg.SB_TEXT
	} else if cost <= 1600 {
		spd_label = "Slow";    spd_color = ui_pkg.SB_PICK_WARN
	} else {
		spd_label = "Very Slow"; spd_color = ui_pkg.SB_HP_LOW
	}
	clay_row("hud-atk-row", "ATK", spd_label, CLAY_HUD_FONT, ui_pkg.SB_HEADER, spd_color)

	if game.equipped_weapon.occupied {
		wpn := game.equipped_weapon.item
		if wpn.max_durability > 0 {
			pick_ratio := f32(wpn.durability) / f32(max(wpn.max_durability, 1))
			pick_fg: eng.Engine_Color
			if wpn.durability <= 0 {
				pick_fg = ui_pkg.SB_PICK_CRIT
			} else if pick_ratio > 0.5 {
				pick_fg = ui_pkg.SB_PICK_OK
			} else if pick_ratio > 0.25 {
				pick_fg = ui_pkg.SB_PICK_WARN
			} else {
				pick_fg = ui_pkg.SB_PICK_CRIT
			}
			if wpn.durability <= 0 {
				clay_text("PICK  BROKEN", CLAY_HUD_FONT, ui_pkg.SB_PICK_CRIT)
			} else {
				clay_row("hud-pick-row", "PICK", fmt.tprintf("%d / %d", i32(wpn.durability), i32(wpn.max_durability)), CLAY_HUD_FONT, ui_pkg.SB_HEADER, ui_pkg.SB_TEXT)
			}
			clay_bar_segmented("hud-pick-bar", pick_ratio, 10, ui_pkg.SB_PICK_BG, pick_fg)
		}
	}
}

// EXPEDITION panel
if clay_panel_begin("hud-expedition", "EXPEDITION") {
	depth_label := fmt.tprintf("DEPTH  %d", i32(game.depth))
	if game.depth == gcore.SURFACE_DEPTH {depth_label = "SURFACE"}
	clay_row("hud-depth-row", depth_label, fmt.tprintf("TURN %d", i32(eng.turn_manager_current(turns))), CLAY_HUD_ROW_FONT, ui_pkg.SB_TEXT, ui_pkg.SB_DIM)
	clay_row("hud-pos-row", fmt.tprintf("POS  %d,%d", i32(game.player.pos.x), i32(game.player.pos.y)), "", CLAY_HUD_ROW_FONT, ui_pkg.SB_DIM, ui_pkg.SB_DIM)

	alive_count: i32 = 0
	for &e in game.enemies {if e.alive {alive_count += 1}}
	clay_row("hud-kills-row", fmt.tprintf("KILLS  %d", i32(game.kills)), fmt.tprintf("NEAR %d", alive_count), CLAY_HUD_ROW_FONT, ui_pkg.SB_TEXT, ui_pkg.SB_DIM)
	if game.light_boost_turns > 0 {
		clay_row("hud-light-row", fmt.tprintf("LIGHT  %d", i32(game.player.light_radius)), fmt.tprintf("%dt fuel", i32(game.light_boost_turns)), CLAY_HUD_ROW_FONT, ui_pkg.SB_OIL, ui_pkg.SB_OIL)
	} else {
		clay_row("hud-light-row", fmt.tprintf("LIGHT  %d", i32(game.player.light_radius)), fmt.tprintf("ITEMS %d", i32(game.items_found)), CLAY_HUD_ROW_FONT, ui_pkg.SB_TEXT, ui_pkg.SB_DIM)
	}
}

// QUEST panel (amber, not gold)
if game.quest != .Complete {
	if clay_panel_begin("hud-quest", "QUEST") {
		clay_text(gcore.quest_objective_text(game), CLAY_HUD_ROW_FONT, ui_pkg.SB_OIL)
	}
}

// GEAR panel
if clay_panel_begin("hud-gear", "GEAR") {
	if game.equipped_weapon.occupied {
		wpn := &game.equipped_weapon.item
		clay_text(fmt.tprintf("WPN  %s (+%d)", wpn.name, i32(wpn.stat_bonus)), CLAY_HUD_FONT, ui_pkg.SB_WPN)
	} else {clay_text("WPN  ---", CLAY_HUD_FONT, ui_pkg.SB_DIM)}
	if game.equipped_armor.occupied {
		arm := &game.equipped_armor.item
		clay_text(fmt.tprintf("ARM  %s (+%d)", arm.name, i32(arm.stat_bonus)), CLAY_HUD_FONT, ui_pkg.SB_ARM)
	} else {clay_text("ARM  ---", CLAY_HUD_FONT, ui_pkg.SB_DIM)}
	if game.equipped_helmet.occupied {
		hlm := &game.equipped_helmet.item
		clay_text(fmt.tprintf("HLM  %s (+%d)", hlm.name, i32(hlm.stat_bonus)), CLAY_HUD_FONT, ui_pkg.SB_HLM)
	} else {clay_text("HLM  ---", CLAY_HUD_FONT, ui_pkg.SB_DIM)}
}

// STATUS panel (only when active)
has_status := game.light_boost_turns > 0 || game.poison_turns > 0 || game.burning_turns > 0 || game.frozen_turns > 0
if has_status {
	if clay_panel_begin("hud-status", "STATUS") {
		if game.light_boost_turns > 0 {clay_text(fmt.tprintf("OIL   %dt remaining", i32(game.light_boost_turns)), CLAY_HUD_FONT, ui_pkg.SB_OIL)}
		if game.poison_turns > 0 {clay_text(fmt.tprintf("POISON  %dt remaining", i32(game.poison_turns)), CLAY_HUD_FONT, ui_pkg.SB_POISON)}
		if game.burning_turns > 0 {clay_text(fmt.tprintf("BURNING (%d)", i32(game.burning_turns)), CLAY_HUD_FONT, eng.Engine_Color{255, 120, 20, 255})}
		if game.frozen_turns > 0 {clay_text(fmt.tprintf("FROZEN (%d)", i32(game.frozen_turns)), CLAY_HUD_FONT, eng.Engine_Color{100, 180, 255, 255})}
	}
}

// BOSS panel (only when a boss is alive)
for &enemy in game.enemies {
	if !enemy.alive || !enemy.is_boss {continue}
	if clay_panel_begin("hud-boss", "BOSS") {
		clay_row("hud-boss-row", fmt.tprintf("%s", enemy.name), fmt.tprintf("%d/%d", i32(enemy.hp), i32(enemy.max_hp)), CLAY_HUD_FONT, ui_pkg.SB_BOSS, ui_pkg.SB_TEXT)
		boss_ratio := f32(max(enemy.hp, 0)) / f32(max(enemy.max_hp, 1))
		clay_bar_segmented("hud-boss-bar", boss_ratio, 10, eng.Engine_Color{50, 15, 15, 255}, ui_pkg.SB_BOSS)
	}
	break
}

clay_spacer_grow("hud-controls-spacer")

// CONTROLS panel
if clay_panel_begin("hud-controls", "CONTROLS") {
	clay_text("[I]nv  [G]rab  [X]Mine", CLAY_HUD_FONT, ui_pkg.SB_KEY)
	clay_text("[M]ap  [?]Help  [.]Wait", CLAY_HUD_FONT, ui_pkg.SB_KEY)
	clay_text("[F1]Mute  [ ]/[ ] Vol", CLAY_HUD_FONT, ui_pkg.SB_KEY)
}
```

The old `clay_theme_divider(...)` calls are removed (panels provide separation). Leave `clay_theme_divider` defined (still used elsewhere until those tasks land).

- [ ] **Step 2: Type-check**

Run: `just check`
Expected: PASS.

- [ ] **Step 3: Build**

Run: `just build`
Expected: builds clean.

- [ ] **Step 4: Visual check (manual)**

Run: `just run` — confirm sidebar shows bordered VITALS/EXPEDITION/QUEST/GEAR/CONTROLS panels with segmented HP/PICK bars. (No assertion; eyeball against the design.)

- [ ] **Step 5: Commit**

```bash
git add src/render/clay_hud.odin
git commit -m "feat(ui): HUD readout panels + segmented bars"
```

---

## Task 5: Message log panel

**Files:**
- Modify: `src/render/clay_messages.odin:19-53`

- [ ] **Step 1: Reskin the log container**

In `clay_render_messages`, change the `messages-panel` `backgroundColor` from the hardcoded `{15,15,20,255}` to `clay_color(ui_pkg.SB_BG)`, add a top border in `SB_DIVIDER`, and add `import ui_pkg "../ui"` at the top of the file. Replace the element declaration's `backgroundColor` line and add a `border`:

```odin
		backgroundColor = clay_color(ui_pkg.SB_BG),
		border = {color = clay_color(ui_pkg.SB_DIVIDER), width = {0, 0, 1, 0, 0}}, // top edge only
```

(If the binding's `BorderWidth` has 4 fields, drop the trailing `0`.)

- [ ] **Step 2: Dim older lines**

Replace the message loop body so the newest line is full `SB_TEXT`-bright and older lines fade. Keep each message's own color hue but scale brightness by recency:

```odin
		for i in 0 ..< visible_count {
			msg_offset := visible_count - 1 - i
			msg_idx := (log.head - 1 - msg_offset + gcore.MAX_MESSAGES * 2) % gcore.MAX_MESSAGES
			msg := &log.messages[msg_idx]
			// i == visible_count-1 is newest (brightest); older lines dim toward 0.5.
			recency := f32(i + 1) / f32(visible_count)
			fade := 0.5 + 0.5 * recency
			c := msg.color
			faded := eng.Engine_Color{u8(f32(c.r) * fade), u8(f32(c.g) * fade), u8(f32(c.b) * fade), c.a}
			clay.TextDynamic(
				string(msg.text[:msg.text_len]),
				{textColor = clay_color(faded), fontSize = CLAY_FONT_SMALL, lineHeight = u16(MSG_LINE_HEIGHT)},
			)
		}
```

- [ ] **Step 2: Type-check + build**

Run: `just check && just build`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add src/render/clay_messages.odin
git commit -m "feat(ui): message log panel with recency fade"
```

---

## Task 6: Reskin overlays

**Files:**
- Modify: `src/render/clay_overlays.odin`

Before editing, read the whole file. Apply the palette + panel system uniformly without changing flow/inputs:

- [ ] **Step 1: Retheme the shared overlay helpers**

In `clay_overlay_decl` (`clay_overlays.odin:287`), give the centered content container `backgroundColor = clay_color(ui_pkg.SB_PANEL)`, a `border = {color = clay_color(ui_pkg.SB_DIVIDER), width = {1,1,1,1,0}}`, and `cornerRadius = {3,3,3,3}`. Keep the full-screen dim backdrop. In `clay_overlay_text` / `clay_title_text` (`clay_overlays.odin:304-316`) retarget default colors: body → `ui_pkg.SB_TEXT`, titles → `ui_pkg.SB_TITLE`. Add `import ui_pkg "../ui"` if absent.

- [ ] **Step 2: Recolor title embers**

In `clay_render_title_embers` (`clay_overlays.odin:54-87`), change the ember color to `ui_pkg.SB_OIL` (lamp) with the existing per-ember alpha phasing preserved.

- [ ] **Step 3: Sweep remaining hardcoded colors**

Grep the file for `Engine_Color{` literals and replace each with the nearest palette token (headers → `SB_TITLE`, body → `SB_TEXT`, dim/help → `SB_DIM`, danger/game-over → `SB_HP_LOW`, gold counts → `SB_TITLE`). Keep layout untouched.

Run: `rg "Engine_Color\{" src/render/clay_overlays.odin` — expected: only intentional remaining literals (none, ideally).

- [ ] **Step 4: Type-check + build**

Run: `just check && just build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/render/clay_overlays.odin
git commit -m "feat(ui): reskin overlays to Lamplit Mine panels"
```

---

## Task 7: Reskin event overlays + dialogue

**Files:**
- Modify: `src/render/clay_events.odin`
- Modify: `src/render/clay_dialogue.odin`

- [ ] **Step 1: Read both files**, then apply the same treatment as Task 6: panel container (`SB_PANEL` + `SB_DIVIDER` border + `cornerRadius {3,3,3,3}`), headers `SB_TITLE`, body `SB_TEXT`, dim `SB_DIM`. Shrine buff options and merchant offers: option labels `SB_TEXT`, material costs `SB_TITLE` (gold = currency). Add `import ui_pkg "../ui"` where absent.

- [ ] **Step 2: Sweep literals**

Run: `rg "Engine_Color\{" src/render/clay_events.odin src/render/clay_dialogue.odin` — replace each with the nearest token.

- [ ] **Step 3: Type-check + build**

Run: `just check && just build`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add src/render/clay_events.odin src/render/clay_dialogue.odin
git commit -m "feat(ui): reskin shrine/merchant/dialogue overlays"
```

---

## Task 8: Reskin tooltip + minimap

**Files:**
- Modify: `src/render/clay_tooltip.odin`
- Modify: `src/render/clay_minimap.odin`

- [ ] **Step 1: Tooltip** — read `clay_tooltip.odin`. Set the tooltip box `backgroundColor = clay_color(ui_pkg.SB_PANEL)` + `border = {color = clay_color(ui_pkg.SB_DIVIDER), width = {1,1,1,1,0}}`. Name text `SB_TEXT`; HP colored by ratio (`SB_HP_FG` >0.3 else `SB_HP_LOW`). Mining/anvil/fountain hint banners → `SB_OIL`.

- [ ] **Step 2: Minimap** — read `clay_minimap.odin`. In `clay_minimap_cell_color` (`clay_minimap.odin:90-144`): player → `SB_TITLE` (gold), enemy/boss → `SB_BOSS`, NPC → keep green (or `SB_POISON`), visible tiles → palette-tinted, explored-only → dim toward `SB_DIM`, unseen → `SB_BG`.

- [ ] **Step 3: Sweep literals**

Run: `rg "Engine_Color\{" src/render/clay_tooltip.odin src/render/clay_minimap.odin` — replace each with the nearest token.

- [ ] **Step 4: Type-check + build**

Run: `just check && just build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/render/clay_tooltip.odin src/render/clay_minimap.odin
git commit -m "feat(ui): reskin tooltip + minimap"
```

---

## Task 9: Fuel-reactive light glow (pure helper, TDD) + wiring

**Files:**
- Modify: `src/render/render_map.odin`
- Test: `test/render/light_glow_test.odin` (create)

Design: `light_glow_tint(boost_turns)` returns an RGB multiplier color. With no boost it returns a faint warm ambient (warms all visible tiles). While oil is burning it lerps from ember (low fuel) to lamp (full fuel). Visible tiles are multiplied by this tint before the existing light-level dim.

- [ ] **Step 1: Write the failing test**

Create `test/render/light_glow_test.odin`:

```odin
package renderer

import "core:testing"

@(test)
light_glow_tint_endpoints :: proc(t: ^testing.T) {
	// No boost → faint warm ambient.
	amb := light_glow_tint(0)
	testing.expect_value(t, amb.r, 255)
	testing.expect_value(t, amb.g, 248)
	testing.expect_value(t, amb.b, 236)

	// Full fuel (>= LIGHT_GLOW_FULL) → lamp tint.
	full := light_glow_tint(LIGHT_GLOW_FULL)
	testing.expect_value(t, full.r, 255)
	testing.expect_value(t, full.g, 225)
	testing.expect_value(t, full.b, 190)

	// Very low fuel (1 turn) → close to ember tint, warmer/redder than full.
	low := light_glow_tint(1)
	testing.expect(t, low.b < full.b, "low fuel should be redder (less blue) than full")
}

@(test)
mul_color_scales :: proc(t: ^testing.T) {
	c := mul_color({200, 100, 50, 255}, {255, 128, 0, 255})
	testing.expect_value(t, c.r, 200) // *255/255
	testing.expect_value(t, c.g, 50) // *128/255 = 50.19 -> 50
	testing.expect_value(t, c.b, 0) // *0
	testing.expect_value(t, c.a, 255)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 scripts/run_odin_tests.py -define:ODIN_TEST_NAMES=renderer.light_glow_tint_endpoints,renderer.mul_color_scales`
Expected: FAIL — symbols undefined.

- [ ] **Step 3: Implement helpers**

Add to `src/render/render_map.odin` (after `dim_color`, ~line 23):

```odin
LIGHT_GLOW_FULL :: 40 // fuel turns at which glow reaches full lamp warmth

// Multiply two colors channel-wise (b acts as a 0..255 tint per channel). Alpha from a.
mul_color :: proc(a, b: eng.Engine_Color) -> eng.Engine_Color {
	return eng.Engine_Color {
		u8(int(a.r) * int(b.r) / 255),
		u8(int(a.g) * int(b.g) / 255),
		u8(int(a.b) * int(b.b) / 255),
		a.a,
	}
}

// Warm tint applied to visible tiles. No oil → faint ambient warmth. Burning oil →
// lerp ember(low fuel) → lamp(full fuel) so the glow itself reads remaining fuel.
light_glow_tint :: proc(boost_turns: int) -> eng.Engine_Color {
	AMBIENT :: eng.Engine_Color{255, 248, 236, 255}
	EMBER :: eng.Engine_Color{255, 170, 110, 255}
	LAMP :: eng.Engine_Color{255, 225, 190, 255}
	if boost_turns <= 0 {
		return AMBIENT
	}
	r := clamp(f32(boost_turns) / f32(LIGHT_GLOW_FULL), 0, 1)
	lerp_u8 :: proc(a, b: u8, t: f32) -> u8 {return u8(f32(a) + (f32(b) - f32(a)) * t)}
	return eng.Engine_Color {
		lerp_u8(EMBER.r, LAMP.r, r),
		lerp_u8(EMBER.g, LAMP.g, r),
		lerp_u8(EMBER.b, LAMP.b, r),
		255,
	}
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 scripts/run_odin_tests.py -define:ODIN_TEST_NAMES=renderer.light_glow_tint_endpoints,renderer.mul_color_scales`
Expected: PASS.

- [ ] **Step 5: Wire glow into tile color**

Change `get_tile_color` (`render_map.odin:63-75`) to accept a glow tint and apply it to visible tiles. Add a defaulted param so existing callers/tests are unaffected:

```odin
get_tile_color :: proc(
	tile: gcore.Tile,
	state: eng.Tile_State,
	palette: gcore.Floor_Palette,
	glow: eng.Engine_Color = {255, 255, 255, 255},
) -> eng.Engine_Color {
	if state.visible {
		return dim_color(mul_color(base_tile_color(tile.type, palette), glow), max(state.light_level, 0.5))
	}
	if state.explored {
		return dim_color(base_tile_color(tile.type, palette), EXPLORED_DIM)
	}
	return UNSEEN_COLOR
}
```

Then in the tile-draw loop (`render_map`, ~lines 131-208), compute the glow once before the loop and pass it to the `get_tile_color(...)` call:

```odin
	glow := light_glow_tint(int(game.light_boost_turns))
	// ... inside loop, at the existing get_tile_color call site:
	color := get_tile_color(tile, state, palette, glow)
```

Read the loop to find the exact `get_tile_color(...)` call and the `game`/state variable names in scope; pass `glow` as the 4th arg there.

- [ ] **Step 6: Type-check + build + full test**

Run: `just check && just build`
Expected: PASS.
Run: `just test`
Expected: all pass (new + existing render tests).

- [ ] **Step 7: Visual check + commit**

Run: `just run` — confirm cave reads warmer; pick up oil and confirm glow brightens to lamp, dims toward ember as fuel runs low.

```bash
git add src/render/render_map.odin test/render/light_glow_test.odin
git commit -m "feat(render): fuel-reactive warm light glow"
```

---

## Task 10: Final gate

- [ ] **Step 1: Format**

Run: `just fmt`

- [ ] **Step 2: Full verify gate**

Run: `just verify`
Expected: PASS (tests + flag matrix + check + build).

- [ ] **Step 3: Commit any formatting**

```bash
git add -A
git commit -m "chore: fmt after UI redesign"
```

---

## Self-review notes

- **Spec coverage:** tokens (T1), panel+bar helpers (T2,T3), HUD (T4), message log (T5), overlays (T6), events+dialogue (T7), tooltip+minimap (T8), light polish (T9), verify gate (T10). All spec §2–§11 mapped.
- **Type consistency:** `clay_panel_begin(id, header) -> bool`, `clay_bar_segmented(id, ratio, segments, height, bg, fg)`, `bar_segment_fill_count(ratio, segments)`, `light_glow_tint(boost_turns)`, `mul_color(a, b)`, `get_tile_color(..., glow := white)` — names used consistently across tasks.
- **Known binding risk:** Clay `border`/`cornerRadius`/`BorderWidth` field shapes must be confirmed against `src/vendor/clay/clay.odin` at first use (Task 3 Step 1 note); same shape reused in Tasks 5–8.
- **Gold discipline:** treasure/title/currency only; quest text uses `SB_OIL` (amber).
