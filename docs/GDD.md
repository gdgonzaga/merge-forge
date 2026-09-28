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
- Shop level: 60 levels from XP that never decreases; every unlock (customer archetype, dungeon, blueprint, crate, reagent) is a `min_shop_level` on its definition
- Economy: gold, material crates, reagent purchases, shop upgrades
- Prep phase between sessions: buy blueprints/reagents/upgrades, rearrange board; material crates bought during shop sessions
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
- Party Abilities / Active Skills (auto-attack only for MVP)
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

1. **Session starts** — 10 customers are dealt from the level-unlocked archetypes, seeded per session (a market modifier can change the count, e.g. Caravan Day +3)
2. **Customer arrives** — displays portrait and 1–3 possible orders
3. **Player crafts** — buys crates, places materials on the board, merges them into more advanced items
4. **Player fulfills order** — taps one order card to deliver the required items, earning gold and XP (more with a longer fulfil streak). Only one order per customer can be fulfilled; remaining orders are discarded. OR rejects the customer, which breaks the fulfil streak; no XP
5. **Repeat** steps 2–4 for all 10 customers
6. **Session summary** — shows gold and XP earned, items sold, satisfied customer portraits, and a level-up panel if a level was crossed
7. **Prep phase** — Forecast tab (default) previews the next session: market modifier card, demand by item family, first 3 customers; spend gold on blueprints, reagents, upgrades (board rearrange deferred to post-MVP)
8. **Choose** — start next session or enter dungeon (if unlocked)

### Dungeon Mode Loop

1. **Party enters dungeon** — party of 3 members walks forward automatically
2. **Encounter spawns** — enemies appear at predefined progress points, party stops and fights. **Progress halts during combat** — the progress bar only advances while the party is walking.
3. **Player crafts in real time** — enemy drops are placed directly on the board when safe cells exist, or in staging area as fallback; player merges items
4. **Player supports party** — drags usable items (heals, buffs) to party members
5. **Combat resolves** — auto-combat ticks, enemies die and drop materials, or party members get knocked out
6. **Repeat** steps 2–5 until all enemies in the dungeon are defeated and progress reaches 100%
7. **Dungeon ends** — rewards (gold, blueprints, XP) on clear; nothing on a wipe

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
- Prep Phase → Dungeon: player taps Enter Dungeon (requires the dungeon's `min_shop_level`)
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

- The player cannot lose in shop mode. Rejecting all customers yields zero gold and zero XP, but the session always completes.

### Dungeon Mode — Win

- **Condition:** Progress reaches 100% (all encounters cleared).
- **On win:** Dungeon summary (cleared) screen — gold reward, any blueprint reward, XP gained (the dungeon's `xp_reward`), and a level-up panel if a level was crossed. All items on the dungeon board are discarded. Return to Prep Phase.

### Dungeon Mode — Fail

- **Condition:** All 3 party members knocked out (HP reaches 0).
- **On fail:** Dungeon summary (failed) screen — no XP. Return to Prep Phase. All items on the dungeon board are lost. Partial progress (encounters cleared) is wiped. Shop board state is unaffected.

---

## 7. Progression

- **Level structure:** Linear. One dungeon (Goblin Cave) with 3 encounters at 20%, 50%, 80% progress:
  - Encounter 1 (20%): 2× Slime
  - Encounter 2 (50%): 1× Goblin Archer, 1× Goblin
  - Encounter 3 (80%): 2× Goblin
- **Number of dungeons:** 1 (MVP). More planned for later versions.
- **Progression unlock:** Shop-level-based. Fulfilling orders and clearing dungeons earn shop XP, which never decreases. Crossing a level unlocks every definition (customer archetype, dungeon, blueprint, crate, reagent) whose `min_shop_level` is that level.
- **Difficulty scaling:** Higher-level customer archetypes demand more advanced items. Dungeon enemies have more HP and damage in later encounters.
- **Save / checkpoint system:** Auto-save after session end, after purchases, and after dungeon end. Single JSON file at `user://save_data.json`.

### Shop Levels

The curve is a power law: XP from level k to k+1 is `round(level_xp_base x k^level_xp_exponent)` (`level_xp_base` 70, `level_xp_exponent` 1.5). At best play, level 10 lands around session 10, level 30 around session 97, level 50 around session 330 — see `tmp/shop-improvements/sim/economy_sim.gd`'s `_print_levels()`.

| Level | Unlocks |
|-------|---------|
| 1 | Customers: Brom, Mira, Hilda. Crate: Basic Crate |
| 2 | Blueprint: Iron Plate. Crate: Herb Crate |
| 3 | Customers: Garrick, Maelys. Crate: Metal Crate |
| 4 | Blueprint: Healing Potion |
| 5 | Customer: Ysolde |
| 6 | Dungeon: Goblin Cave. Blueprint: Battle Elixir |
| 7 | Blueprint: Bomb |
| 8 | Customers: Ser Roland, Caelum. Blueprint: Sword |
| 10 | Blueprint: Iron Shield |
| 12 | Blueprint: Cluster Bomb. Reagent: Fire Essence |
| 14 | Customers: Ser Kaelen, Veska. Blueprints: Flame Sword, Phoenix Draught |
| 16 | Blueprint: Fire Bomb |
| 17–60 | Empty until Phases 4–8 of `tmp/shop-improvements/` fill them in |

### What Persists Between Sessions

- Gold balance
- Shop XP (and the level derived from it)
- Blueprints unlocked
- Upgrade levels bought (`upgrade_levels`, upgrade id to level)
- Reagent inventory (Dictionary[String, int])
- Board state (items on grid carry over)
- Display shelf contents (`shop_shelf_state`; shop only)
- Grid size (if upgraded)

---

## 8. Screens and UI

### Main Menu
- Elements: Game title, New Game button, Continue button (disabled if no save), Privacy policy link, "Privacy choices" button (shown only when UMP says privacy options are required; reopens the consent form)
- Does NOT have: Animated background, settings menu, credits, ads

### Shop Mode (In-Game)
- **Top:** Customer queue — current customer portrait + 1–3 order cards showing item icons and quantities + reject button. On the left side, the current customer's image is shown, with a "Reject" button at the bottom. On the right side, their 1–3 orders are stacked vertically, each showing item icon, quantity, and gold reward. Tapping an order card fulfills it. **Parked:** Show silhouette of other customers behind the current customer, with random movements (just horizontal movements).
- **Center-left:** Merge board (5x5 grid, up to 6x6 with Board Expansion). Under it, once Display Shelf is bought, a one-row display shelf (2, 4 or 6 slots) that stores finished goods: items on it never merge or despawn, the player can drag items between the board and the shelf, and orders are filled from the shelf first. Staging area below the shelf.
- **Right side:** CratePanel — VBoxContainer with crate buy buttons populated from the level-unlocked crate definitions and a discard trash bin below.
- **Overlay (CanvasLayer):** HUD — gold, shop level and XP bar (always visible during gameplay)
- Does NOT have: Timer, health bar, pause button

### Session Summary
- Elements: Gold earned counter (animated count-up), XP earned, items sold list, fulfilled count, rejected count, satisfied/disappointed customer portraits, a level-up panel (shown only if a level was crossed), Continue button
- Does NOT have: Star rating, share button

### Prep Phase
- Elements: TabContainer with tabs — **Forecast** (first, default tab: previews the next session exactly as the shop will deal it — a market modifier card, shown only when a modifier rolled, with its icon, name and description; demand by item family, largest share first; and portraits for the first `forecast_customers` (3) customers), Blueprints (buy blueprints), Upgrades (buy upgrades and reagents). Upgrade cards read "Name (k/N)" (levels bought of the track's N), show the next level's value ("Next: ...") and cost, "Max" once every level is bought, and "Unlocks at level N" while the next level is level-locked; buying an upgrade buys its next level. With Town Crier the forecast reveals that level's customer count (5 or 8), and at the top level every customer plus their orders. Material crates are purchased during shop sessions. Board rearrange deferred to post-MVP. Locked entries are greyed with "Unlocks at level N"; the dungeon button reads "Dungeon (Lv N)" while locked. The forecast refreshes whenever a purchase or level-up could change what's craftable (blueprint bought, reagent count changed, level crossed).
- **Overlay (CanvasLayer):** HUD — gold, shop level and XP bar (always visible during gameplay)
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
- **Overlay (CanvasLayer):** HUD — gold, shop level and XP bar (always visible during gameplay)
- Does NOT have: Manual attack button, movement controls, inventory screen

### Dungeon Cleared Summary Screen
- Elements: Gold reward, blueprint reward (if any), "XP: +N", a level-up panel (shown only if a level was crossed), Continue button

### Dungeon Failed Summary Screen
- Elements: "Party Wiped" message, "No XP", Continue button

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
| Board default size | 5x5 (25 cells) | Board Expansion grows it to 5x6, then 6x6 (never past 6 columns). A third level (6x7) was cut: with the display shelf and a 3-order customer it doesn't fit a 1080x1920 screen (see Decisions Log) |
| Merge minimum | 3 connected identical items | Orthogonally adjacent (4-directional) |
| Merge result count | floor(count / 3) result items | Groups of 3 each produce 1 upper-tier item |
| Merge refund | count % 3 source items | Remainder items refunded to board at former positions |
| Merge bonus gold | (count - 3) × floor(source_value × 0.25) | Gold bonus for groups larger than 3; source = the merged item, not the result |
| Despawn timer (default) | 12 seconds | Staging area items |
| Despawn timer (upgraded) | 15 / 18 / 22 seconds | Patience Clock (`slow_timer`) levels 1 / 2 / 3 |
| Combat tick interval | 1.0 second | Auto-combat damage frequency |
| Party: Fighter | HP 120, ATK 11 | Melee. Slot 0 (front); takes all melee damage while standing. Crit "Cleave" |
| Party: Mage | HP 50, ATK 14 | Missile: hits the weakest enemy. Highest damage. Crit "Fireball". Auto-attack only for MVP |
| Party: Healer | HP 60, ATK 4 | Melee: hits the front enemy. Lowest damage. Crit "Smite". Auto-attack only for MVP |
| Attack windup | 1 second, every unit | A crit winds up 2x as long |
| Crit chance / damage | 15%, every unit / 4x | 2x damage per second of a normal attack |
| Dungeon walk speed | 0.075 progress/second | Default value; configurable per dungeon definition |
| Session size | 10 customers per session | A market modifier's `session_size_delta` can change this (e.g. Caravan Day, +3) |
| Starting gold | 50 | |
| Crate discount | 10% / 20% / 30% (x0.9 / x0.8 / x0.7) | Bulk Deal (`crate_discount`) levels 1 / 2 / 3 |
| Crate cost | `max(floor(cost x modifier x discount + 0.0001), 1)` | Modifier and Crate Discount both apply, rounded down once (the epsilon stops float error losing a gold: `30 x 0.7` is `20.999...`); a crate is never free |
| Display shelf | 2 / 4 / 6 slots | Display Shelf (`display_shelf`) levels 1 / 2 / 3. Shop only (the dungeon board has none). Shelf items never merge and never despawn; order fulfilment takes from the shelf first, then the board. The shelf is saved between sessions |
| Town Crier | 5 / 8 / all customers | Town Crier (`town_crier`) levels 1 / 2 / 3; replaces `forecast_customers` (3) in the Forecast tab. A level value of 0 means every customer, and revealing every customer also shows their orders |
| Shop Signage | order gold x1.05 / x1.10 / x1.15 / x1.20 / x1.25 | Shop Signage (`shop_signage`) levels 1 to 5; applied with the other order price multipliers and rounded once (see Customers) |
| Market modifier chance | 35% | `ShopRulesDefinition.modifier_chance`; at most one modifier per session, rolled from the seed (`hash([session_seed, "modifier"])`), not the clock — see Market Modifiers below and Decisions Log |
| Forecast customers revealed | 3 | `ShopRulesDefinition.forecast_customers`; the prep Forecast tab shows this many of the next session's dealt customers |
| Upgrades | Data-driven leveled tracks | One `UpgradeDefinition` per track under `resources/definitions/upgrades/`, each with `levels: Array[UpgradeLevel]` (cost, value, grid growth, `min_shop_level`). Level costs (gold, unlock level): Board Expansion 1000 (L1), 3000 (L12); Patience Clock 400 (L1), 1200 (L8), 3000 (L24); Town Crier 600 (L3), 1800 (L15), 4500 (L32); Bulk Deal 800 (L4), 2400 (L22), 5000 (L50); Display Shelf 700 (L5), 2500 (L20), 5500 (L42); Shop Signage 700 (L6), 1800 (L14), 3500 (L28), 5500 (L40), 7500 (L55). Upgrades total 51400g. Gold for every blueprint and every upgrade level arrives in about 52 best-case sessions, but the unlock levels, not gold, set when every upgrade can be maxed: level 50 comes around session 330 and level 55 around session 418 under best play |
| Crates | Data-driven | Defined in `crates.json` (whatever entries exist become buy buttons) |
| Customers | Data-driven: level-gated archetypes | `CustomerDefinition` archetypes under `resources/definitions/customers/`, dealt each session by `autoloads/customer_generator.gd` (weighted draw with replacement by `weight`, no back-to-back repeats). Order price = `round(gold_value x quantity x price_multiplier x modifier.price_multiplier(item) x signage)`, rounded once; `signage` is Shop Signage's level value (1.0 without it). |
| Order XP | `round(gold_reward x xp_per_gold x (1 + min(streak x streak_step, streak_cap)))` | `xp_per_gold` 0.5, `streak_step` 0.1, `streak_cap` 0.5. `streak` is the customers fulfilled in a row before this one. |
| Shop level curve | `round(level_xp_base x level^level_xp_exponent)` | XP from level k to k+1. `level_xp_base` 70, `level_xp_exponent` 1.5. |
| Max shop level | 60 | XP past the level-60 threshold has nowhere to go; the HUD's XP bar stays full |
| Dungeon gold reward | 120g | Goblin Cave (MVP) |
| Dungeon XP reward | 60 | Goblin Cave, on clear. A wipe gives none. |
| Dungeon unlock | Level 6 | Goblin Cave's `min_shop_level` |

### Market Modifiers (MVP)

`SessionModifierDefinition` events under `resources/definitions/modifiers/`, at most one rolled per session (35% chance, see Fixed Values above). An empty `family` means every item (Festival); every other field defaults to "no effect" (multiplier 1.0, delta 0).

| id | Name | Min level | Effect |
|----|------|-----------|--------|
| herb_shortage | Herb Shortage | 5 | Herb crates (Herb Crate) cost x1.5; herb-family orders pay x1.3 |
| festival | Festival | 8 | Every order pays x1.2 (`family` empty = all items) |
| iron_glut | Iron Glut | 12 | Metal crates (Metal Crate) cost x0.7; metal-family orders pay x0.85 |
| knights_tournament | Knights' Tournament | 18 | Ser Roland and Ser Kaelen's archetype weight x3 |
| caravan_day | Caravan Day | 25 | Maelys's archetype weight x3; session size +3 customers |

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
- **Save system:** Yes — single JSON file (`user://save_data.json`), auto-save at checkpoints. `SAVE_VERSION` 7: `upgrade_levels` (upgrade id to level bought) replaced `purchased_upgrades`, and `shop_shelf_state` holds the display shelf; older saves load as CORRUPT
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
- Shop Level
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
- Upgrade levels from GameManager.upgrade_levels (upgrade id to level bought); every effect getter reads the value at the bought level

**Outputs:**
- Modifies GameManager.gold
- Spawns items on the board directly when possible (via BoardGrid.place_or_stage), only using staging area as fallback when no safe cell exists
- Adds reagents to GameManager.reagent_inventory (Dictionary[String, int]) directly — reagents are never placed on the board or in staging
- Adds blueprints to GameManager.unlocked_blueprints
- Raises GameManager.upgrade_levels: buying an upgrade buys its next level
- Applies upgrade effects (grid size, despawn timer, crate discount, shelf slots, forecast reveal, order price)

**States / Logic:**
```
Purchase flow:
1. Check gold >= price (apply discount if applicable)
2. Deduct gold
   3. If crate → pick random items from crate's pool definition (weighted), place on board directly via merge-safe placement; only use staging if no safe cell exists
4. If reagent → add reagents to GameManager.reagent_inventory directly (no staging, no board items)
5. If blueprint → add to unlocked_blueprints, emit blueprint_added
6. If upgrade → buy its next level (raise upgrade_levels), apply effect, emit upgrade_level_changed(upgrade_id, level)
7. Trigger auto-save
```

**Fixed values:**

| Property | Value | Notes |
|----------|-------|-------|
| Starting gold | 50 | |
| Crate discount | 10% / 20% / 30% (multiply by 0.9 / 0.8 / 0.7) | Bulk Deal levels 1 / 2 / 3 |
| Crate cost | `max(floor(cost x modifier x discount + 0.0001), 1)` | The dealt session's market modifier (if any) and the Crate Discount upgrade both apply, rounded down once; never free |
| Crate definitions | Fully data-driven, one `.tres` per crate | Each crate has: name, cost, item_count range, weighted item pool. Whatever crate definitions exist are shown as buy buttons, cheapest first. No hardcoded crate types. |
| Crates (current) | Basic Crate 10g, Metal Crate 25g, Herb Crate 25g | Basic: iron_ore (weight 3) / herb_leaf (weight 2), 3-5 items. Metal: iron_ore (weight 4) / iron_ingot (weight 1), 3-4 items. Herb Crate (new): herb_leaf (weight 4) / herb_bundle (weight 1), 3-4 items. |
| Fire Essence price | 100g | 1 reagent, goes directly to inventory |
| Upgrade costs | Per level, see Fixed Values (Upgrades row) | Data-driven, one `.tres` per track under `resources/definitions/upgrades/`; costs rise within a track. Tuned by `tmp/shop-improvements/sim/economy_sim.gd` to about 52 best-case sessions to buy every blueprint and every upgrade level (target 40-60). That measures gold only: the level gates (up to L55) mean maxing every track waits on the level curve, about 330-420 sessions under best play |

**Does NOT:**
- Set prices dynamically (all prices are fixed in JSON)
- Implement real-money purchases

**GDD dependencies:**
- Merge system
- Reagent
- Blueprint

---

### Submodule — Shop Level

**What it tracks:**
Cumulative shop XP (`GameManager.shop_xp`, never decreases) and the shop level it derives (`get_shop_level()`, 1 to `max_level`). Every definition that has a `min_shop_level` — customer archetype, dungeon, blueprint, crate, reagent — is gated by the player's current level.

**What triggers it:**
Customer order fulfilled (XP per `order_xp`, streak-boosted), customer rejected (streak resets, no XP change), dungeon cleared (the dungeon's `xp_reward`; 60 for the Goblin Cave), dungeon failed (no XP).

**Inputs:**
- Events from ShopSession (fulfill, reject)
- Events from DungeonController (dungeon cleared, dungeon failed)
- Current `shop_xp` from GameManager
- `ShopRulesDefinition` (`xp_per_gold`, `streak_step`, `streak_cap`, `level_xp_base`, `level_xp_exponent`, `max_level`)

**Outputs:**
- Updates `GameManager.shop_xp`, emits `shop_xp_changed`
- Emits `shop_level_changed` once per level crossed (a gain that skips levels still fires once per level in between)
- `GameManager.meets_level(min_shop_level)` is read directly by `core/purchases.gd`, `board/merge_board.gd` (crate purchase), `autoloads/recipe_resolver.gd` (`is_craftable`) and `core/prep_phase.gd`; `GameManager.get_shop_level()` is passed into `autoloads/customer_generator.gd.generate()`, which compares it to each archetype's `min_shop_level` directly
- `DefinitionLibrary.get_unlocks_between(old_level, new_level)` feeds the level-up panel shown on both summaries

**States / Logic:**
```
XP from level k to k+1: round(level_xp_base x k^level_xp_exponent)
  — a power law, not geometric (see Decisions Log 2026-09-28).

Order XP: round(gold_reward x xp_per_gold x (1 + min(streak x streak_step, streak_cap))),
  where streak is the customers fulfilled in a row before this one.
A rejection resets the streak to 0 and earns no XP.

Every definition with min_shop_level is gated individually, not by tier:
a fresh game (level 1) only unlocks the archetypes, blueprints, crates and
reagents with min_shop_level 1.
```

**Fixed values:** see Section 10, Fixed Values and the Shop Levels table in Section 7.

**Does NOT:**
- Decrease `shop_xp` (no penalty for rejecting or wiping)
- Group unlocks into tiers — gating is per-definition
- Affect dungeon difficulty

**GDD dependencies:**
- Reads/writes `GameManager.shop_xp`
- Affects `autoloads/customer_generator.gd`, `core/purchases.gd`, `board/merge_board.gd`, `autoloads/recipe_resolver.gd` (per-definition `min_shop_level` gates)
- Affects Prep Phase (dungeon button text/enabled state, greyed locked entries)

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
| Staff | TBD | Recipe | wood_shaft → staff *(deferred — Wood family)* |
| Healing Potion | 300g | Recipe | herbal_tonic → healing_potion |
| Battle Elixir | 400g | Recipe | herbal_tonic → battle_elixir |
| Iron Shield | 900g | Recipe | iron_plate → iron_shield |
| Bomb | 500g | Recipe | firecracker → bomb |
| Cluster Bomb | 1200g | Recipe | bomb → cluster_bomb |
| Phoenix Draught | 1500g | Variant | herbal_tonic + fire_essence → phoenix_draught |
| Fire Bomb | 1800g | Variant | bomb + fire_essence → fire_bomb |
| Wand | TBD | Recipe | magic_focus → wand *(deferred — Wood family)* |
| Flame Sword | 1500g | Variant | iron_plate + fire_essence → flame_sword |
| Flame Staff | TBD | Variant | staff + fire_essence → flame_staff *(deferred — Wood family)* |

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
- Affects Shop Level (no XP on wipe; `xp_reward` on clear)

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
| 2026-06-04 | Demand forecast deferred | Forecast tab and forecast_bias not in MVP. **Superseded 2026-09-28:** shipped — see the "Demand forecast shipped" entry below. |
| 2026-06-04 | Premium customer tier deferred | CustomerGenerator only produces Basic and Standard for MVP |
| 2026-06-04 | Reject penalty: reputation only, no gold cost | -2 reputation per rejected customer. **Superseded 2026-09-28:** reputation is gone; a reject now breaks the fulfil streak and earns no XP, with no other penalty. |
| 2026-06-04 | Usable item values confirmed for v1.0 | Healing Potion: heal 30 HP; Battle Elixir: +5 ATK for 10s. Tune during playtesting |
| 2026-06-04 | Dungeon clear reputation reward: +25 | **Superseded 2026-09-28:** reputation is gone; a clear now awards `xp_reward` shop XP instead (60 for the Goblin Cave). |
| 2026-06-04 | Goblin Cave: no blueprint reward | First dungeon awards gold + XP only (reputation, superseded 2026-09-28). Post-MVP dungeons may award blueprints. |
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
| 2026-09-28 | Economy baseline retune | Margins now rise with tier (price / material cost at least 1.3 / 1.6 / 2.0 at depth 2 / 3 / 4); tier-4 herbs had sold below cost. New Herb Crate (herbs cost 6.25g per leaf through the mixed crate). Merge bonus pays 25% of the *source* value per extra item; paying 50% of the result's value on refunded extras was a repeatable gold farm. Blueprint and upgrade costs scaled so buying everything takes about 12 best-case sessions instead of about 2.5. Checked by `tmp/shop-improvements/sim/economy_sim.gd`. Dungeon clear reward 400 -> 120g: runs are free and repeatable, so a bigger reward let repeated dungeon runs out-earn the shop; 120 keeps roughly the old 80g's share of a best-case session (about 11% of about 1032g). |
| 2026-09-28 | Customers are seeded archetype sessions, not a fixed list | `CustomerDefinition` becomes an archetype (`reputation_required`, `weight`, `min_orders`/`max_orders`, `price_multiplier`, `wants: Array[OrderTemplate]`) instead of a customer with fixed orders. Each shop session deals `session_size` customers from `shop/customer_generator.gd`, seeded by `GameManager.get_session_seed()` (`run_seed` + `sessions_played`, both new save fields) so a session is reproducible and previewable. Dealing is a deck without replacement: every reputation-unlocked, currently-craftable archetype gets one slot per pass, with no archetype repeating back-to-back while another is available; `weight` only biases draw order within a pass. Every dealt customer's first order is guaranteed craftable today (`RecipeResolver.is_craftable`); remaining orders may be locked behind a blueprint the player doesn't have yet, as a teaser for what it would unlock. `SAVE_VERSION` 5 (breaking: `run_seed` and `sessions_played` are required fields, old saves are rejected as CORRUPT). **Superseded 2026-09-28:** `reputation_required` is `min_shop_level`, and the deck-without-replacement dealing (one slot per pass) is a weighted draw with replacement — see the "Archetype weight is a real frequency weight" row below. |
| 2026-09-28 | Drop archetype price premiums | The economy sim's endgame pace was 7.8 sessions against the 10-15 session target after archetypes shipped. Every archetype's `price_multiplier` was set back to 1.0 except Hilda (`cust_06`, 0.9), and Caelum's `healing_potion` want quantity was tightened from a range to a flat 1. Re-simmed pace is about 10.5 sessions. |
| 2026-09-28 | No separate premium tier | Superseded by seeded archetype sessions: later archetypes gated by `reputation_required` fill the role the old "Basic/Standard/Premium" tier split was meant for. **Superseded 2026-09-28:** `reputation_required` is `min_shop_level`. |
| 2026-09-28 | Reputation replaced by shop XP and levels | `GameManager.reputation_points` and every `reputation_required`/`reputation_changed` field are gone. `shop_xp` (never decreases) drives `get_shop_level()`, 1 to `max_level` (60); every unlock a definition used to gate by reputation now uses `min_shop_level`. `SAVE_VERSION` 6, breaking: old saves are rejected as CORRUPT. |
| 2026-09-28 | Power-law level curve, not geometric | XP from level k to k+1 is `round(level_xp_base x k^level_xp_exponent)`, not a fixed per-level multiplier. Income plateaus once content runs out (there's nothing left to sell for more gold), so a geometric curve would make each later level cost a fixed factor more sessions forever; a power law's cost grows but at a rate the sim can tune to match the content that actually exists. |
| 2026-09-28 | Archetype weight is a real frequency weight | Supersedes the deck rule in this date's "seeded archetype sessions" entry: the generator no longer deals a deck (one guaranteed slot per pass). It now does a weighted draw with replacement, so `weight` sets how often an archetype is dealt relative to the others, not just draw order within a pass; the no-repeat-back-to-back rule is unchanged. |
| 2026-09-28 | Demand forecast shipped: market modifiers, Forecast tab | Reverses the 2026-06-04 "Demand forecast deferred" entry. The modifier rolls on its own RNG stream (`hash([session_seed, "modifier"])`), before the customers are dealt and independent of the customer RNG (still seeded by `session_seed` alone) — the spec's "roll after dealing" would let a modifier's customer-weight and session-size effects reshuffle who gets dealt; rolling first, on a separate stream, means adding a modifier to the catalog never reshuffles a seed's customers when the rolled modifier has no customer effects. A modifier's `family` field empty means it affects every item (Festival); other modifiers name a family key such as `"herb"`. Crate cost under a modifier is `cost x modifier x discount`, rounded down once and clamped to at least 1g (`max(floor(... + 0.0001), 1)`, the epsilon guarding float error like `30 x 0.7 == 20.999...`). The Forecast tab is the first, default prep tab, since planning is what prep is for; it shows the market modifier (if any), demand by item family, and the first `forecast_customers` (3) customers of the next session exactly as the shop will deal it, refreshing whenever a purchase or level-up could change what's craftable. Five modifiers ship (Herb Shortage L5, Festival L8, Iron Glut L12, Knights' Tournament L18, Caravan Day L25), checked by the economy sim's `_print_modifiers()`: no modifier pushes an item's margin from 1.0 or more down under 1.0. |
| 2026-09-28 | Leveled upgrade tracks and the display shelf | Upgrades are tracks of levels (`UpgradeDefinition.levels: Array[UpgradeLevel]`), so they keep absorbing gold for the long haul; buying an upgrade buys its next level, and `GameManager.upgrade_levels` replaces `purchased_upgrades` (`SAVE_VERSION` 7, breaking: old saves load as CORRUPT). Three new tracks: Display Shelf, Town Crier and Shop Signage. The shelf is a second `BoardGrid` inside `MergeBoard` with merges off (a spike beat a custom shelf widget), so drag and drop between board and shelf reuses the board's code; the shop only talks to `MergeBoard`. A shrinking shelf never loses items: saved items past its end go to the board, else staging. Town Crier starts at 5, not the spec's 3, because the free forecast already shows 3; a level value of 0 means every customer, and revealing every customer also shows their orders, so no "top level" flag is needed in data. Shop Signage multiplies inside the customer generator, where order gold is computed and rounded once, so the order card, the forecast and the payout agree. The level-up panel doesn't list upgrade levels: it lists catalog entries with a top-level `min_shop_level`, and upgrades gate per level. Layout: with a 6-slot shelf and a 3-order customer the shop screen leaves the merge board 1202 px at 1080x1920, and a 6x7 board (968 px tall) plus the shelf, staging and padding needs 1332 (still over 1202 with the padding cut to nothing), so Board Expansion stops at 6x6 (its 6x7 level was cut). `merge_board.tscn` padding was trimmed and the board area now sizes to its grid; 6x6 with a 6-slot shelf fits at 1080x1920 and 1080x2520 with 128 px cells. Sim: level costs retuned so buying every blueprint and every upgrade level takes about 52 best-case sessions (target 40-60, was about 72), with unlock levels spread from 1 to 55. That pace is gold only: the level curve, not gold, sets when every upgrade can be maxed, since best play reaches level 50 around session 330 and level 55 around session 418; the gates are kept on purpose so something still unlocks through the 50s. |

---

## 15. Open Questions

- Balance tuning: all gold values, shop level XP curve, and economy numbers are placeholders until playtesting
- Dungeon mid-exit penalty (post-MVP): what penalty and which anti-scumming measures?
