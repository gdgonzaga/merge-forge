# AGENTS.md

MergeForge — a portrait mobile merge game for Android, built in Godot 4.7 with GDScript only. The player merges items on a grid board to fill customer orders in a shop, spends earnings in a prep phase (blueprints, upgrades, reagents), and runs dungeons that use a second merge board. Work lands directly on `main`.

## Hard rules

1. **Content is data.** All content (items, party members, enemies, effects, reagents, blueprints, crates, upgrades, customers, dungeons) lives in `res://resources/definitions/<catalog>/*.tres`, loaded by `DefinitionLibrary`. Definitions use dedicated `Resource` subclasses; anything with art has a single `sprite: Texture2D` property for its visual representation. Definitions reference each other directly, never by id string, and references only point down the tiers (Godot can't load cyclic resources). Scripts never hardcode content values or content ids.
2. **No cross-subsystem coupling.** A subsystem folder never preloads from, or node-paths into, another subsystem's folder. No `get_node("../../")`. Talk across subsystems through autoloads or EventBus. The shared folders `ui/` and `resources/` are the only exceptions (see Project map).
3. **`res://` is read-only at runtime.** Saves and every other runtime write go to `user://`.
4. **Never commit, amend, or rewrite history unless explicitly asked.** "Work lands on main" describes where commits go once requested, not permission to make them. Ask the user for permission if such action is needed.
5. **No backward compatibility.** Don't write migration layers, legacy fallbacks, optional-field shims or compatibility parsers, and that includes save files: bump `GameManager.SAVE_VERSION` instead, and old saves are rejected as CORRUPT. When a schema changes, update the definitions and code directly. Always flag breaking changes to the user.
6. **Run only relevant tests, and only when needed.** Run the suites that cover the code you changed in this session. Don't run the full suite by default.
7. **Scratch files go in `tmp/<task-name>/`.** Never in the repo root or subsystem folders. Never commit `tmp/`.
8. **No LaTeX** (`$...$`, `\pm`, `\times`) in responses, docs, or comments. Write `+/- 3`, `2x2`, `5x5`.

## Project map

| Path | Contents |
|---|---|
| `autoloads/` | `EventBus` (signal relay), `GameManager` (all persistent state), `DefinitionLibrary` (loads every `.tres` definition), `RecipeResolver` (rules over definitions: merge options, blueprint gates, weighted rolls), `SaveManager` (JSON save to `user://save_data.json`), `AudioManager` |
| `core/` | `main.tscn` (root; swaps screens in `SceneContainer` on EventBus signals), `main_menu`, `intro`, `prep_phase`, `hud` |
| `board/` | Merge board shared by shop and dungeon: grid, cells, drag and drop, merge detection and resolution, merge-choice popup, bonus coins |
| `shop/` | Shop session: customer queue, order and purchase cards, crates, session summary |
| `dungeon/` | Dungeon run: combat engine and units, party, enemies, drops, summary |
| `ui/` | **Shared**, subsystem-agnostic widgets (for example `confirm_dialog`). Any subsystem may preload from `ui/`, but `ui/` must never reference a subsystem. |
| `resources/` | **Shared** assets: definitions (`definitions/<catalog>/*.tres`, one folder per catalog, file name = id), sprites, audio, fonts, themes |
| `test/unit/`, `test/helpers/` | gdUnit4 suites; `TestBase` is the base class for all suites |
| `docs/` | Design docs (GDD, architecture, task list). `ARCHITECTURE.md` is the source of truth for the scene tree, the autoload list and the EventBus registry. |

Screen flow: MainMenu -> (New Game) Intro -> PrepPhase <-> ShopSession -> SessionSummary -> PrepPhase; PrepPhase -> DungeonRun -> DungeonSummary -> PrepPhase.

## Architecture rules

- **Cross-scene communication goes through EventBus**, which only relays signals and holds no state. Adding a signal is fine when it's needed, but update the EventBus registry table in `docs/ARCHITECTURE.md` in the same change.
- **Same-scene communication uses direct references.** GameManager state changes are announced on GameManager's own signals (`gold_changed`, etc.), not on EventBus.
- **All persistent state lives in GameManager.** When you add a persistent field, update `serialize()`, `deserialize()` and `is_valid_save()` in the same change. `deserialize({})` is the single source of fresh-game defaults; both New Game and `TestBase` use it.
- **Signals describe events, not commands:** `customer_fulfilled`, not `fulfill_customer`.
- **Composition over inheritance.** Behavior lives in child nodes (`@onready var _x: Type = $Child`) or small `RefCounted` helpers. Panels and helpers expose `setup(...)`, called right after `add_child` or construction. `_init` is rare.
- **Update `docs/ARCHITECTURE.md` alongside the code** whenever scenes, autoloads, EventBus signals or save fields change.

## Data conventions

- **Identity is the `id` string** (the dictionary key, or an `id` field in array-shaped files), never the display `name`. Ids are `snake_case`.
- **Read content through `DefinitionLibrary`** and never mutate a loaded definition: they are shared. `duplicate()` first if you need a modified copy.
- **An id is part of the save format.** Saves store ids (blueprints, reagents, upgrades, board items), so renaming one needs a `SAVE_VERSION` bump.

## GDScript style

- **Indentation and typing:** tabs, full static typing, `-> ReturnType` on every function, typed parameters, and `:=` for inferred types.
- **Naming:**
  - `snake_case` file names; a `.tscn` file name matches its root node name.
  - `PascalCase` for classes and nodes.
  - `_` prefix for private members.
  - `SCREAMING_SNAKE_CASE` for constants and enum members.
- **Autoload scripts omit `class_name`.**
- **Function structure:**
  - Keep functions small and single-purpose. Split one when it does more than one job; around 30 lines is a warning sign, not a hard limit.
  - Prefer pure helpers that take typed arguments over helpers that read or mutate shared state.
  - Put public and orchestrating functions first, with private helpers below the functions that call them, so a file reads top-down.
- **Comments:** explain *why* (an invariant, a Godot quirk, a bug a line guards against), not *what*. Match the comment density of the surrounding code. Don't add a comment to every call.

## UI

- **Prefer `.tscn` scenes over nodes built in code** for any non-trivial UI.
- **Reference UI nodes by unique name (`%Name`)**, not `$A/B/C` path chains, which break when a scene is restructured.
- **Mobile constraints.** The game is portrait-only, running on the Mobile renderer with touch input.
  - **Canvas:** design at 1080x1920 with `canvas_items` stretch. Layouts must hold from 9:16 up to tall 9:21 phones, so use anchors and containers and never absolute positions near screen edges.
  - **Safe area:** keep interactive and critical UI inside `DisplayServer.get_display_safe_area()` (notches and gesture bars), with at least 48 px of side margin.
  - **Touch targets:** at least 120x120 px on the 1080-wide canvas, which is about 48 dp on a typical phone, with at least 24 px between adjacent targets.
  - **Text:** at least 32 px; body text 40-48 px.
  - **Input:** no hover-only affordances, no right-click, and no keyboard-only paths. Mouse input emulates touch for desktop testing.
  - **Android back button** (`NOTIFICATION_WM_GO_BACK_REQUEST`) must do something sensible on every screen: close a popup, go back, or confirm quit. Save on `NOTIFICATION_APPLICATION_PAUSED`.
  - **Performance:** target 60 fps on mid-range Android. Don't allocate per frame in `_process`, and don't use features that only work on Forward+.

## Testing

Framework: gdUnit4 (`addons/gdUnit4`). Godot binary: `godot` (4.7).

```sh
# One suite (the normal case, per Hard rule 6)
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_game_manager.gd
# Whole suite
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/
```

- **Stale class cache.** If a run fails with `Could not find type` or `Identifier "X" not declared` for a class that exists, run `godot --headless --import` once, then rerun.
- **Fail-stop.** gdUnit4 stops a suite at its first failure, so `Executed test cases: (3/3)` can hide later tests. Fix the earliest failure and rerun.
- **Reports** land in `reports/`, which is gitignored.

### Test rules

- **Every suite extends `TestBase`.** Before each test it resets GameManager to a fresh game and redirects `SaveManager.save_path` to `TestBase.TEST_SAVE_DIR`. After each test it removes that folder and restores any catalog fixtures. Suites that override `before_test()` or `after_test()` must call `super`.
- **Tests are content-agnostic.** Never assert on shipped ids, counts or values from the definitions (for example `"iron_ore"`). Build fixture definitions in code (`ItemDefinition.new()`, ...) and pass them directly, or register them with `set_definition(DefinitionLibrary.<catalog>, def)`; `TestBase` puts back exactly what was there before.
- **Never touch the developer's real save.** Use `SaveManager.save_path`, never a hardcoded `user://save_data.json`. Any other `user://` fixture folder must be removed in `after_test()`, which runs even when an assertion fails.
- **Restore only what you touched.** Snapshot the ids and fields a test changes and put back exactly those; a blanket clear can hide a leak.
- **No wall-clock waits:** no `create_timer`, `OS.delay_msec` or busy loops. Await `process_frame` in a bounded loop tied to the real condition, or await the component's completion signal.
- **No tautologies.** Expected values are literals derived by hand, never the formula the code under test uses.
- **Compare nodes with `is_same`**, never `is_equal`, which can crash gdUnit on a mismatch.
- **Test the public contract**, not `_`-prefixed helpers.
- **One owner per scenario.** Before adding a test, check whether an existing suite already covers the behavior, and delete the weaker duplicate. Split a suite by feature before it grows past a few hundred lines.
- **Mutation-check high-risk code:** save/load and validation, gold and reagent accounting, merge resolution, and combat damage. Break the production line on purpose in a scratch copy and confirm the test goes red.
- **No tests that pin a legacy shape** (Hard rule 5). Delete the test and the production fallback together, and flag the break.

## Commits

Commit only on request (Hard rule 4).

- **Format:** Conventional Commits, `type(scope): lowercase imperative subject`, with an optional task tag at the end.
  - Example: `feat(shop): show pending customers as a portrait queue (U3)`
- **Types:** `feat`, `fix`, `refactor`, `test`, `chore`, `docs`, `wip`.
- **Scopes:** `board`, `shop`, `dungeon`, `core`, `ui`, `save`, `data`, `audio`, `test`, `build`, `arch`.
- **Body:** explain what changed and why, and end with the test tally for the suites you ran (for example `31/31 green`).
