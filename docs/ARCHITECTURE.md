# Architecture — MergeForge

Last updated: 2026-06-11

---

## Directory Structure

```
res://
├── autoloads/
├── board/
├── core/
├── shop/
├── dungeon/
└── resources/
    ├── definitions/   (content .tres files, one folder per catalog)
    ├── sprites/
    ├── audio/
    │   ├── music/
    │   └── sfx/
    └── fonts/
```

> **Convention:** All files for a subsystem live together in its folder (scenes, scripts, data schemas). Autoloads stay in `autoloads/`. Game content lives in `resources/definitions/`. Shared assets live in `resources/`. See each subsystem's Files table for exact file placement. Scripts in one subsystem folder must not use `preload` or direct node paths into another subsystem's folder — use autoloads or EventBus for cross-subsystem access.

## Scene Tree Overview

- `Main` (`main.tscn`) — root scene, manages scene transitions by swapping child
  - `CanvasLayer` → `HUD` (`hud.tscn`) — gold display, shop level and XP bar (always visible in-game)
  - `SceneContainer` (`Node`) — child swapped by Main on transition
    - `MainMenu` (`main_menu.tscn`)
    - `ShopSession` (`shop_session.tscn`) → instances `MergeBoard` (`merge_board.tscn`) (shop board; `MergeBoard/VBox/ShelfArea/ShelfGrid` is the display shelf, a second `board_grid.gd` with merges off, hidden without slots)
    - `SessionSummary` (`session_summary.tscn`)
    - `PrepPhase` (`prep_phase.tscn`) → TabContainer: Forecast / Blueprints / Upgrades / Reagents (Forecast tab holds `ForecastPanel`, `core/forecast_panel.tscn`)
    - `DungeonRun` (`dungeon_run.tscn`) → instances `MergeBoard` (`merge_board.tscn`) (dungeon board, separate state)
    - `DungeonSummary` (`dungeon_summary.tscn`)

Scene transitions are driven by `main.gd` listening to EventBus signals. Main frees the old scene, instances the new one, and adds it as child of `SceneContainer`.

## Autoloads / Singletons

| Name              | Script                  | Responsibility                                                                                                   |
| ----------------- | ----------------------- | ---------------------------------------------------------------------------------------------------------------- |
| GameManager       | `game_manager.gd`       | Persistent state: gold, shop XP, blueprints, reagent inventory, upgrade levels, shop board and shelf state, grid size |
| EventBus          | `event_bus.gd`          | Cross-scene signal relay (see registry below)                                                                    |
| DefinitionLibrary | `definition_library.gd` | Loads and indexes every content definition (see Content Definitions), one catalog per folder under `resources/definitions/`. Lists folders with `ResourceLoader.list_directory` (works in exports, where `.tres` files are remapped). Every definition needs a unique `id`; an empty catalog is a hard error, since there is no fallback content. |
| RecipeResolver    | `recipe_resolver.gd`    | Rules over the definitions, holding no content itself: merge options filtered by blueprint ownership and reagent inventory, blueprint dependency checks, weighted pool rolls, and the dictionary a board cell holds (`make_item`). |
| SessionPlanner    | `session_planner.gd`    | `plan_next_session() -> SessionPlan`, the one place the next shop session is dealt: a pure function of GameManager's state, via `customer_generator.gd`. Prep (`core/`) and the shop (`shop/`) both call it, since neither subsystem folder may preload the other. |
| SaveManager       | `save_manager.gd`       | Auto-save/load to single JSON file at checkpoints                                                                |
| AudioManager      | `audio_manager.gd`      | Music playback with crossfade, SFX one-shots                                                                     |

No autoload uses `class_name` — globally accessible by registration name only (per GDD decision log).

### EventBus Signal Registry

| Signal | Emitted by | Listeners | Purpose |
|--------|-----------|-----------|---------|
| `merge_completed(result_id: String, result_quality: int)` | `merge_resolver.gd` | `audio_manager.gd` | A merge produced a result item, at `result_quality` (0 Normal, 1 Fine, 2 Masterwork) |
| `customer_fulfilled(order_id: String)` | `shop_session.gd` | `save_manager.gd` | Order delivered to customer |
| `customer_rejected(customer_id: String)` | `shop_session.gd` | `save_manager.gd` | Customer was skipped |
| `session_ended(summary: Dictionary)` | `shop_session.gd` | `main.gd` | 10th customer done, transition to summary. Summary: `{gold_earned: int, items_sold: int, fulfilled: int, rejected: int, portraits: Array, xp_earned: int, level_before: int, level_after: int}` |
| `session_summary_dismissed()` | `session_summary.gd` | `main.gd` | Player taps Continue, go to prep |
| `prep_start_session()` | `prep_phase.gd` | `main.gd` | Player starts next shop session |
| `prep_enter_dungeon(dungeon_id: String)` | `prep_phase.gd` | `main.gd` | Player enters that dungeon (if unlocked) |
| `dungeon_cleared(rewards: Dictionary)` | `dungeon_controller.gd` | `main.gd`, `save_manager.gd` | Dungeon completed. Rewards: `{cleared: true, gold_reward: int, blueprint_reward: String or null, xp_gained: int, level_before: int, level_after: int}` |
| `dungeon_failed(summary: Dictionary)` | `dungeon_controller.gd` | `main.gd`, `save_manager.gd` | Dungeon failed. Summary: `{cleared: false, gold_reward: 0, blueprint_reward: null, xp_gained: 0, level_before: int, level_after: int}` |
| `dungeon_summary_dismissed()` | `dungeon_summary.gd` | `main.gd` | Player taps Continue, return to prep |
| `new_game_started()` | `main_menu.gd` | `main.gd` | Player starts new game |
| `continue_game()` | `main_menu.gd` | `main.gd` | Player loads save |
| `prep_quit_to_menu()` | `prep_phase.gd` | `main.gd` | Player quits to main menu from prep phase |
| `save_requested()` | multiple | `save_manager.gd` | Trigger auto-save |

### State-Change Signals (on GameManager)

These are emitted directly on GameManager. Connect via `GameManager.gold_changed.connect(handler)`. NOT routed through EventBus.

| Signal | Trigger | Example Listener |
|--------|---------|-----------------|
| `gold_changed(new_amount: int)` | Gold balance changes | HUD gold label, prep buy buttons |
| `shop_xp_changed(xp: int)` | Shop XP changes | HUD level label |
| `shop_level_changed(level: int)` | Crossed a level, once per level crossed | `prep_phase.gd` (refreshes the dungeon button and every purchase list), `shop_session.gd` (rebuilds crate buttons) |
| `blueprint_added(bp_id: String)` | Blueprint unlocked | Prep phase blueprints tab, audio_manager (SFX) |
| `upgrade_level_changed(upgrade_id: String, level: int)` | An upgrade level was bought (`level` is the new level) | audio_manager (SFX), prep_phase (refreshes the upgrade cards) |
| `reagent_count_changed(id: String, count: int)` | Reagent inventory changes | Prep phase reagent display, merge choice popup |
| `grid_size_changed(cols: int, rows: int)` | Grid upgrade purchased | Active MergeBoard instance |

## Signal Flow Rules

**Rule:** Nodes within the same scene communicate via direct references (`@onready`, passed references, parent methods). Nodes communicating across scene boundaries use EventBus. GameManager emits its own signals for state changes — connect directly, not through EventBus.

**Exceptions:**
- **MergeBoard:** Shared scene instanced by ShopSession and DungeonRun. Owns its own MergeChoicePopup internally. Defaults to GameManager values for grid size, despawn time, and crate discount, but accepts overrides via `setup(config)`. Communicates merge choices via its internal popup. Parent scenes call `board.setup({})` and interact via public methods (`buy_crate()`, `place_drop()`, `get_board_grid()`, `get_staging_area()`, and for the shop's display shelf `count_sellable()`, `take_sellable()`, `get_shelf_state()`, `load_shelf_state()`). The shop never reaches into the shelf grid itself.
- **Drag-to-party-portrait (dungeon):** Uses Godot's built-in Control drag-and-drop. BoardCell provides `_get_drag_data`, PartyMember provides `_can_drop_data` / `_drop_data`. PartyMember calls `DungeonController.apply_usable_item()` on successful drop. No custom hit-testing needed — Godot handles cross-scene-tree drop detection.
- **AudioManager:** Listens to EventBus signals for SFX. No script calls `AudioManager.play_sfx()` directly — SFX is fully signal-driven. Music switching is the one exception: `main.gd` calls `AudioManager.play_music()` directly during scene transitions, since only Main knows which scene just loaded. AudioManager also connects directly to GameManager signals (`blueprint_added`, `upgrade_level_changed`) for purchase SFX.

## Key Conventions

- All game content is `.tres` definitions under `res://resources/definitions/`, loaded once at startup by DefinitionLibrary, never at runtime per-frame. Definitions reference each other directly (a merge result points at its ItemDefinition), and those references only point down the tiers, since Godot can't load cyclic resource files.
- Scene-specific UI lives inside its own scene. Only HUD (gold, level, XP bar) is global via CanvasLayer.
- No `get_node("../../")` path hacks — use signals, autoloads, or passed references
- Signals describe events (`merge_completed`), not commands (`do_merge`)
- MergeBoard receives configuration via `setup(config)` and defaults to GameManager values (grid size, despawn time, crate discount). Parent scenes can override via the config Dictionary.
- All touch input uses `InputEventScreenTouch` / `InputEventScreenDrag`. Mouse emulation is for editor testing only.
- **All drag-and-drop uses Godot's built-in Control drag system** (`_get_drag_data`, `_can_drop_data`, `_drop_data`). No custom hit-testing or Rect math. This covers all three drag interactions: staging→board, board→board (swap), and board→party member (usable items). Drag sources: `FloatingItem`, `BoardCell`. Drop targets: `BoardCell`, `PartyMember`.
- **Mobile drag preview offset:** Drag previews are offset upward by ~50px from the touch point so the player can see the item under their finger. Set via `set_drag_preview()` with an offset position.
- Board grid dimensions are data-driven from `GameManager.grid_cols` / `GameManager.grid_rows` — never hardcoded
- Save data uses atomic writes: write to `user://save_data.tmp`, then `DirAccess.remove_absolute()` + `DirAccess.rename_absolute()` to `user://save_data.json`
- Placeholder art: colored rectangles with text labels. No final sprites until gameplay is complete.
- No `class_name` on autoload scripts — access by registration name only

## Known Tech Debt

- **Grid upgrade migration defined but not implemented:** When upgrading from 5x5 to 6x5, new column cells start empty. BoardGrid.load_board_state() must handle grids smaller than the current grid_cols gracefully.
- **Same-scene SFX resolved via direct calls:** The architecture says SFX is "fully signal-driven via EventBus," but several GDD-listed SFX originate from same-scene signals that never reach EventBus. Resolution: allow scenes to call `AudioManager.play_sfx()` directly for same-scene SFX. See Audio subsystem SFX mapping table for full resolution paths.
- **SFX using direct calls (see Audio subsystem for details):**
  - `item_place` — emitted within board scene, no EventBus signal
  - `gold_earn` — gold_changed is a GameManager signal but is a state change, not a "earned" event
  - `session_start` — shop_session._ready(), no EventBus signal
  - `session_end` — session_ended exists on EventBus but covers summary transition, not the SFX moment
  - `dungeon_start` — dungeon_controller._ready(), no EventBus signal
  - `ko` — played by combat_engine when a member is KO'd (same scene, not on EventBus)
  - `crate_open` — shop_session.try_buy_crate(), no EventBus signal
- **Resolved SFX paths (AudioManager can connect to existing signal):**
  - `dungeon_clear` / `dungeon_fail` → `dungeon_cleared` / `dungeon_failed` on EventBus
  - `customer_reject` → `customer_rejected` on EventBus
  - `merge_complete` → `merge_completed` on EventBus
  - `customer_happy` → `customer_fulfilled` on EventBus
  - `purchase` → `blueprint_added` / `upgrade_level_changed` on GameManager

## Unresolved / Needs Input

> 📝 Items that require decisions or data before implementation can proceed.
> Remove items from this section once resolved and update the relevant subsystem.

### Post-MVP (Deferred)

- **Equipment Durability / Repair mechanic:** Party equipment wears during dungeon raids. The player must maintain item durability during the raid by crafting repair items (usable item type: `repair`). This mechanic is deferred to post-MVP — do not implement `repair` as a usable item effect type for v1.0.
- **Party Abilities / Healing:** All party members auto-attack only for MVP. No healer ability, no skills, no active party abilities. Usable-item buffs (buff_attack) remain in MVP. Post-MVP: add active abilities, healing, and party/enemy skill system.
- **Dungeon Mid-Exit Penalty:** MVP wipes all partial progress on dungeon exit/fail. Post-MVP: impose a penalty for mid-dungeon exit and implement anti-scumming measures (e.g., gold cost, cooldown timer).
- **Additional dungeons:** Beyond the first dungeon (Goblin Cave).
- **Gem and Wood material families:** Family keys reserved in data (`"gem"`, `"wood"`). Wood items defined for forward compatibility. Gem items not yet defined.
- **Additional reagent types:** Beyond Fire Essence (Ice, Shadow, Holy).
- **Timed events or daily challenges.**
- **Board themes / cosmetics.**
- **Encrypted save file.**

---

## Confirmed for v1.0

### ❗ Usable Item Effects — Confirmed for v1.0 (tune during playtesting)

The GDD lists effect types (heal, buff_attack). Party stats are confirmed (see the PartyMemberDefinition schema in the Dungeon Run subsystem). These are **consumable items** the player crafts and uses during dungeon runs — separate from party abilities (deferred). Usable items are `ItemDefinition` resources with `dungeon_usable = true`, a `dungeon_use_target`, and an `EffectDefinition`:

- Targets: `party-individual`, `enemy-individual`, `enemy-all`. Only party members accept drops so far.
- Effect types (`value` meaning in `effect_definition.gd`): `heal`, `buff_attack` (applied by CombatEngine); `absorb`, `crit_charges`, `revive`, `damage` (defined on items, not applied yet).
- Tier 1 items are raw materials; tiers 2 to 4 are usable. Enemy drop pools hold only usable items. The per-item values are in the GDD Item Catalog.

---

## Subsystem: Core (Main, HUD, Menus)

### Scenes & Scripts

| File | Type | Responsibility |
|------|------|----------------|
| `core/main.tscn` | Scene | Root scene. Manages scene transitions by swapping children of SceneContainer. Owns the CanvasLayer for HUD. |
| `core/main.gd` | Script | Listens to EventBus transition signals, frees old scene, instances new scene, manages music switches. Does NOT own game logic. |
| `core/hud.tscn` | Scene | Persistent overlay: gold label, level label, XP progress bar. Child of Main's CanvasLayer. |
| `core/hud.gd` | Script | Connects to GameManager state-change signals, updates gold, level and XP bar display. Does NOT own game state. |
| `core/main_menu.tscn` | Scene | Main menu screen with New Game and Continue buttons. |
| `core/main_menu.gd` | Script | Emits EventBus signals for new game / continue. Checks SaveManager.has_save() to enable/disable Continue button. |

### Signals

| Signal | Emitted by | Listeners | Via EventBus? | Flows |
|--------|-----------|-----------|---------------|-------|
| `new_game_started()` | `main_menu.gd` | `main.gd` | Yes | New Game |
| `continue_game()` | `main_menu.gd` | `main.gd` | Yes | Load Game |

### Flow Trace: Scene Transition

**Trigger:** Any EventBus scene-transition signal (session_ended, session_summary_dismissed, prep_start_session, prep_enter_dungeon, dungeon_cleared, dungeon_failed, dungeon_summary_dismissed, prep_quit_to_menu, new_game_started, continue_game).

1. `main.gd` receives EventBus signal
2. Determines target scene from signal type (mapping stored in a Dictionary)
3. Frees current child of `SceneContainer`
4. Instances new scene, adds as child of `SceneContainer`
5. Calls `AudioManager.play_music(track_name)` if music should change (shop ↔ dungeon transitions)

**End state:** New scene displayed, music switched if applicable.

### Flow Trace: New Game

**Trigger:** Player taps New Game on MainMenu.

1. `main_menu.gd` emits `new_game_started` via EventBus
2. `main.gd` calls `SaveManager.delete_save()` (if any)
3. `main.gd` calls `GameManager.deserialize({})` to reset all state to defaults (gold = 50, etc.)
4. Instances `prep_phase.tscn` as first scene

**End state:** Fresh game state, prep phase started.

### Flow Trace: Load Game

**Trigger:** Player taps Continue on MainMenu.

1. `main_menu.gd` emits `continue_game` via EventBus
2. `main.gd` calls `SaveManager.load_game()` → gets Dictionary
3. `main.gd` calls `GameManager.deserialize(data)` to restore all state
4. Instances `prep_phase.tscn` (player resumes from prep)

**End state:** All persistent state restored, player enters prep phase.

### Class Reference

#### Main

**Extends:** Node
**Script:** `core/main.gd`
**Description:** Root scene controller. Manages scene transitions by listening to EventBus signals and swapping children of SceneContainer. Owns the HUD via CanvasLayer. Handles new game initialization and save loading.

**Lifecycle:** `_ready()` instances MainMenu as first child of SceneContainer. Connects to all EventBus transition signals.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `scene_container: Node` | [onready] | Node whose child gets swapped on transitions |
| `hud: Control` | [onready] | HUD instance on CanvasLayer |
| `scene_map: Dictionary` | Dictionary | Maps EventBus signal name → scene resource path. Entries: `session_ended → session_summary.tscn`, `session_summary_dismissed → prep_phase.tscn`, `prep_start_session → shop_session.tscn`, `prep_enter_dungeon → dungeon_run.tscn`, `dungeon_cleared → dungeon_summary.tscn`, `dungeon_failed → dungeon_summary.tscn`, `dungeon_summary_dismissed → prep_phase.tscn`, `prep_quit_to_menu → main_menu.tscn`, `new_game_started → prep_phase.tscn`, `continue_game → prep_phase.tscn` |
| `pending_summary: Dictionary` | Dictionary | Data passed to SessionSummary across scene transition |
| `pending_dungeon_summary: Dictionary` | Dictionary | Data passed to DungeonSummary across scene transition |

**Functions:**

| Function | Description |
|----------|-------------|
| `_transition_to(scene_path: String, configure: Callable = Callable())` | Frees current scene, instances new scene from path, passes it to `configure` (when valid) before adding it to SceneContainer. |
| `_on_prep_enter_dungeon(dungeon_id: String)` | Transitions to DungeonRun, setting its `dungeon_id` before `_ready` runs. |
| `_on_new_game()` | Deletes save, resets GameManager, transitions to PrepPhase. |
| `_on_continue_game()` | Loads save into GameManager, transitions to PrepPhase. |

#### HUD

**Extends:** Control
**Script:** `core/hud.gd`
**Description:** Persistent overlay showing gold balance, shop level and an XP progress bar. Always visible during gameplay (shop, dungeon, prep). Updates reactively via GameManager signals.

**Lifecycle:** `_ready()` sets initial gold text and calls `_refresh_level()`, connects to `GameManager.gold_changed` and `GameManager.shop_xp_changed`.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `_gold_label: Label` | `@onready $HBox/GoldLabel` | Gold amount display |
| `_level_label: Label` | `@onready $HBox/LevelLabel` | "Lv N" display |
| `_xp_bar: ProgressBar` | `@onready $HBox/XpBar` | Fills within the current level; full and static once `max_level` is reached |

**Functions:**

| Function | Description |
|----------|-------------|
| `_on_gold_changed(new_amount: int)` | Updates gold label text. |
| `_on_shop_xp_changed(_xp: int)` | Calls `_refresh_level()`. |
| `_refresh_level()` | Reads `DefinitionLibrary.get_shop_rules()` and `GameManager.get_shop_level()`/`shop_xp`, sets the level label and the XP bar's range (`xp_for_level(level)` to `xp_for_level(level + 1)`) and value. At `max_level` the bar is pinned full since XP past the cap has nowhere to go. |

---

## Subsystem: Merge Board

### Scenes & Scripts

| File                            | Type   | Responsibility                                                                                                                                                                                                                                                                                                         |
| ------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `board/merge_board.tscn`d       | Scene  | Board grid + display shelf grid (shop only) + staging area container + AnimOverlay for merge animations. Instanced by ShopSession and DungeonRun. Holds MergeDetector and MergeResolver as member instances (RefCounted, not child nodes). Owns MergeChoicePopup internally — instantiated and managed in _ready(). Background texture via TextureRect. |
| `board/merge_board.gd`          | Script | Root script for the merge board scene. Receives config Dictionary via `setup()` called by parent, creates BoardGrid/MergeDetector/MergeResolver instances, wires them together, manages staging area, runs merge animations (burst + converge). Does NOT own game logic or state.                                      |
| `board/board_grid.gd`           | Script | Grid data model: placement, removal, swap, discard. Used twice by MergeBoard: the merge board and the display shelf (`merges_enabled` false). Does NOT own merge logic or recipe resolution.                                                                                                                                                                                                                     |
| `board/board_cell.gd`           | Script | Single cell visual + touch drag initiation via `_get_drag_data`. Drop target for board-to-board swaps via `_can_drop_data` / `_drop_data`. Does NOT own item data. Exposes `get_icon_texture()` for merge animations.                                                                                                  |
| `board/floating_item.tscn`      | Scene  | Staging area item with despawn timer. Drag source via `_get_drag_data` (drags to BoardCell). Does NOT own placement logic.                                                                                                                                                                                             |
| `board/merge_choice_popup.tscn` | Scene  | Non-blocking popup with 2–4 choice buttons. Instanced and owned by MergeBoard. Receives options from MergeResolver, emits choice. Does NOT own recipe data.                                                                                                                                                            |
| `board/merge_detector.gd`       | Script | Flood-fill scan for connected groups of 3+ identical items. Stateless. Does NOT resolve merges.                                                                                                                                                                                                                        |
| `board/merge_resolver.gd`       | Script | Processes merge groups: queries RecipeResolver, manages choice popup, triggers merge animation (via MergeBoard), places results, handles chain merges via rescan. Does NOT detect groups.                                                                                                                              |
| `board/quality_rules.gd`        | Script | Pure static helper (`RefCounted`, no instance state): `resolve(qualities: Array[int], count: int) -> Dictionary` decides a merge result's quality and which source items are refunded. Does NOT touch the board or RecipeResolver. |
| `ui/quality_stars.tscn`, `.gd`  | Scene (shared, `ui/`) | Draws 0/1/2 stars in code (`draw_colored_polygon`, no star art or font glyph) with a dark outline so the count carries the meaning, not color. `set_quality(quality: int)`. Used by `board/board_cell.tscn`, `board/floating_item.tscn` and `shop/order_card.tscn`. |

### Signals

| Signal | Emitted by | Listeners | Via EventBus? | Flows |
|--------|-----------|-----------|---------------|-------|
| `cell_drag_started(from_pos: Vector2i, item: Dictionary)` | `board_cell.gd` | `board_grid.gd` | No | Item Drag |
| `cell_drag_ended(to_pos: Vector2i, drag_data: Dictionary)` | `board_cell.gd` | `board_grid.gd` (`_on_cell_drop`) | No | Item Move, Item Swap (within a grid or between board and shelf), Staging Placement |
| `item_placed(item: Dictionary, pos: Vector2i)` | `board_grid.gd` | `merge_detector.gd` (via parent callback) | No | Merge Detection |
| `staging_item_placed(item: Dictionary, pos: Vector2i)` | `board_grid.gd` (`finalize_move`, only when the move's `from_grid` was null) | `merge_board.gd` (`_on_staging_item_placed`) | No | Staging Placement |
| `item_removed(pos: Vector2i)` | `board_grid.gd` | `merge_detector.gd` (via parent callback) | No | Chain Merge |
| `merge_detected(groups: Array)` | `merge_detector.gd` | `merge_resolver.gd` | No | Merge Resolution |
| `merge_completed(result_id: String, result_quality: int)` | `merge_resolver.gd` | EventBus | Yes | Merge Resolution |
| `merge_choice_requested(options: Array, callback: Callable)` | `merge_resolver.gd` | `merge_choice_popup.tscn` | No | Merge with Choice |
| `choice_made(item_id: String, is_variant: bool, reagent_id: String)` | `merge_choice_popup.gd` | `merge_resolver.gd` (via callback) | No | Merge with Choice |
| `despawn_timeout()` | `floating_item.gd` | `board_grid.gd` (staging handler) | No | Staging Despawn |
| `item_discarded(pos: Vector2i)` | `board_grid.gd` | internal | No | Item Discard |

> **Note on drag-and-drop:** BoardCell and FloatingItem implement `_get_drag_data()` (drag source). BoardCell implements `_can_drop_data()` / `_drop_data()` (drop target for swaps/placement). PartyMember implements `_can_drop_data()` / `_drop_data()` (drop target for usable items in dungeon). Godot handles hit-testing automatically across the scene tree. BoardCell turns a drop into `cell_drag_ended(to_pos, drag_data)`: the drag data travels with the signal, since `get_viewport().gui_get_drag_data()` is null outside a live OS drag. Drag data is the item Dictionary plus `_source_pos`, `_source_grid` (the BoardGrid the item left; absent for a staging item) and `_source_screen`. The target grid reads `_source_grid` to tell a same-grid move, a cross-grid move (board and shelf) and a staging placement apart; moves passed to the move callback name `from_grid` (null from staging) and `to_grid`. **Drops are refused while a merge is being resolved:** MergeBoard gives both grids a drop guard (`set_drop_guard`) that fails while `MergeResolver.is_processing`, because between the merge burst and `remove_items()` the grid model still holds the merging items, so a drop then could lose or duplicate one.

### Flow Trace: Merge Detection and Resolution

**Trigger:** Player places an item on the board (drag from staging via Godot `_drop_data`, or drag between cells via board-to-board `_drop_data`).

1. FloatingItem or BoardCell `_get_drag_data()` initiates drag with item Dictionary. Drag preview shown with ~50px upward offset for mobile visibility.
2. Player releases over a BoardCell → `_drop_data()` called on target BoardCell → BoardGrid processes placement/swap
3. `board_grid.gd` (`_on_cell_drop`) interprets the target: refused while a merge is resolving (drop guard); empty cell → place or move, occupied cell → swap (a staging item only fills empty cells). The source may be the same grid, the other grid (board and shelf), or staging. Releasing outside every cell cancels the drag and the item stays where it was
4. Grid array updated → `board_grid.gd` calls `merge_detector.gd.scan(grid)`
5. `merge_detector.gd` runs flood-fill from each occupied cell, finds groups of 3+ orthogonally connected identical items → returns array of `MergeGroup` dicts
6. If no groups → flow ends
7. If groups found → first group queued for processing by `merge_resolver.gd`
8. `merge_resolver.gd` resolves the result placement position (`_resolve_result_position()`) — simulates post-removal state to find exact cell where result will go
9. `merge_resolver.gd` calls `merge_board.animate_merge(positions, result_center, callback)` — cells cleared visually, floating icon copies burst 30px outward then converge to result position (0.4s total: 0.15s burst + 0.25s converge)
10. Animation completes → `merge_resolver.gd` calls `board_grid.remove_items(positions)` to consume the group
11. `merge_resolver.gd` reads the group's quality from the board (`_group_qualities`, so a chain merge sees the quality a previous merge just placed) and calls `board/quality_rules.gd.resolve(qualities, count)` for `{result_quality, refund_qualities}`, then `RecipeResolver.get_options(item_id)` to get filtered results
12. If 1 option → auto-place floor(count/3) result items at `result_quality` (first at `_result_center`, rest at nearby empty cells; `RecipeResolver.make_item(result_def, result_quality)`), refund `refund_qualities` (the group's lowest qualities, count%3 of them) as source items at former positions, show a star sparkle if `result_quality > 0` or a "<quality> lost" cue if the group's best quality was above `result_quality`, emit `merge_completed(result_id, result_quality)` via EventBus
13. If 2+ options → set `is_processing = true`, emit `merge_choice_requested(options, callback)` → `merge_choice_popup` shows buttons labeled with the predicted quality (for example "Sword (Fine)"), naming what the player is about to get — the popup only appears for 2+ options and only after the merge is already committed in step 10, so it's not a warning about anything (non-blocking; combat continues if in dungeon). Merge queue is paused — no new scans run until the player picks an option **or dismisses the popup**. Choice (or dismissal fallback) applies to all result items.
14. Player taps choice → callback fires → `merge_resolver.gd` places floor(count/3) result items at `result_quality`, refunds `refund_qualities` source items, consumes reagent if variant, shows the sparkle if `result_quality > 0` or the "<quality> lost" cue if the group's best was higher, emits `merge_completed(result_id, result_quality)` via EventBus, sets `is_processing = false`. **Dismissal fallback:** if the popup is closed without a pick (Esc / tap-outside), the popup re-emits `choice_made` with the first option, so the merge resolves identically — the queue can't deadlock, and the merge cannot be safely undone because the source items were already removed in step 10.
15. `merge_resolver.gd` calls `_try_chain()` — rescans grid for new groups formed by result items → if found, go to step 7 with next group (another animation plays)

**End state:** floor(count/3) result items placed on grid at the resolved quality, (count%3) lowest-quality source items refunded at former positions, a star sparkle shown for a Fine or Masterwork result or a "<quality> lost" cue when the merge downgraded the group's best quality (no gold paid for a merge either way), chain merges fully resolved with animations between each, merge SFX played. The display shelf (never auto-merged) is the only place a quality item is safe from an unwanted merge; a quality item left on the board can be caught up in the next matching group at any time.

### Flow Trace: Staging Area Despawn

**Trigger:** FloatingItem's internal Timer reaches 0.

1. `floating_item.gd` timer expires → emits `despawn_timeout()`
2. `board_grid.gd` removes the floating item from staging area, frees the node
3. Item is permanently lost (no EventBus signal for MVP)

**End state:** Item removed from staging, despawn SFX played. Item is permanently lost.

### Flow Trace: Release Outside the Board

**Trigger:** Player drags a grid or shelf item and releases touch outside every BoardCell.

1. No `_drop_data()` runs, so `cell_drag_ended` is never emitted: `cell_drag_ended(to_pos, drag_data)` only fires on a drop onto a cell
2. Godot cancels the drag; the grid model was never touched, so the item stays in its cell

**End state:** Nothing changes. There is no drag-off discard; `BoardGrid.discard_item(pos)` is only called by the dungeon when a usable item is dropped on a party member.

### Class Reference

#### MergeBoard

**Extends:** Control
**Script:** `board/merge_board.gd`
**Description:** Root script for the merge board scene. Owns MergeChoicePopup, MergeDetector, and MergeResolver. Provides public API for parent scenes: `setup()`, `buy_crate()`, `get_crate_cost()`, `place_drop()`, `get_board_grid()`, `get_shelf_grid()`, `get_staging_area()`, `count_sellable()`, `take_sellable()`, `get_shelf_state()`, `load_shelf_state()`. Defaults to GameManager values but accepts overrides via setup config. Runs merge animations via AnimOverlay child node (burst + converge, configurable via constants).

`setup(config)` reads `config.crate_cost_multipliers` (`Dictionary[String, float]`, crate id → multiplier, default `{}`) — `ShopSession` passes the dealt session's `SessionPlan.modifier.get_crate_cost_multipliers()` here. `get_crate_cost(crate) -> int` returns `max(floor(crate.cost x multiplier x GameManager.get_crate_discount() + 0.0001), 1)`: the market modifier and the Crate Discount upgrade both apply, rounded down once, never free. `buy_crate()` charges this same value, and `ShopSession`'s crate buttons call `get_crate_cost()` so the shown price always matches the charge.

**Scene layout** (`merge_board.tscn`):

- `MergeBoard` (`merge_board.gd`)
  - `VBox` (VBoxContainer)
    - `TopPadding` (8 px)
    - `BoardArea` (CenterContainer, expands; its minimum height is the grid's, so a taller board can't overlap the shelf) → `BoardGrid` (`board_grid.gd`)
    - `%ShelfGap` (8 px, hidden with the shelf when it has no slots)
    - `%ShelfArea` (PanelContainer, hidden when the shelf has no slots) → `%ShelfGrid` (`board_grid.gd`, one row, merges off)
    - `StagingWrapper` (160 px) → `StagingBg`, `StagingArea` (FlowContainer)
    - `BottomPadding` (40 px)
  - `AnimOverlay`

Fits a 6x6 board of 128 px cells plus a 6-slot shelf on the shop screen at 1080x1920 even when the current customer shows 3 orders (see GDD Decisions Log, 2026-09-28 leveled upgrades entry).

**Display shelf:** `setup(config)` reads `config.shelf_slots` (default 0): the shop passes `GameManager.get_shelf_slots()`, the dungeon passes none, so its shelf stays hidden. The shelf is a second BoardGrid with `merges_enabled` false, the same cell scene and the same move callback, so drags between board and shelf reuse the board's code. Its `staging_item_placed` also removes a dropped staging item from staging; `item_placed` (both grids) only drives merge detection, which only scans the board. Shelf items never merge and never despawn.

| Function | Description |
|----------|-------------|
| `get_shelf_grid() -> Control` | The shelf BoardGrid (for tests and animations; the shop doesn't use it). |
| `count_sellable(item_id: String, min_quality: int = 0) -> int` | Items with this id at `min_quality` or above, on the board plus the shelf. Used by order fulfilment. |
| `take_sellable(item_id: String, count: int, min_quality: int = 0)` | Removes `count` items at the lowest qualifying quality first (never spends a Masterwork on a Normal order); within one quality, the shelf goes first (shelf stock is what the player set aside to sell), then the board. |
| `get_shelf_state() -> Array` | The shelf's `{col, row, item_id, quality}` entries, saved as `GameManager.shop_shelf_state`. |
| `load_shelf_state(state: Array)` | Restores the shelf. Saved items past the shelf's end (a shelf with fewer slots) go through `place_drop` to the board, else staging, so nothing is lost. |

**Animation constants:**

| Constant | Value | Description |
|----------|-------|-------------|
| `MERGE_BURST_DISTANCE` | 30.0 | Pixels icons float outward from center |
| `MERGE_BURST_TIME` | 0.15 | Duration of burst phase in seconds |
| `MERGE_CONVERGE_TIME` | 0.25 | Duration of converge phase in seconds |

**Animation function:**

| Function | Description |
|----------|-------------|
| `animate_merge(positions: Array[Vector2i], center: Vector2i, callback: Callable)` | Creates floating TextureRect copies of cell icons, clears cells visually, tweens icons outward then converges to center. Calls callback on completion. Total duration: 0.4s. |
| `show_quality_sparkle(quality: int, grid_pos: Vector2i)` | Pops the star icon for `quality` over `grid_pos`, scaling up then fading out (~0.35s). Called by MergeResolver when the result quality is above 0. |
| `show_quality_lost(best_quality: int, grid_pos: Vector2i)` | Floating "`<QUALITY_NAMES[best_quality]> lost`" label over `grid_pos`, font size 32, fading upward over ~0.8s, `mouse_filter = MOUSE_FILTER_IGNORE`. Emits `quality_lost` on show. Called by MergeResolver when the group's best quality is above the result's (for example a `[1,0,0]` group making Normal), so a downgrade is never silent even though it isn't color-coded. |

**Signal:**

| Signal | Description |
|--------|-------------|
| `quality_lost(best_quality: int, grid_pos: Vector2i)` | Emitted by `show_quality_lost`, alongside the label. Exists so tests can assert the cue fired without racing the label's free-after-tween lifetime. |

**Used by:** Shop Session, Dungeon Run, Economy & Progression (PrepPhase)

#### BoardGrid
**Script:** `board/board_grid.gd`
**Description:** Manages the grid data model and item placement/removal/swap. Creates BoardCell nodes dynamically based on grid dimensions. Handles staging area for floating items. BoardCells are both drag sources and drop targets via Godot's built-in drag-and-drop. MergeBoard runs two: the merge board and the display shelf.

**Lifecycle:** `setup(config)` called externally by MergeBoard — reads grid dimensions from config dict, creates BoardCell children, initializes empty grid array.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `grid: Array[Array]` | 2D array of Dictionary or null | Live board state. Each cell is item dict or null. |
| `grid_cols: int` | int | Column count (5 or 6 on the board; the slot count on the shelf) |
| `grid_rows: int` | int | Row count (5 or 6 on the board; 1 on the shelf) |
| `despawn_time: float` | float | Seconds before staging items despawn (from GameManager) |
| `merges_enabled: bool` | bool | From `setup` config (`merges_enabled`, default true); false on the shelf |

**Signals:**

| Signal | Description |
|--------|-------------|
| `item_placed(item: Dictionary, pos: Vector2i)` | Emitted when an item lands on the grid. merge_detector listens via parent. |
| `staging_item_placed(item: Dictionary, pos: Vector2i)` | Emitted alongside `item_placed`, only for a move whose source was the staging area (`from_grid` null). MergeBoard removes the matching staging item on this signal, never on plain `item_placed` — a board/shelf move or swap must not touch staging just because an item there shares an id. |
| `item_removed(pos: Vector2i)` | Emitted when an item is removed (merge consume, discard). |

**Functions:**

| Function | Description |
|----------|-------------|
| `set_move_callback(cb: Callable)` | MergeBoard's move animation; called with the moves of a drop, each naming `from_grid`/`from_pos` and `to_grid`/`to_pos`. |
| `set_drop_guard(guard: Callable)` | A drop is refused while `guard.call()` is false (MergeBoard: no merge resolving). |
| `finalize_move(moves: Array[Dictionary])` | Refreshes the cells each move leaves and lands on (either grid) and emits `item_placed` on the landing grid, plus `staging_item_placed` when that move's `from_grid` is null (it came from staging). |
| `place_item(item: Dictionary, pos: Vector2i) -> bool` | Places item at pos. Returns false if occupied. Emits `item_placed`. |
| `remove_items(positions: Array[Vector2i])` | Removes items at given positions. Emits `item_removed` for each. |
| `swap_items(pos_a: Vector2i, pos_b: Vector2i)` | Swaps items at two positions. |
| `discard_item(pos: Vector2i)` | Removes item at pos permanently. |
| `find_safe_cell(item_id: String) -> Vector2i` | Returns an empty cell where placing this item would NOT create a group of 3+ orthogonally connected identical items. Returns `Vector2i(-1, -1)` if no safe cell exists. |
| `place_or_stage(item: Dictionary) -> bool` | Merge-safe placement: calls `find_safe_cell(item.item_id)`. If found, places on board directly (returns true). If not, adds to staging area (returns false). Used by crate opening and enemy drops — not player drag placement. |
| `count_items_on_board(item_id: String, min_quality: int = 0) -> int` | Counts how many of a given item at `min_quality` or above are on this grid. Order fulfilment goes through `MergeBoard.count_sellable`, which adds the board and the shelf. |
| `remove_items_by_id(item_id: String, count: int, min_quality: int = 0)` | Removes N items matching item_id, lowest quality (at or above `min_quality`) first. Used by order fulfillment. |
| `clear_board()` | Removes all items. Used for dungeon cleanup. |
| `get_board_state() -> Array` | Serializes grid for save/load. Returns array of `{col, row, item_id, quality}` dicts: ids and quality only, since item data (and its sprite texture) can't round-trip through JSON. |
| `load_board_state(state: Array) -> Array[Dictionary]` | Restores grid from save data, rebuilding each item with `RecipeResolver.make_item(DefinitionLibrary.get_item(item_id), entry.quality)`. Ids missing from the catalog are skipped with an error. Returns the items that fall outside this grid (a smaller shelf) instead of dropping them. Updates BoardCell visuals. |

#### MergeDetector

**Extends:** RefCounted
**Script:** `board/merge_detector.gd`
**Description:** Pure stateless flood-fill scanner. Takes a grid, returns connected groups of 3+ identical items. No side effects.

**Functions:**

| Function | Description |
|----------|-------------|
| `scan(grid: Array[Array]) -> Array[Dictionary]` | Returns array of MergeGroup dicts: `{item_id: String, positions: Array[Vector2i]}`. |

#### MergeResolver

**Extends:** RefCounted
**Script:** `board/merge_resolver.gd`
**Description:** Processes merge groups one at a time. For each group, triggers a merge animation (burst outward + converge inward via MergeBoard), then produces floor(count/3) result items and refunds count%3 source items. Detection ignores quality, so a group may mix qualities; `board/quality_rules.gd.resolve()` decides the result's quality (`min(2, floor(mean quality) + 1 for a group of 5+)`) and which source items (the group's lowest-quality ones) come back as refunds. No gold is paid for a merge; a Fine or Masterwork result shows a star sparkle instead, and a result whose quality is below the group's best (mixed-quality groups can downgrade, e.g. `[1,0,0]` making Normal) shows a "<quality> lost" cue via `MergeBoard.show_quality_lost` — this is the only feedback for a lost upgrade, since the choice popup (when it appears) only names the quality the player is about to get, not what a merge is about to cost. Queries RecipeResolver for options, manages the choice popup (button labels include the predicted quality, e.g. "Sword (Fine)"), places results at the pre-resolved result position, handles chain merges via rescan (reading quality straight from the board, so a chain merge sees what a previous merge just placed). When a choice popup is open, the merge queue is blocked — no new detection scans run and no further groups are processed until the player picks an option or dismisses the popup (dismissal resolves to the first option; see MergeChoicePopup). This keeps things simple: one popup at a time, no stacking, and the queue can never deadlock on an unanswered popup. The choice applies to all result items in the group. Held as a member instance by MergeBoard, not added to the scene tree.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `merge_queue: Array[Dictionary]` | Array | Queue of MergeGroup dicts to process |
| `is_processing: bool` | bool | True while resolving a merge (including while popup is open). Prevents new detection scans from interleaving. |
| `board: Control` | Control | Reference to the active board (set by parent) |
| `_detector: RefCounted` | RefCounted | MergeDetector reference for chain rescan |
| `_merge_board: Control` | Control | MergeBoard reference for triggering animations |
| `_result_center: Vector2i` | Vector2i | Pre-resolved placement position (animation target matches result placement) |
| `_pending_options: Array[Dictionary]` | Array | Stored merge options for use after animation completes |
| `_pending_quality: Dictionary` | Dictionary | `{result_quality, refund_qualities}` from `quality_rules.resolve()`, computed when the group starts processing |

**Functions:**

| Function | Description |
|----------|-------------|
| `process_next()` | Pops next group from queue, resolves result position, triggers merge animation. |
| `_on_animation_done()` | Callback after animation: removes items from grid, handles options (auto-pick or popup). |
| `_try_chain()` | Rescans board grid when queue empties; enqueues new groups for chain merges. |
| `_resolve_result_position() -> Vector2i` | Calculates actual result placement cell (simulates post-removal state). |
| `calculate_center_of_mass(positions: Array[Vector2i]) -> Vector2i` | Returns the center cell of a merge group (average x/y, floored). |
| `_group_qualities(positions: Array[Vector2i]) -> Array[int]` | Reads the quality of each item currently on the board at these positions, for `quality_rules.resolve()`. |
| `_spawn_results(result_data: Dictionary, count: int)` | Places count result items (already carrying `result_quality`): first at `_result_center`, rest at nearest empty cells. |
| `_refund_source_items(source_def: ItemDefinition, qualities: Array)` | Refunds one source item per entry in `qualities` (the group's lowest-quality items) at former group positions. |
| `handle_choice(item_id: String, is_variant: bool, reagent_id: String)` | Callback from MergeChoicePopup. Places result(s), consumes reagent if variant. |

#### BoardCell

**Extends:** Control
**Script:** `board/board_cell.gd`
**Description:** Single cell visual in the board grid. Acts as both a drag source (board-to-board swap) and drop target (staging-to-board placement, board-to-board swap) via Godot's built-in drag-and-drop. Displays item icon when occupied. Does NOT own item data — the item Dictionary is set by BoardGrid.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `grid_pos: Vector2i` | Vector2i | This cell's position in the grid (col, row) |
| `item: Dictionary` | Dictionary or null | Item data currently in this cell, or null if empty |

**Signals:**

| Signal | Description |
|--------|-------------|
| `cell_drag_started(from_pos: Vector2i, item: Dictionary)` | Drag initiated from this cell. board_grid listens. |
| `cell_drag_ended(to_pos: Vector2i, drag_data: Dictionary)` | An item was dropped on this cell. board_grid reads the source from `drag_data` (`_source_grid`, `_source_pos`) and places, moves or swaps. Not emitted for a release outside every cell. |

**Functions:**

| Function                                                      | Description                                                          |
| ------------------------------------------------------------- | -------------------------------------------------------------------- |
| `set_item(item: Dictionary)`                                  | Updates visual to show item icon. Stores item data.                  |
| `clear_item()`                                                | Removes item visual. Sets item to null.                              |
| `_get_drag_data(at_position: Vector2) -> Variant`             | Returns `make_drag_data()`: the item Dictionary plus `_source_pos`, `_source_grid` (this cell's grid) and `_source_screen`. Sets drag preview with ~50px upward offset. |
| `_can_drop_data(at_position: Vector2, data: Variant) -> bool` | Returns true if data contains valid item dict.                       |
| `_drop_data(at_position: Vector2, data: Variant)`             | Receives dropped item, emits `cell_drag_ended(grid_pos, data)`.      |

#### MergeChoicePopup

**Extends:** PopupPanel
**Script:** `board/merge_choice_popup.gd`
**Description:** Displays 2–4 merge result options as tappable buttons. Non-blocking — does NOT pause the game. No cancel button, no timer. If dismissed without a pick (Esc / tap-outside), falls back to the first option via `choice_made` so the merge resolves and the queue doesn't deadlock — the merge can't be safely undone because the source items were already consumed by the time the popup appears.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `_options: Array[Dictionary]` | Array | Options for the currently shown choice; used to fall back to the first option on dismissal. |
| `_answered: bool` | bool | True once the player picked an option; distinguishes a hide-from-choice from an external dismissal. |

**Signals:**

| Signal | Description |
|--------|-------------|
| `choice_made(item_id: String, is_variant: bool, reagent_id: String)` | Player selected a result, OR the popup was dismissed and the first option was used as a fallback. merge_resolver receives via callback. |
| `cancelled` | Safety net: emitted only on dismissal when there are no options (unreachable in normal flow). |

**Functions:**

| Function | Description |
|----------|-------------|
| `show_options(options: Array[Dictionary])` | Populates buttons and shows popup. |
| `_on_popup_hide()` | On hide: if no option was picked, emits `choice_made` with the first option (or `cancelled` if there are none). |

#### FloatingItem

**Extends:** Control
**Script:** `board/floating_item.gd`
**Description:** A staging area item with a countdown timer. Acts as a drag source via Godot `_get_drag_data` — player drags from here to a BoardCell to place items on the grid. Shows remaining time visually (shrinking bar or opacity fade).

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `item_data: Dictionary` | Dictionary | The item this represents |
| `despawn_time: float` | float | Total seconds before despawn |
| `time_remaining: float` | float | Current countdown value |

**Signals:**

| Signal | Description |
|--------|-------------|
| `despawn_timeout()` | Timer expired. board_grid (staging handler) removes this item. |

**Functions:**

| Function | Description |
|----------|-------------|
| `setup(data: Dictionary, time: float)` | Initializes item data and despawn timer. Called by MergeBoard. |
| `_get_drag_data(at_position: Vector2) -> Variant` | Returns item Dictionary. Sets drag preview with ~50px upward offset. |

---

## Subsystem: Content Definitions, Recipes & Blueprints

### Scenes & Scripts

| File | Type | Responsibility |
|------|------|----------------|
| `autoloads/definition_library.gd` | Autoload | Loads every definition folder into a catalog keyed by id. Shop listings (blueprints, crates, upgrades, reagents) come back cheapest first, customers in `queue_order`, party members in `slot_order`. |
| `autoloads/recipe_resolver.gd` | Autoload | Synchronous rules over the definitions, filtered by player progress. |
| `autoloads/session_planner.gd` | Autoload | `plan_next_session() -> SessionPlan`. The only caller of `customer_generator.gd`; prep and the shop both go through it. |
| `autoloads/session_plan.gd` | Script (`RefCounted`, `SessionPlan`) | One dealt shop session: `customers: Array[ShopCustomer]`, `modifier: SessionModifierDefinition` (null when none rolled). `family_demand() -> Array[Dictionary]` returns `{"family", "share"}` per item family across every order, largest share first (ties by family) — the prep forecast's "what will they ask for". |
| `autoloads/customer_generator.gd` | Script (`RefCounted`) | `plan(...)` rolls a market modifier (its own RNG stream, so adding modifiers never reshuffles a seed's customers) then deals the session's customers from the unlocked archetypes: filters by shop level and craftability, does a weighted draw with replacement, rolls each dealt customer's orders. `roll_modifier(...)` picks at most one modifier, gated by `ShopRulesDefinition.modifier_chance` and each modifier's `min_shop_level`, weighted like everything else. Deterministic from its inputs (same archetypes, modifiers, level, seed and craftability give the same session). |
| `autoloads/shop_customer.gd` | Script (`RefCounted`, `ShopCustomer`) | One customer dealt into a session: the `CustomerDefinition` archetype plus the `Array[OrderDefinition]` rolled for it. |
| `resources/definitions/*.gd` | Resource scripts | One `class_name` per definition type (below). |

### Content Definitions

Each catalog is a folder of `.tres` files under `resources/definitions/`; the file name is the definition's `id`. Types without a folder are value objects that live inside another definition as sub-resources.

| Folder | Type | Fields |
|--------|------|--------|
| `items/` | `ItemDefinition` | See below. |
| `party/` | `PartyMemberDefinition` | See the Dungeon Run subsystem. |
| `enemies/` | `EnemyDefinition` | See the Dungeon Run subsystem. |
| `reagents/` | `ReagentDefinition` | `id`, `name`, `cost`, `description`, `sprite`, `min_shop_level` |
| `blueprints/` | `BlueprintDefinition` | `id`, `name`, `cost`, `dependencies: Array[BlueprintDefinition]`, `min_shop_level` |
| `crates/` | `CrateDefinition` | `id`, `name`, `cost`, `min_items`, `max_items`, `pool: Array[WeightedItem]`, `min_shop_level` |
| `upgrades/` | `UpgradeDefinition` | A leveled track: `id`, `name`, `description`, `effect` (`grid_size`, `despawn_time`, `crate_discount`, `shelf_slots`, `forecast_detail` or `order_price`), `levels: Array[UpgradeLevel]`. `max_level()` is `levels.size()`; `next_level(level)` is the level bought after `level`, or null at the max. Buying an upgrade buys its next level. |
| `customers/` | `CustomerDefinition` | A customer *archetype*, not a fixed customer: `id`, `name`, `role`, `sprite` (portrait), `min_shop_level`, `weight` (a real frequency weight: how often this archetype is dealt relative to the other eligible archetypes — see Shop Session), `min_orders`, `max_orders`, `price_multiplier` (scales every rolled order's price), `wants: Array[OrderTemplate]` |
| `shop_rules/` | `ShopRulesDefinition` | One definition, id `"default"`: `id`, `session_size`, `modifier_chance`, `forecast_customers`, `xp_per_gold`, `streak_step`, `streak_cap`, `level_xp_base`, `level_xp_exponent`, `max_level` |
| `dungeons/` | `DungeonDefinition` | See the Dungeon Run subsystem. |
| `modifiers/` | `SessionModifierDefinition` | A market event a shop session may roll, at most one per session (`ShopRulesDefinition.modifier_chance`): `id`, `name`, `description`, `sprite`, `min_shop_level`, `weight`, `boosted_customers: Array[CustomerDefinition]`, `customer_weight_multiplier`, `family`, `family_price_multiplier`, `affected_crates: Array[CrateDefinition]`, `crate_cost_multiplier`, `session_size_delta` |
| (inline) | `EffectDefinition` | `type`, `value`, `duration` (ticks, 0 = instant). The `value` meaning per type is in `effect_definition.gd`. |
| (inline) | `MergeResult` | `result: ItemDefinition`, `blueprint: BlueprintDefinition` (null = always available) |
| (inline) | `ReagentVariant` | `result: ItemDefinition`, `reagent: ReagentDefinition`, `blueprint` (null = always available) |
| (inline) | `UpgradeLevel` | One level of an upgrade track: `cost`, `value` (the absolute value at this level, not a step: seconds for despawn_time, price multiplier for crate_discount and order_price, slots for shelf_slots, customers revealed for forecast_detail with 0 meaning every customer plus their orders), `grid_cols` and `grid_rows` (what this level adds to the board, for grid_size), `min_shop_level` (default 1). Costs rise within a track (checked by `test_definition_library`). |
| (inline) | `WeightedItem` | `item: ItemDefinition`, `weight: int` (relative; 0 never rolls) |
| (inline) | `OrderTemplate` | A thing a customer archetype may ask for, on `CustomerDefinition.wants`: `item: ItemDefinition`, `weight: int`, `min_quantity`, `max_quantity`, `min_quality: int` (0 any, 1 Fine or better, 2 Masterwork; only meaningful on an item at least `min_quality` merges deep — a crate item can never be Fine). Rolled into an `OrderDefinition` per session (see Shop Session). |
| (inline) | `OrderDefinition` | A rolled order on a dealt `ShopCustomer`: `item: ItemDefinition`, `quantity`, `gold_reward`, `min_quality: int` (copied from the template; priced by `ShopRulesDefinition.quality_price_multipliers[min_quality]`) |
| (inline) | `EncounterDefinition`, `EnemySpawn` | `spawns: Array[EnemySpawn]`; `enemy: EnemyDefinition`, `count` |

Saves store ids only, never resources, so an id is part of the save format: renaming one needs a `SAVE_VERSION` bump.

### Definition Schema: ItemDefinition (`resources/definitions/items/*.tres`)

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique identifier, required. e.g. "iron_ore", "sword" |
| `name` | `String` | Display name |
| `family` | `String` | Item family for grouping. e.g. "metal", "herb", "powder" |
| `gold_value` | `int` | Base gold value (used for order pricing and selling) |
| `dungeon_usable` | `bool` | Whether this item can be used during dungeon runs |
| `dungeon_use_target` | `String` | If dungeon_usable: `"party-individual"`, `"enemy-individual"`, or `"enemy-all"`. `""` if not. |
| `effect` | `EffectDefinition` or null | Null if not dungeon_usable. |
| `sprite` | `Texture2D` | The item's image. |
| `merge_results` | `Array[MergeResult]` | What three of this item merge into. More than one available result opens the choice popup. |
| `reagent_variants` | `Array[ReagentVariant]` | Extra merge results that cost one reagent. |

**Board item:** a board cell holds `RecipeResolver.make_item(def, quality)`, a dictionary `{item_id, definition, quality}`. `quality` is 0 Normal, 1 Fine or 2 Masterwork (`ItemDefinition.MAX_QUALITY` and `.QUALITY_NAMES` are the single source for the limit and display names). `item_id` and `quality` are what merge detection (ignores quality; groups form by `item_id` alone), order fulfillment and saves read; views read `definition.sprite` and draw `quality` as stars (`ui/quality_stars.tscn`). Drag and drop copies it and adds transient `_source_pos` / `_source_grid` / `_source_screen` keys. Crates and drops give Normal (`quality = 0`) items.

### Signals

RecipeResolver has no signals — it is queried synchronously by MergeResolver, ShopSession, MergeBoard, DropManager and PrepPhase.

### Flow Trace: Resolve Merge Options

**Trigger:** MergeResolver processes a merge group and needs available results.

1. `merge_resolver.gd` calls `RecipeResolver.get_options(item_id)`
2. `recipe_resolver.gd` reads the item's `merge_results`
3. For each result, checks its blueprint gate: null → include; in `GameManager.unlocked_blueprints` → include; otherwise exclude
4. Returns the available `MergeResult`s; MergeResolver turns them into popup options

**End state:** Caller has the list of available options to display or auto-resolve.

### Flow Trace: Resolve Reagent Variants

**Trigger:** MergeResolver builds the options for a merge group.

1. `merge_resolver.gd` calls `RecipeResolver.get_variant_options(item_id)`
2. `recipe_resolver.gd` reads the item's `reagent_variants`
3. For each variant: blueprint gate passes (as above) and `GameManager.reagent_inventory[reagent.id] >= 1` → include
4. Returns the available `ReagentVariant`s (may be empty)

**End state:** Variant options (if any) added to the merge choice popup alongside base results.

### Class Reference

#### DefinitionLibrary

**Extends:** Node
**Script:** `autoloads/definition_library.gd`

| Function | Description |
|----------|-------------|
| `get_catalogs() -> Dictionary` | Folder name to catalog, for code that walks every catalog (the integrity tests). |
| `get_item(id)`, `get_party_member(id)`, `get_enemy(id)`, `get_reagent(id)`, `get_blueprint(id)`, `get_crate(id)`, `get_upgrade(id)`, `get_dungeon(id)`, `get_modifier(id)` | The definition, or null. |
| `get_all_items() -> Dictionary`, `get_all_enemies() -> Dictionary` | The catalogs themselves (read-only). |
| `get_all_party_members()` | Ordered by `slot_order`: index 0 is the front member. |
| `get_all_blueprints()`, `get_all_crates()`, `get_all_upgrades()`, `get_all_reagents()` | Typed arrays, cheapest first (ties by id). |
| `get_all_customers() -> Array[CustomerDefinition]` | Sorted by id: the archetype pool `autoloads/customer_generator.gd` deals a session from. Not a fixed order — the generator decides who's dealt. |
| `get_shop_rules() -> ShopRulesDefinition` | The one `shop_rules` definition, id `"default"` (`session_size`, `modifier_chance`, `forecast_customers`, `quality_price_multipliers` (`default.tres` ships `[1.0, 1.2, 1.5]`, indexed by `min_quality`), `xp_per_gold`, `streak_step`, `streak_cap`, `level_xp_base`, `level_xp_exponent`, `max_level`). |
| `get_all_dungeons()` | Ordered by `min_shop_level` (unlock order), ties by id. PrepPhase's Enter Dungeon button targets the first. |
| `get_all_modifiers() -> Array[SessionModifierDefinition]` | Sorted by id, so a seeded modifier roll can't depend on catalog load order. |
| `get_unlocks_between(old_level: int, new_level: int) -> Array[Resource]` | Every definition across every catalog whose `min_shop_level` is above `old_level` and at or below `new_level` (exclusive below, inclusive above). Sorted by level, then folder, then id. Used by `LevelUpPanel` to list what a level-up opened. |

#### RecipeResolver

**Extends:** Node
**Script:** `autoloads/recipe_resolver.gd`
**Description:** Rules over DefinitionLibrary's content. All filtering happens at query time from current GameManager state.

| Function | Description |
|----------|-------------|
| `make_item(def: ItemDefinition, quality: int = 0) -> Dictionary` | The board item dictionary `{item_id, definition, quality}`. |
| `get_options(item_id: String) -> Array[MergeResult]` | Available merge results, filtered by blueprint ownership. Empty for an unknown id. |
| `get_variant_options(item_id: String) -> Array[ReagentVariant]` | Available reagent variants, filtered by blueprint and reagent inventory. |
| `is_unlocked(blueprint: BlueprintDefinition) -> bool` | True for null or an owned blueprint. |
| `has_blueprint(bp_id: String) -> bool` | Checks `GameManager.unlocked_blueprints`. |
| `are_dependencies_met(blueprint: BlueprintDefinition) -> bool` | True when every dependency is owned. |
| `is_craftable(item: ItemDefinition) -> bool` | True if the item is raw, or can be reached today via merge results and reagent variants whose source is craftable — counting only crates open at the player's level (`GameManager.meets_level(crate.min_shop_level)`) and reagents for sale at their level or already in stock. Used by `autoloads/customer_generator.gd` to keep every dealt order deliverable. |
| `roll_weighted_pool(pool: Array[WeightedItem], min_rolls: int, max_rolls: int) -> Array[ItemDefinition]` | Static. Rolls `randi_range(min_rolls, max_rolls)` independent picks, each weighted by `weight`. Shared by crates and enemy drops. |

---

## Subsystem: Shop Session

### Scenes & Scripts

| File | Type | Responsibility |
|------|------|----------------|
| `shop/shop_session.tscn` | Scene | Top-level shop session. Layout: `HBoxContainer [CustomerDisplay | MergeBoard | CratePanel]`. CustomerDisplay and CratePanel are sub-components within this scene (no separate scene files). CratePanel is a VBoxContainer on the right with crate buy buttons populated dynamically from the crate definitions and a discard trash bin below. |
| `shop/shop_session.gd` | Script | Orchestrates the session loop: customer display, order fulfillment, session end, crate purchasing. Does NOT own board logic or merge resolution. Gets its `plan: SessionPlan` (and `customers`, `= plan.customers`) from `SessionPlanner.plan_next_session()`. |
| `shop/order_card.tscn` | Scene | One order display: item icon, quantity, reward, and a `ui/quality_stars.tscn` badge (`_stars.set_quality(order.min_quality)`) for a Fine or Masterwork order. Tappable to fulfill. |
| `shop/order_streak.gd` | Script (`RefCounted`) | Tracks the fulfil streak for the current session (`count`, not saved). `fulfill(gold_reward, rules)` returns the order's XP via `ShopRulesDefinition.order_xp` and then grows the streak; `reject()` resets it to 0. A rejection breaks the streak and earns no XP. |
| `shop/session_summary.tscn` | Scene | End-of-session summary. Animated gold counter, XP earned, items sold, fulfilled/rejected counts, customer portraits, and a `LevelUpPanel` if a level was crossed. |
| `ui/level_up_panel.tscn`, `.gd` | Scene (shared, `ui/`) | The "Level N!" banner plus "Unlocked: X" lines. `setup(old_level: int, new_level: int)`: visible only when `new_level > old_level`; lists `DefinitionLibrary.get_unlocks_between(old_level, new_level)` by `definition.name`. Used by both `session_summary.tscn` and `dungeon/dungeon_summary.tscn` — a shared `ui/` widget, not owned by either subsystem. |

### Customers and Crates

Customers are dealt from `CustomerDefinition` archetypes (see Content Definitions) by `autoloads/customer_generator.gd`, called only through `SessionPlanner.plan_next_session()`, and crates are `CrateDefinition`s. No separate premium tier: later archetypes gated by `min_shop_level` fill that role. The generator does a weighted draw with replacement from every level-unlocked, currently-craftable archetype: each draw is weighted by `weight` (a real frequency, not just a tiebreaker), with no archetype repeating back-to-back while another is eligible (`pick_weighted` treats a non-positive weight as 0, falling back to a uniform draw if every weight is non-positive). A fresh game only unlocks the archetypes with `min_shop_level` 1, so only those compete for every slot in a `session_size`-customer session (`ShopRulesDefinition`, default 10) until the player's level clears the next archetype's `min_shop_level`. Each dealt customer gets `min_orders` to `max_orders` orders, the first always for something the player can craft today and the rest possibly gated behind a blueprint. Whatever crates are defined and open at the player's level are rendered as buy buttons in the shop's CratePanel, cheapest first; crate cost is multiplied by the Crate Discount upgrade and, when the dealt session rolled a market modifier, that modifier's `crate_cost_multiplier` for the crates it affects (see MergeBoard's `get_crate_cost`). The panel rebuilds on `GameManager.shop_level_changed` so a newly-unlocked crate appears immediately.

**Crate generation algorithm:** For each item slot (rolled `min_items` to `max_items` times, independently):
1. Sum all weights in the pool
2. Generate a random float in `[0, sum)`
3. Iterate items, accumulating weights — the item whose cumulative range contains the random number is selected
4. Each roll is independent (same item can appear multiple times in one crate)

### Signals

| Signal | Emitted by | Listeners | Via EventBus? | Flows |
|--------|-----------|-----------|---------------|-------|
| `customer_fulfilled(order_id: String)` | `shop_session.gd` | EventBus → `save_manager.gd` | Yes | Order Fulfillment |
| `customer_rejected(customer_id: String)` | `shop_session.gd` | EventBus → `save_manager.gd` | Yes | Customer Reject |
| `session_ended(summary: Dictionary)` | `shop_session.gd` | `main.gd` | Yes | Session End |
| `session_summary_dismissed()` | `session_summary.gd` | `main.gd` | Yes | Summary → Prep |
| `order_tapped(order_index: int)` | `order_card.gd` | `shop_session.gd` | No | Order Fulfillment |
| `crate_buy_requested(crate_id: String)` | crate panel buy button | `shop_session.gd` | No | Crate Purchase |

### Flow Trace: Shop Session Loop

**Trigger:** Main instances `shop_session.tscn` (from prep phase or new game).

1. `shop_session.gd._ready()` calls `SessionPlanner.plan_next_session()`, which asks `autoloads/customer_generator.gd` for `session_size` customers, seeded by `GameManager.get_session_seed()`, from the level-unlocked archetypes.
2. `shop_session.gd` displays first customer: portrait on left, 1–3 order cards stacked vertically on right, silhouette of remaining customers behind
3. Player crafts items on the merge board (standard merge board flow) or buys crates from the CratePanel on the right (crate button → `shop_session.try_buy_crate(crate_id)` → picks random items from the crate's weighted pool, places on board via merge-safe placement, staging area as fallback). Available crates are the level-unlocked crate definitions; the panel rebuilds on `shop_level_changed`.
4. Player taps one of the displayed `order_card.gd` options → emits `order_tapped(index)` → `shop_session.gd.try_fulfill_order(index)`. Only one order can be fulfilled per customer — the chosen order is fulfilled, all other orders for that customer are discarded.
5. If board has required items for the chosen order: remove items, add gold to GameManager, compute XP via `order_streak.gd.fulfill(reward, rules)` (grows the streak) and add it with `GameManager.add_shop_xp`, emit `customer_fulfilled` via EventBus, discard remaining orders, advance customer
6. If board lacks items for the chosen order: flash order card red, no action, other orders remain available to tap
7. Player taps reject → `order_streak.gd.reject()` breaks the fulfil streak (no XP change), emit `customer_rejected` via EventBus, advance customer
8. After the last customer (`customers.size()`, the dealt session's count — `_rules.session_size` defaults to 10, but a market modifier's `session_size_delta` can change it) → compile summary data (including `xp_earned`, `level_before`, `level_after`), emit `session_ended(summary)` via EventBus → Main transitions to `session_summary.tscn`

**End state:** GameManager updated with gold and XP changes, SessionSummary displayed (with a `LevelUpPanel` if a level was crossed), auto-save triggered.

### Flow Trace: Order Fulfillment

**Trigger:** Player taps one order card from the current customer's 1–3 displayed orders.

1. `order_card.gd` emits `order_tapped(order_index)` → `shop_session.gd.try_fulfill_order(index)`
2. `shop_session.gd` reads the chosen order's requirements: `{item_id: quantity}` plus `order.min_quality`
3. Calls `board.count_sellable(item_id, order.min_quality)` for each required item (board plus display shelf, counting only items at `min_quality` or above)
4. If all requirements met: `board.take_sellable(item_id, qty, order.min_quality)` for each (the lowest qualifying quality first, so a Masterwork is never spent on a Normal order; within one quality, shelf first, then board), `GameManager.add_gold(reward)`, `GameManager.add_shop_xp(_streak.fulfill(reward, _rules))` (`ShopRulesDefinition.order_xp`: `round(gold x xp_per_gold x (1 + min(streak x streak_step, streak_cap)))`), emit `customer_fulfilled`, discard all other unfulfilled orders for this customer
5. Advance to next customer (or end session if last)

**End state:** Chosen order fulfilled, remaining orders discarded, items removed from the shelf and board, gold and XP added, customer replaced. At session end ShopSession saves the board to `GameManager.shop_board_state` and the shelf to `GameManager.shop_shelf_state`.

### Class Reference

#### ShopSession

**Extends:** Control
**Script:** `shop/shop_session.gd`
**Description:** Orchestrates the shop session (`session_size` customers, `ShopRulesDefinition`, default 10). Each customer presents 1–3 order options; the player picks one to fulfill (others are discarded). Manages customer queue state and delegates to BoardGrid and OrderCards.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `plan: SessionPlan` | `SessionPlan` | This session's plan, from `SessionPlanner.plan_next_session()` |
| `customers: Array[ShopCustomer]` | Array | `= plan.customers`, as dealt by `autoloads/customer_generator.gd` |
| `current_index: int` | int | Current customer index (0 to `session_size - 1`) |
| `board: Control (MergeBoard instance)` | Control | Reference to instanced merge board |
| `summary_data: Dictionary` | Dictionary | Accumulated stats: gold_earned, items_sold, fulfilled, rejected, portraits, xp_earned, level_before, level_after |

**Functions:**

| Function | Description |
|----------|-------------|
| `advance_customer()` | Displays next customer. If index >= `customers.size()` (the dealt session's count), ends session. |
| `try_fulfill_order(order_index: int)` | Checks board for items for the chosen order. If met: fulfills, awards XP via `order_streak.gd`, discards remaining orders, advances customer. If not: flashes red. |
| `reject_customer()` | Breaks the fulfil streak via `order_streak.gd.reject()` (no XP change), advances. |
| `try_buy_crate(crate_id: String) -> bool` | Delegates to `board.buy_crate(crate_id)`. MergeBoard handles discount, pool rolling, and merge-safe placement internally, and refuses (returning false) a crate below `GameManager.meets_level(crate.min_shop_level)`. |

#### OrderCard

**Extends:** Control
**Script:** `shop/order_card.gd`
**Description:** Displays a single order: item icon, quantity needed, gold reward. Emits signal when tapped.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `order: OrderDefinition` | OrderDefinition | Set by `setup(order, index)` |

**Signals:**

| Signal | Description |
|--------|-------------|
| `order_tapped(order_index: int)` | Player tapped this card. shop_session listens. |

#### SessionSummary

**Extends:** Control
**Script:** `shop/session_summary.gd`
**Description:** Displays end-of-session stats. Gold count-up animation, items sold list, fulfilled/rejected counts, satisfied customer portraits.

**Functions:**

| Function | Description |
|----------|-------------|
| `display_summary(data: Dictionary)` | Populates UI and starts gold count-up animation. |

---

## Subsystem: Dungeon Run

### Scenes & Scripts

| File | Type | Responsibility |
|------|------|----------------|
| `dungeon/dungeon_run.tscn` | Scene | Top-level dungeon scene. Owns party display, enemy display, merge board, combat area, encounter banner (simple label showing encounter number, shown/hidden by dungeon_controller). A fixed-height `Battlefield` spacer separates the party row from the enemy row so telegraph lines have room, and `EnemyContainer` keeps a fixed minimum height so the board doesn't move when an encounter starts or ends. Transient combat visuals (VFX, telegraphs) live on `AnimOverlay`, never inside the layout containers, so nothing in combat moves the board or the unit rows. |
| `dungeon/dungeon_controller.gd` | Script | Orchestrates dungeon flow: walking → encounter → combat → walking → end. Reads dungeon and party definitions from DefinitionLibrary. Does NOT own combat math. |
| `dungeon/combat_engine.gd` | Script | 1-second combat ticks. Damage distribution, HP tracking, knockout detection, buff timers. Does NOT own dungeon flow. |
| `dungeon/drop_manager.gd` | Script | Generates enemy drops, places on dungeon board via merge-safe placement. Does NOT own board logic. |
| `dungeon/party_member.tscn` | Scene | Visual: 300 px wide card with a 128x128 sprite, a 270x24 HP bar, an HP number, an attack-type badge and buff text. Accepts drag-drops of usable items. |
| `dungeon/enemy_display.tscn` | Scene | Visual: enemy sprite + HP bar + attack-type badge (100x140). No interaction. Fades on death but keeps its slot until the encounter ends. |
| `dungeon/combat_unit.tscn` | Scene | Reusable unit node with sprite, HP bar (with HP ghost overlay), and animation helpers (directional lunge, cast, hit, walk, death). Sprite and bar sizes are exported so PartyMember can enlarge them. Tracks the HP it displays, which trails the engine until a hit plays. Pulses gold while its unit winds up a crit (`play_crit_charge`). |
| `dungeon/attack_badge.tscn` | Scene | Attack badge with empty slot backing, bottom-to-top windup gauge progress, foreground attack type icon (`badge_icon_melee.png`, `badge_icon_missile.png`), crit icon overlay (`crit_sprite`), and split-second glow pulse (`play_glow_pulse`). Swaps to `crit_sprite` during crit windup and resets to standard attack type icon on empty. |
| `dungeon/combat_presenter.gd` | Script | Child node created by dungeon_controller. Plays combat from CombatEngine's signals: coordinates attack badge windup gauges in real-time, triggers badge glow and empty state on attack release, launches battle line heads via CombatLines, and delays impact by tunable `flight_duration` (default 0.25 s) so damage numbers, recoil and HP updates trigger on arrival. Crits swap the unit badge to `crit_sprite`, add the attacker's `crit_name` popup, gold numbers, a bigger impact and a screen shake; `windup_changed` toggles the attacker's crit charge pulse. |
| `dungeon/combat_lane.gd` | Script | Pure lane geometry (RefCounted, static only). Every attack line is shifted and bowed toward the attacker's right, so A-to-B and B-to-A attacks use separate lanes. |
| `dungeon/hp_ghost.gd` | Script | On CombatUnit's `HPGhost` node, drawn over the HP bar: the pulsing chunk the attacks winding up at the member will take (faster pulse when lethal) and the pale trail of HP just lost draining away. |
| `dungeon/combat_lines.gd` | Script | On `AnimOverlay/CombatLines` in dungeon_run.tscn; draws active attack flights on their lanes. When an attack launches, a line shoots from the attacker's attack badge screen position to the target over `flight_duration` with `badge_head` (`badge_bg.png`) and optional `crit_sprite` overlay rotating along the lane trajectory. Lines are pixel art traced with Bresenham onto a 4 px block grid and drawn as solid blocks from a three-shade ramp per side. Thickness is 1 to 4 blocks by the hit's share of the target's displayed HP (`line_thickness`). Normal lines are team colored (party cool, enemy warm); crit lines are gold, outlined over a dark track, ring the target end and put a "!" on the attacker during windup. A hit that would finish the target gets a larger ring, and enemy lines turn red. Pushes each party member's incoming damage to its HP ghost. |
| `dungeon/dungeon_vfx.gd` | Script | VFX overlay attached to AnimOverlay in dungeon_run.tscn: floating combat text, slashes, impacts, heal/buff sparkles, screen shake. |
| `dungeon/dungeon_summary.tscn` | Scene | End-of-dungeon results (cleared or failed). |

### Definition Schema: DungeonDefinition (`resources/definitions/dungeons/*.tres`)

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique identifier |
| `name` | `String` | Display name |
| `min_shop_level` | `int` | Minimum shop level to unlock (`GameManager.meets_level`); also sets the order of `DefinitionLibrary.get_all_dungeons()` |
| `walk_speed` | `float` | Progress per second while walking |
| `encounter_points` | `Array[float]` | Progress thresholds triggering encounters (e.g. [0.2, 0.5, 0.8]) |
| `encounters` | `Array[EncounterDefinition]` | One per encounter point. Each holds `spawns: Array[EnemySpawn]` (`enemy`, `count`). |
| `gold_reward` | `int` | Gold awarded on clear |
| `blueprint_reward` | `BlueprintDefinition` or null | Awarded on clear. Goblin Cave: null. |
| `xp_reward` | `int` | Shop XP awarded on clear. A wipe gives none. Goblin Cave: 60. |

Goblin Cave (MVP): `min_shop_level` 6, walk speed 0.075, encounters at 0.2 / 0.5 / 0.8: two Slimes; a Goblin Archer and a Goblin; two Goblins. 120 gold, 60 XP, no blueprint.

### Definition Schema: EnemyDefinition (`resources/definitions/enemies/*.tres`)

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique identifier, required |
| `name` | `String` | Display name |
| `max_hp` | `int` | Base HP |
| `attack_type` | `String` | `"melee"` or `"missile"`; required. Sets whom each attack hits (always one target). Melee hits the front member (the lowest party slot still standing, so the next slot takes over when the front falls); missile hits the weakest standing member (lowest current HP). |
| `attack` | `int` | Damage of one normal hit. |
| `windup` | `int` | Ticks a normal attack winds up before it lands; required (0 fails CombatEngine's check). |
| `crit_windup` | `int` | Ticks a crit attack winds up before it lands; defaults to `windup * 2` if 0. |
| `crit_chance` | `float` | 0..1, rolled when each windup starts. A crit winds up `crit_windup` ticks and deals `CRIT_DAMAGE_MULT` (4) times the damage. |
| `crit_name` | `String` | Pops up over the attacker when a crit lands. |
| `crit_sprite` | `Texture2D` | Alternative badge icon overlaid during crit windup and battle line flight; falls back to melee/missile icon if null. |
| `min_drops`, `max_drops` | `int` | Number of drops on death |
| `drop_pool` | `Array[WeightedItem]` | Weighted item pool, same as crate pools. Only dungeon-usable items. |
| `sprite` | `Texture2D` | Enemy sprite |

**Drop generation algorithm:** Same as crate generation — for each drop slot (rolled `min_drops` to `max_drops` times, independently):
1. Sum all weights in the pool
2. Generate a random float in `[0, sum)`
3. Iterate items, accumulating weights — the item whose cumulative range contains the random number is selected
4. Each roll is independent (same item can drop multiple times from one enemy)

**Example values:** Goblin is melee, 160 HP, attack 7, windup 1, 15% crit "Smash" (28 after a 4-tick windup); Goblin Archer is missile, 60 HP, attack 5, windup 1, 15% crit "Arrow" (6-tick windup). See the `.tres` files for drop pools.

### Definition Schema: PartyMemberDefinition (`resources/definitions/party/*.tres`)

`DefinitionLibrary.get_all_party_members()` returns the party ordered front to back by `slot_order`: the index is the member's slot, and slot 0 is the front member melee enemies hit.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique identifier, required (e.g. `"fighter"`) |
| `name` | `String` | Display name |
| `sprite` | `Texture2D` | Chibi sprite |
| `max_hp` | `int` | Base HP |
| `attack` | `int` | Damage of one normal hit (plus attack buffs) |
| `attack_type` | `String` | `"melee"` or `"missile"`; required (the empty default fails CombatEngine's check). Same rule as enemies: melee hits the front enemy (lowest alive slot); missile hits the weakest alive enemy. |
| `windup`, `crit_windup`, `crit_chance`, `crit_name`, `crit_sprite` | `int`, `int`, `float`, `String`, `Texture2D` | Same as on enemies; `windup` is required, `crit_windup` defaults to `windup * 2` if 0, `crit_sprite` falls back to normal badge icon if null. |
| `slot_order` | `int` | Party order, front (0) to back |

MVP party: Fighter (slot 0, 120 HP, 11 ATK, melee, crit "Cleave", crit windup 2), Mage (slot 1, 50 HP, 14 ATK, missile, crit "Fireball", crit windup 4), Healer (slot 2, 60 HP, 4 ATK, melee, crit "Smite", crit windup 4); all 15% crit.


No special abilities for MVP — auto-attack only.

### Signals

| Signal | Emitted by | Listeners | Via EventBus? | Flows |
|--------|-----------|-----------|---------------|-------|
| `dungeon_cleared(rewards: Dictionary)` | `dungeon_controller.gd` | `main.gd`, `save_manager.gd` | Yes | Dungeon Win |
| `dungeon_failed(summary: Dictionary)` | `dungeon_controller.gd` | `main.gd`, `save_manager.gd` | Yes | Dungeon Fail |
| `dungeon_summary_dismissed()` | `dungeon_summary.gd` | `main.gd` | Yes | Summary → Prep |
| `encounter_ended()` | `combat_engine.gd` | `dungeon_controller.gd` | No | Combat End |
| `enemy_died(enemy_index: int)` | `combat_engine.gd` | `drop_manager.gd` | No | Enemy Death |
| `member_ko(member_index: int)` | `combat_engine.gd` | (none; the KO greying is shown when the killing hit plays) | No | Party KO |
| `party_wiped()` | `combat_engine.gd` | `dungeon_controller.gd` | No | Dungeon Fail |
| `party_attacked(member_index: int, target_index: int, damage: int, is_crit: bool)` | `combat_engine.gd` | `combat_presenter.gd` | No | Combat Animation |
| `enemy_attacked(enemy_index: int, target_index: int, damage: int, is_crit: bool)` | `combat_engine.gd` | `combat_presenter.gd` (played `ENEMY_VOLLEY_DELAY` later) | No | Combat Animation |
| `windup_changed(side: int, attacker_index: int, target_index: int, is_crit: bool)` | `combat_engine.gd` | `combat_presenter.gd` (crit charge pulse only; lines and ghosts are drawn by `combat_lines.gd` from engine state) | No | Combat Windup |
| `tick_resolved()` | `combat_engine.gd` | `combat_presenter.gd` (buff timers) | No | Combat |
| `effect_applied(member_index: int, effect_type: String, amount: int)` | `combat_engine.gd` | `combat_presenter.gd` | No | Item Use |

### Flow Trace: Dungeon Run (Full Loop)

**Trigger:** Main instances `dungeon_run.tscn` from prep phase.

1. `dungeon_controller.gd._ready()`: reads dungeon data from RecipeResolver. Progress = 0.0, initialize 3 party members with base stats (from the party definitions, in slot order), call `PartyMember.setup(data)` on each to load sprites and store stats, create empty dungeon board, start walk timer (walk speed from dungeon definition)
2. Walk timer ticks → progress bar updates. Player can rearrange dungeon board during walk. Progress only advances while walking.
3. Progress reaches encounter threshold (e.g. 0.2) → walk timer **stops** → `dungeon_controller.start_encounter(encounter_data[0])`
4. Dungeon controller spawns enemy display nodes (calling `EnemyDisplay.setup(enemy_data)` on each to load sprites), then calls `combat_engine.start_combat(enemies)` → initializes enemy array, starts 1-second tick timer
5. **Combat tick** (every 1 second):
   a. Each standing party member counts down its windup. When it ends, the hit lands on the locked target (re-picked if that one fell): `attack` plus buffs, times `CRIT_DAMAGE_MULT` for a crit. Melee targets the front enemy (lowest alive slot), missile the weakest (lowest current HP); every attack hits one target.
   b. Enemy deaths are marked, then each alive enemy does the same against the party.
   c. For each death → emit `enemy_died(index)` → dungeon_controller looks up enemy_data from combat_engine → `drop_manager.spawn_drops(enemy_data)` returns drops array → `drop_manager.add_drops_to_board(drops, board)` creates FloatingItems
   d. Check member KO (HP ≤ 0) → emit `member_ko(index)` (the card greys when the killing hit plays)
   e. If all enemies dead → emit `encounter_ended()` → resume walking
   f. If all members KO → emit `party_wiped()` → go to step 9 (fail)
   g. Tick all buffs: reduce duration, remove expired
   h. Every standing unit without a windup starts one (rolling its crit and locking a target); a winding unit whose target fell retargets. This runs after all hits, so nothing locks onto a unit dropped this tick. `start_combat` does the same for the first windups.
   i. Emit `tick_resolved()` → combat_presenter refreshes buff indicators. HP bars aren't refreshed here: each unit's bar updates when a hit on it plays (party hits on the tick, enemy hits 0.3 s later). Attack lines and HP ghosts read engine state every frame (`combat_lines.gd`).
6. During combat, player merges on the dungeon board (standard merge flow, combat continues)
7. During combat, player drags usable items to party member portraits → `dungeon_controller.apply_usable_item(index, item)` → `combat_engine.apply_effect(index, effect)`
8. All enemies dead → `encounter_ended()` → walk timer **resumes** → encounters at next threshold (0.5, 0.8) → repeat steps 3–7
9. Progress reaches 1.0 AND all encounters cleared → `end_dungeon_cleared()` calculates rewards (gold + blueprint, if any + `xp_reward`) → emit `dungeon_cleared({cleared: true, gold_reward, blueprint_reward, xp_gained, level_before, level_after})` via EventBus → Main transitions to DungeonSummary (cleared)
10. OR all members KO → `end_dungeon_failed()` → emit `dungeon_failed({cleared: false, gold_reward: 0, blueprint_reward: null, xp_gained: 0, level_before, level_after})` via EventBus → Main transitions to DungeonSummary (failed)

**End state (cleared):** Rewards (gold, blueprint, XP) applied to GameManager, dungeon board discarded, auto-save triggered.
**End state (failed):** No XP, dungeon board items lost, shop board unaffected, auto-save triggered.

### Flow Trace: Usable Item Applied to Party Member

**Trigger:** Player drags a usable item from the dungeon board to a party member portrait (via Godot `_drop_data`).

1. BoardCell `_get_drag_data()` initiates drag with item Dictionary. Drag preview shown with ~50px upward offset.
2. Player releases over a PartyMember → `_can_drop_data()` checks if item is a usable type (heal, buff_attack) → returns true
3. PartyMember `_drop_data()` receives item → calls `dungeon_controller.apply_usable_item(member_index, item_data)`
4. `dungeon_controller.gd` calls `board.discard_item(source_pos)`, then `combat_engine.apply_effect(member_index, item_data.definition.effect)`
5. `combat_engine.gd` applies: heal restores HP, buff adds entry to `active_buffs` with duration
6. Party member HP bar and buff indicators update

**End state:** Item consumed from dungeon board, effect applied to party member, combat continues.

### Flow Trace: Enemy Drop Placement

**Trigger:** An enemy dies during combat.

1. `combat_engine.gd` detects enemy HP ≤ 0 → emits `enemy_died(enemy_index)`
2. `drop_manager.gd.spawn_drops(enemy_definition)` → rolls `min_drops` to `max_drops` items from the enemy's drop pool
3. `drop_manager.gd` calls `board.place_drop(drop_data)` for each drop (MergeBoard handles merge-safe placement internally)
4. For each drop: if a merge-safe cell exists, item appears directly on the board. If no safe cell, item goes to staging area with despawn timer.
5. Enemy display removed from combat area

**End state:** Drops placed on board (preferred) or in staging area (fallback), enemy display removed.

### Class Reference

#### DungeonController

**Extends:** Control
**Script:** `dungeon/dungeon_controller.gd`
**Description:** Orchestrates the full dungeon run: walking phases, encounter triggers, combat delegation, usable item routing, and end conditions.

**Lifecycle:** `_ready()` initializes party, creates dungeon board instance, starts walk timer. `_process()` is unused — all logic is timer/signal driven.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `dungeon_id: String` | String | Which DungeonDefinition to run. Set by Main before the scene enters the tree; an unknown id is an error (no fallback). |
| `progress: float` | float | 0.0 to 1.0 dungeon progress |
| `walk_speed: float` | float | Progress gained per second while walking (from dungeon definition) |
| `encounter_points: Array[float]` | Array | Progress thresholds where encounters trigger (e.g. [0.2, 0.5, 0.8], from dungeon definition) |
| `encounters_cleared: int` | int | Completed encounter count |
| `combat_engine: CombatEngine` | Node | Reference to combat engine child |
| `board: Control (MergeBoard instance)` | Control | Dungeon board instance |
| `drop_mgr: Node (DropManager)` | Node | Reference to drop manager |
| `party_defs: Array[PartyMemberDefinition]` | Array | The party, front to back |
| `party_members: Array[PartyMember]` | Array | References to the 3 PartyMember nodes (for setup and HP/buff updates) |
| `enemy_displays: Array[EnemyDisplay]` | Array | Currently spawned enemy display nodes (cleared after each encounter) |

**Functions:**

| Function | Description |
|----------|-------------|
| `start_encounter(encounter_idx: int)` | Looks up encounter data by index, spawns EnemyDisplay nodes, calls `setup(enemy_data)` on each, starts combat via combat_engine, pauses walk timer. |
| `end_encounter()` | After `END_BEAT` (0.8 s, so the final volley plays out), frees all EnemyDisplay nodes, clears `enemy_displays`, resumes walking. A party wipe waits the same beat before `end_dungeon_failed()`. |
| `apply_usable_item(member_index: int, item_data: Dictionary)` | Routes item effect to combat_engine, removes item from board, and has combat_presenter refresh that member at once. |
| `end_dungeon_cleared()` | Calculates rewards (gold, blueprint if any, `xp_reward`), applies to GameManager (`add_gold`, `add_blueprint`, `add_shop_xp`), emits `dungeon_cleared({cleared: true, gold_reward, blueprint_reward, xp_gained, level_before, level_after})`. |
| `end_dungeon_failed()` | No rewards, no XP. Emits `dungeon_failed({cleared: false, gold_reward: 0, blueprint_reward: null, xp_gained: 0, level_before, level_after})`. |

#### CombatEngine

**Extends:** Node
**Script:** `dungeon/combat_engine.gd`
**Description:** Manages auto-combat: 1-second tick timer, damage distribution, HP tracking, buff management, knockout and wipe detection.

**Lifecycle:** Creates and manages its own Timer node (1-second interval). Started by start_combat(), stopped by stop_combat().

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `party_members: Array[Dictionary]` | Array | Runtime state per member: `{name, max_hp, current_hp, attack, active_buffs: [{effect, value, duration}], ...}` |
| `enemies: Array[Dictionary]` | Array | Runtime state per enemy: `{definition, name, max_hp, current_hp, sprite, attack, alive, ...}` |
| `tick_timer: Timer` | Timer | 1-second combat tick |

**Signals:**

| Signal | Description |
|--------|-------------|
| `enemy_died(enemy_index: int)` | Enemy HP reached 0. drop_manager listens. |
| `member_ko(member_index: int)` | Party member HP reached 0. dungeon_controller and portrait UI listen. |
| `party_wiped()` | All 3 members KO. dungeon_controller listens. |
| `encounter_ended()` | All enemies dead. dungeon_controller listens. |
| `tick_resolved()` | Fired once a tick's damage has landed, so views can refresh HP and buffs. |
| `party_attacked(member_index: int, target_index: int, damage: int, is_crit: bool)` | Fired when a party member's windup ends and its hit lands. |
| `enemy_attacked(enemy_index: int, target_index: int, damage: int, is_crit: bool)` | Fired when an enemy's windup ends and its hit lands. |
| `windup_changed(side: int, attacker_index: int, target_index: int, is_crit: bool)` | Fired when a windup starts or retargets; target -1 when it ends (landed, or the attacker fell). `side` is `SIDE_PARTY` or `SIDE_ENEMY`. |
| `effect_applied(member_index: int, effect_type: String, amount: int)` | Fired when a heal or buff effect is applied to a party member. |

**Functions:**

| Function | Description |
|----------|-------------|
| `init_party(members: Array[PartyMemberDefinition])` | Builds party state; array order is slot order. |
| `start_combat(spawns: Array[EnemySpawn])` | Initializes enemy array, starts tick timer. |
| `stop_combat()` | Stops tick timer. |
| `tick()` | One combat tick: distribute damage, check deaths/KOs, tick buffs. Called by timer timeout. |
| `apply_effect(member_index: int, effect: EffectDefinition)` | Applies heal (restore HP up to max) or buff_attack (add to active_buffs). Other effect types do nothing yet. |
| `get_active_member_count() -> int` | Returns count of non-KO members. |
| `get_alive_enemy_count() -> int` | Returns count of alive enemies. |
| `get_enemy_data(index: int) -> Dictionary` | Returns the enemy's runtime state; its `definition` feeds DropManager after `enemy_died`. |
| `is_combat_running() -> bool` | True while the tick timer runs. |
| `is_winding_up(side: int, index: int) -> bool` | True while the unit is standing and winding up an attack. |
| `get_pending_damage(side: int, index: int) -> int` | What the current windup will deal when it lands (buffs and crit included); 0 when idle. |
| `get_incoming_damage(member_index: int) -> int` | Sum of damage alive enemies are winding up at this member. |
| `windup_progress(ticks_left: int, windup_ticks: int, tick_time_left: float, tick_wait: float, landing_delay: float) -> float` | Static and pure. 0 when a windup starts, 1 when its hit plays; a side whose hits play `landing_delay` after their tick gets a countdown stretched to end on that beat. Clamped. |
| `get_windup_progress(side: int, index: int, landing_delay: float) -> float` | `windup_progress` for a unit using the tick timer; -1 if it isn't winding up or combat is stopped. |
| `rng: RandomNumberGenerator` | Rolls crits; randomized in `_ready`. |

#### DropManager

**Extends:** Node
**Script:** `dungeon/drop_manager.gd`
**Description:** Generates item drops from dead enemies and places them on the dungeon board. Calls `board.place_drop()` which handles merge-safe placement internally.

**Functions:**

| Function | Description |
|----------|-------------|
| `spawn_drops(enemy: EnemyDefinition) -> Array[Dictionary]` | Rolls the enemy's drop pool; returns board items (`RecipeResolver.make_item`). |
| `add_drops_to_board(drops: Array[Dictionary], board: Node)` | Calls `board.place_drop(drop_data)` for each drop. MergeBoard handles merge-safe placement internally (board first, staging fallback). |

#### CombatUnit

**Extends:** VBoxContainer
**Script:** `dungeon/combat_unit.gd`
**Scene:** `dungeon/combat_unit.tscn`
**Description:** Reusable sub-scene with a sprite TextureRect and an `HPFrame` holding the HP bar ProgressBar and the `HPGhost` overlay (siblings, so the ghost isn't tinted by the bar's modulate). Instanced by PartyMember and EnemyDisplay. Handles HP bar color coding (green >60%, yellow 30-60%, red <30%).

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `sprite_size: Vector2` | `@export` | Sprite min size, default 80x80 (PartyMember: 128x128) |
| `hp_bar_size: Vector2` | `@export` | HP frame min size, default 80x12 (PartyMember: 270x24) |
| `sprite: TextureRect` | `@onready $Sprite` | Unit sprite |
| `hp_bar: ProgressBar` | `@onready %HPBar` | HP bar with color coding |

**Functions:**

| Function | Description |
|----------|-------------|
| `update_hp(current: int, max_hp: int)` | Sets HP bar value and color based on ratio; forwards to the ghost (a drop starts the damage trail). |
| `set_incoming_damage(amount: int)` | Shows `amount` of damage being wound up at the unit as the HP ghost; 0 hides it. |
| `get_displayed_hp() -> int` | The HP the bar shows (it trails the engine until a hit arrives). CombatLines judges lethality against it. |
| `play_lunge(direction: Vector2, distance: float)` | Moves the sprite toward the target and back over 0.2 s, as the hit plays. |

#### PartyMember

**Extends:** PanelContainer
**Script:** `dungeon/party_member.gd`
**Scene:** `dungeon/party_member.tscn` (instances CombatUnit + a StatusRow with HPLabel, AttackBadge and a fixed-width BuffLabel; text 32 px)
**Description:** Visual representation of a party member: chibi sprite, HP bar, buff icons. Drop target for usable items via Godot's `_can_drop_data` / `_drop_data` — player drags from BoardCell to here.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `member_index: int` | int | 0, 1, or 2 — identifies this member in combat engine |
| `_unit` | `@onready %Unit` | CombatUnit sub-scene instance (sprite + HP bar) |
| `_hp_label: Label` | `@onready %HPLabel` | "current/max" HP text |
| `_buff_label: Label` | `@onready %BuffLabel` | Buff text display |

**Functions:**

| Function | Description |
|----------|-------------|
| `setup(def: PartyMemberDefinition, index: int)` | Shows the member's sprite, HP and attack badge. Called by DungeonController in `_ready`. |
| `update_hp(current: int, max_hp: int)` | Delegates to CombatUnit.update_hp() and updates the HP label. |
| `set_incoming_damage(amount: int)` | Delegates to CombatUnit.set_incoming_damage(). |
| `update_buffs(buffs: Array[Dictionary])` | Updates buff indicator text. |
| `set_ko()` | Plays KO visual (grayscale modulate), disables drop target. |

**Functions (drag-and-drop):**

| Function | Description |
|----------|-------------|
| `_can_drop_data(at_position: Vector2, data: Variant) -> bool` | True for a board item whose definition is `dungeon_usable` with a `dungeon_use_target` containing `"party"`. |
| `_drop_data(at_position: Vector2, data: Variant)` | Receives usable item, calls `dungeon_controller.apply_usable_item(member_index, data)`. |

#### EnemyDisplay

**Extends:** PanelContainer
**Script:** `dungeon/enemy_display.gd`
**Scene:** `dungeon/enemy_display.tscn` (instances CombatUnit)
**Description:** Visual representation of an enemy: sprite, HP bar. No interaction — purely display.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `_unit` | `@onready $Unit` | CombatUnit sub-scene instance (sprite + HP bar) |

**Functions:**

| Function | Description |
|----------|-------------|
| `setup(data: Dictionary)` | Loads sprite texture from `data.sprite` path, stores enemy data. Called by DungeonController when spawning enemies. |
| `update_hp(current: int, max_hp: int)` | Updates HP bar. |
| `play_death()` | Fades out. The node keeps its slot so surviving enemies don't slide; DungeonController frees it when the encounter ends. |

#### DungeonSummary

**Extends:** Control
**Script:** `dungeon/dungeon_summary.gd`
**Description:** Displays dungeon results. Two modes: cleared (rewards) or failed (no XP).

**Properties:**

| Property | Type | Description |
|----------|------|-------------|

**Functions:**

| Function | Description |
|----------|-------------|
| `display_results(data: Dictionary)` | Populates summary. data: `{cleared, gold_reward, blueprint_reward, xp_gained, level_before, level_after}`. Cleared shows "XP: +N"; failed shows "No XP". Both call `LevelUpPanel.setup(level_before, level_after)`. |

---

## Subsystem: Economy & Progression

### Scenes & Scripts

| File | Type | Responsibility |
|------|------|----------------|
| `core/prep_phase.tscn` | Scene | Prep phase with TabContainer: Forecast (next session preview), Blueprints (buy blueprints), Upgrades (buy upgrades), Reagents (buy reagents). Crates are purchased during shop sessions, not here. |
| `core/forecast_panel.tscn` | Scene | The Forecast tab's content: `SessionPlanner.plan_next_session()`'s modifier card, demand by item family, and the first `forecast_customers` customers. |
| `core/forecast_panel.gd` | Script | `setup(plan: SessionPlan, reveal_count: int)`. Rebuilds its demand rows and customer portraits each call; frees the previous ones with `queue_free`. |
| `autoloads/game_manager.gd` | Autoload | Persistent state data store. No game logic — pure state with change signals. |
| `core/purchases.gd` | RefCounted | Purchase rules for blueprints, upgrades and reagents: checks (including `GameManager.meets_level(min_shop_level)` for blueprints and reagents), charges and grants, and refuses without charging when a check fails. Held by PrepPhase. |

### Upgrades and Reagents

Upgrades are `UpgradeDefinition`s and reagents `ReagentDefinition`s (see Content Definitions). Each upgrade is a track of `UpgradeLevel`s; `GameManager.upgrade_levels` maps an upgrade id to the level bought (0 or absent = none). GameManager finds an upgrade's effect by its `effect` type, never by upgrade id, and reads the value at the bought level (capped at the track's length). `core/purchases.gd buy_upgrade` buys the next level: it checks the next level exists, `meets_level(next.min_shop_level)` and gold, charges `next.cost`, adds the level's `grid_cols`/`grid_rows` to `GameManager.grid_cols`/`grid_rows` for `grid_size`, then calls `GameManager.raise_upgrade_level(id)`. The Upgrades tab shows "Name (k/N)", the next level's value and cost, "Max" at the top level and "Unlocks at level N" while the next level is locked. Upgrade levels are not listed on the level-up panel (it lists catalog entries with a top-level `min_shop_level`).

Reagents are bought in the prep phase and stored in `GameManager.reagent_inventory` as counts. They are never placed on the board. At merge time, the merged item's `reagent_variants` whose reagent is in stock become extra options (see Resolve Reagent Variants).

### Signals

| Signal | Emitted by | Listeners | Via EventBus? | Flows |
|--------|-----------|-----------|---------------|-------|
| `prep_start_session()` | `prep_phase.gd` | `main.gd` | Yes | Start Session |
| `prep_enter_dungeon(dungeon_id: String)` | `prep_phase.gd` | `main.gd` | Yes | Enter Dungeon |
| `prep_quit_to_menu()` | `prep_phase.gd` | `main.gd` | Yes | Quit to Menu |
| `save_requested()` | multiple | `save_manager.gd` | Yes | After Purchase/Session/Dungeon |
| `gold_changed(new_amount: int)` | `game_manager.gd` | HUD, prep tabs | No (GameManager direct) | Any gold change |
| `shop_xp_changed(xp: int)` | `game_manager.gd` | HUD | No (GameManager direct) | Shop XP change |
| `shop_level_changed(level: int)` | `game_manager.gd` | `prep_phase.gd`, `shop_session.gd` | No (GameManager direct) | Level crossed |
| `blueprint_added(bp_id: String)` | `game_manager.gd` | prep blueprints tab, `audio_manager.gd` | No (GameManager direct) | Blueprint Purchase |
| `upgrade_level_changed(upgrade_id: String, level: int)` | `game_manager.gd` | `audio_manager.gd`, `prep_phase.gd` | No (GameManager direct) | Upgrade Purchase |
| `grid_size_changed(cols: int, rows: int)` | `game_manager.gd` | active MergeBoard | No (GameManager direct) | Grid upgrade |
| `reagent_count_changed(id: String, count: int)` | `game_manager.gd` | prep reagent display | No (GameManager direct) | Reagent purchase/use |

### Flow Trace: Purchase (Any Type)

**Trigger:** Player taps a buy button in the prep phase (Blueprints / Upgrades tab).

1. Tab script calls `prep_phase.gd.try_purchase(type, id)`
2. `prep_phase.gd` looks up the definition in DefinitionLibrary for its price
3. Check `GameManager.gold >= price` → if not, flash button red, stop
4. `GameManager.deduct_gold(price)` → `gold_changed` signal updates HUD
5. Route by type:
   - **Reagent:** `GameManager.add_reagent(id, 1)` — goes directly to inventory. No items spawned to board or staging.
   - **Blueprint:** check dependencies met → `GameManager.add_blueprint(id)` → `blueprint_added` emitted
   - **Upgrade:** `purchases.buy_upgrade(id)` buys the next level (price is that level's `cost`): grid growth is added for `grid_size`, then `GameManager.raise_upgrade_level(id)` emits `upgrade_level_changed(id, level)`. Other effects are read through GameManager's getters when next used
6. `EventBus.save_requested` emitted → SaveManager writes
7. SFX played via GameManager `blueprint_added` / `upgrade_level_changed` signals (AudioManager connects directly)

**End state:** Purchase applied, gold deducted, HUD updated, save triggered.

### Class Reference

#### PurchaseCard

**Extends:** PanelContainer
**Script:** `shop/purchase_card.gd`
**Scene:** `shop/purchase_card.tscn`
**Description:** Reusable purchase card with name label, description label, and buy button. Instanced dynamically in PrepPhase tabs. Has `_pending_setup` guard for pre-tree setup timing.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `name_label: Label` | `@onready $HBox/Info/NameLabel` | Item name |
| `desc_label: Label` | `@onready $HBox/Info/DescLabel` | Description or dependency warning |
| `buy_btn: Button` | `@onready $HBox/BuyBtn` | Buy/Owned button |

**Functions:**

| Function | Description |
|----------|-------------|
| `setup(card_name, description, desc_color, btn_text, disabled, on_press, min_height)` | Configures card appearance and buy callback. Disconnects previous signal connections. |

#### ForecastPanel

**Extends:** VBoxContainer
**Script:** `core/forecast_panel.gd`
**Scene:** `core/forecast_panel.tscn`
**Description:** The Forecast tab's content: a `SessionPlan`'s market modifier card (hidden when `modifier` is null), demand by item family (`SessionPlan.family_demand()`, one label per family, largest share first) and portraits for the first `reveal_count` customers. Shows `%EmptyLabel` when the plan has no customers.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `_modifier_card: PanelContainer` | `@onready %ModifierCard` | Visible only when `plan.modifier != null` |
| `_modifier_icon: TextureRect` | `@onready %ModifierIcon` | Modifier sprite; hidden when the modifier has none |
| `_modifier_name: Label` | `@onready %ModifierName` | Modifier name |
| `_modifier_description: Label` | `@onready %ModifierDescription` | Modifier description |
| `_demand_list: VBoxContainer` | `@onready %DemandList` | One row per family from `family_demand()`, rebuilt (`queue_free` + `remove_child`) each `setup` |
| `_portraits: HBoxContainer` | `@onready %CustomerPortraits` | One portrait + name column per revealed customer |
| `_empty_label: Label` | `@onready %EmptyLabel` | Shown when `plan.customers` is empty |

**Functions:**

| Function | Description |
|----------|-------------|
| `setup(plan: SessionPlan, reveal_count: int)` | Refreshes the modifier card, demand rows and the first `reveal_count` customers' portraits from `plan`. |

#### PrepPhase

**Extends:** Control
**Script:** `core/prep_phase.gd`
**Scene:** `core/prep_phase.tscn`
**Description:** TabContainer-based prep phase with 4 tabs: Forecast (first, opens by default), Blueprints, Upgrades, Reagents. Does not instance a MergeBoard — board rearrange deferred to post-MVP. Layout is scene-based with placeholder PurchaseCard instances in each purchase tab (cleared at runtime).

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `_bp_scroll: VBoxContainer` | `@onready $VBox/TabContainer/Blueprints/BpContent` | Blueprint tab content container |
| `_upgrade_scroll: VBoxContainer` | `@onready $VBox/TabContainer/Upgrades/UpgradeContent` | Upgrade tab content container |
| `_reagent_scroll: VBoxContainer` | `@onready $VBox/TabContainer/Reagents/ReagentContent` | Reagent tab content container |
| `_dungeon_btn: Button` | `@onready %DungeonBtn` | Enter Dungeon button; its text and disabled state follow `GameManager.shop_level_changed` (`_refresh_dungeon_button`), reading "Dungeon (Lv N)" while locked |
| `_dungeon: DungeonDefinition` | DungeonDefinition | The button's target: `DefinitionLibrary.get_all_dungeons()[0]`, the first dungeon to unlock. Sets the button text and the `meets_level` check. |
| `_purchases: RefCounted` | `core/purchases.gd` | Purchase rules; `try_purchase` delegates to it |
| `_forecast_panel: VBoxContainer` | `@onready %ForecastPanel` | The Forecast tab's content; `_refresh_forecast()` calls `setup(plan, forecast_customers)` on it |
| `_plan: SessionPlan` | SessionPlan | The next session, from `SessionPlanner.plan_next_session()`; exposed via `get_forecast_plan()` and used to feed the forecast panel |

**Functions:**

| Function | Description |
|----------|-------------|
| `get_forecast_plan() -> SessionPlan` | Returns `_plan`, the session the Forecast tab is showing. `shop_session.gd` deals the same plan (both call `SessionPlanner.plan_next_session()`, a pure function of GameManager's state). |
| `try_purchase(type: String, id: String) -> bool` | Delegates a blueprint, upgrade or reagent purchase to its `core/purchases.gd` helper. Returns true on success. |
| `_refresh_forecast()` | Rolls `_plan` from `SessionPlanner` and calls `_forecast_panel.setup(_plan, GameManager.get_forecast_customers())`. Called from `_ready`, and from the `blueprint_added`, `reagent_count_changed`, `shop_level_changed` and `upgrade_level_changed` handlers whenever a purchase or level-up could change what's craftable. |
| `_debug_unlock_all()` | Debug: sets debug_mode, grants 20000g, 1000 rep, all blueprints, 5 of every reagent. |

#### GameManager

**Extends:** Node
**Script:** `autoloads/game_manager.gd`
**Description:** Singleton data store for all persistent game state. No game logic — getters, setters, and change signals only. `SAVE_VERSION` is 8: every board entry (`shop_board_state`, `shop_shelf_state`, `dungeon_board_state`) gained `quality`, validated as a number in 0..`ItemDefinition.MAX_QUALITY`; a missing or out-of-range `quality` makes that entry, and the save, CORRUPT. Older saves are rejected as CORRUPT.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `gold: int` | int | Current gold balance. Default: 50 (starting gold). |
| `shop_xp: int` | int | Cumulative shop XP (`SAVE_VERSION` 6) |
| `unlocked_blueprints: Array[String]` | Array | Blueprint IDs owned |
| `reagent_inventory: Dictionary` | Dictionary | String → int (reagent_id → count) |
| `upgrade_levels: Dictionary` | Dictionary | String → int (upgrade id → level bought). `SAVE_VERSION` 7. |
| `shop_board_state: Array` | Array | Shop board as `{col, row, item_id, quality}` entries (see BoardGrid.get_board_state). `quality` added `SAVE_VERSION` 8. |
| `shop_shelf_state: Array` | Array | Display shelf, same shape (see MergeBoard.get_shelf_state). `SAVE_VERSION` 7, `quality` added `SAVE_VERSION` 8. |
| `dungeon_board_state: Array` | Array | Dungeon board, same shape. Quality forms here too (the resolver is shared) but has no dungeon effect yet; drops are always Normal. `quality` added `SAVE_VERSION` 8. |
| `grid_cols: int` | int | Board width (5 default; Board Expansion adds its levels' `grid_cols`) |
| `grid_rows: int` | int | Board height (5 default; Board Expansion adds its levels' `grid_rows`) |
| `run_seed: int` | int | Rolled once per new game; combined with `sessions_played` to seed each shop session. `SAVE_VERSION` 5. |
| `sessions_played: int` | int | Completed shop-session count. Incremented by `record_session_played()` at `end_session()`, saved right then. Also the ad grace-period counter (Submodule — Ads). `SAVE_VERSION` 5. |

**Signals:**

| Signal | Description |
|--------|-------------|
| `gold_changed(new_amount: int)` | Gold balance changed. HUD and buy buttons listen. |
| `shop_xp_changed(xp: int)` | Shop XP changed. HUD listens. |
| `shop_level_changed(level: int)` | Level crossed. Emitted once per level crossed. |
| `blueprint_added(bp_id: String)` | Blueprint unlocked. Prep phase blueprints tab, audio_manager (purchase SFX) listen. |
| `upgrade_level_changed(upgrade_id: String, level: int)` | An upgrade level was bought; `level` is the new level. audio_manager (purchase SFX) and prep_phase (upgrade cards) listen. |
| `reagent_count_changed(id: String, count: int)` | Reagent inventory changed. |
| `grid_size_changed(cols: int, rows: int)` | Grid dimensions changed. Active MergeBoard listens. |

**Functions:**

| Function | Description |
|----------|-------------|
| `add_gold(amount: int)` | Adds gold, emits `gold_changed`. |
| `deduct_gold(amount: int) -> bool` | Deducts if sufficient. Returns false if not. Emits `gold_changed`. |
| `add_shop_xp(amount: int)` | Adds XP (ignores <= 0), emits `shop_xp_changed`, then `shop_level_changed` once per level crossed. |
| `add_blueprint(bp_id: String)` | Appends to unlocked, emits `blueprint_added`. |
| `add_reagent(reagent_id: String, count: int)` | Updates inventory dict, emits `reagent_count_changed`. |
| `consume_reagent(reagent_id: String) -> bool` | Deducts 1 if count > 0. Returns false if none. |
| `get_upgrade_level(upgrade_id: String) -> int` | Level bought (0 if none). |
| `raise_upgrade_level(upgrade_id: String)` | Adds one level, emits `upgrade_level_changed(upgrade_id, level)`. Charging, checks and grid growth are the caller's (`core/purchases.gd buy_upgrade`). |
| `get_shop_level() -> int` | Returns `DefinitionLibrary.get_shop_rules().level_for_xp(shop_xp)`. |
| `meets_level(min_shop_level: int) -> bool` | Returns `get_shop_level() >= min_shop_level`. |
| `get_despawn_time() -> float` | Bought level's `value` of the `despawn_time` track, else `DEFAULT_DESPAWN_TIME` (12.0). |
| `get_crate_discount() -> float` | Bought level's `value` of the `crate_discount` track, else 1.0. |
| `get_shelf_slots() -> int` | Bought level's `value` of the `shelf_slots` track, else `DEFAULT_SHELF_SLOTS` (0). |
| `get_order_price_multiplier() -> float` | Bought level's `value` of the `order_price` track (Shop Signage), else 1.0. `SessionPlanner` passes it to the generator, which multiplies it into order gold before the one rounding. |
| `get_forecast_customers() -> int` | Bought level's `value` of the `forecast_detail` track (Town Crier), else `ShopRulesDefinition.forecast_customers`. 0 means every customer, plus their orders. |
| `record_session_played()` | Increments `sessions_played`. Called once, at the end of a shop session. |
| `get_session_seed() -> int` | `hash([run_seed, sessions_played])`. Fixed for a given run and session number: previewable in prep. A crash mid-session replays the same customers unless the shop level crossed an archetype's `min_shop_level` mid-session. |
| `serialize() -> Dictionary` | Returns all persistent state as a Dictionary for SaveManager. |
| `deserialize(data: Dictionary)` | Restores all state from save data. |

---

## Subsystem: Save/Load

### Scenes & Scripts

| File | Type | Responsibility |
|------|------|---------------|
| `autoloads/save_manager.gd` | Autoload | Reads/writes single JSON file. Auto-saves on `save_requested` signal. |

### Signals

| Signal | Emitted by | Listeners | Via EventBus? | Flows |
|--------|-----------|-----------|---------------|-------|
| `save_requested()` | multiple | `save_manager.gd` | Yes | Auto-save |
| `save_completed()` | `save_manager.gd` | none currently | No | Write confirmed |
| `save_loaded(data: Dictionary)` | `save_manager.gd` | `game_manager.gd` | No | Load game |

### Flow Trace: Auto-Save

**Trigger:** `EventBus.save_requested` emitted (after session end, purchase, or dungeon end).

1. `save_manager.gd` receives `save_requested`
2. Calls `GameManager.serialize() -> Dictionary`
3. Converts Dictionary to JSON string via `JSON.stringify(data, "\t")`
4. Opens `user://save_data.tmp`, writes JSON string
5. Closes file → `DirAccess.remove_absolute(SAVE_PATH)` then `DirAccess.rename_absolute(tmp_path, SAVE_PATH)`
6. Emits `save_completed`

**End state:** Save file atomically written to disk.

### Flow Trace: Load Game

**Trigger:** Main menu "Continue" button → `EventBus.continue_game`.

1. `main.gd` calls `SaveManager.load_game()` → reads `user://save_data.json`
2. Returns parsed Dictionary (or empty dict if no file / parse error)
3. `main.gd` calls `GameManager.deserialize(data)` to restore all state
4. Main transitions to PrepPhase (resumes from last known state)

**End state:** All persistent state restored, player enters prep phase.

### Class Reference

#### SaveManager

**Extends:** Node
**Script:** `autoloads/save_manager.gd`
**Description:** Handles auto-save and load for a single JSON file. Uses atomic writes (temp file + rename) to prevent corruption on crash.

**Lifecycle:** `_ready()` connects to `EventBus.save_requested`.

**Functions:**

| Function | Description |
|----------|-------------|
| `save_game()` | Serializes GameManager, writes JSON atomically. |
| `load_game() -> Dictionary` | Reads and parses JSON. Returns empty dict on failure. |
| `has_save() -> bool` | Returns `FileAccess.file_exists("user://save_data.json")`. |
| `delete_save()` | Removes save file (new game action). |

---

## Parked (Visual Polish)

> These are visual details deferred from MVP implementation. No architecture impact — they slot into existing scenes without structural changes.

- Customer silhouette with random horizontal movements behind current customer (in `shop_session.tscn` CustomerDisplay area)
- Walking/attack/hit animations for party members (in `party_member.tscn`)
- Front/rear line distinction for party formation (would require CombatEngine changes — defer to post-MVP)
- Specific party members taking damage for others (tank mechanic — requires CombatEngine targeting changes — defer to post-MVP)

---

## Class Reference: EventBus

**Extends:** Node
**Script:** `autoloads/event_bus.gd`
**Description:** Pure signal relay autoload. Declares all game-wide signals listed in the EventBus Signal Registry (lines 67–83). No properties, no logic — other autoloads and scenes connect to its signals for cross-scene communication. State-change signals (gold_changed, shop_xp_changed, shop_level_changed, etc.) are owned by GameManager, not EventBus.

---

## Subsystem: Audio

### Scenes & Scripts

| File | Type | Responsibility |
|------|------|---------------|
| `autoloads/audio_manager.gd` | Autoload | Plays music tracks with crossfade. Plays SFX one-shots. Fully signal-driven. |

### Signals

No signals emitted. AudioManager only listens.

### Flow Trace: Scene Music Switch

**Trigger:** Scene transition (shop → dungeon, dungeon → prep, etc.).

1. `main.gd` calls `AudioManager.play_music(track_name)` after transitioning
2. If same track → no-op
3. If different track → crossfade over ~1 second: fade out current, fade in new
4. Shop theme: `res://resources/audio/music/shop_theme.wav`
5. Dungeon theme: `res://resources/audio/music/dungeon_theme.wav`

**End state:** New music track playing, crossfaded smoothly.

### Flow Trace: SFX on Game Event

**Trigger:** Any EventBus signal or GameManager signal that maps to a SFX (merge_completed, customer_fulfilled, blueprint_added, upgrade_level_changed, etc.).

1. `audio_manager.gd` receives signal from EventBus or GameManager in connected handler
2. Looks up SFX resource path from `sfx_map`:

| SFX Name | Signal Source | Listener Pattern |
|----------|--------------|------------------|
| `merge_complete` | EventBus `merge_completed` | EventBus connection |
| `customer_happy` | EventBus `customer_fulfilled` | EventBus connection |
| `customer_reject` | EventBus `customer_rejected` | EventBus connection |
| `purchase` | GameManager `blueprint_added` / `upgrade_level_changed` | GameManager signal |
| `dungeon_clear` | EventBus `dungeon_cleared` | EventBus connection |
| `dungeon_fail` | EventBus `dungeon_failed` | EventBus connection |
| `item_place` | Same-scene (board_grid) | Direct call `AudioManager.play_sfx()` |
| `crate_open` | Same-scene (merge_board) | Direct call `AudioManager.play_sfx()` |
| `despawn` | Same-scene (floating_item) | Direct call `AudioManager.play_sfx()` |
| `session_start` | Same-scene (shop_session) | Direct call `AudioManager.play_sfx()` |
| `session_end` | Same-scene (shop_session end_session) | Direct call `AudioManager.play_sfx()` |
| `dungeon_start` | Same-scene (dungeon_controller) | Direct call `AudioManager.play_sfx()` |
| `ko` | Same-scene (combat_engine) | Direct call `AudioManager.play_sfx()` |
| `gold_earn` | GameManager `gold_changed` | GameManager signal (filter for increases only) |
| `session_start` | Same-scene (shop_session._ready()) | Direct call `AudioManager.play_sfx()` |
| `session_end` | EventBus `session_ended` | EventBus connection | ⚠️ Timing: signal fires on summary transition, not the exact "session ends" SFX moment. May need same-scene direct call for precise timing. |
| `dungeon_start` | Same-scene (dungeon_controller._ready()) | Direct call `AudioManager.play_sfx()` |
| `ko` | Same-scene (combat_engine) | Direct call `AudioManager.play_sfx()` |
| `crate_open` | Same-scene (shop_session.try_buy_crate()) | Direct call `AudioManager.play_sfx()` |

3. Calls `play_sfx(sfx_name)` → finds available AudioStreamPlayer from pool → plays stream

**End state:** SFX plays as one-shot, player returns to pool when finished.

### Class Reference

#### AudioManager

**Extends:** Node
**Script:** `autoloads/audio_manager.gd`
**Description:** Manages music crossfade and SFX playback. Connects to EventBus at startup for signal-driven SFX. Same-scene SFX (item_place, session_start, dungeon_start, ko, crate_open) use direct calls to `AudioManager.play_sfx()`.

**Lifecycle:** `_ready()` connects to all relevant EventBus signals and GameManager state-change signals (`blueprint_added`, `upgrade_level_changed`). Preloads audio streams.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `music_player: AudioStreamPlayer` | Node | Current music player |
| `music_fade: Tween` | Tween | Active crossfade tween |
| `sfx_pool: Array[AudioStreamPlayer]` | Array | Pool of 4–6 SFX players for overlapping sounds |
| `sfx_map: Dictionary` | Dictionary | Event/signal name → SFX resource path mapping (covers both EventBus and GameManager signals) |

**Functions:**

| Function | Description |
|----------|-------------|
| `play_music(track: String)` | Crossfades to new music track. No-op if same track. |
| `play_sfx(sfx_name: String)` | Plays a one-shot SFX from an available pool player. |
| `stop_music()` | Fades out current music over 1 second. |
