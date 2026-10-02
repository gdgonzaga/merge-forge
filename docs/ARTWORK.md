# Artwork Notes — MergeForge

Last updated: 2026-09-30

Notes for anyone making or swapping art. The game is pixel art on a 1080x1920 canvas.

---

## Attack line heads

Each attack line in a dungeon ends in a head sprite: a slash for melee attackers, an arrow for missile attackers.

### Where to set them

Open `dungeon/dungeon_run.tscn`, select `AnimOverlay/CombatLines`, and set these in the Inspector:

| Property | What it is |
|---|---|
| `melee_head` | Melee head, drawn pointing **right** |
| `melee_head_diagonal` | Melee head, drawn pointing **down-right** |
| `missile_head` | Missile head, drawn pointing **right** |
| `missile_head_diagonal` | Missile head, drawn pointing **down-right** |
| `head_scale` | Line blocks per sprite pixel for normal heads (default 2) |
| `crit_head_scale` | Line blocks per sprite pixel for crit heads (default 3) |

The shipped heads are `resources/sprites/vfx/line_slash_head.png`, `line_arrow_head.png` and their `_diagonal` versions. The old `slash.png` and `arrow.png` are still used by the attack badge and the slash hit effect, so don't reuse them for heads.

### Why there are straight and diagonal versions

A pixel sprite stays crisp only when it's turned in 90 degree steps. Turning it 45 degrees forces Godot to resample it, and the edges go jagged. So each head has two drawings:

| Texture | Draw it pointing | Used for |
|---|---|---|
| Straight | right | right, down, left, up |
| Diagonal | down-right | down-right, down-left, up-left, up-right |

If a diagonal slot is left empty, the straight sprite is turned 45 degrees instead. That works, but it looks rougher.

### How to draw them

- **Draw in white and light greys with a dark outline.** The line's colour tints the sprite, so a white head takes the colour of its line (blue for party, peach for enemies, gold for crits, red for lethal hits). The outline stays dark.
- **Use a small, square, odd size**, like the current 7x7. An odd size gives the sprite a centre pixel, and that pixel sits on the end of the line.
- **Draw at native size (1 pixel per pixel).** The game scales heads up by whole numbers, so don't upscale or smooth the art yourself.
- **Keep hard edges.** Heads are drawn with nearest filtering, so blurred or anti-aliased edges show up as stray grey pixels.

---

## Attack line style

The lines themselves are drawn in code (`dungeon/combat_lines.gd`), not from textures:

- **Block grid.** One art pixel is 4 px on the 1080 canvas (`PIXEL`). Lines are traced block by block, so diagonals come out as stair steps.
- **Thickness.** 1 to 4 blocks, one block per quarter of the target's HP that the hit takes. Crits are at least 3 blocks.
- **Colour ramps.** Each side has three solid shades (dark, mid, light) with no transparency: `PARTY_RAMP`, `ENEMY_RAMP`, `CRIT_RAMP` and `LETHAL_RAMP`. Crit flashes and pulses switch between shades in steps instead of fading.
- **Rings.** Crit and lethal hits ring the target end with a circle drawn in blocks.

To change the look, edit those constants in `dungeon/combat_lines.gd`.

---

## Placeholder art (Phase 7)

These six definitions currently reuse existing item sprites and need their own 64x64 art in the same item frame:

| Definition | Current placeholder | Needed look |
|---|---|---|
| `ice_essence` | `resources/sprites/items/fire_essence.png` | A pale blue ice shard with a cold glow. |
| `shadow_essence` | `resources/sprites/items/fire_essence.png` | A dark violet wisp with a faint edge. |
| `holy_essence` | `resources/sprites/items/fire_essence.png` | A warm white glow from a small shrine fragment. |
| `frost_blade` | `resources/sprites/items/flame_sword.png` | A pale blue blade rimmed with frost. |
| `holy_draught` | `resources/sprites/items/phoenix_draught.png` | A bright, gold-tinted potion with a white aura. |
| `nightshade_tonic` | `resources/sprites/items/herbal_tonic.png` | A deep purple tonic with shadow around its bottle. |

## Placeholder art (Phase 8)

No new art was commissioned for towns, Guild Charter or the codex (Ruling 16). Every new definition below reuses an existing sprite.

**15 new items** (gem items reuse herb sprites, wood items reuse metal sprites — the same tier-for-tier mapping as the family they mirror):

| Definition | Current placeholder | Needed look |
|---|---|---|
| `rough_gem` | `resources/sprites/items/herb_leaf.png` | A small uncut gem shard, grey-blue with a rough facet. |
| `cut_gem` | `resources/sprites/items/herb_bundle.png` | A cluster of cut gems with a faint inner glow. |
| `polished_gem` | `resources/sprites/items/herbal_tonic.png` | A polished gem cluster with a bright, faceted shine. |
| `mending_ring` | `resources/sprites/items/healing_potion.png` | A silver ring set with a healing-blue gem. |
| `keen_amulet` | `resources/sprites/items/battle_elixir.png` | A sharp-cut amulet that glints when it catches light. |
| `phoenix_diadem` | `resources/sprites/items/phoenix_draught.png` | A gold diadem crowned with a fiery gem. |
| `radiant_scepter` | `resources/sprites/items/phoenix_draught.png` | A jeweled scepter radiating a warm, holy light. |
| `shade_crystal` | `resources/sprites/items/herbal_tonic.png` | A dark, faceted crystal wreathed in shadow. |
| `timber_log` | `resources/sprites/items/iron_ore.png` | A rough-cut log with visible wood grain. |
| `wood_plank` | `resources/sprites/items/iron_ingot.png` | A stack of smooth, finished wood planks. |
| `oak_stave` | `resources/sprites/items/iron_plate.png` | A sturdy oak stave banded at both ends. |
| `longbow` | `resources/sprites/items/sword.png` | A curved longbow strung with a taut cord. |
| `warding_staff` | `resources/sprites/items/iron_shield.png` | A carved staff topped with a warding rune. |
| `ember_wand` | `resources/sprites/items/flame_sword.png` | A slender wand tipped with a flickering ember. |
| `frost_wand` | `resources/sprites/items/flame_sword.png` | A slender wand rimmed with frost. |

**Four new crates:**

| Definition | Current placeholder | Needed look |
|---|---|---|
| `miner_crate` | `resources/sprites/items/crate_basic.png` | A miner's crate with pick-and-lantern stenciling. |
| `themed_gem` | `resources/sprites/items/crate_herb.png` | A lined jeweler's box for sorted gems. |
| `forager_crate` | `resources/sprites/items/crate_basic.png` | A forager's basket crate with a druid's-satchel look. |
| `themed_wood` | `resources/sprites/items/crate_metal.png` | A bundled-timber crate with rope lashing. |

**26 new customer portraits:** `st_01`-`st_13` (Stonereach) and `gh_01`-`gh_13` (Greenhollow) all reuse `resources/sprites/portraits/customer_01.png` through `customer_10.png` (cycling past 10). Needed look: a miner/jeweler cast for Stonereach, a ranger/druid cast for Greenhollow, matching each town's description.

**Six new modifier icons:**

| Definition | Current placeholder | Needed look |
|---|---|---|
| `gem_shortage` | `resources/sprites/modifiers/herb_shortage.png` | A cracked, empty gem-cutter's tray. |
| `mage_conclave` | `resources/sprites/modifiers/knights_tournament.png` | A cluster of mage hats and glowing staves. |
| `prospectors_day` | `resources/sprites/modifiers/caravan_day.png` | A prospector's pick and pan icon. |
| `rangers_muster` | `resources/sprites/modifiers/knights_tournament.png` | A banner of crossed bows. |
| `timber_glut` | `resources/sprites/modifiers/iron_glut.png` | A stacked-logs icon. |
| `wagon_day` | `resources/sprites/modifiers/caravan_day.png` | A timber-laden wagon icon. |

**Town backgrounds:** Stonereach and Greenhollow both reuse `resources/sprites/backgrounds/bg_shop_session.png`. Needed look: a mining-town backdrop (Stonereach) and a forest-village backdrop (Greenhollow), distinct from Millbrook's.

**Enemies:** the Crystal Mine and Whisperwood reuse Goblin Cave's enemies (Slime, Goblin, Goblin Archer) for now (Ruling 13); each needs its own enemy set once Phase 8's placeholder economy is validated.

## Known gaps

- **Texture filtering.** The project never sets a default texture filter, so Godot uses smooth (linear) filtering and scaled pixel sprites elsewhere may look blurred. Only the attack line overlay forces nearest filtering. The project-wide fix is Project Settings > Rendering > Textures > Default Texture Filter = Nearest.
- **Mixed pixel sizes.** Party sprites are 64x64 and show at about 80 to 110 px, so their pixels aren't a whole-number multiple of the 4 px line grid.
