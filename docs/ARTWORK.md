# Artwork Notes — MergeForge

Last updated: 2026-09-28

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
| `crit_mark` | The "!" over an attacker winding up a crit, drawn upright |
| `crit_mark_scale` | Line blocks per sprite pixel for the crit mark (default 2) |

The shipped heads are `resources/sprites/vfx/line_slash_head.png`, `line_arrow_head.png` and their `_diagonal` versions; the shipped crit mark is `vfx/crit_mark.png` (5x12). The crit mark follows the same drawing rules as the heads below, but it never turns, so it has no diagonal version and needn't be square. The old `slash.png` and `arrow.png` are still used by the attack badge and the slash hit effect, so don't reuse them for heads.

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

## Known gaps

- **Texture filtering.** The project never sets a default texture filter, so Godot uses smooth (linear) filtering and scaled pixel sprites elsewhere may look blurred. Only the attack line overlay forces nearest filtering. The project-wide fix is Project Settings > Rendering > Textures > Default Texture Filter = Nearest.
- **Mixed pixel sizes.** Party sprites are 64x64 and show at about 80 to 110 px, so their pixels aren't a whole-number multiple of the 4 px line grid.
