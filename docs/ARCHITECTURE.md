# Architecture — MergeForge

Last updated: 2026-06-11

---

## Directory Structure

```
res://
├── autoloads/
├── data/
├── board/
├── core/
├── shop/
├── dungeon/
└── resources/
    ├── sprites/
    ├── audio/
    │   ├── music/
    │   └── sfx/
    └── fonts/
```

> **Convention:** All files for a subsystem live together in its folder (scenes, scripts, data schemas). Autoloads stay in `autoloads/`. Shared game data lives in `data/`. Shared assets live in `resources/`. See each subsystem's Files table for exact file placement. Scripts in one subsystem folder must not use `preload` or direct node paths into another subsystem's folder — use autoloads or EventBus for cross-subsystem access.

## Scene Tree Overview

- `Main` (`main.tscn`) — root scene, manages scene transitions by swapping child
  - `CanvasLayer` → `HUD` (`hud.tscn`) — gold display, reputation display (always visible in-game)
  - `SceneContainer` (`Node`) — child swapped by Main on transition
    - `MainMenu` (`main_menu.tscn`)
    - `ShopSession` (`shop_session.tscn`) → instances `MergeBoard` (`merge_board.tscn`) (shop board)
    - `SessionSummary` (`session_summary.tscn`)
    - `PrepPhase` (`prep_phase.tscn`) → TabContainer: Blueprints / Upgrades / Reagents
    - `DungeonRun` (`dungeon_run.tscn`) → instances `MergeBoard` (`merge_board.tscn`) (dungeon board, separate state)
    - `DungeonSummary` (`dungeon_summary.tscn`)

Scene transitions are driven by `main.gd` listening to EventBus signals. Main frees the old scene, instances the new one, and adds it as child of `SceneContainer`.

## Autoloads / Singletons

| Name           | Script               | Responsibility                                                                                                   |
| -------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------- |
| GameManager    | `game_manager.gd`    | Persistent state: gold, reputation, blueprints, reagent inventory, upgrades, shop board state, grid size         |
| EventBus       | `event_bus.gd`       | Cross-scene signal relay (see registry below)                                                                    |
| AudioManager   | `audio_manager.gd`   | Music playback with crossfade, SFX one-shots                                                                     |
| RecipeResolver | `recipe_resolver.gd` | Loads recipe/blueprint/reagent/crate/upgrade JSON data. Filters merge options by blueprint ownership and reagent availability. Provides crate and pricing data for shop/prep. |
| SaveManager    | `save_manager.gd`    | Auto-save/load to single JSON file at checkpoints                                                                |

No autoload uses `class_name` — globally accessible by registration name only (per GDD decision log).

### EventBus Signal Registry

| Signal | Emitted by | Listeners | Purpose |
|--------|-----------|-----------|---------|
| `merge_completed(result_id: String, bonus_gold: int)` | `merge_resolver.gd` | `audio_manager.gd` | A merge produced a result item |
| `customer_fulfilled(order_id: String)` | `shop_session.gd` | `save_manager.gd` | Order delivered to customer |
| `customer_rejected(customer_id: String)` | `shop_session.gd` | `save_manager.gd` | Customer was skipped |
| `session_ended(summary: Dictionary)` | `shop_session.gd` | `main.gd` | 10th customer done, transition to summary |
| `session_summary_dismissed()` | `session_summary.gd` | `main.gd` | Player taps Continue, go to prep |
| `prep_start_session()` | `prep_phase.gd` | `main.gd` | Player starts next shop session |
| `prep_enter_dungeon()` | `prep_phase.gd` | `main.gd` | Player enters dungeon (if unlocked) |
| `dungeon_cleared(rewards: Dictionary)` | `dungeon_controller.gd` | `main.gd`, `save_manager.gd` | Dungeon completed. Rewards: `{cleared: true, gold_reward: int, blueprint_reward: String or null, reputation_change: 25}` |
| `dungeon_failed(summary: Dictionary)` | `dungeon_controller.gd` | `main.gd`, `save_manager.gd` | Dungeon failed. Summary: `{cleared: false, gold_reward: 0, blueprint_reward: null, reputation_change: -20}` |
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
| `reputation_changed(new_points: int)` | Reputation points change | HUD reputation badge |
| `reputation_level_changed(level: String)` | Crossed a threshold ("low"/"mid"/"high") | Prep phase dungeon button, customer generator |
| `blueprint_added(bp_id: String)` | Blueprint unlocked | Prep phase blueprints tab, audio_manager (SFX) |
| `upgrade_added(upgrade_id: String)` | Upgrade purchased | audio_manager (SFX) |
| `reagent_count_changed(id: String, count: int)` | Reagent inventory changes | Prep phase reagent display, merge choice popup |
| `grid_size_changed(cols: int, rows: int)` | Grid upgrade purchased | Active MergeBoard instance |

## Signal Flow Rules

**Rule:** Nodes within the same scene communicate via direct references (`@onready`, passed references, parent methods). Nodes communicating across scene boundaries use EventBus. GameManager emits its own signals for state changes — connect directly, not through EventBus.

**Exceptions:**
- **MergeBoard:** Shared scene instanced by ShopSession and DungeonRun. Owns its own MergeChoicePopup internally. Defaults to GameManager values for grid size, despawn time, and crate discount, but accepts overrides via `setup(config)`. Communicates merge choices via its internal popup. Parent scenes call `board.setup({})` and interact via public methods (`buy_crate()`, `place_drop()`, `get_board_grid()`, `get_staging_area()`).
- **Drag-to-party-portrait (dungeon):** Uses Godot's built-in Control drag-and-drop. BoardCell provides `_get_drag_data`, PartyMember provides `_can_drop_data` / `_drop_data`. PartyMember calls `DungeonController.apply_usable_item()` on successful drop. No custom hit-testing needed — Godot handles cross-scene-tree drop detection.
- **AudioManager:** Listens to EventBus signals for SFX. No script calls `AudioManager.play_sfx()` directly — SFX is fully signal-driven. Music switching is the one exception: `main.gd` calls `AudioManager.play_music()` directly during scene transitions, since only Main knows which scene just loaded. AudioManager also connects directly to GameManager signals (`blueprint_added`, `upgrade_added`) for purchase SFX.

## Key Conventions

- Game data lives in `res://data/` as `.json` files — loaded at startup by the relevant autoload, never at runtime per-frame
- Scene-specific UI lives inside its own scene. Only HUD (gold, reputation badge) is global via CanvasLayer.
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
  - `ko` — member_ko is a same-scene signal (combat_engine → party_member UI), not on EventBus
  - `crate_open` — shop_session.try_buy_crate(), no EventBus signal
- **Resolved SFX paths (AudioManager can connect to existing signal):**
  - `dungeon_clear` / `dungeon_fail` → `dungeon_cleared` / `dungeon_failed` on EventBus
  - `customer_reject` → `customer_rejected` on EventBus
  - `merge_complete` → `merge_completed` on EventBus
  - `customer_happy` → `customer_fulfilled` on EventBus
  - `purchase` → `blueprint_added` / `upgrade_added` on GameManager

## Unresolved / Needs Input

> 📝 Items that require decisions or data before implementation can proceed.
> Remove items from this section once resolved and update the relevant subsystem.

### Post-MVP (Deferred)

- **Demand Forecast / Forecast tab:** The prep phase Forecast tab and CustomerGenerator's `forecast_bias` parameter are deferred to post-MVP. The tab should be removed from the PrepPhase TabContainer for v1.0, or hidden behind a feature flag. Do not build forecast UI or bias logic for MVP.
- **Equipment Durability / Repair mechanic:** Party equipment wears during dungeon raids. The player must maintain item durability during the raid by crafting repair items (usable item type: `repair`). This mechanic is deferred to post-MVP — do not implement `repair` as a usable item effect type for v1.0.
- **Algorithmic Customer Generation:** CustomerGenerator should generate customers algorithmically based on reputation, with weighted item demands (e.g., by gold_value or merge depth). Premium customer tier also deferred. MVP uses a flat, hand-authored customer list.
- **Party Abilities / Healing:** All party members auto-attack only for MVP. No healer ability, no skills, no active party abilities. Usable-item buffs (buff_attack) remain in MVP. Post-MVP: add active abilities, healing, and party/enemy skill system.
- **Dungeon Mid-Exit Penalty:** MVP wipes all partial progress on dungeon exit/fail. Post-MVP: impose a penalty for mid-dungeon exit and implement anti-scumming measures (e.g., gold cost, reputation penalty, cooldown timer).
- **Additional dungeons:** Beyond the first dungeon (Goblin Cave).
- **Gem and Wood material families:** Family keys reserved in data (`"gem"`, `"wood"`). Wood items defined for forward compatibility. Gem items not yet defined.
- **Premium customer tier:** CustomerGenerator only produces Basic and Standard for MVP.
- **Additional reagent types:** Beyond Fire Essence (Ice, Shadow, Holy).
- **Timed events or daily challenges.**
- **Board themes / cosmetics.**
- **Encrypted save file.**

---

## Confirmed for v1.0

### ❗ Usable Item Effects — Confirmed for v1.0 (tune during playtesting)

The GDD lists effect types (heal, buff_attack). Party stats are confirmed (see party.json schema in Dungeon Run subsystem). These are **consumable items** the player crafts and uses during dungeon runs — separate from party abilities (deferred). Define usable items in `items.json` with fields like:

```json
{
  "healing_potion": {
    "name": "Healing Potion",
    "family": "herb",
    "gold_value": 40,
    "dungeon_usable": true,
    "dungeon_use_target": "party-individual",
    "effect": { "type": "heal", "power": 30 }
  },
  "battle_elixir": {
    "name": "Battle Elixir",
    "family": "herb",
    "gold_value": 50,
    "dungeon_usable": true,
    "dungeon_use_target": "party-individual",
    "effect": { "type": "buff_attack", "power": 5, "duration": 10 }
  }
}
```

---

## Subsystem: Core (Main, HUD, Menus)

### Scenes & Scripts

| File | Type | Responsibility |
|------|------|----------------|
| `core/main.tscn` | Scene | Root scene. Manages scene transitions by swapping children of SceneContainer. Owns the CanvasLayer for HUD. |
| `core/main.gd` | Script | Listens to EventBus transition signals, frees old scene, instances new scene, manages music switches. Does NOT own game logic. |
| `core/hud.tscn` | Scene | Persistent overlay: gold label, reputation badge. Child of Main's CanvasLayer. |
| `core/hud.gd` | Script | Connects to GameManager state-change signals, updates gold and reputation display. Does NOT own game state. |
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
| `_transition_to(scene_path: String)` | Frees current scene, instances new scene from path, adds to SceneContainer. |
| `_on_new_game()` | Deletes save, resets GameManager, transitions to PrepPhase. |
| `_on_continue_game()` | Loads save into GameManager, transitions to PrepPhase. |

#### HUD

**Extends:** Control
**Script:** `core/hud.gd`
**Description:** Persistent overlay showing gold balance and reputation display. Always visible during gameplay (shop, dungeon, prep). Updates reactively via GameManager signals.

**Lifecycle:** `_ready()` sets initial text on `@onready` labels from `hud.tscn`, connects to `GameManager.gold_changed` and `GameManager.reputation_changed`.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `_gold_label: Label` | `@onready $HBox/GoldLabel` | Gold amount display |
| `_rep_label: Label` | `@onready $HBox/RepLabel` | Reputation display |

**Functions:**

| Function | Description |
|----------|-------------|
| `_on_gold_changed(new_amount: int)` | Updates gold label text. |
| `_on_reputation_changed(new_points: int)` | Updates reputation label text. |

---

## Subsystem: Merge Board

### Scenes & Scripts

| File                            | Type   | Responsibility                                                                                                                                                                                                                                                                                                         |
| ------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `board/merge_board.tscn`d       | Scene  | Board grid + staging area container + AnimOverlay for merge animations. Instanced by ShopSession and DungeonRun. Holds MergeDetector and MergeResolver as member instances (RefCounted, not child nodes). Owns MergeChoicePopup internally — instantiated and managed in _ready(). Background texture via TextureRect. |
| `board/merge_board.gd`          | Script | Root script for the merge board scene. Receives config Dictionary via `setup()` called by parent, creates BoardGrid/MergeDetector/MergeResolver instances, wires them together, manages staging area, runs merge animations (burst + converge). Does NOT own game logic or state.                                      |
| `board/board_grid.gd`           | Script | Grid data model: placement, removal, swap, discard. Does NOT own merge logic or recipe resolution.                                                                                                                                                                                                                     |
| `board/board_cell.gd`           | Script | Single cell visual + touch drag initiation via `_get_drag_data`. Drop target for board-to-board swaps via `_can_drop_data` / `_drop_data`. Does NOT own item data. Exposes `get_icon_texture()` for merge animations.                                                                                                  |
| `board/floating_item.tscn`      | Scene  | Staging area item with despawn timer. Drag source via `_get_drag_data` (drags to BoardCell). Does NOT own placement logic.                                                                                                                                                                                             |
| `board/merge_choice_popup.tscn` | Scene  | Non-blocking popup with 2–4 choice buttons. Instanced and owned by MergeBoard. Receives options from MergeResolver, emits choice. Does NOT own recipe data.                                                                                                                                                            |
| `board/merge_detector.gd`       | Script | Flood-fill scan for connected groups of 3+ identical items. Stateless. Does NOT resolve merges.                                                                                                                                                                                                                        |
| `board/merge_resolver.gd`       | Script | Processes merge groups: queries RecipeResolver, manages choice popup, triggers merge animation (via MergeBoard), places results, handles chain merges via rescan. Does NOT detect groups.                                                                                                                              |

### Signals

| Signal | Emitted by | Listeners | Via EventBus? | Flows |
|--------|-----------|-----------|---------------|-------|
| `cell_drag_started(from_pos: Vector2i, item: Dictionary)` | `board_cell.gd` | `board_grid.gd` | No | Item Drag |
| `cell_drag_ended(from_pos: Vector2i, to_pos: Vector2i)` | `board_cell.gd` | `board_grid.gd` | No | Item Move, Item Swap, Item Discard |
| `item_placed(item: Dictionary, pos: Vector2i)` | `board_grid.gd` | `merge_detector.gd` (via parent callback) | No | Merge Detection |
| `item_removed(pos: Vector2i)` | `board_grid.gd` | `merge_detector.gd` (via parent callback) | No | Chain Merge |
| `merge_detected(groups: Array)` | `merge_detector.gd` | `merge_resolver.gd` | No | Merge Resolution |
| `merge_completed(result_id: String, bonus_gold: int)` | `merge_resolver.gd` | EventBus | Yes | Merge Resolution |
| `merge_choice_requested(options: Array, callback: Callable)` | `merge_resolver.gd` | `merge_choice_popup.tscn` | No | Merge with Choice |
| `choice_made(item_id: String, is_variant: bool, reagent_id: String)` | `merge_choice_popup.gd` | `merge_resolver.gd` (via callback) | No | Merge with Choice |
| `despawn_timeout()` | `floating_item.gd` | `board_grid.gd` (staging handler) | No | Staging Despawn |
| `item_discarded(pos: Vector2i)` | `board_grid.gd` | internal | No | Item Discard |

> **Note on drag-and-drop:** BoardCell and FloatingItem implement `_get_drag_data()` (drag source). BoardCell implements `_can_drop_data()` / `_drop_data()` (drop target for swaps/placement). PartyMember implements `_can_drop_data()` / `_drop_data()` (drop target for usable items in dungeon). Godot handles hit-testing automatically across the scene tree. Custom signals (`cell_drag_started`, `cell_drag_ended`) may still be used internally by BoardGrid for move/swap logic, but the initial drag detection uses the Godot system.

### Flow Trace: Merge Detection and Resolution

**Trigger:** Player places an item on the board (drag from staging via Godot `_drop_data`, or drag between cells via board-to-board `_drop_data`).

1. FloatingItem or BoardCell `_get_drag_data()` initiates drag with item Dictionary. Drag preview shown with ~50px upward offset for mobile visibility.
2. Player releases over a BoardCell → `_drop_data()` called on target BoardCell → BoardGrid processes placement/swap
3. `board_grid.gd` interprets target: empty cell → place, occupied cell → swap, outside board / over trash bin → discard
4. Grid array updated → `board_grid.gd` calls `merge_detector.gd.scan(grid)`
5. `merge_detector.gd` runs flood-fill from each occupied cell, finds groups of 3+ orthogonally connected identical items → returns array of `MergeGroup` dicts
6. If no groups → flow ends
7. If groups found → first group queued for processing by `merge_resolver.gd`
8. `merge_resolver.gd` resolves the result placement position (`_resolve_result_position()`) — simulates post-removal state to find exact cell where result will go
9. `merge_resolver.gd` calls `merge_board.animate_merge(positions, result_center, callback)` — cells cleared visually, floating icon copies burst 30px outward then converge to result position (0.4s total: 0.15s burst + 0.25s converge)
10. Animation completes → `merge_resolver.gd` calls `board_grid.remove_items(positions)` to consume the group
11. `merge_resolver.gd` calls `RecipeResolver.get_options(item_id)` to get filtered results
12. If 1 option → auto-place floor(count/3) result items (first at `_result_center`, rest at nearby empty cells), refund (count%3) source items at former positions, award bonus gold, emit `merge_completed` via EventBus
13. If 2+ options → set `is_processing = true`, emit `merge_choice_requested(options, callback)` → `merge_choice_popup` shows buttons (non-blocking; combat continues if in dungeon). Merge queue is paused — no new scans run until the player picks an option **or dismisses the popup**. Choice (or dismissal fallback) applies to all result items.
14. Player taps choice → callback fires → `merge_resolver.gd` places floor(count/3) result items, refunds (count%3) source items, awards bonus gold, consumes reagent if variant, emits `merge_completed` via EventBus, sets `is_processing = false`. **Dismissal fallback:** if the popup is closed without a pick (Esc / tap-outside), the popup re-emits `choice_made` with the first option, so the merge resolves identically — the queue can't deadlock, and the merge cannot be safely undone because the source items were already removed in step 10.
15. `merge_resolver.gd` calls `_try_chain()` — rescans grid for new groups formed by result items → if found, go to step 7 with next group (another animation plays)

**End state:** floor(count/3) result items placed on grid, (count%3) source items refunded at former positions, bonus gold added to GameManager, chain merges fully resolved with animations between each, merge SFX played.

### Flow Trace: Staging Area Despawn

**Trigger:** FloatingItem's internal Timer reaches 0.

1. `floating_item.gd` timer expires → emits `despawn_timeout()`
2. `board_grid.gd` removes the floating item from staging area, frees the node
3. Item is permanently lost (no EventBus signal for MVP)

**End state:** Item removed from staging, despawn SFX played. Item is permanently lost.

### Flow Trace: Item Discard (Drag Off Board)

**Trigger:** Player drags a grid item and releases touch outside the board area.

1. `board_cell.gd` detects touch release outside board bounds → emits `cell_drag_ended(from, invalid_target)`
2. `board_grid.gd` recognizes invalid target → removes item from grid array, frees cell visual, emits `item_removed(pos)`
3. Item is permanently lost

**End state:** Item removed from board. No SFX (discard is silent per GDD).

### Class Reference

#### MergeBoard

**Extends:** Control
**Script:** `board/merge_board.gd`
**Description:** Root script for the merge board scene. Owns MergeChoicePopup, MergeDetector, and MergeResolver. Provides public API for parent scenes: `setup()`, `buy_crate()`, `place_drop()`, `get_board_grid()`, `get_staging_area()`. Defaults to GameManager values but accepts overrides via setup config. Runs merge animations via AnimOverlay child node (burst + converge, configurable via constants).

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

**Used by:** Shop Session, Dungeon Run, Economy & Progression (PrepPhase)

#### BoardGrid
**Script:** `board/board_grid.gd`
**Description:** Manages the grid data model and item placement/removal/swap. Creates BoardCell nodes dynamically based on grid dimensions. Handles staging area for floating items. BoardCells are both drag sources and drop targets via Godot's built-in drag-and-drop.

**Lifecycle:** `setup(config)` called externally by MergeBoard — reads grid dimensions from config dict, creates BoardCell children, initializes empty grid array.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `grid: Array[Array]` | 2D array of Dictionary or null | Live board state. Each cell is item dict or null. |
| `grid_cols: int` | int | Column count (5 or 6) |
| `grid_rows: int` | int | Row count (5) |
| `despawn_time: float` | float | Seconds before staging items despawn (from GameManager) |

**Signals:**

| Signal | Description |
|--------|-------------|
| `item_placed(item: Dictionary, pos: Vector2i)` | Emitted when an item lands on the grid. merge_detector listens via parent. |
| `item_removed(pos: Vector2i)` | Emitted when an item is removed (merge consume, discard). |

**Functions:**

| Function | Description |
|----------|-------------|
| `place_item(item: Dictionary, pos: Vector2i) -> bool` | Places item at pos. Returns false if occupied. Emits `item_placed`. |
| `remove_items(positions: Array[Vector2i])` | Removes items at given positions. Emits `item_removed` for each. |
| `swap_items(pos_a: Vector2i, pos_b: Vector2i)` | Swaps items at two positions. |
| `discard_item(pos: Vector2i)` | Removes item at pos permanently. |
| `find_safe_cell(item_id: String) -> Vector2i` | Returns an empty cell where placing this item would NOT create a group of 3+ orthogonally connected identical items. Returns `Vector2i(-1, -1)` if no safe cell exists. |
| `place_or_stage(item: Dictionary) -> bool` | Merge-safe placement: calls `find_safe_cell(item.item_id)`. If found, places on board directly (returns true). If not, adds to staging area (returns false). Used by crate opening and enemy drops — not player drag placement. |
| `count_items_on_board(item_id: String) -> int` | Counts how many of a given item are on the grid. Used by order fulfillment. |
| `remove_items_by_id(item_id: String, count: int)` | Removes N items matching item_id. Used by order fulfillment. |
| `clear_board()` | Removes all items. Used for dungeon cleanup. |
| `get_board_state() -> Array` | Serializes grid for save/load. Returns array of {col, row, item} dicts. |
| `load_board_state(state: Array)` | Restores grid from save data. Creates BoardCell visuals. |

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
**Description:** Processes merge groups one at a time. For each group, triggers a merge animation (burst outward + converge inward via MergeBoard), then produces floor(count/3) result items and refunds count%3 source items. Queries RecipeResolver for options, manages the choice popup, places results at the pre-resolved result position, handles chain merges via rescan. When a choice popup is open, the merge queue is blocked — no new detection scans run and no further groups are processed until the player picks an option or dismisses the popup (dismissal resolves to the first option; see MergeChoicePopup). This keeps things simple: one popup at a time, no stacking, and the queue can never deadlock on an unanswered popup. The choice applies to all result items in the group. Held as a member instance by MergeBoard, not added to the scene tree.

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

**Functions:**

| Function | Description |
|----------|-------------|
| `process_next()` | Pops next group from queue, resolves result position, triggers merge animation. |
| `_on_animation_done()` | Callback after animation: removes items from grid, handles options (auto-pick or popup). |
| `_try_chain()` | Rescans board grid when queue empties; enqueues new groups for chain merges. |
| `_resolve_result_position() -> Vector2i` | Calculates actual result placement cell (simulates post-removal state). |
| `calculate_center_of_mass(positions: Array[Vector2i]) -> Vector2i` | Returns the center cell of a merge group (average x/y, floored). |
| `calculate_bonus_gold(count: int, item_value: int) -> int` | `(count - 3) * floor(item_value * 0.5)` |
| `_spawn_results(result_data: Dictionary, count: int)` | Places count result items: first at `_result_center`, rest at nearest empty cells. |
| `_refund_source_items(source_data: Dictionary, count: int)` | Refunds count source items at former group positions. |
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
| `cell_drag_ended(from_pos: Vector2i, to_pos: Vector2i)` | Drag released. board_grid uses to_pos to determine place/swap/discard. |

**Functions:**

| Function                                                      | Description                                                          |
| ------------------------------------------------------------- | -------------------------------------------------------------------- |
| `set_item(item: Dictionary)`                                  | Updates visual to show item icon. Stores item data.                  |
| `clear_item()`                                                | Removes item visual. Sets item to null.                              |
| `_get_drag_data(at_position: Vector2) -> Variant`             | Returns item Dictionary. Sets drag preview with ~50px upward offset. |
| `_can_drop_data(at_position: Vector2, data: Variant) -> bool` | Returns true if data contains valid item dict.                       |
| `_drop_data(at_position: Vector2, data: Variant)`             | Receives dropped item, notifies BoardGrid via cell_drag_ended.       |

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

## Subsystem: Recipe & Blueprint System

### Scenes & Scripts

| File | Type | Responsibility |
|------|------|----------------|
| `autoloads/recipe_resolver.gd` | Autoload | Loads and caches recipe, blueprint, reagent combo, crate, upgrade, and reagent data. Provides synchronous lookups filtered by player progress. |

### Data Schema: items.json

| Field | Type | Description |
|-------|------|-------------|
| `item_id` | `String` | Unique identifier (key). e.g. "iron_ore", "sword" |
| `name` | `String` | Display name |
| `family` | `String` | Item family for grouping. e.g. "metal", "herb", "gem", "wood" |
| `gold_value` | `int` | Base gold value (used for bonus gold calc and selling) |
| `dungeon_usable` | `bool` | Whether this item can be used during dungeon runs |
| `dungeon_use_target` | `String` or null | If dungeon_usable: `"party-individual"`, `"party-all"`, `"enemy-individual"`, or `"enemy-all"`. Null if not dungeon_usable. |
| `effect` | `Dictionary` or null | If dungeon_usable: `{type, power, duration?}`. Null if not dungeon_usable. |
| `icon` | `String` | Resource path to icon texture |

### Data Schema: recipes.json

| Field | Type | Description |
|-------|------|-------------|
| `item_id` | `String` | Source item_id (key). The item being merged. |
| `results` | `Array[Dictionary]` | Array of possible outcomes. Each: `{result_id: String, blueprint_required: String or null}` |
| `count_required` | `int` | Number of input items needed for this recipe (always 3 for MVP) |

### Data Schema: blueprints.json

| Field | Type | Description |
|-------|------|-------------|
| `bp_id` | `String` | Unique blueprint identifier (key) |
| `name` | `String` | Display name |
| `cost` | `int` | Gold cost to purchase |
| `dependencies` | `Array[String]` | Prerequisite bp_ids that must be unlocked first |
| `unlocks_item` | `String` | item_id this blueprint makes available in merge results |

### Data Schema: reagent_combos.json

| Field | Type | Description |
|-------|------|-------------|
| `base_item_id` | `String` | Item that this reagent combo applies to |
| `reagent_id` | `String` | Reagent consumed to produce this variant |
| `variant_item_id` | `String` | Resulting variant item |
| `blueprint_required` | `String` or null | bp_id needed to unlock this combo, or null if always available |

### Signals

RecipeResolver has no signals — it is queried synchronously by MergeResolver, ShopSession, and PrepPhase.

### Flow Trace: Resolve Merge Options

**Trigger:** MergeResolver processes a merge group and needs available results.

1. `merge_resolver.gd` calls `RecipeResolver.get_options(item_id)`
2. `recipe_resolver.gd` looks up `item_id` in recipes data → gets raw result list
3. For each result, checks blueprint gate:
   - Blueprint required AND in `GameManager.unlocked_blueprints` → include
   - Blueprint required AND NOT unlocked → exclude
   - No blueprint required → always include
4. Returns filtered options to caller

**End state:** Caller has the list of available options to display or auto-resolve.

### Flow Trace: Resolve Reagent Variants

**Trigger:** MergeResolver resolves a merge and checks `reagent_combos.json` for the result item.

1. `merge_resolver.gd` calls `RecipeResolver.get_variant_options(base_item_id)`
2. `recipe_resolver.gd` looks up `reagent_combos.json` for entries matching `base_item_id`
3. For each combo:
   - Check required blueprint is in `GameManager.unlocked_blueprints`
   - Check `GameManager.reagent_inventory[reagent_id] >= 1`
   - Both true → add variant to options
4. Returns variant options (may be empty)

**End state:** Variant options (if any) added to the merge choice popup alongside base results.

### Class Reference

#### RecipeResolver

**Extends:** Node
**Script:** `autoloads/recipe_resolver.gd`
**Description:** Read-only data cache for recipes, blueprints, reagent combos, and items. All filtering is done at query time based on current GameManager state.

**Lifecycle:** `_ready()` loads `items.json`, `recipes.json`, `blueprints.json`, `reagent_combos.json`, `crates.json`, `upgrades.json`, `reagents.json`, `enemies.json`, `dungeons.json`, and `party.json` from `res://data/` into Dictionary members.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `items: Dictionary` | Dictionary | item_id → item data |
| `recipes: Dictionary` | Dictionary | item_id → recipe data (results array, count_required) |
| `blueprints: Dictionary` | Dictionary | bp_id → blueprint data (cost, dependencies, unlocks_item) |
| `reagent_combos: Dictionary` | Dictionary | base_item_id → array of variant combos |
| `crates: Dictionary` | Dictionary | crate_id → crate data (name, cost, item_count, pool) |
| `upgrades: Dictionary` | Dictionary | upgrade_id → upgrade data (name, cost, effect_type, effect_value) |
| `reagents: Dictionary` | Dictionary | reagent_id → reagent data (name, cost, icon, description) |
| `enemies: Dictionary` | Dictionary | enemy_id → enemy data (name, max_hp, attack, drop_count, drop_pool, sprite) |
| `dungeons: Dictionary` | Dictionary | dungeon_id → dungeon data (name, walk_speed, encounter_points, encounters, gold_reward, blueprint_reward) |
| `party: Dictionary` | Dictionary | party data including party_members keyed by role |

**Functions:**

| Function | Description |
|----------|-------------|
| `get_options(item_id: String) -> Array[Dictionary]` | Returns available merge results, filtered by blueprint ownership. |
| `get_variant_options(base_item_id: String) -> Array[Dictionary]` | Returns reagent variant options for the given item, filtered by blueprint + reagent inventory. Returns empty array if no combos exist for this item. |
| `get_item_data(item_id: String) -> Dictionary` | Returns full item definition from items.json. |
| `get_blueprint_cost(bp_id: String) -> int` | Returns gold cost of a blueprint. |
| `get_blueprint_dependencies(bp_id: String) -> Array[String]` | Returns prerequisite blueprint IDs. |
| `has_blueprint(bp_id: String) -> bool` | Checks `GameManager.unlocked_blueprints`. |
| `get_crate_data(crate_id: String) -> Dictionary` | Returns crate definition (name, cost, item_count, pool). Used by ShopSession. |
| `get_all_crate_ids() -> Array[String]` | Returns all crate IDs for populating CratePanel buttons. |
| `get_upgrade_data(upgrade_id: String) -> Dictionary` | Returns upgrade definition. |
| `get_reagent_data(reagent_id: String) -> Dictionary` | Returns reagent definition (name, cost, icon, description). |
| `roll_weighted_pool(pool: Array, count: Dictionary) -> Array[Dictionary]` | Static method. Shared weighted random selection for crate and drop pools. |

---

## Subsystem: Shop Session

### Scenes & Scripts

| File | Type | Responsibility |
|------|------|----------------|
| `shop/shop_session.tscn` | Scene | Top-level shop session. Layout: `HBoxContainer [CustomerDisplay | MergeBoard | CratePanel]`. CustomerDisplay and CratePanel are sub-components within this scene (no separate scene files). CratePanel is a VBoxContainer on the right with crate buy buttons populated dynamically from `crates.json` and a discard trash bin below. |
| `shop/shop_session.gd` | Script | Orchestrates 10-customer session loop: customer display, order fulfillment, session end, crate purchasing. Does NOT own board logic or merge resolution. |
| `shop/customer_generator.gd` | Script | Generates 10 customers at session start. For MVP, uses a flat, hand-authored customer list (same order every session). Loads from `data/customers.json`. Does NOT own customer display. |
| `shop/order_card.tscn` | Scene | One order display: item icon, quantity, reward. Tappable to fulfill. |
| `shop/session_summary.tscn` | Scene | End-of-session summary. Animated gold counter, items sold, fulfilled/rejected counts, customer portraits. |

### Data Schema: customers.json

| Field | Type | Description |
|-------|------|-------------|
| `customers` | `Array[Dictionary]` | Ordered list of 10 customers. Each: `{id: String, portrait_id: String, orders: Array[Dictionary]}` |
| `customers[].id` | `String` | Unique customer identifier |
| `customers[].portrait_id` | `String` | Portrait resource reference |
| `customers[].orders` | `Array[Dictionary]` | 1–3 possible orders. Each: `{item_id: String, quantity: int, gold_reward: int}` |

For MVP, this file is a static, hand-authored list. Post-MVP: replace with algorithmic generation based on reputation tier.

### Data Schema: crates.json

| Field | Type | Description |
|-------|------|-------------|
| `crate_id` | `String` | Unique identifier (key). e.g. "basic", "themed_metal", "tier2" |
| `name` | `String` | Display name shown on the buy button |
| `cost` | `int` | Gold price (modified by Crate Discount upgrade: ×0.8) |
| `item_count` | `Dictionary` | `{min: int, max: int}` number of items generated per crate |
| `pool` | `Array[Dictionary]` | Weighted item pool: `{item_id: String, weight: int or float}`. Weights are relative probabilities — any positive number, no need to sum to 100. |

Crate definitions are fully data-driven. Whatever crates exist in this file are rendered as buy buttons in the shop's CratePanel. No hardcoded crate types. Adding or removing a crate only requires editing this file.

**Crate generation algorithm:** For each item slot (rolled `item_count` times, independently):
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

1. `shop_session.gd._ready()` calls `customer_generator.generate_customers()` → generates 10 customers, each with 1–3 possible orders
2. `shop_session.gd` displays first customer: portrait on left, 1–3 order cards stacked vertically on right, silhouette of remaining customers behind
3. Player crafts items on the merge board (standard merge board flow) or buys crates from the CratePanel on the right (crate button → `shop_session.try_buy_crate(crate_id)` → picks random items from the crate's weighted pool, places on board via merge-safe placement, staging area as fallback). Available crates are loaded from `crates.json` — no hardcoded crate types.
4. Player taps one of the displayed `order_card.gd` options → emits `order_tapped(index)` → `shop_session.gd.try_fulfill_order(index)`. Only one order can be fulfilled per customer — the chosen order is fulfilled, all other orders for that customer are discarded.
5. If board has required items for the chosen order: remove items, add gold + reputation to GameManager, emit `customer_fulfilled` via EventBus, discard remaining orders, advance customer
6. If board lacks items for the chosen order: flash order card red, no action, other orders remain available to tap
7. Player taps reject → `GameManager.add_reputation(-2)`, emit `customer_rejected` via EventBus, advance customer
8. After customer 10 → compile summary data, emit `session_ended(summary)` via EventBus → Main transitions to `session_summary.tscn`

**End state:** GameManager updated with gold/reputation changes, SessionSummary displayed, auto-save triggered.

### Flow Trace: Order Fulfillment

**Trigger:** Player taps one order card from the current customer's 1–3 displayed orders.

1. `order_card.gd` emits `order_tapped(order_index)` → `shop_session.gd.try_fulfill_order(index)`
2. `shop_session.gd` reads the chosen order's requirements: `{item_id: quantity}`
3. Calls `board.count_items_on_board(item_id)` for each required item
4. If all requirements met: `board.remove_items_by_id(item_id, qty)` for each, `GameManager.add_gold(reward)`, `GameManager.add_reputation(10)`, emit `customer_fulfilled`, discard all other unfulfilled orders for this customer
5. Advance to next customer (or end session if last)

**End state:** Chosen order fulfilled, remaining orders discarded, items removed from board, gold and reputation added, customer replaced.

### Class Reference

#### ShopSession

**Extends:** Control
**Script:** `shop/shop_session.gd`
**Description:** Orchestrates the 10-customer shop session. Each customer presents 1–3 order options; the player picks one to fulfill (others are discarded). Manages customer queue state and delegates to CustomerGenerator, BoardGrid, and OrderCards.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `customers: Array[Dictionary]` | Array | Generated customer data for this session (10 entries) |
| `current_index: int` | int | Current customer index (0–9) |
| `board: Control (MergeBoard instance)` | Control | Reference to instanced merge board |
| `summary_data: Dictionary` | Dictionary | Accumulated stats: gold_earned, items_sold, fulfilled, rejected, portraits |

**Functions:**

| Function | Description |
|----------|-------------|
| `advance_customer()` | Displays next customer. If index >= 10, ends session. |
| `try_fulfill_order(order_index: int)` | Checks board for items for the chosen order. If met: fulfills, discards remaining orders, advances customer. If not: flashes red. |
| `reject_customer()` | Applies -2 reputation penalty, advances. |
| `try_buy_crate(crate_id: String) -> bool` | Delegates to `board.buy_crate(crate_id)`. MergeBoard handles discount, pool rolling, and merge-safe placement internally. |

#### CustomerGenerator

**Extends:** RefCounted
**Script:** `shop/customer_generator.gd`
**Description:** Generates a list of 10 customers. For MVP, uses a flat, hand-authored customer list (same order every session). Each customer has 1–3 possible orders. Reputation-based scaling deferred to post-MVP.

**Functions:**

| Function | Description |
|----------|-------------|
| `generate_customers() -> Array[Dictionary]` | Returns 10 customer dicts. Each: `{id, portrait_id, orders: [{item_id, quantity, gold_reward}]}`. |

#### OrderCard

**Extends:** Control
**Script:** `shop/order_card.gd`
**Description:** Displays a single order: item icon, quantity needed, gold reward. Emits signal when tapped.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `order_data: Dictionary` | Dictionary | `{item_id, quantity, gold_reward}` |

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
| `dungeon/dungeon_run.tscn` | Scene | Top-level dungeon scene. Owns party display, enemy display, merge board, combat area, encounter banner (simple label showing encounter number, shown/hidden by dungeon_controller). |
| `dungeon/dungeon_controller.gd` | Script | Orchestrates dungeon flow: walking → encounter → combat → walking → end. Reads dungeon/enemy/party data from RecipeResolver (loaded at startup). Does NOT own combat math. |
| `dungeon/combat_engine.gd` | Script | 1-second combat ticks. Damage distribution, HP tracking, knockout detection, buff timers. Does NOT own dungeon flow. |
| `dungeon/drop_manager.gd` | Script | Generates enemy drops, places on dungeon board via merge-safe placement. Does NOT own board logic. |
| `dungeon/party_member.tscn` | Scene | Visual: chibi character + HP bar + buff indicators. Accepts drag-drops of usable items. |
| `dungeon/enemy_display.tscn` | Scene | Visual: enemy sprite + HP bar. No interaction. |
| `dungeon/dungeon_summary.tscn` | Scene | End-of-dungeon results (cleared or failed). |

### Data Schema: dungeons.json

| Field | Type | Description |
|-------|------|-------------|
| `dungeon_id` | `String` | Unique identifier (key) |
| `name` | `String` | Display name |
| `reputation_required` | `int` | Minimum reputation to unlock |
| `walk_speed` | `float` | Progress per second while walking (default 0.02) |
| `encounter_points` | `Array[float]` | Progress thresholds triggering encounters (e.g. [0.2, 0.5, 0.8]) |
| `encounters` | `Array[Array[Dictionary]]` | One enemy group per encounter point. Each enemy: `{enemy_id, count}` |
| `gold_reward` | `int` | Gold awarded on clear |
| `blueprint_reward` | `String` or null | bp_id awarded on clear, or null. Goblin Cave: null (no blueprint reward). |

**Goblin Cave (MVP dungeon) encounter data:**

```json
{
  "dungeon_id": "goblin_cave",
  "name": "Goblin Cave",
  "reputation_required": 150,
  "walk_speed": 0.02,
  "encounter_points": [0.2, 0.5, 0.8],
  "encounters": [
    [{"enemy_id": "slime", "count": 2}],
    [{"enemy_id": "slime", "count": 1}, {"enemy_id": "goblin", "count": 1}],
    [{"enemy_id": "goblin", "count": 2}]
  ],
  "gold_reward": 80,
  "blueprint_reward": null
}
```

### Data Schema: enemies.json

| Field | Type | Description |
|-------|------|-------------|
| `enemy_id` | `String` | Unique identifier (key) |
| `name` | `String` | Display name |
| `max_hp` | `int` | Base HP |
| `attack` | `int` | Damage dealt per tick (distributed across targets) |
| `drop_count` | `Dictionary` | `{min: int, max: int}` number of drops on death |
| `drop_pool` | `Array[Dictionary]` | Weighted item pool: `{item_id: String, weight: int or float}`. Same structure and algorithm as crate pools. |
| `sprite` | `String` | Resource path to sprite texture |

**Drop generation algorithm:** Same as crate generation — for each drop slot (rolled `drop_count` times, independently):
1. Sum all weights in the pool
2. Generate a random float in `[0, sum)`
3. Iterate items, accumulating weights — the item whose cumulative range contains the random number is selected
4. Each roll is independent (same item can drop multiple times from one enemy)

**MVP enemy data:**

```json
{
  "slime": {
    "name": "Slime",
    "max_hp": 30,
    "attack": 5,
    "drop_count": {"min": 1, "max": 2},
    "drop_pool": [
      {"item_id": "iron_ore", "weight": 3},
      {"item_id": "herb_leaf", "weight": 2}
    ],
    "sprite": "res://resources/sprites/enemies/slime.png"
  },
  "goblin": {
    "name": "Goblin",
    "max_hp": 50,
    "attack": 8,
    "drop_count": {"min": 2, "max": 3},
    "drop_pool": [
      {"item_id": "iron_ore", "weight": 2},
      {"item_id": "iron_ingot", "weight": 1},
      {"item_id": "herb_leaf", "weight": 2}
    ],
    "sprite": "res://resources/sprites/enemies/goblin.png"
  }
}
```

### Data Schema: party.json

| Field | Type | Description |
|-------|------|-------------|
| `party_members` | `Dictionary` | Keyed by role (`"fighter"`, `"mage"`, `"healer"`). Each value is a Dictionary with the fields below. |
| `party_members.*.name` | `String` | Display name |
| `party_members.*.sprite` | `String` | Resource path to chibi sprite texture |
| `party_members.*.max_hp` | `int` | Base HP |
| `party_members.*.attack` | `int` | Damage dealt per tick (distributed across alive enemies) |

**MVP party data:**

```json
{
  "fighter": {
    "name": "Fighter",
    "sprite": "res://resources/sprites/party/fighter.png",
    "max_hp": 90,
    "attack": 14
  },
  "mage": {
    "name": "Mage",
    "sprite": "res://resources/sprites/party/mage.png",
    "max_hp": 50,
    "attack": 18
  },
  "healer": {
    "name": "Healer",
    "sprite": "res://resources/sprites/party/healer.png",
    "max_hp": 60,
    "attack": 5
  }
}
```

No special abilities for MVP — auto-attack only.

### Signals

| Signal | Emitted by | Listeners | Via EventBus? | Flows |
|--------|-----------|-----------|---------------|-------|
| `dungeon_cleared(rewards: Dictionary)` | `dungeon_controller.gd` | `main.gd`, `save_manager.gd` | Yes | Dungeon Win |
| `dungeon_failed(summary: Dictionary)` | `dungeon_controller.gd` | `main.gd`, `save_manager.gd` | Yes | Dungeon Fail |
| `dungeon_summary_dismissed()` | `dungeon_summary.gd` | `main.gd` | Yes | Summary → Prep |
| `encounter_ended()` | `combat_engine.gd` | `dungeon_controller.gd` | No | Combat End |
| `enemy_died(enemy_index: int)` | `combat_engine.gd` | `drop_manager.gd` | No | Enemy Death |
| `member_ko(member_index: int)` | `combat_engine.gd` | `dungeon_controller.gd`, party_member UI | No | Party KO |
| `party_wiped()` | `combat_engine.gd` | `dungeon_controller.gd` | No | Dungeon Fail |

### Flow Trace: Dungeon Run (Full Loop)

**Trigger:** Main instances `dungeon_run.tscn` from prep phase.

1. `dungeon_controller.gd._ready()`: reads dungeon data from RecipeResolver. Progress = 0.0, initialize 3 party members with base stats (from `party.json`), call `PartyMember.setup(data)` on each to load sprites and store stats, create empty dungeon board, start walk timer (walk speed from dungeon definition — default 0.02 progress/sec, configurable per dungeon)
2. Walk timer ticks → progress bar updates. Player can rearrange dungeon board during walk. Progress only advances while walking.
3. Progress reaches encounter threshold (e.g. 0.2) → walk timer **stops** → `dungeon_controller.start_encounter(encounter_data[0])`
4. Dungeon controller spawns enemy display nodes (calling `EnemyDisplay.setup(enemy_data)` on each to load sprites), then calls `combat_engine.start_combat(enemies)` → initializes enemy array, starts 1-second tick timer
5. **Combat tick** (every 1 second):
   a. Each active party member: deal `floor(attack / alive_enemy_count)` damage to each alive enemy, min 1
   b. Each alive enemy: deal `floor(attack / active_member_count)` damage to each active member, min 1
   c. Check enemy deaths → emit `enemy_died(index)` → dungeon_controller looks up enemy_data from combat_engine → `drop_manager.spawn_drops(enemy_data)` returns drops array → `drop_manager.add_drops_to_board(drops, board)` creates FloatingItems
   d. Check member KO (HP ≤ 0) → emit `member_ko(index)` → update portrait visual
   e. If all enemies dead → emit `encounter_ended()` → resume walking
   f. If all members KO → emit `party_wiped()` → go to step 9 (fail)
   g. Tick all buffs: reduce duration, remove expired, update buff indicators
6. During combat, player merges on the dungeon board (standard merge flow, combat continues)
7. During combat, player drags usable items to party member portraits → `dungeon_controller.apply_usable_item(index, item)` → `combat_engine.apply_effect(index, effect)`
8. All enemies dead → `encounter_ended()` → walk timer **resumes** → encounters at next threshold (0.5, 0.8) → repeat steps 3–7
9. Progress reaches 1.0 AND all encounters cleared → calculate rewards (gold + blueprint + 25 reputation) → emit `dungeon_cleared(rewards)` via EventBus → Main transitions to DungeonSummary (cleared)
10. OR all members KO → apply -20 reputation penalty → emit `dungeon_failed({cleared: false, gold_reward: 0, blueprint_reward: null, reputation_change: -20})` via EventBus → Main transitions to DungeonSummary (failed)

**End state (cleared):** Rewards applied to GameManager, dungeon board discarded, auto-save triggered.
**End state (failed):** -20 reputation penalty applied, dungeon board items lost, shop board unaffected, auto-save triggered.

### Flow Trace: Usable Item Applied to Party Member

**Trigger:** Player drags a usable item from the dungeon board to a party member portrait (via Godot `_drop_data`).

1. BoardCell `_get_drag_data()` initiates drag with item Dictionary. Drag preview shown with ~50px upward offset.
2. Player releases over a PartyMember → `_can_drop_data()` checks if item is a usable type (heal, buff_attack) → returns true
3. PartyMember `_drop_data()` receives item → calls `dungeon_controller.apply_usable_item(member_index, item_data)`
4. `dungeon_controller.gd` calls `board.remove_items([source_pos])`, then `combat_engine.apply_effect(member_index, effect_dict)`
5. `combat_engine.gd` applies: heal restores HP, buff adds entry to `active_buffs` with duration
6. Party member HP bar and buff indicators update

**End state:** Item consumed from dungeon board, effect applied to party member, combat continues.

### Flow Trace: Enemy Drop Placement

**Trigger:** An enemy dies during combat.

1. `combat_engine.gd` detects enemy HP ≤ 0 → emits `enemy_died(enemy_index)`
2. `drop_manager.gd.spawn_drops(enemy_data)` → rolls drop count (1–2 or 2–3 from enemy definition), picks random items from enemy's drop pool
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
| `progress: float` | float | 0.0 to 1.0 dungeon progress |
| `walk_speed: float` | float | Progress gained per second while walking (from dungeon definition) |
| `encounter_points: Array[float]` | Array | Progress thresholds where encounters trigger (e.g. [0.2, 0.5, 0.8], from dungeon definition) |
| `encounters_cleared: int` | int | Completed encounter count |
| `combat_engine: CombatEngine` | Node | Reference to combat engine child |
| `board: Control (MergeBoard instance)` | Control | Dungeon board instance |
| `drop_mgr: Node (DropManager)` | Node | Reference to drop manager |
| `party_data: Array[Dictionary]` | Array | 3 party member state dicts |
| `party_members: Array[PartyMember]` | Array | References to the 3 PartyMember nodes (for setup and HP/buff updates) |
| `enemy_displays: Array[EnemyDisplay]` | Array | Currently spawned enemy display nodes (cleared after each encounter) |

**Functions:**

| Function | Description |
|----------|-------------|
| `start_encounter(encounter_idx: int)` | Looks up encounter data by index, spawns EnemyDisplay nodes, calls `setup(enemy_data)` on each, starts combat via combat_engine, pauses walk timer. |
| `end_encounter()` | Frees all EnemyDisplay nodes, clears `enemy_displays` array, resumes walk timer. |
| `apply_usable_item(member_index: int, item_data: Dictionary)` | Routes item effect to combat_engine, removes item from board. |
| `end_dungeon_cleared()` | Calculates rewards (gold, blueprint, +25 reputation), applies to GameManager, emits `dungeon_cleared`. |
| `end_dungeon_failed()` | Applies -20 reputation penalty, emits `dungeon_failed({cleared: false, gold_reward: 0, blueprint_reward: null, reputation_change: -20})`. |

#### CombatEngine

**Extends:** Node
**Script:** `dungeon/combat_engine.gd`
**Description:** Manages auto-combat: 1-second tick timer, damage distribution, HP tracking, buff management, knockout and wipe detection.

**Lifecycle:** Creates and manages its own Timer node (1-second interval). Started by start_combat(), stopped by stop_combat().

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `party_members: Array[Dictionary]` | Array | Each: `{max_hp, current_hp, attack, active_buffs: [{effect, power, duration}]}` |
| `enemies: Array[Dictionary]` | Array | Each: `{max_hp, current_hp, attack, alive: bool}` |
| `tick_timer: Timer` | Timer | 1-second combat tick |

**Signals:**

| Signal | Description |
|--------|-------------|
| `enemy_died(enemy_index: int)` | Enemy HP reached 0. drop_manager listens. |
| `member_ko(member_index: int)` | Party member HP reached 0. dungeon_controller and portrait UI listen. |
| `party_wiped()` | All 3 members KO. dungeon_controller listens. |
| `encounter_ended()` | All enemies dead. dungeon_controller listens. |

**Functions:**

| Function | Description |
|----------|-------------|
| `start_combat(enemy_definitions: Array[Dictionary])` | Initializes enemy array, starts tick timer. |
| `stop_combat()` | Stops tick timer. |
| `tick()` | One combat tick: distribute damage, check deaths/KOs, tick buffs. Called by timer timeout. |
| `apply_effect(member_index: int, effect: Dictionary)` | Applies heal (restore HP) or buff (add to active_buffs). |
| `get_active_member_count() -> int` | Returns count of non-KO members. |
| `get_alive_enemy_count() -> int` | Returns count of alive enemies. |
| `get_enemy_data(index: int) -> Dictionary` | Returns enemy definition at index. Used by DropManager after `enemy_died` signal. |

#### DropManager

**Extends:** Node
**Script:** `dungeon/drop_manager.gd`
**Description:** Generates item drops from dead enemies and places them on the dungeon board. Calls `board.place_drop()` which handles merge-safe placement internally.

**Functions:**

| Function | Description |
|----------|-------------|
| `spawn_drops(enemy_data: Dictionary) -> Array[Dictionary]` | Rolls drop count and items from enemy's drop pool. |
| `add_drops_to_board(drops: Array[Dictionary], board: Node)` | Calls `board.place_drop(drop_data)` for each drop. MergeBoard handles merge-safe placement internally (board first, staging fallback). |

#### CombatUnit

**Extends:** VBoxContainer
**Script:** `dungeon/combat_unit.gd`
**Scene:** `dungeon/combat_unit.tscn`
**Description:** Reusable sub-scene with a sprite TextureRect and HP bar ProgressBar. Instanced by PartyMember and EnemyDisplay. Handles HP bar color coding (green >60%, yellow 30-60%, red <30%).

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `sprite: TextureRect` | `@onready $Sprite` | 80×80 item sprite |
| `hp_bar: ProgressBar` | `@onready $HPBar` | 80×12 HP bar with color coding |

**Functions:**

| Function | Description |
|----------|-------------|
| `update_hp(current: int, max_hp: int)` | Sets HP bar value and color based on ratio. |

#### PartyMember

**Extends:** PanelContainer
**Script:** `dungeon/party_member.gd`
**Scene:** `dungeon/party_member.tscn` (instances CombatUnit + BuffLabel)
**Description:** Visual representation of a party member: chibi sprite, HP bar, buff icons. Drop target for usable items via Godot's `_can_drop_data` / `_drop_data` — player drags from BoardCell to here.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `member_index: int` | int | 0, 1, or 2 — identifies this member in combat engine |
| `_unit` | `@onready $VBox/Unit` | CombatUnit sub-scene instance (sprite + HP bar) |
| `_buff_label: Label` | `@onready $VBox/BuffLabel` | Buff text display |

**Functions:**

| Function | Description |
|----------|-------------|
| `setup(data: Dictionary)` | Loads sprite texture from `data.sprite` path, stores member data. Called by DungeonController at encounter start. |
| `update_hp(current: int, max_hp: int)` | Delegates to CombatUnit.update_hp(). |
| `update_buffs(buffs: Array[Dictionary])` | Updates buff indicator text. |
| `set_ko()` | Plays KO visual (grayscale modulate), disables drop target. |

**Functions (drag-and-drop):**

| Function | Description |
|----------|-------------|
| `_can_drop_data(at_position: Vector2, data: Variant) -> bool` | Returns true if data has `dungeon_usable == true` and `dungeon_use_target` contains `"party"` (party-individual or party-all). |
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
| `play_death()` | Plays death animation, then queues free. |

#### DungeonSummary

**Extends:** Control
**Script:** `dungeon/dungeon_summary.gd`
**Description:** Displays dungeon results. Two modes: cleared (rewards) or failed (penalty).

**Properties:**

| Property | Type | Description |
|----------|------|-------------|

**Functions:**

| Function | Description |
|----------|-------------|
| `display_results(data: Dictionary)` | Populates summary. data: `{cleared, gold_reward, blueprint_reward, reputation_change}`. |

---

## Subsystem: Economy & Progression

### Scenes & Scripts

| File | Type | Responsibility |
|------|------|----------------|
| `core/prep_phase.tscn` | Scene | Prep phase with TabContainer: Blueprints (buy blueprints), Upgrades (buy upgrades), Reagents (buy reagents). Crates are purchased during shop sessions, not here. Forecast tab deferred to post-MVP. |
| `autoloads/game_manager.gd` | Autoload | Persistent state data store. No game logic — pure state with change signals. |

### Data Schema: upgrades.json

| Field | Type | Description |
|-------|------|-------------|
| `upgrade_id` | `String` | Unique identifier (key). e.g. "grid_expand", "slow_timer", "crate_discount" |
| `name` | `String` | Display name |
| `cost` | `int` | Gold cost to purchase |
| `effect_type` | `String` | Effect to apply: "grid_size", "despawn_time", "crate_discount" |
| `effect_value` | `Variant` | Type depends on effect_type. grid_size: `{cols: int, rows: int}`, despawn_time: `float`, crate_discount: `float` (multiplier, e.g. 0.8) |

### ❗ Data Schema: reagents.json

| Field | Type | Description |
|-------|------|-------------|
| `reagent_id` | `String` | Unique identifier (key). e.g. "fire_essence" |
| `name` | `String` | Display name |
| `cost` | `int` | Gold cost to purchase in prep phase |
| `icon` | `String` | Resource path to icon texture |
| `description` | `String` | Short description for UI |

Reagents are bought in the prep phase and stored in `GameManager.reagent_inventory` as counts. They are never placed on the board. At merge time, if the merge result has entries in `reagent_combos.json`, available reagents create variant options (see Reagent Variants subsystem).

### Signals

| Signal | Emitted by | Listeners | Via EventBus? | Flows |
|--------|-----------|-----------|---------------|-------|
| `prep_start_session()` | `prep_phase.gd` | `main.gd` | Yes | Start Session |
| `prep_enter_dungeon()` | `prep_phase.gd` | `main.gd` | Yes | Enter Dungeon |
| `prep_quit_to_menu()` | `prep_phase.gd` | `main.gd` | Yes | Quit to Menu |
| `save_requested()` | multiple | `save_manager.gd` | Yes | After Purchase/Session/Dungeon |
| `gold_changed(new_amount: int)` | `game_manager.gd` | HUD, prep tabs | No (GameManager direct) | Any gold change |
| `reputation_changed(new_points: int)` | `game_manager.gd` | HUD, dungeon button | No (GameManager direct) | Reputation change |
| `reputation_level_changed(level: String)` | `game_manager.gd` | `prep_phase.gd` | No (GameManager direct) | Threshold crossed |
| `blueprint_added(bp_id: String)` | `game_manager.gd` | prep blueprints tab, `audio_manager.gd` | No (GameManager direct) | Blueprint Purchase |
| `upgrade_added(upgrade_id: String)` | `game_manager.gd` | `audio_manager.gd` | No (GameManager direct) | Upgrade Purchase |
| `grid_size_changed(cols: int, rows: int)` | `game_manager.gd` | active MergeBoard | No (GameManager direct) | Grid upgrade |
| `reagent_count_changed(id: String, count: int)` | `game_manager.gd` | prep reagent display | No (GameManager direct) | Reagent purchase/use |

### Flow Trace: Purchase (Any Type)

**Trigger:** Player taps a buy button in the prep phase (Blueprints / Upgrades tab).

1. Tab script calls `prep_phase.gd.try_purchase(type, id)`
2. `prep_phase.gd` looks up price from data (via RecipeResolver for blueprints)
3. Check `GameManager.gold >= price` → if not, flash button red, stop
4. `GameManager.deduct_gold(price)` → `gold_changed` signal updates HUD
5. Route by type:
   - **Reagent:** `GameManager.add_reagent(id, 1)` — goes directly to inventory. No items spawned to board or staging.
   - **Blueprint:** check dependencies met → `GameManager.add_blueprint(id)` → `blueprint_added` emitted
   - **Upgrade:** `GameManager.add_upgrade(id)` → applies effect immediately (grid size, despawn time, discount), `upgrade_added` emitted
6. `EventBus.save_requested` emitted → SaveManager writes
7. SFX played via GameManager `blueprint_added` / `upgrade_added` signals (AudioManager connects directly)

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

#### PrepPhase

**Extends:** Control
**Script:** `core/prep_phase.gd`
**Scene:** `core/prep_phase.tscn`
**Description:** TabContainer-based prep phase with 3 tabs: Blueprints, Upgrades, Reagents. Does not instance a MergeBoard — board rearrange deferred to post-MVP. Layout is scene-based with placeholder PurchaseCard instances in each tab (cleared at runtime).

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `_bp_scroll: VBoxContainer` | `@onready $VBox/TabContainer/Blueprints/BpContent` | Blueprint tab content container |
| `_upgrade_scroll: VBoxContainer` | `@onready $VBox/TabContainer/Upgrades/UpgradeContent` | Upgrade tab content container |
| `_reagent_scroll: VBoxContainer` | `@onready $VBox/TabContainer/Reagents/ReagentContent` | Reagent tab content container |

**Functions:**

| Function | Description |
|----------|-------------|
| `try_purchase(type: String, id: String) -> bool` | Validates and executes a purchase (blueprint, upgrade, or reagent). Returns true on success. |
| `_debug_unlock_all()` | Debug: sets debug_mode, grants 2000g, 1000 rep, all blueprints, 5 fire_essence. |

#### GameManager

**Extends:** Node
**Script:** `autoloads/game_manager.gd`
**Description:** Singleton data store for all persistent game state. No game logic — getters, setters, and change signals only.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `gold: int` | int | Current gold balance. Default: 50 (starting gold). |
| `reputation_points: int` | int | Cumulative reputation |
| `unlocked_blueprints: Array[String]` | Array | Blueprint IDs owned |
| `reagent_inventory: Dictionary` | Dictionary | String → int (reagent_id → count) |
| `purchased_upgrades: Array[String]` | Array | Upgrade IDs purchased |
| `shop_board_state: Array` | Array | Serialized shop board items |
| `grid_cols: int` | int | Board width (5 default, 6 with upgrade) |
| `grid_rows: int` | int | Board height (always 5) |

**Signals:**

| Signal | Description |
|--------|-------------|
| `gold_changed(new_amount: int)` | Gold balance changed. HUD and buy buttons listen. |
| `reputation_changed(new_points: int)` | Reputation points changed. HUD listens. |
| `reputation_level_changed(level: String)` | Crossed threshold: "low", "mid", "high". CustomerGenerator and prep phase listen. |
| `blueprint_added(bp_id: String)` | Blueprint unlocked. Prep phase blueprints tab, audio_manager (purchase SFX) listen. |
| `upgrade_added(upgrade_id: String)` | Upgrade purchased. audio_manager (purchase SFX) listens. |
| `reagent_count_changed(id: String, count: int)` | Reagent inventory changed. |
| `grid_size_changed(cols: int, rows: int)` | Grid dimensions changed. Active MergeBoard listens. |

**Functions:**

| Function | Description |
|----------|-------------|
| `add_gold(amount: int)` | Adds gold, emits `gold_changed`. |
| `deduct_gold(amount: int) -> bool` | Deducts if sufficient. Returns false if not. Emits `gold_changed`. |
| `add_reputation(points: int)` | Adds points (clamped to min 0), checks level change, emits signals. |
| `add_blueprint(bp_id: String)` | Appends to unlocked, emits `blueprint_added`. |
| `add_reagent(reagent_id: String, count: int)` | Updates inventory dict, emits `reagent_count_changed`. |
| `consume_reagent(reagent_id: String) -> bool` | Deducts 1 if count > 0. Returns false if none. |
| `add_upgrade(upgrade_id: String)` | Appends to purchased_upgrades, emits `upgrade_added`. Effect application is handled by the caller (e.g., prep_phase._buy_upgrade() applies grid_size changes). |
| `get_reputation_level() -> String` | Returns "low" (0–99), "mid" (100–299), "high" (300+). |
| `is_dungeon_unlocked() -> bool` | Returns `reputation_points >= 150`. |
| `get_despawn_time() -> float` | 18.0 if slow timer upgrade purchased, else 12.0. |
| `get_crate_discount() -> float` | 0.8 if discount upgrade purchased, else 1.0. |
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
**Description:** Pure signal relay autoload. Declares all game-wide signals listed in the EventBus Signal Registry (lines 67–83). No properties, no logic — other autoloads and scenes connect to its signals for cross-scene communication. State-change signals (gold_changed, reputation_changed, etc.) are owned by GameManager, not EventBus.

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

**Trigger:** Any EventBus signal or GameManager signal that maps to a SFX (merge_completed, customer_fulfilled, blueprint_added, upgrade_added, etc.).

1. `audio_manager.gd` receives signal from EventBus or GameManager in connected handler
2. Looks up SFX resource path from `sfx_map`:

| SFX Name | Signal Source | Listener Pattern |
|----------|--------------|------------------|
| `merge_complete` | EventBus `merge_completed` | EventBus connection |
| `customer_happy` | EventBus `customer_fulfilled` | EventBus connection |
| `customer_reject` | EventBus `customer_rejected` | EventBus connection |
| `purchase` | GameManager `blueprint_added` / `upgrade_added` | GameManager signal |
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

**Lifecycle:** `_ready()` connects to all relevant EventBus signals and GameManager state-change signals (`blueprint_added`, `upgrade_added`). Preloads audio streams.

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
