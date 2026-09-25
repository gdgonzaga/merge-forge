# MergeForge — Code Review & Polish Plan

Reviewed against the full source tree (~3,100 lines of GDScript across `autoloads/`,
`board/`, `core/`, `shop/`, `dungeon/`, `progression/`, `test/`). Godot 4.6, mobile
target. Every finding below was verified by reading the code directly; file:line
references point to the current tree.

> Note: the `progression/` directory is **empty** — all progression logic lives in
> `GameManager`. Either build the module or remove the folder (see §6).

---

## TL;DR — Top 8 things to fix, in priority order

| #   | Severity   | Area            | Issue                                                                             |
| --- | ---------- | --------------- | --------------------------------------------------------------------------------- |
| 1   | 🔴 Blocker | board           | Merge-choice popup can **deadlock** the merge queue forever if dismissed          |
| 2   | 🔴 Blocker | board           | Drag-and-drop is **mouse-only** — broken on the mobile target                     |
| 3   | 🟠 High    | board           | **Crate drops never trigger merge detection** (silent groups)                     |
| 4   | 🟠 High    | recipe_resolver | `get_item_data()` **mutates the shared JSON cache** in place                      |
| 5   | 🟠 High    | data/code drift | Despawn time & crate discount are **hardcoded** and disagree with `upgrades.json` |
| 6   | 🟠 High    | save            | Save integrity is fragile: no versioning, corrupt==missing, ignored rename errors |
| 7   | 🟡 Med     | dungeon         | Combat damage **asymmetry** (party DPS flat, enemy DPS scales with members)       |
| 8   | 🟡 Med     | shop            | Multi-order customers can only ever fulfill **one order**                         |

Details and more in the sections below.

---

## 1. Bugs & correctness issues (fix these first)

### 1.1 🔴 Merge-choice popup deadlock — `board/merge_choice_popup.gd`

There is **no cancel/close path**. If the player presses Escape, clicks outside, or
the popup is dismissed any way other than picking an option, `choice_made` is never
emitted. In `merge_resolver.gd`, `is_processing` stays `true` forever and
`process_next()` is never called again — the merge queue **deadlocks permanently**.
No further merges will ever resolve.

```gdscript
# board/merge_choice_popup.gd — no popup_hide handler
func _on_button_pressed(...): hide(); choice_made.emit(...)
# nothing wires popup_hide / close_request / WINDOW_EVENT_CLOSE_REQUEST
```

**Fix:** wire `popup_hide` (or override `_notification`) to a cancel callback that
either picks a safe default or advances the resolver:
```gdscript
func _ready() -> void:
    popup_hide.connect(_on_cancelled)
func _on_cancelled() -> void:
    if not _answered:
        choice_made.emit(_default_item_id, false, "")  # or a dedicated cancelled signal
```

Also note the **double `popup_centered()`**: `merge_board.gd:284-285` calls
`_popup.call("show_options", ...)` and then `_popup.popup_centered()`, but
`show_options` already ends with `popup_centered()` (`merge_choice_popup.gd:25`).
Drop one.

### 1.2 🔴 Mobile drag-and-drop is non-functional

`board/board_cell.gd` and `board/floating_item.gd` implement drag via Godot's Control
GUI system (`_get_drag_data` / `_can_drop_data` / `_drop_data`). In Godot 4, these
are **only driven by mouse events**, not `InputEventScreenTouch`. On a touch device
(the stated platform — `project.godot` is Mobile, portrait phone) the entire
drag-to-merge loop silently does nothing.

The `project.godot` setting `pointing/emulate_touch_from_mouse=true` goes the *wrong*
way for this (it makes mouse act like touch, not touch act like mouse).

**Fix:** add an explicit `_gui_input` path that handles `InputEventScreenTouch` +
`InputEventScreenDrag`, or use a drag helper that converts touch into a floating
preview + manual drop. This is the single biggest "game doesn't work on target"
issue.

### 1.3 🟠 Crate drops skip merge detection — `board/board_grid.gd`

`place_or_stage()` (around `board_grid.gd:133`) places crate-dropped items but does
**not** emit `item_placed` and does **not** play the place SFX, unlike `place_item()`.
Merge detection (`merge_board`) is wired to `item_placed`. So items that arrive via a
crate form silent groups that only get detected on the *next* manual move — chain
merges from crate drops effectively don't happen.

**Fix:** make `place_or_stage` route through the same emit as `place_item`, or have
`merge_board.place_drop` explicitly trigger a `scan()` after placing.

### 1.4 🟠 `get_item_data` mutates the shared cache — `autoloads/recipe_resolver.gd:51-55`

```gdscript
func get_item_data(item_id: String) -> Dictionary:
    var data: Dictionary = items.get(item_id, {})   # same reference as the cached dict!
    if not data.is_empty():
        data["item_id"] = item_id                    # writes into the persistent cache
    return data
```

`items.get(id)` returns the *same Dictionary* stored in the loaded cache, so this
stamps `item_id` into the shared catalog as a side effect of every lookup. A future
caller that iterates keys or re-checks `item_id` will see contamination.

**Fix:** `var data := items.get(item_id, {}).duplicate(); data["item_id"] = item_id; return data`

### 1.5 🟠 Data/code drift: despawn & crate-discount — `autoloads/game_manager.gd:87-92`

```gdscript
func get_despawn_time() -> float:
    return 18.0 if "slow_timer" in purchased_upgrades else 12.0   # code says 18s
func get_crate_discount() -> float:
    return 0.8 if "crate_discount" in purchased_upgrades else 1.0
```

But `data/upgrades.json` declares `effect_value: 15.0` for `slow_timer`. The runtime
uses **18.0**; `prep_phase._describe_upgrade` shows the JSON value (**15s**) to the
player. The two disagree. The JSON `effect_value` is effectively dead for these two
upgrades — they're only used for display text.

**Fix:** read from data: `RecipeResolver.get_upgrade_data("slow_timer").get("effect_value", 12.0)`,
making JSON the single source of truth. (Note: `grid_expand` *does* read its
`effect_value` correctly in `prep_phase.gd:73-76` — that upgrade works.)

### 1.6 🟠 Save integrity — `autoloads/save_manager.gd` + `game_manager.gd`

Four compounding problems:

1. **No save versioning.** `serialize()` (`game_manager.gd:95-106`) has no `version`
   field. Any future schema change has no migration path.
2. **`deserialize` blindly trusts types** (`game_manager.gd:112-114`):
   `unlocked_blueprints.assign(data.get("unlocked_blueprints", []))` will runtime-error
   on a tampered/corrupt save that stores a non-Array. No validation anywhere.
3. **Corrupt save is indistinguishable from "no save"** (`save_manager.gd:27-40`):
   both file-missing and JSON-parse-failure return `{}`. `main._on_continue_game`
   then treats it as a fresh game silently. At minimum `push_error` on parse failure.
4. **Atomic-rename errors are ignored** (`save_manager.gd:22-23`):
   `DirAccess.remove_absolute`/`rename_absolute` return `Error` codes that are never
   checked. If rename fails, the player is left with no save at `SAVE_PATH` *and* a
   stranded `.tmp`, yet `save_completed` is still emitted.

**Fixes:** add `"version": 1` to the serialized dict; validate each field's type in
`deserialize`; distinguish MISSING vs CORRUPT in `load()` (return a result enum or
emit distinct signals); check the rename return code before emitting success.

### 1.7 🟡 Combat damage asymmetry — `dungeon/combat_engine.gd:66,93`

```gdscript
var dmg_per_enemy  := maxi(floori(atk / alive_enemies), 1)   # party → enemies
var dmg_per_member := maxi(floori(eatk / active_members), 1) # enemies → party
```

Each party member splits their attack across all live enemies, so **adding more
enemies does not increase total party DPS** — the party does `atk` total per member
regardless of enemy count. But each enemy applies `floori(eatk/active_members)` to
*every* active member, so enemy total damage **scales multiplicatively** with member
count (2 enemies × 3 members = 6 applications). The party is paradoxically penalized
for having more members. Almost certainly not the intended model.

**Fix:** decide the design (typical auto-battlers apply each enemy's attack to a
*single* target, or split among targets). Document it in a comment and add a combat
unit test once RNG is seeded (see §5).

### 1.8 🟡 Multi-order customers can only fulfill one order — `shop/shop_session.gd:108-109`

```gdscript
current_index += 1
advance_customer.call_deferred()
```

A successful fulfill unconditionally advances to the **next customer**. Customers in
`data/customers.json` (e.g. `cust_02`, `cust_04`) carry multiple `orders`. The player
can only ever complete one per customer; the rest are silently dropped and it counts
as a single "fulfilled". Either the data model is misleading or this is a real bug.
**Confirm intent**, then either remove the unconditional advance or make orders
alternative offers (and rename the field).

### 1.9 🟡 Bonus coin double-collect — `board/bonus_coin.gd`

`_collect` has no `_collected` guard. Tapping a coin mid-float starts a second tween,
calls `GameManager.add_gold` twice, and `queue_free`s twice. Add `if _collected: return`.

### 1.10 🟡 Silent result loss — `board/merge_resolver.gd:183-184`

If `_spawn_results` finds no empty cell (`center.x < 0`), the result item is **dropped
on the floor** with no refund — but `EventBus.merge_completed` still emits at line 156
as if it succeeded. The consumed input items are gone. Either refund fully or
guarantee a placement cell (queue the merge until space exists).

### 1.11 🟡 `consume_reagent` return ignored — `board/merge_resolver.gd:142`

```gdscript
if rid != "":
    GameManager.consume_reagent(rid)   # return value ignored
```

If the reagent is unavailable the variant is still produced "for free". Today it's
race-free because the button is only shown when stock ≥ 1, but there's no assertion.
Check the return value; abort the variant if false.

### 1.12 🟡 Dungeon double-resolution risk — `dungeon/dungeon_controller.gd`

`end_dungeon_cleared` / `end_dungeon_failed` can be reached from two places (the
progress≥1.0 tick branch and `end_encounter`). If both fire on the same frame, the
player is double-rewarded (gold/rep/blueprint) and `dungeon_cleared` emits twice,
double-transitioning the scene. Add a `_resolved: bool` guard.

---

## 2. Architecture

### 2.1 `board/merge_board.gd` is a God class

~290 lines orchestrating: grid wiring, detector, resolver, staging, popups, the
animation system, gold-text spawning, crate purchasing, and drop placement. Split it:
- `AnimationController` (the tween code, lines ~85-200)
- `StagingController` (floating-item lifecycle, lines ~230-265)
- keep `MergeBoard` as a thin coordinator.

### 2.2 Two sources of truth for "game events"

`EventBus` holds `merge_completed`, `customer_*`, `session_*`, `dungeon_*`, while
`GameManager` holds `gold_changed`, `reputation_*`, `blueprint_added`, `upgrade_added`,
`reagent_count_changed`, `grid_size_changed`. Consumers must know two locations for
what is conceptually one event stream. Consider consolidating economy/state signals
onto `EventBus` (or onto `GameManager`) so there's one bus.

### 2.3 `RecipeResolver` (a "data" autoload) reaches into `GameManager` (state)

`recipe_resolver.gd:46,70` read `GameManager.reagent_inventory` / `unlocked_blueprints`
directly, coupling the data layer to state. Move `has_blueprint`/reagent lookups onto
`GameManager` and pass results in, so `RecipeResolver` stays stateless and testable.

### 2.4 Cross-scene coupling via tree walk + public field

`shop/session_summary.gd` and `dungeon/dungeon_summary.gd` do `find_child("Main", ...)`
and read `main_node.pending_summary`. Hidden coupling through the root node's public
fields. `main.gd:19` initializes `pending_summary = {}` (not null), so the guard
`pending_summary != null` is always true. Prefer passing data through the
`EventBus.session_ended` payload + a small typed struct.

### 2.5 No `class_name` anywhere in `board/`

Every node reference is by string path (`find_child("BoardGrid", true, false)`,
`load("res://board/merge_detector.gd").new()`). This defeats static typing,
autocomplete, and grep. Add `class_name BoardGrid`, `class_name MergeDetector`, etc.

### 2.6 Dictionaries as unit structs (dungeon)

`combat_engine.gd` uses `Array[Dictionary]` for party/enemies with ~40 `.get(key,
default)` calls and divergent magic defaults (`max_hp` defaults to `50` at `:40,137`
but real party values are 90/50/60; `attack` defaults to `10` at `:42` vs `5` at
`:92,181`). A `class_name CombatUnitState extends RefCounted` with typed fields would
remove the default-mismatch footgun.

---

## 3. Performance & UX

### 3.1 Full UI rebuild on every gold change — `core/prep_phase.gd`

`_refresh_all` (line 94) runs on every `gold_changed` (line 23), rebuilding all three
scroll lists by `queue_free`-ing and re-instantiating every `purchase_card`, and
`load("res://shop/purchase_card.tscn")` is called on every refresh (lines 104, 137,
154). On a burst of gold changes you can accumulate freed nodes before they're
collected.

**Fixes:**
- `const CARD_SCENE := preload("res://shop/purchase_card.tscn")` at the top.
- Update existing cards' `disabled` state instead of full rebuilds, or debounce with
  `call_deferred`.

### 3.2 Audio re-loads on every trigger — `autoloads/audio_manager.gd`

`play_sfx` calls `_load_audio` → `load(path)` on **every** SFX play (lines 88-100),
and `play_music` re-`load`s the stream each call. For SFX fired many times per second
(`gold_earn` on every coin) this is needless churn. Preload all `sfx_map` streams in
`_ready` into an `AudioStream` dictionary.

### 3.3 Spurious `gold_earn` SFX on load — `audio_manager.gd:48,51-54`

`_prev_gold` is captured once in `_ready` (= 50). When `GameManager.deserialize`
emits `gold_changed` with a saved amount > 50, the coin SFX plays on the main menu.
Reset `_prev_gold` in a load hook (subscribe to a future `state_loaded` signal).

### 3.4 Failed scene load leaves a blank screen — `core/main.gd:73-79`

```gdscript
for c in _scene_container.get_children(): c.queue_free()   # free current
var scene = load(scene_path).instantiate()                  # may fail
```

If `load` fails (missing `.tscn`), the old scene is already freed and nothing replaces
it — blank screen, only a `push_error`. **Validate the load before freeing children.**

### 3.5 Music chosen by path substring — `core/main.gd:85-90`

`"dungeon" in scene_path` / `"main_menu" in scene_path`. Renaming a scene file flips
the music track. Encode the music cue in `scene_map` (e.g. value becomes
`{scene=..., music=...}`).

### 3.6 Bonus coin / icon textures re-loaded per spawn — `board/bonus_coin.gd:12,42`

Hardcoded `COIN_ICON` path `load()`ed on every coin; coins spawn in bursts of up to 3.
Preload once.

### 3.7 SFX spam during multi-result merges

`merge_resolver._place_results` places N result items + M refunds, each `place_item`
emits `item_placed` → `board_grid` plays `item_place` SFX. A single merge can fire the
sound N+M times in one frame. Batch to one sound per merge.

### 3.8 Debug leftover — `core/main.gd:84`

`print("[Main] _play_scene_music: path='%s'" % scene_path)` — ship-code noise. Remove.

---

## 4. Code-quality & cleanup

- **`_debug_unlock_all` ships ungated** (`prep_phase.gd:177-186`, wired at line 22).
  It bypasses `add_gold` by setting `GameManager.gold = 2000` directly and manually
  emitting. Reachable in release builds. Gate with `if OS.is_debug_build():` and route
  through `add_gold`.
- **`add_gold` doesn't clamp at zero** (`game_manager.gd:25-27`). `add_gold(-1000)`
  makes gold negative, bypassing the guard `deduct_gold` enforces. Use
  `gold = maxi(gold + amount, 0)` or route decrements through `deduct_gold`.
- **`add_upgrade` is not idempotent** (`game_manager.gd:70-72`), unlike `add_blueprint`
  (`:47-49`). Buying the same upgrade twice double-appends and the list grows
  unbounded through saves. Dedupe.
- **Magic numbers everywhere.** Reputation thresholds `100/150/300`
  (`game_manager.gd:76-84`, duplicated in `prep_phase.gd:17,18,29` and
  `dungeons.json`). The `3` in merge math (`merge_resolver.gd:144,145,161,218`),
  `0.5` gold factor, coin cap `3`. Colors in `prep_phase.gd:116-143`. Promote to
  `const`s and make dungeon-unlock read from `dungeons.json[...].reputation_required`
  (currently the JSON value is never read by code).
- **Duplicated crate-cost math** (`shop_session.gd:55` and `merge_board.gd:51`):
  `int(cost * GameManager.get_crate_discount())`. Extract `GameManager.get_crate_cost(crate_id)`.
- **Duplicated flood-fill** between `board_grid._count_connected` and
  `merge_detector._flood_fill`. Unify.
- **Duplicated drag-preview boilerplate** between `board_cell.gd:52-70` and
  `floating_item.gd`. Extract a shared helper.
- **`animate_move`'s `_callback` param is never invoked** (`merge_board.gd:260`,
  passed `func(): pass`). Dead parameter — drop it.
- **Redundant `despawn_timeout.connect(fi.queue_free)`** (`merge_board.gd:238`) —
  `floating_item` already self-frees (`floating_item.gd:40`).
- **`_create_cells` frees children before checking `_cell_scene == null`**
  (`board_grid.gd:36-41`). Reversed order is a latent bug — null-check first.
- **`floating_item._process` doesn't guard `_timer_bar`** (`floating_item.gd:43`) —
  a scene edit removing TimerBar crashes every frame.
- **`roll_weighted_pool` edge case** (`recipe_resolver.gd:91-105`): if all weights are
  0/missing, `total_weight == 0`, the inner loop never satisfies `roll < accumulated`,
  and the function silently returns fewer than `rolls` entries. Guard with
  `if total_weight <= 0: continue`.
- **`_load_json` swallows all failures** (`recipe_resolver.gd:108-119`) returning `{}`.
  For data the whole game depends on, a silent `{}` means empty catalogs with no
  diagnostic. `push_error` on parse failure for required files.
- **`customer_generator._load` swallows all failures** (`customer_generator.gd:14-28`)
  → session runs with zero customers → instant "Session Complete!" with no feedback.
  `push_error` on failure paths.
- **`main.gd` dual-mode `_go_to(_data=null, scene_key="")`** (`main.gd:37`) relies on
  bound zero-arg signals delivering their bound string as `_data`. If a signal later
  emits a payload, routing silently breaks. Use explicit per-signal handlers.
- **Unused signals:** `board_cell.cell_drag_started` (emitted, never consumed);
  `SaveManager.save_loaded` (emitted, no listener). Remove or wire.
- **Dead fields?** `shop_board_state`/`dungeon_board_state` are serialized but the
  mid-session save window is inconsistent: buying a crate + force-quitting saves spent
  gold but not placed items (board state only snapshots in `end_session`). Snapshot
  board state on `save_requested` too. Also, `dungeon_board_state` isn't reset on a
  cleared run → the dungeon may be farmable. Confirm intended.

---

## 5. Tests (currently only `GameManager` is covered)

`test/unit/test_game_manager.gd` is solid for the autoload. But:

- **Zero coverage** for `shop/`, `dungeon/`, or anything in `board/` — the most
  bug-prone modules (combat math, drop rolling, customer fulfillment, merge detection,
  save integrity).
- **RNG is global and unseeded** (`recipe_resolver.roll_weighted_pool` uses
  `randi_range`/`randf`; combat uses global RNG). There is **no way to write a
  deterministic combat/drop test**. This is the single biggest testability gap.
  Inject a `RandomNumberGenerator` into `combat_engine`, `drop_manager`, and
  `roll_weighted_pool`.
- **`test_click_probe_spike.gd` is a non-failing "spike"** — it prints diagnostics but
  has no assertions, so it's green noise in CI. Either convert to real assertions or
  exclude it from the default run / mark `@warning_ignore`.
- **Signal leaks across tests:** inline `GameManager.gold_changed.connect(func(...):...)`
  lambdas are never disconnected, and `GameManager` is an autoload that persists across
  tests. Disconnect in an `after_test()`, or use gdUnit4's `monitor_signals`.
- **No drift test** linking the code's `150` (dungeon unlock) to
  `dungeons.json`'s `reputation_required: 150` — exactly the kind of two-sources-of-truth
  bug that a one-line test would lock down.
- **No test for `add_upgrade` idempotency** (because it isn't idempotent — §4).

**Highest-value tests to add after seeding RNG:**
1. `merge_detector` — groups of 3/4/5, 4- vs 8-connectivity, edge wrapping.
2. `combat_engine.tick` — "party [fighter,mage,healer] clears 2 slimes within N ticks".
3. `merge_resolver` — result placement when board is full (the silent-loss case),
   refund math, chain merges.
4. Save round-trip with a *corrupt* JSON (asserts MISSING vs CORRUPT distinction).

---

## 6. Project hygiene

- **Empty `progression/` directory.** The module was never built; all progression
  (reputation tiers, dungeon unlock, upgrade effects) lives in `GameManager`. Either
  build a `ProgressionManager` autoload with data-driven thresholds, or delete the
  folder to stop implying a module that doesn't exist.
- **`export_presets.cfg` is gitignored** (`.gitignore` line) but **is committed** —
  `git ls-files | grep export_presets` will show it. Reconcile: either untrack it or
  remove from `.gitignore`. (It contains Android keystore paths — worth checking it
  doesn't leak secrets.)
- **`tmp/` and `reports/` are gitignored but exist locally** — fine, just be aware
  they won't ship.
- **`.editorconfig` is minimal** (charset only). Add `indent_style = tab`,
  `insert_final_newline = true`, `[*.{gd,tscn}]` section to match Godot conventions —
  the project mixes tabs in `.gd` with whatever the editor inserts elsewhere.
- **Autoload order is load-bearing** (`project.godot`): `EventBus → GameManager →
  RecipeResolver → SaveManager → AudioManager`. `AudioManager._ready` reads
  `GameManager.gold` and `SaveManager._ready` connects to `EventBus`. Reordering
  breaks startup silently. Add a comment in `project.godot`.

---

## 7. Suggested order of work

A pragmatic sequence that knocks out risk first, then quality:

**Sprint 1 — make it correct on the target platform**
1. §1.2 mobile drag (touch `_gui_input` path in `board_cell` + `floating_item`)
2. §1.1 merge popup deadlock (wire `popup_hide`) + remove double `popup_centered`
3. §1.3 crate-drop merge detection
4. §1.9 bonus coin double-collect guard
5. §3.4 validate scene load before freeing

**Sprint 2 — economy & save integrity**
6. §1.4 `get_item_data` cache mutation (one-line fix)
7. §1.5 data/code drift for despawn + crate discount (read from JSON)
8. §1.6 save versioning + type validation + MISSING/CORRUPT distinction + rename error check
9. §1.10 silent result loss refund; §1.11 `consume_reagent` return check
10. §1.8 confirm multi-order intent; §4 `add_gold` clamp, `add_upgrade` dedupe

**Sprint 3 — balance & testability**
11. §5 inject seeded RNG; then add combat + merge unit tests
12. §1.7 combat damage formula (decide + document + test)
13. §1.12 dungeon double-resolution guard
14. drift test for dungeon-unlock reputation

**Sprint 4 — architecture & polish**
15. §2.1 split `merge_board`; §2.6 `CombatUnitState`; §2.5 add `class_name`s
16. §3.1 stop full rebuilds on gold change; §3.2 preload audio; §3.6 preload coin icon
17. §3.8 remove debug print; §4 gate `_debug_unlock_all` behind `is_debug_build`
18. §6 reconcile `export_presets.cfg` tracking; enrich `.editorconfig`

---

*Generated 2026-07-02. Re-run after Sprint 1–2 to re-verify line numbers.*
