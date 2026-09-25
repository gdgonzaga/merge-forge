# MergeForge — Implementation Task List

Derived from `tmp/code-review.md` (CR) and `tmp/ux-polish-review.md` (UX). Organized
into **7 phases** ordered by dependency + value: fix what's broken → fix the
onboarding cliff you flagged → make it feel good → add depth → balance/tests →
polish. Each task is sized **S** (~1h), **M** (~half day), **L** (~1+ day).

> **Reading the IDs:** `C` = code/correctness, `U` = UX/feel. Dependencies point at
> task IDs that must be done first. Ticked boxes `[x]` = done; track progress here.

---

## Phase 1 — Blockers & save integrity
*The game must (a) work on the mobile target and (b) not lose/corrupt player progress.
Nothing else matters until these are fixed.*

- [x] **C1 — Implement touch drag-and-drop** · `CR §1.2` · **L**
  - Files: `board/board_cell.gd`, `board/floating_item.gd`
  - The drag system (`_get_drag_data`/`_can_drop_data`/`_drop_data`) is mouse-only;
    on the portrait-mobile target the entire merge loop does nothing.
  - Do: add an `_gui_input` path handling `InputEventScreenTouch` +
    `InputEventScreenDrag` that produces a floating preview + manual drop, mirroring
    the existing mouse flow. Keep the mouse path for desktop/testing.
  - **Acceptance:** on a touch device, you can drag a board cell onto another cell and
    drag a floating/staging item onto the board. Existing mouse behavior unchanged.
  - Depends on: —  · Blocks: U2, U8, dungeon item-use (C-combat)

- [x] **C2 — Fix merge-choice popup deadlock + double popup** · `CR §1.1` · **S**
  - Files: `board/merge_choice_popup.gd`, `board/merge_board.gd:284-285`
  - No cancel/close path → dismissing the popup leaves `is_processing=true` forever,
    deadlocking the merge queue. Also `popup_centered()` is called twice.
  - Do: wire `popup_hide` to a cancel handler that advances the resolver (pick a safe
    default or a dedicated `cancelled` signal that `merge_resolver.process_next` reacts
    to). Remove one of the two `popup_centered()` calls.
  - **Acceptance:** opening the choice popup and pressing Back/clicking outside does
    not freeze future merges; the queue continues.
  - Depends on: —

- [x] **C3 — Save integrity overhaul** · `CR §1.6` · **M**
  - Files: `autoloads/save_manager.gd`, `autoloads/game_manager.gd`
  - No versioning; `deserialize` trusts types blindly; corrupt save is
    indistinguishable from missing; atomic-rename errors ignored.
  - Do: (1) add `"version": 1` to `serialize()`; (2) validate each field's type in
    `deserialize` before `assign`/use (skip bad fields, keep defaults);
    (3) in `load()` return a result enum/signal distinguishing `MISSING | CORRUPT |
    OK` and `push_error` on parse failure; (4) check the rename `Error` code in
    `save()` before emitting `save_completed`.
  - **Acceptance:** a hand-corrupted save no longer crashes on load (falls back to
    defaults + logs), missing vs corrupt are distinguishable, a failed rename no
    longer falsely reports success. Add a test (C-TEST-2 will formalize).
  - Depends on: —

- [x] **C4 — `get_item_data` cache mutation** · `CR §1.4` · **S**
  - Files: `autoloads/recipe_resolver.gd:51-55`
  - `items.get(id)` returns the cached dict; stamping `item_id` onto it mutates the
    shared catalog.
  - Do: `var data := items.get(item_id, {}).duplicate(); data["item_id"] = item_id;
    return data`.
  - **Acceptance:** repeated `get_item_data` calls don't grow the cached dict's keys.
  - Depends on: —

- [x] **C5 — Despawn/crate-discount data→code drift** · `CR §1.5` · **S**
  - Files: `autoloads/game_manager.gd:87-92`, `data/upgrades.json`
  - Code hardcodes `18.0`/`0.8`; JSON declares `15.0`/`0.8`. UI shows JSON value,
    game uses hardcoded → mismatch.
  - Do: read from `RecipeResolver.get_upgrade_data(id).get("effect_value", …)` so JSON
    is the single source of truth. Reconcile the actual intended number in the JSON.
  - **Acceptance:** the despawn time shown in prep equals the time used at runtime.
  - Depends on: C4 (safer once lookup doesn't mutate)

---

## Phase 2 — The onboarding cliff  *(your stated priority)*
*New Game currently wipes the save and dumps the player on a shopping screen with no
context and no visible board. This phase gives the game a soul and a goal.*

- [ ] **U1 — Intro / "how to play" screen between New Game and prep** · `UX §1.1` · **M**
  - New scenes: `core/intro.tscn`, `core/intro.gd`; edit `core/main.gd`
  - Do: add a 1–3 panel intro (story beat or visual loop explainer) shown **only on a
    fresh save**. Route `new_game_started → intro → prep_phase`; Continue skips intro.
    Add `EventBus.intro_finished`. Persist a `seen_intro` flag in the save.
  - **Acceptance:** New Game shows the intro once; Continue never does; the intro's
    Begin button reaches prep_phase; re-launching Continue still skips.
  - Depends on: C3 (save has a place for `seen_intro`)  · Blocks: U-TUTORIAL

- [ ] **U2 — Reusable confirmation dialog** · `UX §1.3` · **M**
  - New: `ui/confirm_dialog.tscn` (+ a small helper script); edit `core/main.gd`,
    `core/main_menu.gd`, `core/prep_phase.gd`
  - Do: themed medieval `ConfirmationDialog`. Wire it before **New Game** (when a save
    exists) and **Quit to Menu** from prep. (Reject-customer can stay instant.)
  - **Acceptance:** New Game with a save prompts "Erase current progress?"; Quit to
    Menu prompts before leaving; confirming proceeds, cancelling does nothing.
  - Depends on: C2 (popup plumbing patterns to mirror)

- [ ] **U3 — Customer identity & upcoming queue** · `UX §2.3` · **M**
  - Files: `shop/shop_session.gd`, `shop/shop_session.tscn`, `data/customers.json`
  - Do: (1) give customers `name` + a one-line `want` line in JSON; display name (not
    raw `cust_02`) and the want line; (2) populate the currently-empty
    `PendingCustomers` HBox with the next 2–3 portrait thumbnails so players can plan.
  - **Acceptance:** customers show a real name and request; upcoming customers appear
    as small portraits; fulfilling/rejecting updates the queue.
  - Depends on: —

- [ ] **U4 — Prep screen context: rename + rep bar + gold prominence** · `UX §2.2` · **M**
  - Files: `core/prep_phase.gd`, `core/prep_phase.tscn`
  - Do: rename title "Prep Phase" → in-world ("The Forge"/"Your Workshop"); add a
    prominent gold readout; add a reputation progress bar toward the dungeon-unlock
    threshold (read the number from data per C-rep-const). Use
    `GameManager.is_dungeon_unlocked()` instead of the literal `150` (`prep_phase.gd:29`).
  - **Acceptance:** title is in-world; gold is clearly visible; a bar shows rep
    progress to the unlock; passing the threshold visibly enables the dungeon button.
  - Depends on: —

- [ ] **U-TUTORIAL — First-session merge coach** · `UX §1.2` · **M**
  - Files: `shop/shop_session.gd/.tscn`
  - Do: dismissible tooltip banner on the first shop_session only ("Tap a crate to
    draw materials. Drag 3 of the same together to merge."). Optionally pulse-highlight
    the crate panel until first merge. Gate on a `seen_tutorial` save flag.
  - **Acceptance:** first-ever session shows the coach; it dismisses on tap or after
    first merge; never shows again.
  - Depends on: U1 (intro pattern + save flag), C1 (touch drag so the coached action works)

---

## Phase 3 — Core loop feel
*Hard cuts and snap-updating numbers are the biggest global jank. These are small,
high-impact changes.*

- [ ] **U5 — Scene fade/crossfade transitions** · `UX §4.1` · **S**
  - Files: `core/main.tscn`, `core/main.gd`
  - Do: add a full-screen `ColorRect` overlay in `main.tscn`; in `_transition_to` tween
    it to black, swap scenes, tween back. Validate the new scene loads **before**
    freeing the old one (also fixes `CR §3.4` blank-screen risk).
  - **Acceptance:** every scene change fades; a missing `.tscn` no longer leaves a
    blank screen (old scene stays + error logged).
  - Depends on: —

- [ ] **U6 — Animate HUD gold & reputation** · `UX §4.4` · **S**
  - Files: `core/hud.gd`, `core/hud.tscn`
  - Do: rolling count (`tween_method`, pattern from `session_summary.gd:29-31`),
    scale pulse, and a `+N` floater on gains. Bump label sizes for phone legibility.
  - **Acceptance:** gold/rep changes animate instead of snapping; a `+10` floater
    appears on gains and fades.
  - Depends on: —

- [ ] **U7 — Tactile button feedback + UI click sound** · `UX §4.2, §4.6` · **M**
  - New: `ui/button_behaviour.gd`; an asset `resources/audio/sfx/ui_click.wav`
  - Do: shared script applying a scale-down-on-press / bounce-on-release tween + a
    subtle click sound to all buttons. Attach to the button scenes/themes used across
    menu/prep/session/summary.
  - **Acceptance:** every tappable button squishes on press and clicks; consistent
    across screens.
  - Depends on: —

- [ ] **U8 — "Not enough gold" feedback** · `UX §4.3` · **S**
  - Files: `core/prep_phase.gd`, `shop/purchase_card.gd`
  - Do: detect a tap on an unaffordable/locked card (e.g. `gui_input` on disabled
    state) and respond with a shake + a short "Not enough gold" toast.
  - **Acceptance:** tapping a too-expensive card shakes it and explains why, instead
    of doing nothing.
  - Depends on: U7 (button behaviour/toast patterns)

- [ ] **C6 — Stop full prep rebuilds on every gold change** · `CR §3.1` · **M**
  - Files: `core/prep_phase.gd`
  - Do: `const CARD_SCENE := preload(...)`; update existing cards' `disabled` state on
    `gold_changed` instead of `queue_free`+rebuild; debounce with `call_deferred` if
    needed.
  - **Acceptance:** gold changes no longer re-instantiate all cards; affordability
    still updates immediately.
  - Depends on: —  · Pairs well with: U4

---

## Phase 4 — Bring the dungeon to life
*Currently the dullest screen: long dead air, then invisible spreadsheet combat. Do
the combat-math fix before adding juice to broken math.*

- [ ] **C7 — Combat damage formula decision + document** · `CR §1.7` · **M**
  - Files: `dungeon/combat_engine.gd:66,93`, data
  - Do: decide the intended model (party DPS flat vs enemy DPS scaling with members is
    asymmetric — likely a bug). Pick e.g. "each enemy attacks one target" or "split
    among targets"; implement; document in a comment; tune constants in data.
  - **Acceptance:** combat feels balanced; formula documented; no asymmetry that
    punishes larger parties.
  - Depends on: C-TEST-1 (seeded RNG to test it)  · Blocks: U9

- [ ] **C-TEST-1 — Injectable seeded RNG** · `CR §5` · **M**
  - Files: `autoloads/recipe_resolver.gd` (`roll_weighted_pool`), `dungeon/combat_engine.gd`,
    `dungeon/drop_manager.gd`
  - Do: replace global `randi_range`/`randf` with an injectable `RandomNumberGenerator`
    so combat/drops are deterministic in tests. Default to a time-seeded instance in
    production.
  - **Acceptance:** a test can pass a seeded RNG and get reproducible combat/drop
    outcomes.
  - Depends on: —  · Blocks: C7, all combat/drop tests

- [ ] **U9 — Combat juice: damage numbers, hit flashes, lunges** · `UX §2.5` · **L**
  - Files: `dungeon/combat_engine.gd`, `dungeon/party_member.gd`, `dungeon/enemy_display.gd`,
    `dungeon/combat_unit.gd`
  - Do: floating damage numbers each tick; white hit-flash on targets; brief
    attacker→target lunge/hop tween; KO fall/fade (beyond current greyscale). Batch any
    per-cell SFX to one sound per merge/encounter (`CR §3.7`).
  - **Acceptance:** combat visibly shows hits, damage, and KOs; no longer static bars.
  - Depends on: C7, C-TEST-1

- [ ] **U10 — Dungeon "walking" life + encounter punch** · `UX §2.5` · **M**
  - Files: `dungeon/dungeon_controller.gd`, `dungeon/dungeon_run.tscn`
  - Do: animate party shuffle during the ~50s walk; add per-encounter sting + screen
    flash/zoom + encounter banner on `start_encounter`. (Consider shortening walk
    time or cutting between encounters.)
  - **Acceptance:** between encounters there's visible motion; encounters start with a
    punch instead of a silent label flip.
  - Depends on: —

- [ ] **C8 — Dungeon double-resolution guard** · `CR §1.12` · **S**
  - Files: `dungeon/dungeon_controller.gd`
  - Do: add a `_resolved: bool` guard in `end_dungeon_cleared`/`end_dungeon_failed` so
    simultaneous progress+encounter completion can't double-reward/double-transition.
  - **Acceptance:** the summary fires exactly once per run regardless of frame timing.
  - Depends on: —

- [ ] **C9 — Crate drops trigger merge detection** · `CR §1.3` · **S**
  - Files: `board/board_grid.gd` (`place_or_stage`), `board/merge_board.gd`
  - Do: make crate-dropped items emit `item_placed` (or have `place_drop` trigger a
    `scan()`) so crate-spawned groups auto-merge instead of sitting silent.
  - **Acceptance:** dropping 3+ matching items from a crate merges them without a
    manual move.
  - Depends on: —

---

## Phase 5 — Meta-progression & retention
*Turn the bare loop into something with visible goals and reasons to keep playing.*

- [ ] **U11 — Reputation tier bar + day counter in HUD** · `UX §3, §4` · **M**
  - Files: `core/hud.gd`, `core/hud.tscn`, `autoloads/game_manager.gd`
  - Do: add a reputation bar with tier markers (low/mid/high + dungeon-unlock tick at
    the data-driven threshold) and a "Day N" counter. Requires a `day`/`session_count`
    field in state (add to serialize/deserialize).
  - **Acceptance:** HUD shows rep progress toward tiers/unlock and an incrementing day.
  - Depends on: C3 (new state field), C-rep-const

- [ ] **C-rep-const — Reputation thresholds → consts/data** · `CR §4` · **S**
  - Files: `autoloads/game_manager.gd:75-84`, `data/dungeons.json`, `core/prep_phase.gd:17-29`
  - Do: replace magic `100/150/300` with `const`s; make dungeon-unlock read
    `dungeons.json[...].reputation_required` (currently never read by code).
  - **Acceptance:** unlock threshold is data-driven; no duplicated literal `150`.
  - Depends on: —  · Blocks: U4, U11

- [ ] **U12 — Summary screens: count up all stats + rep change + unlock banner** · `UX §2.4, §2.6` · **M**
  - Files: `shop/session_summary.gd/.tscn`, `dungeon/dungeon_summary.gd/.tscn`
  - Do: extend the gold count-up to items sold / fulfilled; surface reputation change
    ("+10 rep → 160"); show a celebratory "Dungeon Unlocked!" banner if this session
    crossed the threshold. Confirm clear/fail stings play on the summary.
  - **Acceptance:** both summaries animate multiple stats and call out rep + unlocks.
  - Depends on: C-rep-const

- [ ] **U13 — Recipe/item codex screen** · `UX §3` · **L**
  - New: `core/codex.tscn/.gd`; entry point from prep or menu
  - Do: "Discovered X / Y recipes" screen listing unlocked blueprints and items seen,
    greying locked entries. Data already exists in `RecipeResolver`.
  - **Acceptance:** a browsable codex reflects current unlock progress.
  - Depends on: —

- [ ] **C10 — Confirm multi-order customer intent; fix if needed** · `CR §1.8` · **S**
  - Files: `shop/shop_session.gd:108-109`, `data/customers.json`
  - Do: decide whether a customer's multiple `orders` are simultaneous or alternative.
    If simultaneous, stop the unconditional `current_index += 1` after one fulfill.
  - **Acceptance:** behavior matches the decided design and is consistent with the data
    model and any UI shown in U3.
  - Depends on: U3 (customer UX context)

---

## Phase 6 — Balance, tests & architecture
*Hardening: deterministic tests, then the bigger refactors that make future work
safer.*

- [ ] **C-TEST-2 — Unit tests: merge, combat, save** · `CR §5` · **L**
  - Files: new suites under `test/unit/`
  - Do: after C-TEST-1, add suites for `merge_detector` (groups of 3/4/5, connectivity),
    `combat_engine.tick` (deterministic clear/fail), `merge_resolver` (full-board
    result loss, refund math, chains), and save round-trip including a **corrupt**
    JSON (assert MISSING vs CORRUPT). Also a drift test linking code's unlock const to
    `dungeons.json`. Disconnect test signal lambdas in `after_test()`.
  - **Acceptance:** CI covers the bug-prone modules; the corrupt-save case is locked.
  - Depends on: C-TEST-1, C3, C-rep-const

- [ ] **C11 — `add_gold` clamp, `add_upgrade` dedupe, consume_reagent guard** · `CR §1.9, §1.11, §4` · **S**
  - Files: `autoloads/game_manager.gd`, `board/merge_resolver.gd:142`, `board/bonus_coin.gd`
  - Do: `add_gold` clamps at 0 (or routes decrements through `deduct_gold`);
    `add_upgrade` dedupes like `add_blueprint`; `merge_resolver` checks
    `consume_reagent`'s return; `bonus_coin._collect` gets a `_collected` guard.
  - **Acceptance:** gold can't go negative; upgrades can't double-buy; variants can't
    be produced for free; coins can't double-collect.
  - Depends on: —

- [ ] **C12 — Silent result loss refund** · `CR §1.10` · **M**
  - Files: `board/merge_resolver.gd:183-184`
  - Do: when the board is full and no placement cell exists, refund the full result (or
    queue the merge until space exists) instead of dropping it silently while still
    emitting `merge_completed`.
  - **Acceptance:** a full-board merge never consumes inputs without giving the result.
  - Depends on: —

- [ ] **C13 — Split `merge_board.gd` God class** · `CR §2.1` · **L**
  - Files: `board/merge_board.gd` → new `board/animation_controller.gd`,
    `board/staging_controller.gd`
  - Do: extract the tween/animation code and the floating-item lifecycle into their own
    classes; keep `MergeBoard` as a thin coordinator. Add `class_name`s across `board/`.
  - **Acceptance:** `merge_board.gd` is a coordinator; animation/staging are testable
    units; `class_name`s enable typing/grep.
  - Depends on: C2, C9 (behavior settled before refactoring)

- [ ] **C14 — `CombatUnitState` typed class** · `CR §2.6` · **M**
  - Files: `dungeon/combat_engine.gd` → new `dungeon/combat_unit_state.gd`
  - Do: replace the `Array[Dictionary]` unit structs (~40 `.get` calls + divergent magic
    defaults) with a `class_name CombatUnitState extends RefCounted` typed class.
  - **Acceptance:** combat reads typed fields; default-mismatch footgun gone.
  - Depends on: C7, C-TEST-1 (behavior locked + tested first)

- [ ] **C15 — Project hygiene** · `CR §6, §4` · **S**
  - Do: gate `_debug_unlock_all` behind `OS.is_debug_build()` (`prep_phase.gd:22`);
    remove debug `print` in `main.gd:84`; reconcile `export_presets.cfg` (committed but
    gitignored — check for secrets); enrich `.editorconfig` (indent/final newline);
    remove empty `progression/` dir or build the module; add an autoload-order comment
    to `project.godot`.
  - **Acceptance:** no debug button in release; no stray prints; tracked/ignored files
    reconciled; editor config matches Godot conventions.
  - Depends on: —

- [ ] **C16 — Audio preload + music crossfade + load spurious-gold fix** · `CR §3.2, §3.3`, `UX §4.6` · **M**
  - Files: `autoloads/audio_manager.gd`, `core/main.gd:83-90`
  - Do: preload `sfx_map` streams in `_ready`; reset `_prev_gold` on load (subscribe to
    a load signal) so a saved gold>50 doesn't play `gold_earn` on the menu; crossfade
    between music tracks on scene change (encode music cue in `scene_map`, not path
    substring).
  - **Acceptance:** SFX no longer re-`load` per trigger; no menu coin sound on load;
    music crossfades between scenes.
  - Depends on: C3 (load signal/state_loaded)

---

## Phase 7 — Final polish

- [ ] **U14 — Mobile haptics** · `UX §4.7` · **S**
  - Do: `Input.vibrate_handheld(...)` (or Android vibration API) on merge, bonus-coin
    collect, purchase, fulfill, KO, dungeon clear. Gate behind a setting.
  - Depends on: U-SETTINGS

- [ ] **U-SETTINGS — Pause / settings overlay** · `UX §1.4` · **M**
  - New: `ui/settings_overlay.tscn/.gd`; HUD gear button
  - Do: gear icon in HUD → overlay with music + SFX sliders, "reduce motion" toggle,
    quit-to-menu. Requires an audio volume API on `AudioManager`.
  - **Acceptance:** player can pause, mute, and quit from any gameplay screen.
  - Depends on: C16 (audio volume API)  · Blocks: U14

- [ ] **U15 — Accessibility pass** · `UX §5` · **M**
  - Do: bump small body text to 22–28px; add state icons (✓/🔒) alongside color in prep
    cards; verify grey-on-textured-bg contrast; honor a "reduce motion" toggle for
    shakes/flashes.
  - Depends on: U-SETTINGS

- [ ] **U16 — Main menu polish** · `UX §2.1` · **S**
  - Files: `core/main_menu.gd/.tscn`
  - Do: title + button fade-in/stagger; subtitle; "Continue (Day X / Rep Y)" label when
    a save exists; settings cog.
  - Depends on: U11 (day/rep data), U-SETTINGS

- [ ] **U17 — Crate opening ceremony + reject/fulfill animations** · `UX §2.3` · **M**
  - Files: `shop/shop_session.gd`, `board/merge_board.gd` (`_anim_overlay`)
  - Do: crate shake→burst→items-fly-out reveal using the existing anim overlay; angry
    customer leave animation + despawn sound on reject; celebratory pop on fulfill.
  - Depends on: C13 (anim controller extracted) or merge_board anim stable

- [ ] **U18 — Merge combo callouts** · `UX §4.5` · **S**
  - Files: `board/merge_board.gd`/`merge_resolver.gd`
  - Do: scale a "Nice!/Great!/Amazing!" popup to merge size (4/5/6); bonus-coin pop+arc
    spawn animation.
  - Depends on: —

---

## Suggested sequencing at a glance

```
Phase 1 (blockers+save)     C1 C2 C3 C4 C5            ← must-do first
Phase 2 (onboarding cliff)  U1 U2 U3 U4 U-TUTORIAL    ← your priority
Phase 3 (core feel)         U5 U6 U7 U8 + C6
Phase 4 (dungeon life)      C-TEST-1 → C7 → U9; U10; C8; C9
Phase 5 (meta/retention)    C-rep-const → U11 U12; U13; C10
Phase 6 (balance/test/arch) C-TEST-2 C11 C12 C13 C14 C15 C16
Phase 7 (polish)            U-SETTINGS → U14 U15; U16; U17; U18
```

**Hard dependencies to respect:**
- `C1` (touch drag) before `U-TUTORIAL`, `U2` confirm patterns reused, and dungeon
  item-use.
- `C3` (save) before `U1` (`seen_intro` flag), `U11` (day field), `C16` (load signal).
- `C-TEST-1` (seeded RNG) before `C7` (combat formula) and all combat/drop tests.
- `C7` before `U9` (don't juice broken math) and `C14`.
- `C-rep-const` before `U4`, `U11`, `U12`.
- `C13` (anim controller) before `U17` (crate ceremony).

**Notes:**
- Effort is rough; `L` items (C1, U9, U13, C-TEST-2, C13) are good candidates to split.
- Phase 1 + the bottom of Phase 6 (C11/C15) clear most of the "will break" risk; doing
  those first means everything after is polish, not triage.
- Re-verify line numbers after Phase 1–2 edits (the review line refs will drift).
