# MergeForge — Game Design Document

## 1. Overview

**Game title:** MergeForge

**Genre:** Merge-crafting simulation with dungeon RPG elements

**Platform:** Android + iOS

**Target audience:** Advanced casual players, ages 20–40, male-skewed. Players who enjoy merge and crafting games but want more depth — spatial puzzle planning, economy management, real-time dungeon pressure. Fans of RPG crafting systems who wouldn't typically play casual merge games.

**One-sentence description:** You are the town blacksmith — forge legendary gear by merging materials on a crafting board, serve adventurers from your shop, and join dungeon raids where you craft in real time to keep your party alive.

**Core fantasy:** Running a thriving fantasy blacksmith shop, growing from humble ore-smelter to legendary armorer whose gear is sought by heroes.

---

## 2. Scope

### In Scope (v1.0)

- 5×5 merge grid (expandable to 6×5) with drag-and-drop placement and repositioning
- Staging area with timed despawn for incoming materials
- Connected-group merge detection (3+ identical orthogonally adjacent items auto-triggers)
- Fixed recipe tree with player choice (2–4 options per merge)
- Blueprint system gating recipe branches
- 2 material families in MVP gameplay (Metal, Herb), each with a 4-step merge chain defined on the item definitions. Gem and Wood families have the family key reserved in data (`"gem"`, `"wood"`) but no items are defined yet.
- 1 reagent in MVP (Fire Essence) creating variant items as merge options for final-stage merges
- Shop mode: 10-customer sessions with order fulfillment
- 3 customer tiers (Basic, Standard, Premium) gated by reputation
- Economy: gold, material crates, reagent purchases, shop upgrades
- Prep phase between sessions: buy blueprints/reagents/upgrades, rearrange board; material crates bought during shop sessions
- Reputation system with thresholds for customer tier and dungeon unlock
- Dungeon mode: auto-walking party, enemy encounters, auto-combat
- Real-time merging during dungeon with usable items (heal, buff) drag-to-party
- Party knockouts and dungeon fail condition (full party wipe)
- Enemy drops into staging area
- Save/load system (auto-save at key checkpoints)
- Audio: music and SFX for both modes
- Ad-supported: AdMob interstitial ads at natural breaks, with consent through Google's UMP (see Submodule — Ads and `docs/ADS-COMPLIANCE.md`)

### Out of Scope (do not implement, do not design for)

- Multiplayer / co-op / social features
- Player character movement or direct combat control
- Procedural dungeon generation
- In-app purchases, including paid ad removal (tracked in `docs/TODO.md`)
- Banner, rewarded, app-open and native ads (v1.0 shows interstitials only)
- Leaderboards / achievements / challenges
- Tutorial system (v1.0 assumes player learns by doing)
- Localization (English only)
- Cloud save
- Animated cutscenes or narrative events

### Deferred to Later Versions

- Additional dungeons beyond the first
- Gem and Wood material families (family keys reserved: `"gem"`, `"wood"`; no items defined yet)
- Premium customer tier
- Algorithmic Customer Generation (MVP uses flat, hand-authored list)
- Party Abilities / Active Skills (auto-attack only for MVP)
- Demand Forecast / Forecast tab
- Dungeon Mid-Exit Penalty (MVP wipes all partial progress)
- Additional reagent types beyond Fire Essence (Ice, Shadow, Holy)
- Equipment Durability / Repair mechanic — party equipment wears during dungeon raids, player crafts repair items (usable item type: `repair`)
- Timed events or daily challenges
- Board themes / cosmetics
- Encrypted save file

---

## 3. Core Loop

The core loop has two modes: **Shop Mode** and **Dungeon Mode**.

### Shop Mode Loop

1. **Session starts** — 10 customers are generated from a flat, hand-authored list (same order every session for MVP)
2. **Customer arrives** — displays portrait and 1–3 possible orders
3. **Player crafts** — buys crates, places materials on the board, merges them into more advanced items
4. **Player fulfills order** — taps one order card to deliver the required items, earning gold. Only one order per customer can be fulfilled; remaining orders are discarded. OR rejects the customer (small reputation penalty)
5. **Repeat** steps 2–4 for all 10 customers
6. **Session summary** — shows gold earned, items sold, satisfied customer portraits
7. **Prep phase** — spend gold on blueprints, reagents, upgrades; rearrange board (demand forecast tab deferred to post-MVP)
8. **Choose** — start next session or enter dungeon (if unlocked)

### Dungeon Mode Loop

1. **Party enters dungeon** — party of 3 members walks forward automatically
2. **Encounter spawns** — enemies appear at predefined progress points, party stops and fights. **Progress halts during combat** — the progress bar only advances while the party is walking.
3. **Player crafts in real time** — enemy drops are placed directly on the board when safe cells exist, or in staging area as fallback; player merges items
4. **Player supports party** — drags usable items (heals, buffs) to party members
5. **Combat resolves** — auto-combat ticks, enemies die and drop materials, or party members get knocked out
6. **Repeat** steps 2–5 until all enemies in the dungeon are defeated and progress reaches 100%
7. **Dungeon ends** — rewards (gold, blueprints, reputation) on success, reputation loss on failure

**Session length:** 5–10 minutes (shop), 3–5 minutes (dungeon)

**Loop length:** ~30 seconds per customer (shop), ~30 seconds per encounter (dungeon)

---

## 4. Player

### States

The player has no character avatar. Player state is the game mode they are in.

```
States: Main Menu, Shop Session, Session Summary, Prep Phase, Dungeon, Dungeon Summary

Transitions:
- Main Menu → Shop Session: New Game
- Main Menu → Prep Phase: Continue (load save)
- Shop Session → Session Summary: 10th customer served or rejected
- Session Summary → Prep Phase: player taps Continue
- Prep Phase → Shop Session: player taps Start Session
- Prep Phase → Dungeon: player taps Enter Dungeon (requires reputation threshold)
- Dungeon → Dungeon Summary: dungeon cleared or failed
- Dungeon Summary → Prep Phase: player taps Continue
- Prep Phase → Main Menu: player taps Quit (with confirmation)
```

### Actions and Controls

All input is touch-based. Mouse is emulated as touch for testing.

| Action | Input | Notes |
|--------|-------|-------|
| Drag staging item → grid cell | Touch drag from staging area to board | Places on empty cell; rejects if occupied |
| Drag grid item → grid cell | Touch drag from one cell to another | Moves to empty cell; swaps if occupied |
| Drag grid item → off board | Touch drag from cell to outside board | Discards the item permanently |
| Drag usable item → party member | Touch drag from board to party portrait | Dungeon mode only; applies heal/buff |
| Tap order card | Tap | Shop mode only; fulfills order if items are on the board |
| Tap reject button | Tap | Shop mode only; skips current customer |
| Tap buy button (blueprint, reagent, upgrade) | Tap | Prep mode only; purchases if gold is sufficient |
| Tap buy button (crate) | Tap | Shop mode only; purchases if gold is sufficient |
| Tap merge choice button | Tap | Selects merge result when 2+ options |

---

## 5. Enemies

Enemies are auto-combat opponents in dungeon mode. The player does not control combat directly — they influence it by crafting usable items and dragging them to party members.

Every unit, enemy or party member, has one attack, and one rule covers both sides:
- **Every attack winds up.** A unit picks its target, winds up for its `windup` (1 second for every unit today), then hits. A line from attacker to target fills during the windup, so every incoming hit is visible before it lands. The target is locked when the windup starts; it changes only if that target falls first.
- **Crits.** Each windup rolls the unit's crit chance (15% for everyone today). A crit winds up twice as long and hits four times as hard: twice the damage per second, with a longer warning. A crit is shown from the moment its windup starts (gold line, "!" on the attacker), so the player can answer it with a potion; the crit's name ("Smash") pops up when it lands.
- **Every attack hits one target.** **Melee** hits the front of the other side — the lowest slot still standing. The party is ordered Fighter, Mage, Healer, so the Fighter tanks; when the Fighter falls, the Mage becomes the front member, then the Healer. Enemies are ordered as the encounter lists them, so the party's melee members focus the first enemy. **Missile** hits the weakest unit on the other side (lowest current HP), reaching past the front: the Goblin Archer picks off the Mage, and the Mage finishes wounded enemies.

### Enemy — Slime

**Description:** A weak gelatinous blob. First enemy encountered in Goblin Cave.
**Role:** Low-threat enemy that teaches the player the dungeon flow without pressure.

```
States: Alive, Dead

Transitions:
- Alive → Dead: HP <= 0 (from party auto-combat damage)
```

| Property | Value |
|----------|-------|
| Health | 90 |
| Attack type | Melee |
| Attack damage | 3 per 1s windup |
| Crit | 15%, "Slam": 12 damage after a 2s windup |
| Drop pool | `[{item_id: "herb_bundle", weight: 3}, {item_id: "herbal_tonic", weight: 1}, {item_id: "firecracker", weight: 1}]` |
| Drop count | 2–3 |

**Cannot do:** Cannot move, cannot buff itself.

### Enemy — Goblin

**Description:** A basic humanoid enemy. Slightly tougher than slime.
**Role:** Moderate threat that encourages the player to craft healing items during combat.

```
States: Alive, Dead

Transitions:
- Alive → Dead: HP <= 0
```

| Property | Value |
|----------|-------|
| Health | 160 |
| Attack type | Melee |
| Attack damage | 7 per 1s windup |
| Crit | 15%, "Smash": 28 damage after a 2s windup |
| Drop pool | `[{item_id: "iron_plate", weight: 2}, {item_id: "herb_bundle", weight: 2}, {item_id: "herbal_tonic", weight: 1}]` |
| Drop count | 3–4 |

**Cannot do:** Cannot move, cannot buff itself.
**Notes:** Appears as a solo enemy or in groups in the later encounters of Goblin Cave.

### Enemy — Goblin Archer

**Description:** A goblin that shoots from behind the melee line. Uses the Goblin sprite for now.
**Role:** Pressure on the weakest party member, so the Mage and Healer are not perfectly safe while the Fighter tanks.

```
States: Alive, Dead

Transitions:
- Alive → Dead: HP <= 0
```

| Property | Value |
|----------|-------|
| Health | 60 |
| Attack type | Missile |
| Attack damage | 5 per 1s windup, to the weakest member |
| Crit | 15%, "Arrow": 20 damage after a 2s windup |
| Drop pool | `[{item_id: "firecracker", weight: 3}, {item_id: "bomb", weight: 1}, {item_id: "herb_bundle", weight: 1}]` |
| Drop count | 2–3 |

**Cannot do:** Cannot move, cannot buff itself.

---

## 6. Win and Fail Conditions

### Shop Mode — Session Win

- **Condition:** All 10 customers have been served or rejected.
- **On win:** Session summary screen displays — gold earned, items sold, fulfilled count, satisfied customer portraits. Player taps Continue → enters Prep Phase.

### Shop Mode — No Fail State

- The player cannot lose in shop mode. Rejecting all customers yields zero gold and slight reputation loss, but the session always completes.

### Dungeon Mode — Win

- **Condition:** Progress reaches 100% (all encounters cleared).
- **On win:** Dungeon summary (cleared) screen — gold reward, any blueprint reward, +25 reputation gained. All items on the dungeon board are discarded. Return to Prep Phase.

### Dungeon Mode — Fail

- **Condition:** All 3 party members knocked out (HP reaches 0).
- **On fail:** Dungeon summary (failed) screen — reputation penalty applied. Return to Prep Phase. All items on the dungeon board are lost. Partial progress (encounters cleared) is wiped. Shop board state is unaffected.

---

## 7. Progression

- **Level structure:** Linear. One dungeon (Goblin Cave) with 3 encounters at 20%, 50%, 80% progress:
  - Encounter 1 (20%): 2× Slime
  - Encounter 2 (50%): 1× Goblin Archer, 1× Goblin
  - Encounter 3 (80%): 2× Goblin
- **Number of dungeons:** 1 (MVP). More planned for later versions.
- **Progression unlock:** Reputation-based. Fulfilling orders earns reputation points. Crossing thresholds unlocks new customer tiers and dungeon access.
- **Difficulty scaling:** Customer orders demand more advanced items at higher reputation. Dungeon enemies have more HP and damage in later encounters.
- **Save / checkpoint system:** Auto-save after session end, after purchases, and after dungeon end. Single JSON file at `user://save_data.json`.

### Reputation Thresholds

| Level | Points Required | Unlocks |
|-------|----------------|---------|
| Low | 0–99 | Basic customers |
| Mid | 100–299 | Standard customers, dungeon access (at 150 pts) |
| High | 300+ | Premium customers (deferred) |

### What Persists Between Sessions

- Gold balance
- Blueprints unlocked
- Upgrades purchased
- Reagent inventory (Dictionary[String, int])
- Board state (items on grid carry over)
- Grid size (if upgraded)
- Reputation points

---

## 8. Screens and UI

### Main Menu
- Elements: Game title, New Game button, Continue button (disabled if no save), Privacy policy link, "Privacy choices" button (shown only when UMP says privacy options are required; reopens the consent form)
- Does NOT have: Animated background, settings menu, credits, ads

### Shop Mode (In-Game)
- **Top:** Customer queue — current customer portrait + 1–3 order cards showing item icons and quantities + reject button. On the left side, the current customer's image is shown, with a "Reject" button at the bottom. On the right side, their 1–3 orders are stacked vertically, each showing item icon, quantity, and gold reward. Tapping an order card fulfills it. **Parked:** Show silhouette of other customers behind the current customer, with random movements (just horizontal movements).
- **Center-left:** Merge board (5×5 grid with staging area above it).
- **Right side:** CratePanel — VBoxContainer with crate buy buttons populated from `crates.json` and a discard trash bin below.
- **Overlay (CanvasLayer):** HUD — gold display, reputation badge (always visible during gameplay)
- Does NOT have: Timer, health bar, pause button

### Session Summary
- Elements: Gold earned counter (animated count-up), items sold list, fulfilled count, rejected count, satisfied/disappointed customer portraits, Continue button
- Does NOT have: Star rating, share button

### Prep Phase
- Elements: TabContainer with tabs — Board (rearrange freely), Blueprints (buy blueprints), Upgrades (buy upgrades and reagents). Material crates are purchased during shop sessions. Forecast tab deferred to post-MVP.
- **Overlay (CanvasLayer):** HUD — gold display, reputation badge (always visible during gameplay)
- **Bottom:** Continue button → start next session or enter dungeon. Quit button (with confirmation) → return to Main Menu.
- Does NOT have: Timer, limited item slots

### Dungeon Mode (In-Game)
- **Top:** Progress bar (0–100%)
- **Top row:** Party side — 3 party member cards in slot order (Fighter, Mage, Healer), each with a large sprite, a wide HP bar, the HP number, an attack-type badge (sword = melee, bow = missile) and active buffs. The cards are drop targets for usable items.
- **Below the party, after a gap:** Enemy side — enemies with HP bars and the same attack-type badge. A defeated enemy fades but keeps its place, so the others don't slide over.
- **Attack lines:** every unit winding up an attack has a line along its lane to its target. A fill travels from the attacker toward the target, and the hit (flash, impact, number, HP change) lands when the fill arrives, so the line is both the aim and the countdown. Lines are pixel art: traced block by block on a 4 px grid, in solid colours with no transparency. Thickness grows one block per quarter of the target's current HP the hit takes, so a line as thick as they get means "this finishes it". Melee reads as a swing: a solid fill with a slash head, the attacker lunges, and the hit ends in a slash impact. Missile reads as a flight: a dashed fill with an arrow head, the attacker pulses in place, and the hit ends in a burst. Normal lines are thin, party lines cool blue, enemy lines warm peach. Numbers from several attackers on one target are spread apart.
- **Crits:** a crit's line is gold, outlined and shimmering from the moment its windup starts, with a "!" on the attacker and a pulsing gold tint on its sprite. It pulses just before landing; the hit brings gold numbers, a bigger impact, a screen shake and the crit's name over the attacker.
- **Lanes:** every attack line keeps to its attacker's right, like traffic, so "Fighter hits Goblin" and "Goblin hits Fighter" run in two separate curved lanes that never touch.
- **Volleys:** each combat second plays as two beats: the party's attacks on the tick, the enemies' 0.3 s later (their line fills end on that beat). When an encounter is won or lost, the scene waits 0.8 s so the last hits play out.
- **Danger read-out:** each party member's HP bar shows the chunk everything winding up at it will take as a pulsing "ghost". When that would KO the member, the enemy lines turn red and ring the member; healing during the windup visibly shrinks the danger (red goes back, solid HP returns).
- **Damage trail:** when HP drops, the lost chunk stays pale for a moment and then drains away.
- **Layout rule:** nothing that appears during combat (attack lines, VFX, floating text) may move the board or the unit rows.
- **Between sides:** Encounter banner — label showing encounter number (e.g. "Encounter 1/3"), shown during combat
- **Center/bottom:** Merge board (same grid as shop, separate board state)
- **Staging area:** Enemy drops appear here
- **Overlay (CanvasLayer):** HUD — gold display, reputation badge (always visible during gameplay)
- Does NOT have: Manual attack button, movement controls, inventory screen

### Dungeon Cleared Summary Screen
- Elements: Gold reward, blueprint reward (if any), reputation gained, Continue button

### Dungeon Failed Summary Screen
- Elements: "Party Wiped" message, reputation lost, Continue button

### Merge Choice Popup
- Elements: Compact panel with 2–4 buttons, each showing item icon and name. Variant options show the reagent icon badge if a reagent is consumed.
- Behavior: Appears immediately when merge triggers with 2+ options (or base + variants). Combat continues while popup is open (dungeon mode). Player must choose to proceed.
- Does NOT have: Cancel button, timer

---

## 9. Audio

**In scope for v1.0:** Yes

### Music
- **Shop theme:** Calm, cozy medieval workshop feel. Plays during shop sessions and prep phase.
- **Dungeon theme:** Tense, rhythmic adventure music. Plays during dungeon mode.

### Sound Effects

| Event | SFX Name |
|-------|----------|
| Item placed on board | item_place |
| Merge completed | merge_complete |
| Floating item despawned | despawn |
| Customer order fulfilled | customer_happy |
| Customer rejected | customer_reject |
| Gold earned | gold_earn |
| Session started | session_start |
| Session ended | session_end |
| Dungeon started | dungeon_start |
| Dungeon cleared | dungeon_clear |
| Dungeon failed | dungeon_fail |
| Party member knocked out | ko |
| Blueprint / upgrade purchased | purchase |
| Crate opened | crate_open |

---

## 10. Fixed Values

| Value | Setting | Notes |
|-------|---------|-------|
| Target resolution | 1080×1920 portrait | Android primary |
| Board default size | 5×5 (25 cells) | Expandable to 6×5 via upgrade |
| Merge minimum | 3 connected identical items | Orthogonally adjacent (4-directional) |
| Merge result count | floor(count / 3) result items | Groups of 3 each produce 1 upper-tier item |
| Merge refund | count % 3 source items | Remainder items refunded to board at former positions |
| Merge bonus gold | (count - 3) × floor(source_value × 0.25) | Gold bonus for groups larger than 3; source = the merged item, not the result |
| Despawn timer (default) | 12 seconds | Staging area items |
| Despawn timer (upgraded) | 18 seconds | With Slow Timer upgrade |
| Combat tick interval | 1.0 second | Auto-combat damage frequency |
| Party: Fighter | HP 120, ATK 11 | Melee. Slot 0 (front); takes all melee damage while standing. Crit "Cleave" |
| Party: Mage | HP 50, ATK 14 | Missile: hits the weakest enemy. Highest damage. Crit "Fireball". Auto-attack only for MVP |
| Party: Healer | HP 60, ATK 4 | Melee: hits the front enemy. Lowest damage. Crit "Smite". Auto-attack only for MVP |
| Attack windup | 1 second, every unit | A crit winds up 2x as long |
| Crit chance / damage | 15%, every unit / 4x | 2x damage per second of a normal attack |
| Dungeon walk speed | 0.075 progress/second | Default value; configurable per dungeon definition |
| Session size | 10 customers per session | |
| Starting gold | 50 | |
| Crate discount | 20% | With Crate Discount upgrade |
| Upgrades | Data-driven | Defined in `upgrades.json` (Slow Timer, Crate Discount, Grid Expand) |
| Crates | Data-driven | Defined in `crates.json` (whatever entries exist become buy buttons) |
| Customers | Data-driven (MVP: flat list) | Defined in `customers.json`. Post-MVP: algorithmic generation. |
| Reputation fulfill reward | 10 points | Per fulfilled order |
| Reputation reject penalty | 2 points | Per rejected customer |
| Reputation dungeon fail | 20 points lost | On party wipe |
| Reputation dungeon clear | 25 points gained | On dungeon completion |
| Dungeon gold reward | 400g | Goblin Cave (MVP) |
| Dungeon unlock threshold | 150 reputation points | |

### Item Catalog (MVP)

All items are `.tres` definitions in `resources/definitions/items/`; each item lists its merge results and fire variants. Three families, one role each in the dungeon: herbs heal, metal buffs, powder damages. Tier 1 is always a raw material; tiers 2 to 4 are dungeon-usable, and enemies drop only usable items. Effect values are starting points for playtesting.

Effects in *italics* are defined but not applied yet: CombatEngine only runs `heal` and `buff_attack`, and only party members accept drops, so using such an item consumes it with no effect until the engine supports it.

**Herb family (healing):**

| item_id | Name | Gold | Source | Dungeon effect (party-individual) |
|---------|------|------|--------|------------------|
| herb_leaf | Herb Leaf | 5 | Crates | Raw |
| herb_bundle | Herb Bundle | 20 | 3x herb_leaf; drops | Heal 10 |
| herbal_tonic | Herbal Tonic | 75 | 3x herb_bundle; drops | Heal 30 |
| healing_potion | Healing Potion | 280 | 3x herbal_tonic (bp_healing_potion) | Heal 90 |
| battle_elixir | Battle Elixir | 280 | 3x herbal_tonic (bp_battle_elixir) | *Next 3 attacks crit* |
| phoenix_draught | Phoenix Draught | 480 | 3x herbal_tonic + fire_essence (bp_phoenix_draught) | *Revive a KO'd member at 50% HP* |

**Metal family (buffs):**

| item_id | Name | Gold | Source | Dungeon effect (party-individual) |
|---------|------|------|--------|------------------|
| iron_ore | Iron Ore | 5 | Crates | Raw |
| iron_ingot | Iron Ingot | 20 | 3x iron_ore | Raw |
| iron_plate | Iron Plate | 75 | 3x iron_ingot (bp_iron_plate); drops | *25 HP absorb shield* |
| sword | Sword | 280 | 3x iron_plate (bp_sword) | +4 ATK for 20s |
| iron_shield | Iron Shield | 280 | 3x iron_plate (bp_iron_shield) | *60 HP absorb shield* |
| flame_sword | Flame Sword | 480 | 3x iron_plate + fire_essence (bp_flame_sword) | +8 ATK for 20s |

**Powder family (damage):**

| item_id | Name | Gold | Source | Dungeon effect |
|---------|------|------|--------|------------------|
| blast_powder | Blast Powder | 5 | None yet (planned crate) | Raw |
| firecracker | Firecracker | 20 | 3x blast_powder; drops | *15 damage to one enemy* |
| bomb | Bomb | 75 | 3x firecracker (bp_bomb); drops | *45 damage to one enemy* |
| cluster_bomb | Cluster Bomb | 280 | 3x bomb (bp_cluster_bomb) | *30 damage to every enemy* |
| fire_bomb | Fire Bomb | 480 | 3x bomb + fire_essence (bp_fire_bomb) | *40 damage to every enemy* |

**Reagent:**

| item_id | Name | Price | Notes |
|---------|------|-------|-------|
| fire_essence | Fire Essence | 100g | Bought in prep phase. Stored in reagent_inventory. |

**Deferred (data-only, not in MVP gameplay):**

| item_id | Name | Family | Notes |
|---------|------|--------|-------|
| wood_shaft | Wood Shaft | wood | Wood family items exist in data for forward compatibility. |
| magic_focus | Magic Focus | wood | |
| staff | Staff | wood | Blueprint exists (bp_staff) but Wood family not in MVP. |
| wand | Wand | wood | Blueprint exists (bp_wand) but Wood family not in MVP. |
| flame_staff | Flame Staff | wood | Variant of staff + fire_essence. Blueprint exists (bp_flame_staff) but Wood family not in MVP. |

---

## 11. Platform and Technical Notes

- **Platform:** Android + iOS
- **Orientation:** Portrait
- **Engine:** Godot 4.x (GDScript)
- **Min Android version:** API 24 (export preset)
- **Target Android API:** 36, which Google Play requires for new apps and updates from 2026-08-31. The export preset is still at 33 and must be raised before release.
- **Ad integration:** AdMob interstitials only (see Submodule — Ads). Requires the INTERNET permission (currently off in the export preset) and a Gradle build (already on).
- **Consent (UMP/TCF):** Yes. Google's UMP consent message runs on launch before any ad request, and there's an in-game "Privacy choices" entry point. Store and account setup is in `docs/ADS-COMPLIANCE.md`.
- **Save system:** Yes — single JSON file (`user://save_data.json`), auto-save at checkpoints
- **In-app purchases:** Not for v1.0 (paid ad removal is in `docs/TODO.md`)
- **Performance targets:** 60fps on mid-range Android devices
- **Rendering:** 2D, mobile renderer

---

## 12. Art Direction

- **Visual style:** Pixel art, anime-style. Chibi full body character in Dungeon mode.
- **Colour palette:** Warm fantasy tones — browns, golds, deep greens for shop mode. Darker blues and purples for dungeon mode.
- **Art for v1.0:** Placeholder — colored squares with text labels for items. Final art to be created later.
- **Notes:** No procedural generation of art. All sprites are hand-drawn or placeholder. Sprite sheets/texture atlases recommended for performance.

---

## 13. Submodules

> **Cross-reference:** Scene management (Core/Main/HUD/MainMenu), Save/Load, and Audio subsystems are documented in full in `ARCHITECTURE.md`. The submodules below cover game logic and systems that need GDD-level design context.

---

### Submodule — Merge System

**What it does:**
Detects when 3+ identical items are orthogonally connected on the grid, automatically triggers a merge, resolves the result through the recipe tree, and places output items at the group's center of mass and nearby cells. Every group of 3 produces 1 upper-tier item (so a group of 6 produces 2). Remainder items (count % 3) are refunded as source items at former positions. Bonus gold is awarded for oversized groups. Supports chain merges.

**What triggers it:**
Any board change — item placed, item removed, or item swapped. Also re-triggers after a merge completes (chain merge).

**Inputs:**
- Board grid state (which cells hold which items)
- Recipe tree from the item definitions (each item's merge results and reagent variants)
- Blueprint ownership from GameManager (which results are visible)
- Reagent inventory from GameManager.reagent_inventory (for reagent variant options)

**Outputs:**
- Removes consumed items from the grid
- Places floor(count / 3) result items at center of mass and nearby empty cells
- Refunds (count % 3) source items at former group positions
- Awards bonus gold
- Triggers chain rescan

**States / Logic:**
```
1. Scan grid → flood-fill from each occupied cell
2. Group >= 3 connected identical items → create MergeGroup
3. If multiple groups, queue them (process one at a time)
4. Execute first group:
   a. Remove all items in group from grid
   b. Get available recipes from unlocked blueprints
   c. If the result has reagent combo definitions in reagent_combos.json: also populate variant options from reagent inventory (see Reagent Variants submodule)
   d. If 1 option (no variants) → auto-place floor(count / 3) result items
   e. If 2+ options (or base + variants) → show merge choice popup (choice applies to all result items)
   f. On choice → place floor(count / 3) result items, refund (count % 3) source items at former positions, add bonus gold, consume reagent if variant chosen, emit signal
   g. Rescan grid for chain merges
```

**Fixed values:**

| Property | Value | Notes |
|----------|-------|-------|
| Merge minimum | 3 items | Orthogonally connected |
| Merge result count | floor(count / 3) result items | Each group of 3 produces 1 upper-tier item |
| Merge refund | count % 3 source items | Remainder refunded to board at former positions |
| Merge bonus gold | (count - 3) × floor(source_value × 0.25) | Gold bonus for groups larger than 3; source = the merged item, not the result |


**GDD dependencies:**
- Economy
- Reputation
- Blueprint
- Reagent

**Merge-safe placement:**

When items are generated from crates or enemy drops, the system attempts to place them directly on the board rather than in the staging area. A cell is "safe" for an item if placing it there would NOT create a group of 3+ orthogonally connected identical items (i.e., it would not immediately trigger an unintended merge). The system scans empty cells for a safe spot. If no safe cell exists (board is full, or all empty cells would trigger a merge), the item goes to the staging area as a fallback. This applies to crate opening and enemy drops — not to player drag placement, which the player controls intentionally.

### Submodule — Economy

**What it does:**
Manages all gold transactions — earning from customer fulfillment, spending on crates, blueprints, reagents, and shop upgrades. Generates crate contents from item pools. Applies discount upgrades.

**What triggers it:**
Player taps a buy button (blueprint, reagent, or upgrade) in prep phase, a crate buy button during a shop session, a customer order is fulfilled, or if a dungeon is cleared.

**Inputs:**
- Player's current gold (from GameManager)
- Crate/blueprint/reagent/upgrade definitions from JSON files
- Discount upgrade status from GameManager.purchased_upgrades

**Outputs:**
- Modifies GameManager.gold
- Spawns items on the board directly when possible (via BoardGrid.place_or_stage), only using staging area as fallback when no safe cell exists
- Adds reagents to GameManager.reagent_inventory (Dictionary[String, int]) directly — reagents are never placed on the board or in staging
- Adds blueprints to GameManager.unlocked_blueprints
- Adds upgrades to GameManager.purchased_upgrades
- Applies upgrade effects (grid size, despawn timer, discount)

**States / Logic:**
```
Purchase flow:
1. Check gold >= price (apply discount if applicable)
2. Deduct gold
   3. If crate → pick random items from crate's pool definition (weighted), place on board directly via merge-safe placement; only use staging if no safe cell exists
4. If reagent → add reagents to GameManager.reagent_inventory directly (no staging, no board items)
5. If blueprint → add to unlocked_blueprints, emit blueprint_added
6. If upgrade → add to purchased_upgrades, apply effect, emit upgrade_added
7. Trigger auto-save
```

**Fixed values:**

| Property | Value | Notes |
|----------|-------|-------|
| Starting gold | 50 | |
| Crate discount | 20% (multiply by 0.8) | With upgrade only |
| Crate definitions | Fully data-driven, one `.tres` per crate | Each crate has: name, cost, item_count range, weighted item pool. Whatever crate definitions exist are shown as buy buttons, cheapest first. No hardcoded crate types. |
| Crates (current) | Basic Crate 10g, Metal Crate 25g, Herb Crate 25g | Basic: iron_ore (weight 3) / herb_leaf (weight 2), 3-5 items. Metal: iron_ore (weight 4) / iron_ingot (weight 1), 3-4 items. Herb Crate (new): herb_leaf (weight 4) / herb_bundle (weight 1), 3-4 items. |
| Fire Essence price | 100g | 1 reagent, goes directly to inventory |

**Does NOT:**
- Set prices dynamically (all prices are fixed in JSON)
- Implement real-money purchases

**GDD dependencies:**
- Merge system
- Reagent
- Blueprint

---

### Submodule — Reputation System

**What it does:**
Tracks reputation points and determines the player's reputation level (Low/Mid/High). Gates customer tiers and dungeon access based on thresholds.

**What triggers it:**
Customer order fulfilled (+10 pts), customer rejected (-2 pts), dungeon cleared (+25 pts), dungeon failed (-20 pts).

**Inputs:**
- Events from ShopSession (fulfill, reject)
- Events from DungeonController (dungeon cleared, dungeon failed)
- Current reputation points from GameManager

**Outputs:**
- Updates GameManager.reputation_points
- Emits reputation_changed when level changes
- Provides customer tier pool to CustomerGenerator (post-MVP; MVP uses flat list)
- Provides dungeon unlock status

**States / Logic:**
```
Levels: [0, 100, 300]
- Low: 0–99 pts → Basic customers only
- Mid: 100–299 pts → Basic + Standard customers
- High: 300+ pts → All customer tiers

Dungeon unlock: 150 pts required
```

**Fixed values:**

| Property | Value | Notes |
|----------|-------|-------|
| Fulfill reward | 10 pts | Per order fulfilled |
| Reject penalty | 2 pts | Per customer rejected |
| Dungeon clear reward | 25 pts | On dungeon completion |
| Dungeon fail penalty | 20 pts | On full party wipe |
| Dungeon unlock | 150 pts | |
| Mid threshold | 100 pts | |
| High threshold | 300 pts | |

**Does NOT:**
- Decrease reputation below 0
- Directly change customer generation (provides tier pool — post-MVP; MVP uses flat list)
- Affect dungeon difficulty

**GDD dependencies:**
- Reads/writes GameManager.reputation_points
- Affects CustomerGenerator (tier pool — post-MVP; MVP uses flat list)
- Affects Prep Phase (dungeon button visibility)

---

### Submodule — Blueprint System

**What it does:**
Gates recipe branches behind purchasable blueprints. Without a blueprint, merging works but the player sees fewer options. Blueprints are bought with gold or earned from dungeon completion.

**What triggers it:**
Player buys a blueprint in prep phase, or completes a dungeon that awards a blueprint.

**Inputs:**
- Player's gold (from GameManager)
- Blueprint definitions from `resources/definitions/blueprints/`
- Recipe tree from the item definitions

**Outputs:**
- Adds blueprint ID to GameManager.unlocked_blueprints
- Makes additional recipe options visible in merge choice popup
- Emits blueprint_added signal

**States / Logic:**
```
Each blueprint has:
- bp_id: unique identifier (e.g., "bp_iron_plate")
- name: display name
- cost: gold price
- dependencies: ids of blueprints required to make this unlockable
- unlocks_item: the item_id this blueprint unlocks

Blueprints gate two types of content:
1. Recipe branches — additional merge options in the recipe tree
2. Reagent variants — variant items when a reagent is applied to a merge result that has a reagent combo definition

At merge time, RecipeResolver filters options:
- For each possible result, check if a blueprint exists whose "unlocks_item" matches
- If blueprint exists AND is in unlocked_blueprints → show option
- If no blueprint required → always show

For reagent variants (items with entries in reagent_combos.json), see Reagent Variants submodule.
```

**Fixed values:**

| Blueprint | Cost | Type | Unlocks |
|-----------|------|------|---------|
| Iron Plate | 150g | Recipe | iron_ingot → iron_plate |
| Sword | 600g | Recipe | iron_plate → sword |
| Staff | 30g | Recipe | wood_shaft → staff *(deferred — Wood family)* |
| Healing Potion | 300g | Recipe | herbal_tonic → healing_potion |
| Battle Elixir | 400g | Recipe | herbal_tonic → battle_elixir |
| Iron Shield | 900g | Recipe | iron_plate → iron_shield |
| Bomb | 500g | Recipe | firecracker → bomb |
| Cluster Bomb | 1200g | Recipe | bomb → cluster_bomb |
| Phoenix Draught | 1500g | Variant | herbal_tonic + fire_essence → phoenix_draught |
| Fire Bomb | 1800g | Variant | bomb + fire_essence → fire_bomb |
| Wand | 50g | Recipe | magic_focus → wand *(deferred — Wood family)* |
| Flame Sword | 1500g | Variant | iron_plate + fire_essence → flame_sword |
| Flame Staff | 100g | Variant | staff + fire_essence → flame_staff *(deferred — Wood family)* |

**Does NOT:**
- Change the recipe tree itself (only hides/shows options)
- Allow selling or removing blueprints
- Stack or duplicate blueprints

**GDD dependencies:**
- Reads GameManager.gold and unlocked_blueprints
- Affects RecipeResolver (filtering recipe branches)
- Affects Reagent Variants (gates variant options)
- Affects Merge System (available choices)

---

### Submodule — Reagent Variants

**What it does:**
When a merge produces an item that has a reagent combo definition in `reagent_combos.json`, the merge choice popup includes variant options alongside the base result if the player owns both the required blueprint and the corresponding reagent. Selecting a variant consumes the reagent from inventory and produces the variant item.

**What triggers it:**
A merge completes and the result item has entries in `reagent_combos.json`. The system checks for applicable variants and adds them as additional options.

**Inputs:**
- The item_id of the merge result (base item)
- Reagent combo definitions from reagent_combos.json
- Blueprint ownership from GameManager.unlocked_blueprints
- Reagent inventory from GameManager.reagent_inventory

**Outputs:**
- Adds variant options to the merge choice popup
- Consumes reagent from inventory if variant is chosen
- Places variant item at the merge position

**States / Logic:**
```
On merge producing a variant-eligible item:
1. Resolve base merge result(s) as normal
2. For each base result option:
   a. Look up combos in reagent_combos.json matching the base item
   b. For each combo:
      - Check required blueprint is unlocked
      - Check player has >= 1 of the required reagent
      - If both → add variant as additional merge option
3. Present all options (base + variants) in merge choice popup
4. Player selects one:
   a. If base result → place as normal
   b. If variant → consume 1 reagent, place variant item
```

**Fixed values:**

| Variant | Base + Reagent | Result | Blueprint Required |
|---------|----------------|--------|-------------------|
| Flame Sword | iron_plate + fire_essence | flame_sword | bp_flame_sword |
| Flame Staff | staff + fire_essence | flame_staff | bp_flame_staff *(deferred — Wood family)* |

**Does NOT:**
- Apply to items without reagent combo definitions in reagent_combos.json
- Require reagents to be placed on the board
- Auto-apply reagents — player must actively choose the variant
- Consume reagents if the base result is chosen

**GDD dependencies:**
- Reads reagent_combos.json
- Reads GameManager.unlocked_blueprints
- Reads/writes GameManager.reagent_inventory
- Affects Merge System (adds options to merge choice popup)

---

### Submodule — Dungeon Combat

**What it does:**
Manages auto-combat between the party and enemies during dungeon mode. Both sides follow the same rules: every attack winds up before it hits one target, crits are rolled at windup start, melee attackers hit the front of the other side and missile attackers its weakest unit. Handles HP, knockouts, buffs, and usable item effects.

**What triggers it:**
Encounter spawns enemies. Combat ticks every 1 second until all enemies are dead or the party wipes. Progress halts while combat is active — the walk timer resumes only after all enemies in the current encounter are defeated.

**Inputs:**

- Party member stats (HP, attack, active buffs)
- Enemy stats (HP, attack)
- Usable item effects applied by player (heal, buff_attack)

**Outputs:**
- Reduces enemy HP (party damage)
- Reduces party member HP (enemy damage)
- Triggers party member knockout when HP = 0
- Spawns enemy drops via DropManager on enemy death
- Signals dungeon victory or wipe to DungeonController

**States / Logic:**
```
Party members (3): Fighter, Mage, Healer
- Each has: max_hp, current_hp, attack, attack_type, windup, crit_chance, active_buffs
- Buffs have: effect, power, duration (seconds)

Combat tick (every 1 second):
1. For each active party member: count down its windup; when it ends, hit the locked target
   (re-picked if it fell) for attack + buffs, x4 on a crit. Melee targets the front enemy
   (lowest alive slot), missile the weakest.
2. Check enemy deaths → spawn drops
3. For each alive enemy: the same against the party (melee: front member; missile: weakest member)
4. Check member knockouts → emit signal
5. If all enemies dead → victory
6. If all members KO → wipe
7. Tick all buffs (reduce duration, remove expired)
8. Every idle unit starts a new windup: roll the crit (a crit winds up 2x as long), lock a target.
   The line from attacker to target fills over the windup (see Dungeon Mode (In-Game)).
```

**Fixed values:**

| Property | Value | Notes |
|----------|-------|-------|
| Combat tick interval | 1.0 second | |
| Min damage per tick | 1 | Even if attack / targets < 1 |
| Walk speed | 0.075 progress/sec | Default value; configurable per dungeon definition; ~13s total walk time (combat adds ~25s) |
| Party size | 3 members | Fighter, Mage, Healer |

**Does NOT:**
- Allow player to control who attacks whom
- Have elemental weaknesses or resistances
- Support target priority or taunt mechanics
- Revive knocked-out members during combat

**GDD dependencies:**

- Reads enemy data from the enemy definitions (`resources/definitions/enemies/`)
- Reads usable item effects from the item definitions (`resources/definitions/items/`)
- Affects party member HP and buffs
- Affects DropManager (spawns drops on enemy death)
- Affects Reputation System (penalty on wipe)

**Parked:**

* Specific party members can take damage for other members
* Make a front line and rear line distinction, most monster attacks cannot hit the rear line without wiping out the front line.

---

### Submodule — Ads

**What it does:**
Shows a full-screen AdMob interstitial at natural breaks between play sessions. It's the only ad format in v1.0: there are no banners, no rewarded ads and no paid removal yet.

**What triggers it:**
The player leaving a summary screen for the prep phase: the Session Summary's Continue, or the Dungeon Summary's Continue after a **cleared** dungeon. The ad shows before prep loads. If no ad is ready, or a rule below blocks it, the transition goes ahead with no delay.

**Rules:**
- **Never:**
  - on app launch or quit, or on the main menu or intro;
  - during a shop session or dungeon run;
  - over a popup;
  - after a dungeon wipe (a loss plus an ad stacks frustration).
- **Grace period:** no ads until the player has completed `AD_GRACE_SESSIONS` shop sessions in a new game. This needs a persistent count of completed shop sessions.
- **Frequency cap:** at least `AD_MIN_INTERVAL` seconds since the last ad was shown. The AdMob ad-unit frequency cap is a backstop, not the rule.
- **Consent first:** the UMP consent check runs on every launch, and ads are only requested once UMP allows it. When UMP says privacy options are required, the main menu shows a "Privacy choices" button next to the privacy policy link.
- **Failure is silent:** no fill, a load error, or no consent just skips the ad. Game flow never waits on an ad.
- **During an ad:** music and SFX pause, and the game saves before the ad shows, since a click can leave the app.
- **Builds:** debug and closed-test builds use Google's test interstitial unit. Only production builds use the real unit.

**Fixed values (starting points, tune in playtesting):**

| Property | Value | Notes |
|----------|-------|-------|
| AD_GRACE_SESSIONS | 2 | Ad-free completed shop sessions; the first ad can follow session 3 |
| AD_MIN_INTERVAL | 240 s | Between shown ads; about one per shop session (5-10 min) |
| Eligible breaks | Session Summary → Prep; Dungeon Cleared Summary → Prep | Not after a wipe |

**Does NOT:**
- Show banners, rewarded, app-open or native ads
- Reward, encourage or trick the player into clicking an ad
- Block or delay any screen transition while an ad loads

**GDD dependencies:**
- Shop session and dungeon summary transitions (EventBus)
- Save system (save before showing)
- Audio (pause and resume)

---

## 14. Decisions Log

| Date | Decision | Reason |
|------|----------|--------|
| 2026-06-02 | Use 4-tier depth instead of 2-tier for MVP | 2 tiers too shallow for meaningful merge gameplay; 4 tiers with 2 families keeps item count small (11 MVP items) |
| 2026-06-02 | Flame Sword is Tier 4, 200g (not Tier 5) | Keeps within the 4-tier system; variant items are same tier as base with higher gold value |
| 2026-06-02 | items.json is a dict keyed by item ID | O(1) lookup vs array iteration |
| 2026-06-02 | recipes.json uses simple item_id → [results] format | Blueprint gating resolved at runtime, not in data structure |
| 2026-06-02 | Autoloads don't use class_name | Globally accessible by registration name; avoids naming conflicts |
| 2026-06-02 | RecipeResolver registered as autoload | Needed globally by multiple systems (board, economy, dungeon); was previously a scene child causing path issues |
| 2026-06-02 | Board state separate in GameManager vs live BoardGrid | GameManager stores for save/load; BoardGrid is live data model; synced at save/load time |
| 2026-06-02 | Dungeon board is separate instance from shop board | Items don't persist between modes; dungeon starts with empty board |
| 2026-06-02 | Include Gem and Wood families in items.json | Forward compatibility; data exists but not in MVP gameplay |
| 2026-06-03 | Reagents stored as inventory counts, not board-placed items | Variants appear as merge choice options for Tier 4 merges; avoids wasting board space and adjacency confusion; reagent consumed only if player picks the variant |
| 2026-06-03 | Material crates purchasable during shop sessions only | Player buys crates while actively crafting — items go straight to staging. Reagents bought separately in prep phase, go directly to inventory. |
| 2026-06-03 | Dungeon progress halts during combat | Progress bar only advances while party is walking; walk speed is configurable per dungeon definition |
| 2026-06-04 | Party member stats confirmed | Fighter (HP 90, ATK 14), Mage (HP 50, ATK 18), Healer (HP 60, ATK 5) |
| 2026-06-04 | Party abilities deferred to post-MVP | Auto-attack only for MVP; no healer ability, no skills, no active party abilities. Usable-item buffs (buff_attack) remain in MVP |
| 2026-06-04 | Customer generation: flat list for MVP | Algorithmic generation deferred; MVP uses hand-authored customer list |
| 2026-06-04 | Dungeon wipe: partial progress lost on exit/fail | Post-MVP: exit penalty + anti-scumming measures |
| 2026-06-04 | Demand forecast deferred | Forecast tab and forecast_bias not in MVP |
| 2026-06-04 | Premium customer tier deferred | CustomerGenerator only produces Basic and Standard for MVP |
| 2026-06-04 | Reject penalty: reputation only, no gold cost | -2 reputation per rejected customer |
| 2026-06-04 | Usable item values confirmed for v1.0 | Healing Potion: heal 30 HP; Battle Elixir: +5 ATK for 10s. Tune during playtesting |
| 2026-06-04 | Dungeon clear reputation reward: +25 | |
| 2026-06-04 | Goblin Cave: no blueprint reward | First dungeon awards gold + reputation only. Post-MVP dungeons may award blueprints. |
| 2026-06-10 | Remove `tier` field from items.json | Merge chains fully defined by recipes.json; reagent variant eligibility determined by reagent_combos.json entries; no derived or computed tier property needed |
| 2026-06-11 | Merge-safe placement for generated items | Crate contents and enemy drops are placed directly on the board when a "safe" empty cell exists (won't trigger an unintended merge). Staging area used only as fallback. Does not apply to player drag placement. |
| 2026-09-25 | Goblin Cave retune + telegraphed heavy attacks | Unassisted party wipes in encounter 3; one Healing Potion (now 40 HP) clears with a KO, two clear cleanly. Enemies drop refined_potion / herb_bundle so a potion is craftable in-run (~90% by encounter 3). Walk cut from ~50s to ~13s. Healing Potion blueprint is effectively required to clear. |
| 2026-09-26 | Melee vs. missile attacks, party slots | Melee enemies hit the front member (party slot order Fighter, Mage, Healer; the next slot takes over when the front falls); only missile enemies reach the back line, with low damage. New Goblin Archer (missile) replaces the Slime in encounter 2. Retune: Fighter HP 90 → 120; Slime ATK 2 / Slam 12; Goblin ATK 4 / Smash 30. Balance targets unchanged: unassisted wipe in encounter 3, one potion clears with a KO, two clear cleanly. |
| 2026-09-27 | Party attack types, attack tracers, two-lane lines | Party members get melee/missile like enemies (Fighter and Healer melee, Mage missile), so enemies die one at a time and pressure eases mid-fight instead of every enemy dropping at once. Retune: Goblin HP 170 → 160, ATK 4 → 5 (encounter 2 keeps Archer first: Goblin-first put the first kill at 86% of the fight). Every basic attack shows a tracer on its lane (lanes keep to the attacker's right, so opposite attacks never overlap); melee vs. missile differ in motion, tracer and impact, plus idle sword/bow badges. Enemy hits play 0.3 s after the party's, and HP bars change when hits arrive. Balance targets unchanged. |
| 2026-09-27 | Content lives only in `.tres` definitions | The `data/items.json`, `party.json` and `enemies.json` fallback copies are gone. The Android export listed files by hand and shipped no definitions, so phones silently ran on the JSON copies; it now exports all resources minus tmp/test/docs/tools. Board saves store item ids only (a sprite texture can't go through JSON, so reloaded boards had lost their icons); `SAVE_VERSION` 3. |
| 2026-09-27 | Every attack winds up; crits replace heavy attacks | Every attack now winds up (1 s) with a visible line, so every hit is readable before it lands. Heavy attacks are gone; instead each windup rolls a 15% crit (2x windup, 4x damage: 2x DPS with a longer warning), shown gold from the start. Multi-target attacks removed: missile now hits the weakest unit instead of splitting. Line width follows the hit's share of the target's current HP. Retune (sim medians): party ATK Fighter 11, Mage 14, Healer 4 (Mage > Fighter > Healer); Slime 3, Goblin 7, Archer 5. No items: wipe in encounter 3 (~89%); one potion: ~67% clear, usually with a KO; two potions: ~98% clear, no KOs; combat ~23-26 s. |
| 2026-09-27 | Telegraph lines and HP ghost instead of labels | The "Smash: Fighter in 2" label and the hidden target marker resized the unit rows and pushed the board down. Replaced with a line from enemy to target whose fill is the countdown (red when lethal, width by damage) and a ghost chunk on the target's HP bar. Party cards widened (128 px sprites, 270 px HP bars, HP numbers, 32 px buff text); a fixed gap between the party and enemy rows gives the lines room; dead enemies keep their slot. |
| 2026-09-28 | Dungeon item roles and usable-only drops | Herbs heal, metal buffs, powder (new family) damages. Tier 1 stays raw; tiers 2 to 4 are dungeon-usable, and enemy drop pools hold only usable items (Slime: herbs, Archer: powder, Goblin: plates and herbs). refined_potion renamed herbal_tonic (`SAVE_VERSION` 4). Fire essence now makes phoenix_draught from tonics instead of a Healing Potion from herb bundles, which skipped a tier and bp_healing_potion. absorb, crit_charges, revive, damage and enemy targets are defined but not implemented in CombatEngine yet. The old balance targets no longer hold (heals now drop directly); re-sim before tuning. |
| 2026-09-28 | All content is `.tres`; `data/` is gone | Recipes, reagent variants, blueprints, crates, upgrades, reagents, customers and dungeons moved from JSON to typed definitions under `resources/definitions/`. Definitions reference each other directly, so a broken link shows up in the editor and in the integrity tests instead of as a silent id typo; references only point down the tiers because Godot can't load cyclic resources. Ids are unchanged, so saves still load (no `SAVE_VERSION` bump). Fire Essence costs 100 as specified; `reagents.json` had drifted to 75. Shop listings are ordered cheapest first. |
| 2026-09-28 | v1.0 is ad-supported: interstitials only | AdMob interstitials at summary-to-prep breaks, with UMP consent (Submodule — Ads). No persistent banner: it would take about 130-240 px of a full portrait layout, and it would sit next to drag-and-drop input, which risks accidental clicks (an AdMob policy violation) for little revenue. No rewarded ads yet. Paid ad removal is deferred (`docs/TODO.md`). Store and account setup: `docs/ADS-COMPLIANCE.md`. |
| 2026-09-28 | Economy baseline retune | Margins now rise with tier (price / material cost at least 1.3 / 1.6 / 2.0 at depth 2 / 3 / 4); tier-4 herbs had sold below cost. New Herb Crate (herbs cost 6.25g per leaf through the mixed crate). Merge bonus pays 25% of the *source* value per extra item; paying 50% of the result's value on refunded extras was a repeatable gold farm. Blueprint and upgrade costs scaled so buying everything takes about 12 best-case sessions instead of about 2.5. Checked by `tmp/shop-improvements/sim/economy_sim.gd`. |

---

## 15. Open Questions

- Balance tuning: all gold values, reputation thresholds, and economy numbers are placeholders until playtesting
- Dungeon mid-exit penalty (post-MVP): what penalty and which anti-scumming measures?
