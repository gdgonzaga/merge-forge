---
title: Development Plan — MergeForge
tags: [dev-plan, godot, planning]
area: Projects
created: 2026-06-10
updated: 2026-06-10
status: DRAFT
---

# MergeForge — Development Plan

---

## Prerequisites

- [x] GDD completed and reviewed
- [x] ARCHITECTURE.md completed and reviewed
- [x] GDD and architecture are consistent with each other
- [ ] Dev plan pressure-tested against GDD and architecture

---

## Constraints

**Availability:** ~10 hours/week
**Familiar with:** Godot 4, GDScript
**Less familiar with:** Godot drag-and-drop system, mobile performance optimization
**Target launch:** No hard deadline
**Known risks:** Merge detection (flood-fill) edge cases, drag-and-drop across scene trees, mobile touch performance with many nodes

---

## Phase 1 — Vertical Slice

**Goal:** Does the merge board feel good? Can you place, merge, and see a result with placeholder art?

**Phase complete when:** You can buy a crate, see items land in staging, drag them onto a 5×5 grid, watch 3 identical items merge into a result, and see gold update.

**GDD reference:** Submodule — Merge System, Economy (crate buying)
**Architecture reference:** Subsystem: Merge Board, Subsystem: Recipe & Blueprint System (partial)

**Dependencies:** None — this is the starting point.

### Tasks

| # | Task | Done state | Risk | Status |
|---|------|-----------|------|--------|
| 1 | Create Godot project, configure for Android export, portrait 1080×1920 | Project opens, runs on device or emulator | | ☑ |
| 2 | Create `data/` JSON files: `items.json` (Metal + Herb families, 11 MVP items), `recipes.json` (6 recipe entries producing 7 results: iron_ore→iron_ingot, iron_ingot→iron_plate, iron_plate→sword, herb_leaf→herb_bundle, herb_bundle→refined_potion, refined_potion→healing_potion + battle_elixir), `crates.json` (1–2 crate types) | Files load without parse errors in Godot | | ☑ |
| 3 | `autoloads/recipe_resolver.gd` — loads items.json + recipes.json at `_ready()`, provides `get_options(item_id)` and `get_item_data(item_id)` | Unit-testable: given "iron_ore", returns recipe results | | ☑ |
| 4 | `autoloads/game_manager.gd` — gold tracking only (start at 50), `add_gold()`, `deduct_gold()`, emits `gold_changed` | Gold changes, signal fires | | ☑ |
| 5 | `autoloads/event_bus.gd` — empty signal registry, just the autoload shell | No crashes, accessible globally | | ☑ |
| 6 | `board/board_grid.gd` — 5×5 grid, `place_item()`, `remove_item()`, `swap_items()`, `get_board_state()`, empty cells render as colored rectangles | Items appear on grid, can be moved between cells | | ☑ |
| 7 | `board/board_cell.gd` — `_get_drag_data`, `_can_drop_data`, `_drop_data` for board-to-board swaps | Drag item from cell A to cell B, item moves | | ☑ |
| 8 | `board/floating_item.tscn` + `.gd` — staging area item with despawn timer, `_get_drag_data` to drag to board | Item spawns in staging, can be dragged to grid, despawns after timer | | ☑ |
| 9 | `board/merge_detector.gd` (RefCounted) — flood-fill scan for connected groups of 3+ identical items | Given a grid with 3 adjacent "iron_ore", returns correct MergeGroup | | ☑ |
| 10 | `board/merge_resolver.gd` (RefCounted) — consumes group, queries RecipeResolver, places result at center of mass | 3× iron_ore removed, 1× iron_ingot placed at center | | ☑ |
| 11 | `board/merge_choice_popup.tscn` + `.gd` — 2–4 buttons with item names (placeholder text) | Popup shows when merge has multiple options, choice returns to resolver | | ☑ |
| 12 | `board/merge_board.tscn` + `.gd` — assembles BoardGrid + MergeDetector + MergeResolver, wires staging → grid → merge flow. Receives config Dictionary at `_ready()` (grid size, merge callback). Never accesses GameManager directly — parent scene passes configuration including `merge_triggered_callback: Callable` | Full merge cycle: staging → grid → auto-detect → resolve → result appears | | ☑ |
| 13 | Minimal test scene — hardcoded crate purchase button, MergeBoard instance, gold display label | Buy crate → items in staging → drag to board → merge → gold bonus updates | | ☑ |

**Integration tasks:**
- [x] Full merge cycle works: crate buy → staging → drag to board → 3-match detected → result placed
- [x] Chain merge: if merge result matches neighbors, second merge triggers
- [x] Gold bonus calculated correctly: `(count - 3) × floor(item_value × 0.5)`
- [x] Merge choice popup appears when 2+ options, blocks board input until choice made

**Phase risks:**
- Flood-fill edge cases (diagonal false positives, disconnected shapes) — test thoroughly
- Godot drag-and-drop across different Control nodes — may need custom drag implementation
- Merge choice popup timing — must not break chain merge detection

---

## Phase 2 — Foundation

**Goal:** Build the systems everything else depends on. Scene transitions, persistent state, data loading, and the HUD.

**Decision rule:** If removing it would break multiple subsystems, it belongs here.

**Phase complete when:** You can start a new game, play through one shop session (hardcoded customers), see the session summary, return to prep phase, and quit to main menu — all with state persisting correctly.

**GDD reference:** Core Loop (Shop Mode), Screens and UI, What Persists Between Sessions
**Architecture reference:** Subsystem: Core, EventBus, GameManager (full), RecipeResolver (full), SaveManager

**Dependencies:** Phase 1 complete and merge board validated.

### Tasks

| # | Subsystem / Autoload | Task | Done state | Risk | Status |
|---|----------------------|------|-----------|------|--------|
| 1 | Core | `core/main.tscn` + `core/main.gd` — scene transitions via EventBus signals, `scene_map` Dictionary, `_transition_to()` frees old + instances new. Calls `AudioManager.play_music()` on shop ↔ dungeon transitions. Note: scene_map entries for Phase 3 scenes (shop_session, dungeon_run) can use placeholder paths until those scenes are created. | All testable scene transitions fire without memory leaks (Main Menu, Prep Phase; other entries added in Phase 3) | | ☑ |
| 2 | Core | `core/main_menu.tscn` + `core/main_menu.gd` — New Game + Continue buttons, emits `new_game_started` / `continue_game` | Buttons visible, Continue disabled when no save | | ☑ |
| 3 | Core | `core/hud.tscn` + `core/hud.gd` — gold label + reputation badge, connects to GameManager signals | Gold label updates on any gold change | | ☑ |
| 4 | Autoloads | `autoloads/event_bus.gd` — all MVP signals registered (merge_completed, customer_fulfilled, customer_rejected, session_ended, session_summary_dismissed, prep_start_session, prep_enter_dungeon, dungeon_cleared, dungeon_failed, dungeon_summary_dismissed, prep_quit_to_menu, new_game_started, continue_game, save_requested, item_despawned) | Signals emit and receive without errors | | ☑ |
| 5 | Autoloads | `autoloads/game_manager.gd` — full implementation: gold, reputation_points, unlocked_blueprints, reagent_inventory, purchased_upgrades, shop_board_state, grid_cols, grid_rows. All change signals. Methods: `add_gold`, `deduct_gold`, `add_reputation`, `add_blueprint`, `add_reagent`, `consume_reagent`, `add_upgrade`, `get_reputation_level`, `is_dungeon_unlocked`, `get_despawn_time`, `get_crate_discount`, `serialize`, `deserialize` | State survives serialize → deserialize round-trip | | ☑ |
| 6 | Autoloads | `autoloads/recipe_resolver.gd` — full implementation: loads items, recipes, blueprints, reagent_combos, crates, upgrades, reagents. Methods: `get_options`, `get_variant_options`, `get_item_data`, `get_blueprint_cost`, `get_blueprint_dependencies`, `has_blueprint`, `get_crate_data`, `get_all_crate_ids`, `get_upgrade_data`, `get_reagent_data`. Blueprint and reagent filtering. | All `get_*()` methods return correct data from JSON files | | ☑ |
| 7 | Autoloads | `autoloads/save_manager.gd` — `save_game()`, `load_game()`, `has_save()`, `delete_save()`. JSON atomic write to `user://save_data.json`. Listens to `save_requested` | Save file created, readable, survives app restart | | ☑ |
| 8 | Data files | Create remaining JSON files: `blueprints.json` (5 MVP blueprints: bp_iron_plate, bp_sword, bp_healing_potion, bp_battle_elixir, bp_flame_sword), `reagent_combos.json` (flame_sword entry), `upgrades.json` (3 upgrades), `reagents.json` (fire_essence), `customers.json` (10 hand-authored customers), `dungeons.json` (Goblin Cave), `enemies.json` (Slime + Goblin), `party.json` (3 members) | All files parse without errors, RecipeResolver loads them all | | ☑ |

**Integration tasks:**
- [x] New Game → GameManager reset → Shop Session loads
- [x] Continue → SaveManager loads → GameManager restored → Prep Phase loads
- [x] HUD visible in all game scenes, updates on gold/reputation changes
- [x] Auto-save fires on `save_requested` signal (after purchases, session end, dungeon end)
- [x] Scene transitions: no orphaned nodes, no duplicate signals

**Phase risks:**
- Save/load serialization — matching serialize/deserialize fields exactly, especially board state
- EventBus signal wiring — easy to miss a connection; test each transition path
- GameManager state growing beyond what save system handles — keep serialize/deserialize in sync

---

## Phase 3 — Content

**Goal:** Add all game content specified in the GDD. Each task maps to a specific ARCHITECTURE.md subsystem.

**Phase complete when:** Full shop loop works (10 customers, order fulfillment, crate buying, session summary, prep phase with purchases) and full dungeon loop works (walking, encounters, auto-combat, drops, usable items, clear/fail).

**GDD reference:** All content sections — Core Loop, Enemies, Progression, Screens, Submodules
**Architecture reference:** All subsystem entries

**Dependencies:** Phase 2 complete. All autoloads and scene management stable.

### Tasks

| # | Subsystem | Task | Done state | Risk | Status |
|---|-----------|------|-----------|------|--------|
| 1 | Shop Session | `shop/shop_session.tscn` + `shop_session.gd` — 10-customer loop, crate buying, board integration, order display, advance/reject customer | Play through 10 customers, gold updates per fulfillment | | ☑ |
| 2 | Shop Session | `shop/customer_generator.gd` — loads `customers.json`, returns flat list of 10 | Returns 10 customer dicts from JSON | | ☑ |
| 3 | Shop Session | `shop/order_card.tscn` + `.gd` — shows item icon + quantity + gold reward, emits `order_tapped(index)` on tap | Tap fulfills if items on board, flashes red if not | | ☑ |
| 4 | Shop Session | `shop/session_summary.tscn` + `.gd` — gold count-up animation, fulfilled/rejected counts, Continue button | Summary displays correct stats, Continue → prep phase | | ☑ |
| 5 | Economy & Progression | `progression/prep_phase.tscn` + `.gd` — TabContainer (Board / Blueprints / Upgrades), purchase logic, Start Session + Enter Dungeon + Quit buttons | Buy blueprint → appears in unlocked, buy upgrade → effect applies, buy reagent → inventory updates | | ☑ |
| 6 | Economy & Progression | Blueprint purchase — deduct gold, add to `unlocked_blueprints`, emit `blueprint_added`, trigger save | Buy bp_iron_plate → merge of iron_ingot now shows iron_plate option | | ☑ |
| 7 | Economy & Progression | Upgrade purchase — deduct gold, add to `purchased_upgrades`, apply effect (grid expand / slow timer / crate discount), emit `upgrade_added`, trigger save | Grid expand: board grows from 5×5 to 6×5. Slow timer: despawn 12s → 18s. Discount: crate price ×0.8 | | ☑ |
| 8 | Economy & Progression | Reagent purchase — deduct gold, add to `reagent_inventory`, emit `reagent_count_changed`, trigger save | Buy fire_essence → `reagent_inventory["fire_essence"] == 1` | | ☑ |
| 9 | Dungeon Run | `dungeon/dungeon_run.tscn` + `dungeon/dungeon_controller.gd` — loads `dungeons.json`, `enemies.json`, `party.json`. Walk timer, encounter triggers, combat delegation, usable item routing, end conditions | Walk → encounter at 20% → combat → walk → encounter at 50% → combat → walk → encounter at 80% → combat → walk to 100% → cleared | | ☑ |
| 10 | Dungeon Run | `dungeon/combat_engine.gd` — 1-second ticks, damage distribution, HP tracking, knockout detection, buff timers, `apply_effect()`, `get_enemy_data()` | Combat resolves: enemies take damage, party takes damage, KO detected, wipe detected | | ☑ |
| 11 | Dungeon Run | `dungeon/drop_manager.gd` — `spawn_drops(enemy_data)` using weighted pool, `add_drops_to_staging(drops, board)` | Enemy dies → correct items appear in dungeon board staging | | ☑ |
| 12 | Dungeon Run | `dungeon/party_member.tscn` + `.gd` — `setup(data)` loads sprite, HP bar updates, buff indicators, drop target for usable items via `_can_drop_data` / `_drop_data` | Drag healing potion to fighter → HP restores, item consumed from board | | ☑ |
| 13 | Dungeon Run | `dungeon/enemy_display.tscn` + `.gd` — `setup(data)` loads sprite, HP bar, `play_death()` | Enemies spawn with correct sprites, HP bars update during combat | | ☑ |
| 14 | Dungeon Run | `dungeon/dungeon_summary.tscn` + `.gd` — cleared (gold + blueprint + reputation) and failed (reputation loss) variants, Continue button | Cleared: shows +80g, +25 rep. Failed: shows -20 rep. Continue → prep phase | | ☑ |
| 15 | Merge Board | Reagent variant integration — MergeResolver checks `reagent_combos.json` for merge results, adds variant options to popup, consumes reagent on variant choice | Merge sword with fire_essence in inventory + bp_flame_sword unlocked → Flame Sword appears as option | | ☑ |
| 16 | Merge Board | Board state persistence — `get_board_state()` / `load_board_state()` on shop board and dungeon board. Save on session/dungeon end, load on session/dungeon start | Board items survive: session → prep → next session; dungeon run → dungeon run | | ☑ |
| 17 | Merge Board | BoardGrid order fulfillment methods — `count_items_on_board(item_id)` and `remove_items_by_id(item_id, count)` used by ShopSession for order checking and item removal | Fulfilling an order for 3× iron_ore removes exactly 3 from the board | | ☑ |

**Integration tasks:**
- [x] Full shop loop: MainMenu → ShopSession → 10 customers → SessionSummary → PrepPhase
- [x] Full dungeon loop: PrepPhase → DungeonRun → 3 encounters → DungeonSummary → PrepPhase
- [x] Blueprint gating: recipes without blueprint ownership are hidden from merge options
- [x] Reputation system: fulfill (+10), reject (-2), dungeon clear (+25), dungeon fail (-20) all update GameManager
- [x] Dungeon unlock: Enter Dungeon button only enabled at 150+ reputation
- [x] Economy balance: starting gold (50) allows at least 2 crate purchases before first customer
- [x] Usable items: Healing Potion (heal 30 HP) and Battle Elixir (+5 ATK for 10s) work in dungeon
- [x] Reagent variant: requires both blueprint + reagent to appear as option

**Phase risks:**
- Combat damage distribution — `floor(attack / target_count)` with min 1 needs careful edge-case testing (1 enemy, all KO but one, etc.)
- Board state serialization — item dictionaries must survive save/load without losing fields
- Dungeon board is separate instance from shop board — must not accidentally share state
- Merge choice popup in dungeon must NOT pause combat — combat continues while popup is open

---

## Phase 4 — Integration and Feel

**Goal:** Make the game feel like a game. Audio, visual feedback, and the polish that makes it playable end-to-end.

**Phase complete when:** Game is playable from New Game through multiple sessions + one dungeon run with audio, animations, and visual feedback in place.

**GDD reference:** Audio, Art Direction, Screens and UI
**Architecture reference:** Subsystem: Audio

**Dependencies:** Phase 3 complete. All content implemented and testable.

### Tasks

| # | Task | Done state | Risk | Status |
|---|------|-----------|------|--------|
| 1 | `autoloads/audio_manager.gd` — music crossfade, SFX pool (4–6 players), `play_music()`, `play_sfx()`, `stop_music()` | Music plays, crossfades between shop/dungeon themes, overlapping SFX works | | ☐ |
| 2 | Shop theme music — calm medieval workshop loop | Plays during shop session and prep phase, loops cleanly | | ☐ |
| 3 | Dungeon theme music — tense adventure loop | Plays during dungeon run, loops cleanly | | ☐ |
| 4 | SFX — all 14 events from GDD SFX table (item_place, merge_complete, despawn, customer_happy, customer_reject, gold_earn, session_start, session_end, dungeon_start, dungeon_clear, dungeon_fail, ko, purchase, crate_open) | Each event triggers correct sound | | ☐ |
| 5 | Item placeholder art — colored rectangles with text labels for all 11 MVP items + fire_essence reagent | Each item_id renders a distinct visual on the board | | ☐ |
| 6 | Enemy placeholder art — Slime (green rect), Goblin (brown rect) with name labels | Enemy sprites display correctly in dungeon | | ☐ |
| 7 | Party member placeholder art — Fighter (red rect), Mage (blue rect), Healer (green rect) with name labels | Party sprites display correctly in dungeon | | ☐ |
| 8 | Customer portrait placeholders — simple colored rects or icons for Basic and Standard customers | Customer displays in shop, satisfied/disappointed portraits in summary | | ☐ |
| 9 | HP bar color coding — green (>60%), yellow (30–60%), red (<30%) for party and enemy HP bars | Colors change as HP decreases | | ☐ |
| 10 | Staging item despawn visual — countdown indicator or fade-out on floating items | Player can see despawn timer visually | | ☐ |
| 11 | Merge flash — brief highlight or glow on cells involved in a merge | Visual feedback when merge resolves | | ☐ |
| 12 | Gold counter animation — count-up on session summary and dungeon summary | Number animates, not jumps | | ☐ |
| 13 | Touch drag preview — ~50px upward offset on drag preview for board items and staging items | Drag preview visible above finger | | ☐ |
| 14 | Screen layout pass — all screens sized for 1080×1920 portrait, touch targets ≥ 44px | All UI elements reachable, no overlapping, scroll where needed | | ☐ |
| 15 | Performance pass — profile on target device, 60fps target with full board + combat active | Stable 60fps during dungeon combat with merges happening | | ☐ |

**Integration tasks:**
- [ ] Audio manager routes SFX and music without conflicts (music crossfade doesn't cut SFX)
- [ ] All 14 SFX trigger at correct moments per GDD SFX table
- [ ] Performance acceptable with combat + merges + staging items + SFX all active

**Phase risks:**
- Audio asset creation or sourcing — may need to use placeholder sounds longer than expected
- Mobile performance with many Control nodes (25 board cells + staging + enemy displays) — may need optimization
- Touch target sizing — portrait layout on various screen sizes may need multiple passes

---

## Phase 5 — Hardening

**Goal:** Make the game shippable. Edge cases, save reliability, device testing, export.

**Phase complete when:** Game passes device testing, handles edge cases gracefully, builds and runs as a signed APK.

**GDD reference:** Platform and Technical Notes, Save/Load
**Architecture reference:** Subsystem: Save/Load

**Dependencies:** Phase 4 complete. Game feels correct and performs acceptably.

### Tasks

| # | Task | Done state | Risk | Status |
|---|------|-----------|------|--------|
| 1 | Save reliability — test: save during combat, save with full board, save with all upgrades, rapid save requests | No data loss, no corruption, load restores exact state | | ☐ |
| 2 | Edge case: rapid input — spam crate buy, spam order fulfill, spam merge during combat | No crashes, no duplicated items, no negative gold | | ☐ |
| 3 | Edge case: interrupted session — force-quit during shop, during dungeon, during save write | No corrupted save, load returns to last checkpoint | | ☐ |
| 4 | Edge case: low memory — fill board completely, max staging items, all enemies alive | No crashes, graceful degradation | | ☐ |
| 5 | Edge case: boundary values — gold at 0, reputation at 0, board completely full, all party members KO | No negative values, no crashes, correct behavior at boundaries | | ☐ |
| 6 | Android export setup — keystore, permissions, orientation lock (portrait), immersice mode | Signed APK installs and runs on device | | ☐ |
| 7 | Device testing — test on at least 2 physical Android devices (different screen sizes / specs) | Game runs correctly on both, no layout issues | | ☐ |
| 8 | Full playthrough — New Game → 3+ shop sessions → buy blueprints/upgrades → dungeon run → clear or fail → continue playing | No crashes, state correct throughout, no progression blockers | | ☐ |
| 9 | Godot 4 project settings — mobile renderer, texture compression (ETC2), disable unused features | Project exports cleanly with mobile-optimized settings | | ☐ |

**Integration tasks:**
- [ ] Save system works with all GameManager state (gold, reputation, blueprints, upgrades, reagents, board state, grid size)
- [ ] No progression blocker: player can always earn gold and advance (rejecting customers is always possible)

**Phase risks:**
- Save file atomicity on Android — power loss during write could corrupt; use temp file + rename pattern
- Device-specific layout issues — notch/cutout handling, different aspect ratios
- Performance on low-end devices — may need to reduce particle effects or simplify visuals

---

## Deferred Tasks

| Task | Originally in | Reason deferred | Target version |
|------|--------------|-----------------|----------------|
| Gem and Wood material families | GDD Scope | Reduces item count for MVP; family keys reserved in data | v1.1 |
| Premium customer tier | GDD Scope | Basic + Standard sufficient for first dungeon | v1.1 |
| Algorithmic customer generation | GDD Scope | Flat list works for first playtest | v1.2 |
| Party abilities / active skills | GDD Scope | Auto-attack only for MVP | v1.2 |
| Demand forecast / forecast tab | GDD Scope | Not needed for core loop | v1.2 |
| Dungeon mid-exit penalty | GDD Scope | Full wipe sufficient for MVP | v1.1 |
| Additional reagent types (Ice, Shadow, Holy) | GDD Scope | Fire Essence proves the system | v1.1 |
| Equipment durability / repair mechanic | GDD Scope | Significant system complexity | v2.0 |
| Additional dungeons | GDD Scope | One dungeon proves the loop | v1.1 |
| Tutorial system | GDD Out of Scope | v1.0 assumes learn-by-doing | v1.1 |
| Animated cutscenes / narrative | GDD Out of Scope | No narrative in MVP | v2.0 |
| Customer queue silhouettes | GDD Parked | Visual polish, no gameplay impact | v1.1 |
| Party walking/attack/hit animations | GDD Parked | Visual polish | v1.1 |
| Front/rear line distinction | GDD Parked | Combat system change | v2.0 |
| Tank mechanic | GDD Parked | CombatEngine targeting changes | v2.0 |
| Encrypted save file | GDD Deferred | Not needed for single-device offline game | v1.2 |
| Timed events or daily challenges | GDD Deferred | Not core loop | v1.2 |
| Board themes / cosmetics | GDD Deferred | Visual only | v1.2 |

---

## Retrospective

### Phase-by-Phase Notes

| Phase | Expected effort | Actual effort | What took longer | What was faster | Surprises |
|-------|----------------|---------------|-----------------|-----------------|-----------|
| 1 — Vertical Slice | | | | | |
| 2 — Foundation | | | | | |
| 3 — Content | | | | | |
| 4 — Integration & Feel | | | | | |
| 5 — Hardening | | | | | |

### Post-Mortem Notes

-
-
-
