# Dungeon Attack Badge Line Heads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace static battle line heads with an animated attack badge system in dungeon combat: the badge background fills as a bottom-to-top windup gauge, flashes with a glow pulse on full, detaches and shoots along the battle line trajectory as the line head, impacting the target before resetting.

**Architecture:** Split the attack badge into a universal background asset (`badge_bg.png`) and transparent foreground icons (`badge_icon_melee.png`, `badge_icon_missile.png`). Refactor `AttackBadge` into an empty silhouette backing, a bottom-to-top `TextureProgressBar` gauge, a foreground icon, and a glow flash tween. Update `CombatLines` to launch flying badge background heads along the curved lane starting directly from the attacker's attack badge screen position and rotating along trajectory. Update `CombatPresenter` to coordinate the windup gauge during tick progress, trigger the badge launch and empty state, and resolve impact damage after a tunable flight duration (`ATTACK_FLIGHT_DURATION := 0.25`).

**Tech Stack:** Godot 4.7, GDScript (strict typing), gdUnit4.

**Spec:** User interview requirements captured via `/grill-me` on 2026-09-29.

## Global Constraints

- **Static typing:** Full static typing on all functions, return types (`-> void`, `-> Vector2`), and variables (`:=`).
- **No cross-subsystem coupling:** `dungeon/` never preloads outside its folder except `ui/` and `resources/`.
- **Content is data:** Definitions are read-only; assets live in `resources/sprites/ui/` and `resources/sprites/vfx/`.
- **Test rules:** Suites extend `TestBase`, run headlessly via gdUnit4, assert on behaviors rather than hardcoded definitions.
- **Save format:** No changes to save schema or `GameManager.SAVE_VERSION`.
- **No LaTeX:** Use standard text notation (`+/-`, `x`).

## Review Focus

1. **Mid-flight attacker death or KO:** When an attacker dies or gets KO'd while their projectile is mid-flight, the flying badge head and line must still cleanly finish travel to impact or vanish without crashing null references.
2. **Mid-flight target death:** When a target dies before an incoming flying badge arrives (e.g. from an earlier simultaneous strike), the flying badge must not crash attempting to dereference the dead target.
3. **Encounter end / combat stop:** When combat stops or all enemies die, all active in-flight projectiles, lines, and windup glow tweens must immediately clean up without orphan nodes or lingering redraws.
4. **Crit windup scaling:** Crit attacks wind up for `CRIT_WINDUP_MULT` (2x) duration; the gauge must advance at half-speed to reach exactly 100% when the crit windup completes, tinted gold, with the "!" crit mark visible.
5. **Zero windup or rapid attacks:** If windup is 0 or ticks advance rapidly, the gauge must clamp properly between 0.0 and 1.0 without dividing by zero or flickering.

---

### Task 1: Asset Preparation & Split

**Files:**
- Create: `resources/sprites/ui/badge_bg.png`
- Create: `resources/sprites/ui/badge_icon_melee.png`
- Create: `resources/sprites/ui/badge_icon_missile.png`
- Test: `test/unit/test_combat_badge_assets.gd`

**Interfaces:**
- Consumes: Existing `badge_melee.png` and `badge_missile.png` (48x48 RGBA).
- Produces: `res://resources/sprites/ui/badge_bg.png` (universal circular/shield background backing), `res://resources/sprites/ui/badge_icon_melee.png` (sword icon foreground with transparent background), `res://resources/sprites/ui/badge_icon_missile.png` (bow icon foreground with transparent background).

- [ ] **Step 1: Write the failing test for asset presence and dimensions**

Create `test/unit/test_combat_badge_assets.gd`:
```gdscript
extends TestBase

func test_badge_assets_exist_and_have_correct_dimensions() -> void:
	var bg = load("res://resources/sprites/ui/badge_bg.png")
	var melee = load("res://resources/sprites/ui/badge_icon_melee.png")
	var missile = load("res://resources/sprites/ui/badge_icon_missile.png")

	assert_object(bg).is_not_null()
	assert_object(melee).is_not_null()
	assert_object(missile).is_not_null()

	assert_vector(bg.get_size()).is_equal(Vector2(48, 48))
	assert_vector(melee.get_size()).is_equal(Vector2(48, 48))
	assert_vector(missile.get_size()).is_equal(Vector2(48, 48))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_combat_badge_assets.gd`
Expected: FAIL with null resource or load error.

- [ ] **Step 3: Generate the split assets from existing badge sprites**

Write a Python script in `tmp/badge-split/split_badges.py` to extract:
1. `badge_bg.png`: The outer circular frame and backing fill (48x48 RGBA), with the center icon removed/smoothed into a universal backing.
2. `badge_icon_melee.png`: The sword artwork extracted with alpha 0 for all background pixels (48x48 RGBA).
3. `badge_icon_missile.png`: The bow artwork extracted with alpha 0 for all background pixels (48x48 RGBA).
Save the resulting PNGs into `res://resources/sprites/ui/`.
Run `godot --headless --import` to import them into Godot.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_combat_badge_assets.gd`
Expected: PASS (1/1 green).

---

### Task 2: AttackBadge Component Refactor

**Files:**
- Modify: `dungeon/attack_badge.gd`
- Modify: `dungeon/attack_badge.tscn`
- Test: `test/unit/test_attack_badge.gd`

**Interfaces:**
- Consumes: `badge_bg.png`, `badge_icon_melee.png`, `badge_icon_missile.png`.
- Produces:
  - `AttackBadge.set_attack_type(attack_type: String) -> void`
  - `AttackBadge.set_team_color(color: Color) -> void`
  - `AttackBadge.set_fill_progress(progress: float, is_crit: bool, side: int) -> void`
  - `AttackBadge.set_empty() -> void`
  - `AttackBadge.play_glow_pulse() -> void`
  - `AttackBadge.get_badge_center() -> Vector2`

- [ ] **Step 1: Write failing unit tests for AttackBadge behavior**

Create `test/unit/test_attack_badge.gd`:
```gdscript
extends TestBase

const BADGE_SCENE := preload("res://dungeon/attack_badge.tscn")

func test_attack_badge_initializes_empty_and_sets_type() -> void:
	var badge = BADGE_SCENE.instantiate()
	add_child(badge)
	badge.set_attack_type("melee")
	assert_float(badge.get_fill_progress()).is_equal(0.0)

	badge.set_fill_progress(0.5, false, 0)
	assert_float(badge.get_fill_progress()).is_equal_approx(0.5, 0.01)

	badge.set_empty()
	assert_float(badge.get_fill_progress()).is_equal(0.0)
	badge.queue_free()

func test_attack_badge_crit_tinting() -> void:
	var badge = BADGE_SCENE.instantiate()
	add_child(badge)
	badge.set_fill_progress(0.75, true, 0)
	assert_bool(badge.is_crit_active()).is_true()
	badge.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_attack_badge.gd`
Expected: FAIL due to missing methods on `AttackBadge`.

- [ ] **Step 3: Refactor `attack_badge.tscn` and `attack_badge.gd`**

In `attack_badge.tscn`:
Root `Control` (custom minimum size 40x40 or 48x48):
- `%SlotBacking` (`TextureRect`): translucent/dimmed `badge_bg.png` (alpha ~0.25).
- `%GaugeProgress` (`TextureProgressBar`): texture `badge_bg.png`, `fill_mode = FILL_BOTTOM_TO_TOP`, range 0..1000.
- `%Icon` (`TextureRect`): displays `badge_icon_melee.png` or `badge_icon_missile.png`.
- `%GlowOverlay` (`TextureRect`): additive blend or white tint overlay for the split-second pulse, modulate.a = 0 by default.

In `attack_badge.gd`:
- Implement `set_attack_type(attack_type: String) -> void`: sets `%Icon.texture`.
- Implement `set_team_color(color: Color) -> void`: sets base tint for `%GaugeProgress`.
- Implement `set_fill_progress(progress: float, is_crit: bool, side: int) -> void`: updates `%GaugeProgress.value = progress * 1000`, applies party/enemy/crit ramp tinting.
- Implement `set_empty() -> void`: sets gauge value to 0.
- Implement `play_glow_pulse() -> void`: tweens `%GlowOverlay.modulate.a` from 1.0 to 0.0 over 0.12s with a subtle scale bump on `%Icon` / `%GaugeProgress` from 1.15x back to 1.0x.
- Implement `get_badge_center() -> Vector2`: returns global center of the badge.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_attack_badge.gd`
Expected: PASS (2/2 green).

---

### Task 3: Unit Attack Badge Interface (`party_member.gd` and `enemy_display.gd`)

**Files:**
- Modify: `dungeon/party_member.gd`
- Modify: `dungeon/enemy_display.gd`
- Test: `test/unit/test_unit_attack_badge.gd`

**Interfaces:**
- Consumes: Refactored `AttackBadge` from Task 2.
- Produces:
  - `party_member.gd`: `get_badge() -> AttackBadge`, `get_badge_center() -> Vector2`, `set_windup_progress(progress: float, is_crit: bool) -> void`, `play_badge_glow() -> void`, `clear_badge_gauge() -> void`.
  - `enemy_display.gd`: `get_badge() -> AttackBadge`, `get_badge_center() -> Vector2`, `set_windup_progress(progress: float, is_crit: bool) -> void`, `play_badge_glow() -> void`, `clear_badge_gauge() -> void`.

- [ ] **Step 1: Write failing unit test for party and enemy badge interface**

Create `test/unit/test_unit_attack_badge.gd`:
```gdscript
extends TestBase

const PARTY_SCENE := preload("res://dungeon/party_member.tscn")
const ENEMY_SCENE := preload("res://dungeon/enemy_display.tscn")

func test_party_member_exposes_badge_helpers() -> void:
	var member = PARTY_SCENE.instantiate()
	add_child(member)
	var def = PartyMemberDefinition.new()
	def.name = "Hero"
	def.attack_type = "melee"
	def.max_hp = 50
	member.setup(def, 0)

	assert_object(member.get_badge()).is_not_null()
	member.set_windup_progress(0.7, false)
	assert_float(member.get_badge().get_fill_progress()).is_equal_approx(0.7, 0.01)

	member.clear_badge_gauge()
	assert_float(member.get_badge().get_fill_progress()).is_equal(0.0)
	member.queue_free()

func test_enemy_display_exposes_badge_helpers() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.setup({"sprite": null, "attack_type": "missile", "current_hp": 30, "max_hp": 30})

	assert_object(enemy.get_badge()).is_not_null()
	enemy.set_windup_progress(0.4, false)
	assert_float(enemy.get_badge().get_fill_progress()).is_equal_approx(0.4, 0.01)

	enemy.clear_badge_gauge()
	assert_float(enemy.get_badge().get_fill_progress()).is_equal(0.0)
	enemy.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_unit_attack_badge.gd`
Expected: FAIL due to missing badge methods on `party_member.gd` and `enemy_display.gd`.

- [ ] **Step 3: Implement methods on `party_member.gd` and `enemy_display.gd`**

Add public methods:
- `get_badge() -> AttackBadge`: returns `_badge`.
- `get_badge_center() -> Vector2`: returns `_badge.get_global_rect().get_center()`.
- `set_windup_progress(progress: float, is_crit: bool) -> void`: delegates to `_badge.set_fill_progress(progress, is_crit, SIDE_PARTY/SIDE_ENEMY)`.
- `play_badge_glow() -> void`: calls `_badge.play_glow_pulse()`.
- `clear_badge_gauge() -> void`: calls `_badge.set_empty()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_unit_attack_badge.gd`
Expected: PASS (2/2 green).

---

### Task 4: CombatLines Badge Head & Flight Trajectory

**Files:**
- Modify: `dungeon/combat_lines.gd`
- Modify: `dungeon/dungeon_run.tscn`
- Test: `test/unit/test_combat_lines_flight.gd`

**Interfaces:**
- Consumes: `badge_bg.png`, unit badge global positions.
- Produces:
  - `CombatLines.launch_attack(side: int, attacker: int, target: int, damage: int, is_crit: bool, duration: float) -> void`
  - In-flight attack tracker managing head position, trajectory rotation, and trailing line.

- [ ] **Step 1: Write failing test for projectile launch and progress tracking**

Create `test/unit/test_combat_lines_flight.gd`:
```gdscript
extends TestBase

const LINES_SCENE := preload("res://dungeon/combat_lines.gd")

func test_launch_attack_tracks_flight_until_duration_expires() -> void:
	var lines = LINES_SCENE.new()
	add_child(lines)

	# Mock engine and units
	assert_bool(lines.has_active_flights()).is_false()
	lines.launch_attack(0, 0, 0, 20, false, 0.25)
	assert_bool(lines.has_active_flights()).is_true()

	lines.advance_flights(0.3)
	assert_bool(lines.has_active_flights()).is_false()
	lines.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_combat_lines_flight.gd`
Expected: FAIL due to missing `launch_attack`, `has_active_flights`, etc.

- [ ] **Step 3: Update `combat_lines.gd` for badge background flight**

1. Replace line head textures:
   - Export `@export var badge_head: Texture2D` (assigned `badge_bg.png`).
2. Remove drawing lines during windup:
   - During windup, `_draw_windup` does not draw lines across the screen. Lines are only drawn for active flights.
3. Manage active flights:
   - Structure `Flight`: `side`, `attacker`, `target`, `damage`, `is_crit`, `start_time`, `duration`, `from_pos`, `to_pos`.
   - `launch_attack(...)`: creates a flight starting from the attacker's attack badge center to the target unit's anchor.
   - In `_process(delta)`: update flight progress `(now - start_time) / duration`. Once `progress >= 1.0`, flight finishes and is removed.
4. Draw flight:
   - Compute curve from `from_pos` (badge center) to `to_pos`.
   - `reach` advances from 0 to `cell_count` based on flight `progress`.
   - Draw trailing blocks up to `reach`.
   - Draw `badge_head` at `_block_center(reach - 1)`, rotated by `_aim(reach - 1).angle()` (plus 90-deg or 0-deg depending on badge orientation).
   - If `is_crit`: draw crit gold styling, pulse, and outline.
   - When flight reaches 1.0: vanishes immediately with no lingering stroke.
5. In `dungeon_run.tscn`: assign `badge_bg.png` to `CombatLines.badge_head`.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_combat_lines_flight.gd`
Expected: PASS.

---

### Task 5: CombatPresenter Timing & Synchronization

**Files:**
- Modify: `dungeon/combat_presenter.gd`
- Test: `test/unit/test_combat_presenter_flight.gd`

**Interfaces:**
- Consumes: `ATTACK_FLIGHT_DURATION := 0.25`, `CombatLines.launch_attack`, `unit.set_windup_progress`, `unit.play_badge_glow`, `unit.clear_badge_gauge`.
- Produces: Synchronized attack animation flow where damage, floating text, and hit recoil land after flight duration.

- [ ] **Step 1: Write failing test for combat presenter flight delay**

Create `test/unit/test_combat_presenter_flight.gd`:
```gdscript
extends TestBase

const PRESENTER := preload("res://dungeon/combat_presenter.gd")

func test_presenter_has_tunable_flight_duration() -> void:
	var presenter = PRESENTER.new()
	assert_float(presenter.get_flight_duration()).is_equal(0.25)
	presenter.set_flight_duration(0.3)
	assert_float(presenter.get_flight_duration()).is_equal(0.3)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_combat_presenter_flight.gd`
Expected: FAIL due to missing flight duration getters/setters.

- [ ] **Step 3: Implement presenter coordination in `combat_presenter.gd`**

1. Add tunable constant and property:
   `const DEFAULT_ATTACK_FLIGHT_DURATION := 0.25`
   `var flight_duration: float = DEFAULT_ATTACK_FLIGHT_DURATION`
2. In `_process`:
   - For each standing party member and enemy:
     - Query `_engine.get_windup_progress(side, i, 0.0)`.
     - If winding up and not currently in flight: call `unit.set_windup_progress(progress, is_crit)`.
3. When windup completes:
   - In `_on_party_attacked(member_index, target, damage, is_crit)`:
     - Attacker unit plays `play_badge_glow()`.
     - Attacker unit calls `clear_badge_gauge()`.
     - `_lines.launch_attack(SIDE_PARTY, member_index, target, damage, is_crit, flight_duration)`.
     - Use a timer / tween for `flight_duration`: upon timeout, execute impact: `_play_attack`, floating text, and `_refresh_enemy(target)`.
   - In `_on_enemy_attacked(enemy_index, target, damage, is_crit)`:
     - Attacker unit plays `play_badge_glow()`.
     - Attacker unit calls `clear_badge_gauge()`.
     - `_lines.launch_attack(SIDE_ENEMY, enemy_index, target, damage, is_crit, flight_duration)`.
     - After `flight_duration`: execute impact `_play_enemy_hit(...)`.
4. Ensure clean resets:
   - On encounter end or unit death: clear gauges and cancel active tweens.

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_combat_presenter_flight.gd`
Expected: PASS.

---

### Task 6: Visual Polish, Crit Effects & Full Verification

**Files:**
- Modify: `dungeon/attack_badge.gd`
- Modify: `dungeon/combat_lines.gd`
- Modify: `docs/ARCHITECTURE.md`
- Test: All relevant combat suites (`test_combat_engine.gd`, `test_combat_signals.gd`, `test_combat_view_math.gd`, new tests).

**Interfaces:**
- Consumes: All components from Tasks 1-5.
- Produces: Polished visual feel with crit marks, team tinting, smooth gauge transitions, and full regression verification.

- [ ] **Step 1: Write integration test verifying full combat cycle with badges**

Add a test in `test/unit/test_combat_signals.gd` (or dedicated test) confirming `windup_changed`, attack launch, and damage landing sequence.

- [ ] **Step 2: Run all relevant test suites**

Run:
```bash
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_combat_engine.gd
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_combat_signals.gd
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_combat_view_math.gd
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_attack_badge.gd
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_unit_attack_badge.gd
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_combat_lines_flight.gd
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_combat_presenter_flight.gd
```
Expected: All suites PASS green.

- [ ] **Step 3: Update documentation**

Update `docs/ARCHITECTURE.md` to reflect the updated `CombatLines` flight mechanism, `AttackBadge` component structure, and `CombatPresenter` flight duration timing.
Update `docs/TODO.md` to mark the task completed.
