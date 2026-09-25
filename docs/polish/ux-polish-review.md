# MergeForge — UX & Polish Review (Player's Perspective)

This is a **player-experience pass**, not a code-correctness one (that's in
`tmp/code-review.md`). I walked the full loop a player takes — main menu → New Game
→ prep → shop session → summary → (back to prep) → dungeon → summary → loop — and
noted where things feel **abrupt, missing, unclear, or under-built**, plus concrete
additions. Organized by the player's journey, then a "juice & feel" section.

> All current scene flow lives in `core/main.gd:6-17` (`scene_map`). There are
> exactly **7 screens**: main_menu, prep_phase, shop_session, session_summary,
> dungeon_run, dungeon_summary — plus the HUD overlay. There is **no** intro/story
> screen, **no** settings, **no** tutorial, **no** pause, **no** confirm dialogs.

---

## 0. The player's current journey (so the gaps are visible)

```
Launch → main_menu
   ├─ New Game ──► prep_phase  ◄── ⚠️ abrupt, see 1.1
   └─ Continue ──► prep_phase
prep_phase (buy blueprints/upgrades/reagents, board is NOT visible here)
   ├─ Start Session ──► shop_session (the actual merge board + customers)
   │      └─ session ends ──► session_summary ──► prep_phase (loop)
   ├─ Enter Dungeon ──► dungeon_run ──► dungeon_summary ──► prep_phase (loop)
   └─ Quit to Menu ──► main_menu
```

Notice: **the merge board only exists inside shop_session / dungeon_run**, yet the
prep screen is where you spend gold. A new player lands on prep, sees three shopping
tabs, and has *no idea* what merging is or why they'd buy anything. That's the core
problem your "missing middle screen" instinct is pointing at.

---

## 1. Flow gaps — screens that should exist

### 1.1 🔴 New Game → prep_phase is abrupt (your example)

You're right that a screen is missing. New Game currently:
- silently deletes any save (`main.gd:58`), resets state, and dumps you on a
  "Prep Phase" shopping screen with no context.

**What's missing is a narrative + onboarding handoff.** Pick the flavor that fits the
game's tone (it's a medieval merchant-and-dungeon game, so a light story beat works):

**Option A — "Intro / Story" screen (recommended for first-time feel)**
A brief 1–3 panel intro that sets up *who you are and what you're doing*:
> "You've inherited your uncle's forge. Merge materials into gear, fill customer
> orders by day, brave the dungeon by night. Build your reputation."

Then a single **"Begin"** button → prep_phase. This is the "middle screen" you're
sensing. It gives the game a soul and the player a goal ("build reputation to unlock
the dungeon").

**Option B — "How to Play" / tutorial overlay**
If you'd rather not write story, a one-screen visual explainer of the core loop:
*merge 3 → sell to customers → earn gold → buy upgrades → unlock the dungeon*.
Cheaper to produce, still solves the "why am I shopping?" problem.

Either way: **show this only on a fresh save** (gate on `not SaveManager.has_save()`
on New Game, or a `seen_intro` flag in the save). Returning players hitting Continue
should skip straight to prep as they do now.

> Concretely: add `res://core/intro.tscn` + an `EventBus.intro_finished` signal, and
> route `new_game_started` → intro → prep (instead of straight to prep) in
> `main.gd:15,57-60`.

### 1.2 🟠 No tutorial / first-time guidance on the merge board

The shop session is the heart of the game, and a new player gets zero instruction:
- The board is empty. Crates cost gold. Customers have orders. Nothing says "buy a
  crate, then drag matching items together."
- The merge rule ("connect 3+ of the same item") is never shown.
- The despawn timer on staged items (`floating_item`) will surprise players — items
  just vanish with no explanation the first time.

**Add a first-session coach:** a dismissible tooltip banner ("Tap a crate to draw
materials. Drag 3 of the same together to merge.") that appears on the first
shop_session only. Low-cost, high-impact. Optionally highlight the crate panel and
the board with a pulsing arrow until the first merge happens.

### 1.3 🟠 No confirmation dialogs anywhere

Several destructive actions have **no "are you sure?"**:
- **New Game** when a save exists → instantly wipes progress (`main.gd:58`
  `delete_save()`). A player tapping it by accident loses everything.
- **Quit to Menu** from prep (`prep_phase.gd:19`) → leaves the session with no save
  of board state mid-prep.
- **Reject customer** (`shop_session.gd:112`) → -2 rep, no confirm. (This one is
  arguably fine as a fast action, but the cost should at least be clear.)

**Add a reusable confirmation dialog** (Godot's `ConfirmationDialog`, or a themed
custom one matching the medieval UI). Wire it before New Game (when a save exists)
and before Quit to Menu at minimum.

### 1.4 🟡 No pause / settings / audio controls

There is no way to:
- Pause (relevant during the dungeon auto-battler and during a live shop session).
- Mute or adjust music/SFX volume (`audio_manager.gd` has no volume API at all).
- Toggle anything.

On mobile this matters — players get interrupted. Add a **gear icon** in the HUD → a
small **pause/settings overlay** with music + SFX sliders and a "Quit to Menu"
button. This is also where a future "reduce motion" toggle (see §4) could live.

### 1.5 🟡 No "you can't afford this" feedback beyond the button greying

In prep_phase, purchase cards disable when `gold < cost`, but there's **no
explanatory toast or shake** if a player taps a disabled/locked item. Disabled
buttons in Godot don't fire `pressed`, so tapping does *nothing* — the player doesn't
know if the game is broken or if they're short on gold. See §4.3 for the fix.

---

## 2. Per-screen polish

### 2.1 Main menu
- **Static and bare.** Title text + two buttons on a background image. No animation,
  no version/build number, no subtitle ("a merge-and-forge adventure" or similar).
- The **Continue button is disabled** with no visual distinction beyond the disabled
  stylebox — consider showing "Continue (Day X / Rep Y)" when a save exists, so the
  player remembers what they were doing. That data is all in the save already.
- **No fade-in.** The scene pops in instantly. A 0.3s title fade + button stagger
  would feel premium for ~10 lines of tween code.
- Add a small **settings/audio cog** here too (see 1.4).

### 2.2 Prep phase — the shopping hub
- **Title says "Prep Phase"** — a dev-facing term. Rename to something in-world:
  "The Forge", "Your Workshop", or "Between Days".
- **The board is invisible here.** Players buy blueprints/upgrades/reagents but can't
  *see* the thing they're upgrading. Consider a **preview** of the (expanded) grid
  and a small inventory readout (reagents owned) on this screen, so purchases have
  visible context. Right now buying "Board Expansion" gives no feedback that the grid
  grew — the player only finds out next session.
- **No gold/reputation shown on this screen** except via the global HUD. Since the
  whole point of the screen is spending gold, a prominent gold counter (bigger than
  the HUD's) and " reputation progress bar toward dungeon unlock (150)" would make
  the goal tangible. A progress bar to 150 rep turns an invisible number into a goal.
- **Three tabs (Blueprints / Upgrades / Reagents)** with no icons, just text. Add
  small icons to the tabs — they're already a `TabContainer`, cheap to theme.
- The **debug button ("DBG: Unlock All + 2000g + 1000rep")** is visible in normal
  builds (`prep_phase.gd:22`, `prep_phase.tscn:139`). Hide it unless
  `OS.is_debug_build()`. Players *will* tap it. (Also flagged in code review.)

### 2.3 Shop session — the core loop
- **Customer identity is weak.** The label shows the raw customer id
  (`customer.get("id", "Customer")`, `shop_session.gd:159`) — e.g. literally
  "cust_02" — instead of a name. There are 10 portrait images
  (`resources/sprites/portraits/customer_01..10.png`) but no names in the data. Give
  customers names + a one-line want (""I need a healing potion, quick!""). This is
  the single biggest "personality" win for the game.
- **No queue preview.** `PendingCustomers` is an empty HBox in the scene
  (`shop_session.tscn:92`); upcoming customers are invisible. Show the next 2–3 as
  small portrait thumbnails so the player can plan ("oh, the next one wants a sword,
  I should save this iron").
- **No feedback when you can't fulfill.** Tapping an order you can't fill flashes the
  card red (`order_card.gd:41`) — good — but doesn't say *why* or *how many you have
  vs need*. Add "have 1 / need 3" text, or grey out unfulfillable orders entirely so
  the player doesn't waste taps.
- **Crate opening has no ceremony.** Buying a crate just plays a sound and items
  appear. A loot-box-style reveal (crate shakes → bursts open → items fly out) would
  make spending gold feel rewarding. The animation infrastructure already exists
  (`merge_board`'s `_anim_overlay`).
- **Reject is permanent and instant.** Once rejected, the customer is gone with a
  -2 rep ding. A brief "Customer leaves angry" animation + the despawn sound (already
  in the project) would sell it.

### 2.4 Session summary
- **Functional but flat.** A title, four labels, a Continue button. The gold count-up
  tween (`session_summary.gd:29-31`) is a nice touch — extend that energy:
  - Count up **items sold** and **fulfilled** the same way (currently they pop in).
  - Show **reputation change** ("+10 rep → 160, dungeon unlocked!") — right now rep
    isn't on this screen at all, which makes the session feel unrewarding.
  - If the dungeon just got unlocked by this session's rep, surface a celebratory
    banner ("⚔️ Dungeon Unlocked!").
- **No "play again" / "next" framing** — the button just says "Continue" and dumps
  you back at prep. A short "Day complete" framing would make the loop click.

### 2.5 Dungeon run
- **"Walking..." for ~50 seconds of dead air.** The walk timer increments progress at
  ~0.002/tick (`dungeon_controller.gd:187`), and between encounters the screen just
  shows a progress bar and the word "Walking..." with nothing happening. This is the
  most boring moment in the game. Options:
  - Animate the party sprites bobbing/shuffling right (the `party_member` nodes are
    static TextureRects).
  - Sprinkle ambient "flavor" events during the walk (a coin found, a flavor-text
    log line, the background parallax-scrolling).
  - At minimum, speed up the walk or cut it between encounters.
- **Encounter start has no punch.** The label flips to "Encounter 1!" and enemies
  pop in. Add a brief **"screen flash + zoom + encounter banner"** (the
  `dungeon_start.wav` already exists and plays once at scene load, not per
  encounter — consider a per-encounter sting).
- **Combat is invisible math.** HP bars update via the `combat_unit` nodes, but
  there's **no damage numbers, no hit flashes, no attack animations.** The party and
  enemies just stand still while numbers tick down once a second. This makes the
  auto-battler feel like watching a spreadsheet. Even cheap juice helps enormously:
  - Floating damage numbers on each tick.
  - A brief lunge/hop tween from attacker toward target.
  - Hit-flash (white modulate → normal) on the target.
  - The `ko.wav` plays on member KO (good), but there's no visual beyond a greyscale
    (`party_member.gd:37`) — add a fall-over/fade tween.
- **No way to use dungeon-usable items clearly.** `party_member._can_drop_data`
  accepts a drag of a usable item, but (per code review) drag is mouse-only — so on
  the target platform players can't use potions at all. Even on desktop there's no
  hint that dragging a potion onto a party member is a thing. Add a "use item" affordance.
- **Enemy sprites** use the same portrait/sprite loading pattern; if there's only one
  dungeon (`goblin_cave`), make sure enemies are visually distinct and the encounter
  composition is readable (2 slimes vs 1 goblin boss should look different at a glance).

### 2.6 Dungeon summary
- Same flatness as session summary. Failed runs show red title + "-20 rep" and
  nothing else — no "your party was wiped at encounter 2" context, no "try again"
  encouragement. Cleared runs don't celebrate. Extend the count-up juice and add a
  victory sting (`dungeon_clear.wav` exists — confirm it plays on the summary, not
  just on the `dungeon_cleared` signal during gameplay).

---

## 3. Missing meta-progression / "reasons to keep playing"

The game has the bones of a loop but few long-term hooks visible to the player:

- **No "day" or session counter.** There's no sense of progression over time. A
  "Day 5" indicator in the HUD would give structure.
- **No reputation tier visualization.** Reputation has levels (low/mid/high,
  `game_manager.gd:75-80`) and unlocks the dungeon at 150, but the player never
  *sees* the tier or the next threshold. A reputation bar with tier markers would
  turn grinding rep into a visible goal.
- **No collection / codex.** You unlock blueprints and craft items, but there's no
  "items discovered" screen. A simple codex ("12 / 20 recipes discovered") is a
  proven retention hook for merge/craft games and you already have all the data.
- **No dungeon variety yet.** Only `goblin_cave` exists, so once unlocked the dungeon
  is always the same. (This is content, not UX — flagging it as a future direction.)
- **No win state / long-term goal** beyond "get rep." Consider an explicit goal
  ("reach 500 rep to restore the forge" / "clear all dungeons") so the game has an
  arc.

---

## 4. Juice & game feel (applies everywhere)

The game has the *foundations* of juice (merge burst/converge tweens in
`merge_board.gd:3-7`, gold count-ups in summaries, order-card red flash, bonus coins)
but it's uneven. Priorities:

### 4.1 Screen transitions are instant cuts
`main._transition_to` (`main.gd:70-81`) frees the old scene and adds the new one with
no transition. Every screen change is a hard cut. Add a **fade-to-black** (or
crossfade) between scenes — it's a ~20-line `ColorRect` + `Tween` overlay in `main.tscn`
and instantly makes the game feel cohesive instead of jumpy.

### 4.2 Button feedback
Buttons use themed StyleBoxes for normal/pressed/hover/disabled, but there's **no
press animation** (scale-down on tap, bounce-back on release). On mobile, a tactile
squish on tap is one of the highest feel-per-line-of-code wins:
```gdscript
func _on_pressed(): create_tween().tween_property(self, "scale", Vector2(0.95,0.95), 0.06)
# and back on release
```
Consider a shared `ButtonBehaviour` script applied to all buttons.

### 4.3 "Can't afford" / error feedback
Disabled purchase cards do nothing on tap (Godot disabled buttons don't fire). Add a
**shake + "Not enough gold" toast** when the player *tries* to buy something they
can't afford — either by keeping the button enabled and rejecting with feedback, or
by adding a `gui_input` handler that detects taps on disabled buttons. Right now
"nothing happens" reads as a bug.

### 4.4 Gold/reputation changes aren't animated in the HUD
`hud.gd:14-19` just rewrites the label text on every change. A **rolling count** (the
same `tween_method` already used in summaries) + a brief **scale pulse** + a **+N**
floater on gold gains would make earning feel good. Same for rep. This is the most-seen
UI in the game; it deserves the most juice.

### 4.5 Merge reward clarity
When a merge produces bonus gold, `merge_board.show_gold_text` shows it — good. But
there's no **combo/multiplier** framing for big merges (groups of 4, 5, 6). A
"Nice! / Great! / Amazing!" popup scaled to merge size is cheap and rewarding. Bonus
coins already spawn — add a little spawn animation (pop + arc) instead of them just
appearing.

### 4.6 Audio gaps & polish
- SFX exist for the main events (`merge_complete`, `gold_earn`, `customer_happy`,
  `customer_reject`, `crate_open`, `ko`, etc.) — good coverage.
- **No UI click/hover sound.** Every button press is silent. A subtle
  `ui_click.wav` wired into the shared button behaviour (4.2) ties the audio feel
  together.
- **Music is binary** (shop_theme / dungeon_theme / off). The transitions in
  `main.gd:83-90` hard-switch tracks with no crossfade. `audio_manager` has fade
  in/out for *a* track but not for transitioning *between* tracks. Crossfade music
  on scene change.
- **No victory/defeat music** distinct from the themes.

### 4.7 Haptics (mobile)
Since the target is mobile, add **light haptic feedback** (`Input.vibrate_handheld(...)`
or the Android vibration API) on: successful merge, bonus coin collect, purchase,
customer fulfill, KO, dungeon clear. Haptics are a huge part of mobile "feel" and the
game currently has none.

### 4.8 Idle / empty states
- Empty scroll containers (e.g. reagents tab when you own none) show nothing. Add
  friendly empty-state copy ("No reagents yet — buy one to unlock variant merges").
- An empty board at session start (before buying a crate) has no prompt. A faint
  "Tap a crate to begin" hint that disappears on first placement helps.

---

## 5. Accessibility & clarity (quick wins)

- **Tiny text on phone.** Many labels are 16–24px (`shop_session.tscn:45`,
  `hud.tscn:42`). On a 1080×1920 phone held at arm's length, 16px is hard to read.
  Bump body text to ~22–28px and ensure the HUD gold/rep is large.
- **Color-only state.** Owned blueprints are green, locked are grey, affordable are
  white (`prep_phase.gd:122-126`). Color-blind players lose this signal. Add an icon
  (✓ for owned, 🔒 for locked) in addition to color.
- **No "reduce motion" option.** Several effects (flashes, shakes) could be
  uncomfortable. A toggle in settings (1.4) that shortens/disables tweens is a cheap
  inclusivity win.
- **Contrast:** grey-on-grey customer labels (`shop_session.tscn:42`,
  `Color(0.7,0.7,0.7)`) on a textured background may be unreadable. Verify against
  the actual background art.

---

## 6. Recommended priority order

If you do nothing else, these give the most "feel" per effort:

**Tier 1 — fix the onboarding cliff (your "missing screen" instinct)**
1. §1.1 Add an intro/story (or "how to play") screen between New Game and prep.
2. §1.3 Add a confirmation dialog before New Game wipes a save.
3. §2.3 Give customers **names** (replace `cust_02` display) + show the upcoming queue.
4. §2.2 Rename "Prep Phase" → in-world title; add a reputation progress bar to 150.

**Tier 2 — make the core loop feel alive**
5. §4.1 Fade/crossfade between scenes (kills the "hard cut" jank everywhere).
6. §4.4 Animate HUD gold/rep (rolling count + pulse + floater).
7. §4.2 Tactile button press animation + a UI click sound (4.6).
8. §2.5 Add combat juice: damage numbers, hit flashes, attack lunges (the dungeon is
   currently the dullest screen; this flips it).

**Tier 3 — depth & retention**
9. §3 Reputation tier bar + day counter in the HUD.
10. §2.4 Count up all summary stats + surface rep change + "dungeon unlocked" banner.
11. §1.4 Settings overlay with audio sliders + pause.
12. §3 A recipe/item codex screen ("discovered X / Y").

**Tier 4 — polish rounding**
13. §4.3 "Not enough gold" shake/toast.
14. §4.7 Mobile haptics on key events.
15. §4.6 Crossfade music on scene transitions; victory/defeat stings.
16. §2.1 Main menu fade-in + "Continue (Day X)" label.

---

*Generated 2026-07-03. Read alongside `tmp/code-review.md` — this one is "what the
player feels," that one is "what will break."*
