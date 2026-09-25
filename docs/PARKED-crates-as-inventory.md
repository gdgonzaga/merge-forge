# Parked Change: Crates as Inventory Items

**Status:** Parked — implement after Phase 3, before MVP finish
**Created:** 2026-06-11
**Affects:** GDD.md, ARCHITECTURE.md, Development Plan.md

---

## Summary

Change material crates from instant purchases during shop sessions to inventory items. Players buy crates in the prep phase (or receive them as rewards), and they stack by type in a `crate_inventory` dictionary. During shop or dungeon sessions, an "Available Items" panel displays available crates with counts. Players open crates from this inventory to spawn items into the staging area. Crate types with 0 count are hidden.

**Key principle:** Acquisition (prep) is separated from usage (session).

---

## Current vs New Behavior

**Current:** Gold → crate buy button in shop → items to staging (instant)

**New:** Gold → crate buy button in prep → `crate_inventory` → open during session → items to staging

---

## GDD.md Changes

### Core Loop — Shop Mode (line 80)

- Step 3: Change "buys crates, places materials" to "opens crates from inventory, places materials"

### Core Loop — Shop Mode (line 84)

- Step 7: Change "spend gold on blueprints, reagents, upgrades" to "spend gold on blueprints, reagents, upgrades, **crates**"

### Core Loop — Dungeon Mode (line 91)

- Step 3: Add that player can open crates from inventory. Items go to dungeon board staging area.

### Actions and Controls (line 137)

- Change "Tap buy button (crate) | Tap | Shop mode only" to "Tap buy button (crate) | Tap | Prep mode only; purchases if gold is sufficient"
- Add: "Tap crate in Available Items | Tap | Shop/Dungeon mode; opens one crate from inventory"

### Screens and UI — Shop Mode (line 254)

- Change "CratePanel — VBoxContainer with crate buy buttons populated from `crates.json`" to "Available Items panel — VBoxContainer showing crate types with available counts. Tapping opens one crate. Entries with 0 count are hidden."

### Screens and UI — Prep Phase (line 263)

- Change "Material crates are purchased during shop sessions" to "Crates tab — buy crates with gold, stored in inventory for use during sessions"
- Add "Crates" to the TabContainer tabs list

### Screens and UI — Dungeon Mode (line 274)

- Add "Available Items" section showing crate inventory (same inventory as shop). Position TBD.

### Economy Submodule

- **What triggers it (line 486):** Replace "a crate buy button during a shop session" with "a crate buy button in prep phase (acquisition)" and "a crate in the Available Items panel during a session (opening)"
- **States / Logic (line 503):** Step 3 changes from "If crate → pick random items... spawn in staging" to "If crate → add to GameManager.crate_inventory"
- Add step after purchase flow: "Crate opening (session): deduct from inventory → generate items from weighted pool → spawn in staging"
- **Fixed values (line 519):** Update crate definitions note: "Crates are purchased in the prep phase and stored in inventory. During shop or dungeon sessions, players open crates from the Available Items panel."

### What Persists Between Sessions (line 235)

- Add: `crate_inventory (Dictionary[String, int])`

### Progression — Dungeon Rewards

- Optional: add crate rewards to dungeon completion (e.g., Goblin Cave awards 1× basic crate). Exact rewards TBD at implementation time.

### Decisions Log

- Add: "2026-06-11: Crates are inventory items — bought in prep phase, opened during sessions (shop or dungeon). Separates acquisition from usage."

### Parked

- Add: "Rewarded ads for crates — `reward_crate(crate_id, count)` stub. Ad SDK integration deferred."

---

## ARCHITECTURE.md Changes

### GameManager

Add `crate_inventory` following the **same pattern as `reagent_inventory`**:

- Property: `crate_inventory: Dictionary` (crate_id → count)
- Signal: `crate_count_changed(crate_id: String, count: int)`
- Functions: `add_crate(crate_id, count)`, `consume_crate(crate_id) -> bool`
- Include in `serialize()` / `deserialize()`

### ShopSession

- Replace `try_buy_crate(crate_id) -> bool` (gold → staging) with `try_open_crate(crate_id) -> bool` (inventory → staging)
- `try_open_crate`: check `GameManager.crate_inventory`, deduct 1, generate items from weighted pool, add to staging. Returns false if count = 0.
- Update flow trace step 3: CratePanel becomes "Available Items panel" showing inventory counts

### DungeonController

- Add `try_open_crate(crate_id) -> bool` — same logic as ShopSession but adds to dungeon board staging
- Add "Available Items" panel to `dungeon_run.tscn`
- Add to flow trace: player can open crates during walking or combat

### PrepPhase

- Add `try_buy_crate(crate_id) -> bool` — checks gold (with discount), deducts, adds to `GameManager.crate_inventory`
- TabContainer: add "Crates" tab or expand existing tab with crate buy section

### Dungeon Rewards

- Optional: add `crate_rewards` to `dungeon_cleared` signal payload. Exact format TBD.

### EventBus

- Add `crate_opened(crate_id: String)` signal (emitted by ShopSession/DungeonController). Used for `crate_open` SFX. Note: could remain a same-scene direct call instead — decide at implementation time.

### Save/Load

- `crate_inventory` included via `GameManager.serialize()`/`deserialize()` (no separate SaveManager changes needed)

---

## Development Plan.md Changes

Implement after Phase 3 is complete. Changes touch Phase 2 and Phase 3 tasks:

- **Phase 2 Task 5 (GameManager):** Add `crate_inventory` property and methods alongside existing inventory properties
- **Phase 3 Task 1 (ShopSession):** Replace CratePanel with Available Items panel. `try_open_crate()` replaces `try_buy_crate()`
- **Phase 3 Task 5 (PrepPhase):** Add crate purchasing (new tab or section). `try_buy_crate()` deducts gold, adds to inventory
- **Phase 3 Task 9 (DungeonRun):** Add Available Items panel. `try_open_crate()` deducts from inventory, spawns to dungeon staging
- **Phase 3 Task 14 (DungeonSummary):** Optionally include crate rewards on dungeon clear
- **Phase 5:** Add edge cases: inventory at 0, opening last crate, buying with insufficient gold

---

## Decisions

- Crate inventory follows the same pattern as reagent inventory (Dictionary, add/consume, change signal)
- `crate_open` SFX: can remain a same-scene direct call or use a new EventBus `crate_opened` signal — decide at implementation time
- Dungeon crate rewards: optional, TBD at implementation time
- Customer fulfillment does NOT reward crates (gold + reputation only)

---

## Open Questions

- **Prep phase UI:** Separate "Crates" tab or part of existing Upgrades tab?
- **Dungeon Available Items position:** Below merge board? Collapsible panel?

---

## Ad Rewards (Stub)

```gdscript
func reward_crate(crate_id: String, count: int) -> void:
    add_crate(crate_id, count)
    # TODO: integrate with ad SDK for rewarded video ads
```

Ad SDK integration is out of scope per GDD. This stub ensures the inventory system supports ad rewards post-MVP.
