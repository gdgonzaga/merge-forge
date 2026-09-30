# MergeForge Art Style Guide & Asset Production Bible

Last updated: 2026-09-30  
Target Canvas: 1080x1920 (Mobile Portrait, Canvas Items stretch, 9:16 up to 9:21)  
Style Philosophy: Mid-Resolution Stylized 2D Fantasy Illustration  
Audience: Human Artists, Technical Designers, and AI Prompt Engineers  

---

## 1. Vision & Visual Pillars

MergeForge combines the cozy, tactile charm of a medieval fantasy artisan workshop with the instant clarity of arcade mobile tile merging and dungeon combat.

### 1.1 The Core Aesthetic: Mid-Resolution Stylized 2D Illustration
- **Stylized Hand-Painted Fantasy:** All game assets — items, customer portraits, combat units, UI panels, and icons — feature clean digital illustration with smooth vector-clean linework, rich material textures, and soft cel-shading.
- **No Pixel Art:** The game does **not** use retro pixel art, low-res pixel grids, stair-stepped aliasing, or indexed color dithering. Sprites are rendered at mid-resolution with smooth anti-aliased curves and full 32-bit color fidelity.
- **Tactile Materiality:** Interfaces and objects feel physical. Polished oak wood grain, hammered iron edges, warm amber brass fittings, aged parchment paper, and glowing gemstone liquids give the game a crafted, storybook artisan quality.
- **Unified Lighting & Atmosphere:** A warm, golden key light shines consistently from the top-left (hearth and forge glow), casting soft, cool ambient drop-shadows down and to the right.

---

## 2. Core Color Palette & Material Ramps

All artwork and prompt outputs must sample or harmonize with this master palette to ensure visual cohesion across shop and dungeon screens.

### 2.1 Workshop Materials (UI, Containers, Surfaces)
| Material | Swatch Role | Hex Code | Visual Application |
|---|---|---|---|
| **Warm Oak (Dark)** | Base Border / Shadow | `#2B1810` | 9-slice panel outer bevels, deep woodwork crevices |
| **Warm Oak (Mid)** | Wood Body | `#54311C` | Primary button faces, counter borders, wooden shelves |
| **Warm Oak (Highlight)** | Wood Bevel / Rim | `#8B522E` | Top-left light catch on wooden frames and panels |
| **Brass / Gold (Dark)** | Metallic Shadow | `#5C3D0E` | Button rivets, frame indentations, metal bevel base |
| **Brass / Gold (Mid)** | Primary Accent | `#C88D2A` | Primary CTA button borders, gold coins, quality stars |
| **Brass / Gold (Highlight)**| Metallic Sheen | `#F6D365` | Golden highlights, tier stars, level badge crown |
| **Slate / Iron (Dark)** | Secondary Shadow | `#1E232A` | Secondary button borders, anvil slate, lockplates |
| **Slate / Iron (Mid)** | Secondary Base | `#39414D` | Secondary utility button fill, iron plates, weapon blades |
| **Slate / Iron (Highlight)**| Secondary Edge | `#6B788A` | Bevel highlights on iron buttons and metal items |
| **Aged Parchment (Dark)** | Paper Shadow | `#C8B896` | Order card borders, recipe sheet creases |
| **Aged Parchment (Mid)** | Paper Base | `#EADBC4` | Customer order cards, blueprint description plates |
| **Aged Parchment (Light)**| Paper Highlight | `#F9F4EB` | High-contrast card backgrounds, popover text regions |

### 2.2 Vitality & Progression (Bars & Gauges)
| Gauge Type | Track Background | Liquid Fill Base | Liquid Highlight | Glow / Pulse |
|---|---|---|---|---|
| **Health (HP)** | `#2B0E12` | `#C62828` (Ruby Red) | `#EF5350` | `#FF8A80` |
| **Dungeon Progress** | `#0D1B2A` | `#1E88E5` (Lapis Blue) | `#42A5F5` | `#90CAF9` |
| **Experience (XP)** | `#142918` | `#2E7D32` (Emerald Green) | `#66BB6A` | `#A5D6A7` |
| **Windup Fill** | `#1A1D24` | Dynamic (`#73B8F5` Party / `#F5A36B` Enemy) | High tint | `#FFFFFF` |

### 2.3 Combat Telegraphs & Attack Lines
| Element | Dark Shade | Mid Tone | Light Tone / Highlight |
|---|---|---|---|
| **Party Attack Line** | `#204B73` | `#4584BE` | `#73B8F5` (Sky Blue) |
| **Enemy Attack Line** | `#6E381A` | `#C26733` | `#F5A36B` (Warm Peach) |
| **Critical Strike Line**| `#735607` | `#C79B14` | `#FFC71A` (Bright Gold) |
| **Lethal Strike Line** | `#6B1313` | `#B72222` | `#E53935` (Warning Crimson) |

---

## 3. UI Elements & Layout Constraints

MergeForge is a portrait-first mobile title running on Godot 4.7 Mobile renderer.

### 3.1 Mobile Physical Constraints
- **Design Resolution:** 1080x1920 with `canvas_items` stretch mode. Layouts dynamically expand to tall aspect ratios (up to 9:21 / 1080x2520).
- **Safe Area:** Interactive controls must remain inside `DisplayServer.get_display_safe_area()`, with a minimum screen margin of **48 px** on left/right edges.
- **Touch Target Minimum:** Interactive buttons and touch surfaces must be at least **120x120 px** (approx. 48 dp on mobile screens) with at least **24 px** spacing between adjacent targets.
- **Typography:**
  - Headers / Titles: `MedievalSharp-Regular.ttf` at **48 px to 64 px**.
  - Body Text / Status Copy: `RobotoCondensed-VariableFont_wght.ttf` at **40 px to 48 px**.
  - Microcopy (item counts, secondary stats): Never below **32 px**.

### 3.2 9-Slice Panel Architecture
- **Primary Action Panel / Buttons (`panel.png`):**
  - Native Resolution: 400x400 px.
  - 9-Slice Margins: 70 px left, 70 px top, 70 px right, 70 px bottom.
  - Visuals: Warm beveled oak board with brass corner brads and deep drop-shadow.
  - States:
    - *Normal:* Full saturation, clear upper-left bevel highlight.
    - *Pressed (`panel_pressed.png`):* Shifted 4 px down, compressed drop-shadow, darkened inner face.
    - *Disabled (`panel_disabled.png`):* Desaturated by 50%, muted contrast, 60% opacity.
- **Secondary Action Buttons (`panel_secondary.png`):**
  - Native Resolution: 200x200 px.
  - 9-Slice Margins: 30 px on all edges.
  - Visuals: Chiseled dark iron/slate texture with subtle rivets.
- **Progress Bars (`bar_bg.png`):**
  - Native Resolution: 24x24 px (or 48x48 px high-res).
  - 9-Slice Margins: 3 px to 6 px on all edges.
  - Visuals: Recessed bevel with dark slotted interior.

---

## 4. Customer & Character Portraits

Customer portraits represent townspeople, adventurers, guild quartermasters, and traveling merchants in the shop queue and summary screens.

### 4.1 Technical Specifications
- **Master Resolution:** **512x512 px** PNG (downsampled to **256x256 px** or imported with mipmaps enabled).
- **Canvas & Framing:** Bust composition — head, neck, and upper shoulders filling approximately 80% to 85% of the frame.
- **Background:** **MANDATORY 100% TRANSPARENT ALPHA.**
  > [!IMPORTANT]
  > The shop queue dynamically creates silhouette shadows by duplicating the portrait texture, modulating it to black (`Color(0, 0, 0, alpha)`), and offsetting it behind the sprite (`shop/shop_session.gd:165`). Any non-transparent background pixels will cause a box shadow to ruin the visual layering.
- **Frame Offset:** In the main shop scene (`shop/shop_session.tscn`), portraits are placed inside a 260x260 `PortraitWrapper` with a 30 px margin behind `resources/sprites/ui/portrait_frame.png`. Ensure facial features are centered so the wooden frame does not crop the face.

### 4.2 Styling Rules
- **Art Style:** Stylized 2D digital character illustration. Clean, smooth anti-aliased line art with soft cel-shading and painterly highlights.
- **Silhouette & Outlining:** A subtle, dark contour outline (1.5 px to 2 px optical width, colored `#2B1810` or tinted character tone) separating the character from the UI frame. No pixelated or jagged stepping.
- **Lighting:** Warm key light from top-left, soft warm-bounce on right cheek, soft cast shadow beneath the chin.
- **Character Diversity & Archetypes:**
  - Expressive facial features (grizzled dwarven smiths, whimsical herbalist witches, jovial peddlers, disciplined knight captains).
  - Clear tonal separation between skin, hair, and clothing colors. Avoid muddy textures.

---

## 5. Badges, Icons & Combat Indicators

Badges in MergeForge serve both as identification icons and dynamic interactive combat gauges.

### 5.1 The Modular 2-Part Architecture
Badges are composed of two layers:
1. **The Backplate (`badge_bg.png`):**
   - Native Size: **128x128 px** (displays at 48x48 px on UI).
   - Shape: Clean beveled shield, diamond, or crest with polished metallic borders and dark recessed interior.
   - Purpose: Acts as a `TextureProgressBar` fill surface (`dungeon/attack_badge.gd`), filling smoothly from bottom to top during combat windup.
   - Color Tinting: Modulated at runtime — Party Blue (`#73B8F5`), Enemy Peach (`#F5A36B`), or Crit Gold (`#FFC71A`).
2. **The Foreground Glyph (`badge_icon_*.png`):**
   - Native Size: **128x128 px** (centered inside an 80x80 px optical safe zone).
   - Color: Clean white and light-silver metallic tones with a fine dark perimeter outline (`#1A1D24`). Smooth vector-like edges allow runtime tinting without losing silhouette legibility.
   - Standard Glyphs:
     - `badge_icon_melee.png`: Twin crossed swords.
     - `badge_icon_missile.png`: Recurve bow with notched arrow.
     - `badge_icon_cleave.png`: Sweeping broadaxe blade.
     - `badge_icon_fireball.png`: Burning flame orb.
     - `badge_icon_smash.png`: Heavy spiked warhammer.
     - `badge_icon_smite.png`: Radiant holy burst.

### 5.2 Status Badges & HUD Markers
- **Level Badge (`badge_level.png`):** 96x96 px or 128x128 px ornate shield with golden crown trim.
- **Quality Star (`star_gold.png`):** 64x64 px embossed golden star with warm brass drop-shadow, displayed in the upper right corner of Fine and Masterwork board items.
- **Currency Coin (`coin_gold.png`):** 96x96 px embossed circular gold coin with a stamped hammer symbol.

---

## 6. Items, Reagents & Equipment Sprites

Board items represent crafted goods, raw materials, and usable combat potions on the merge grid.

### 6.1 Technical Specifications
- **Native Resolution:** **128x128 px** PNG (displays 1:1 inside the 128x128 board cells).
- **Perspective:** Slight 2.5D top-down / front-isometric angle (approx. 15-20 degrees tilt) showing both top and front surfaces.
- **Contours & Rendering:** Smooth anti-aliased perimeter with clean illustrated brushwork. Solid materials have clear specular highlights (gleaming steel, polished wood grain, bubbling glass reflection).
- **Padding:** 8 px to 12 px transparent padding inside the 128x128 canvas to prevent items from crowding cell borders.

### 6.2 Tier Progression & Visual Evolution
Items in a merge chain must visually communicate escalating value and craftsmanship:
1. **Tier 1 (Raw Material):** Organic, rough, unrefined forms (e.g. rough Iron Ore chunk, freshly plucked Herb Leaf). Matte textures with minimal specular reflection.
2. **Tier 2 (Refined Base):** Clean geometric edges, polished bevels (e.g. smelted Iron Ingot, refined Herbal Extract vial). Clear metallic/glass highlights.
3. **Tier 3 (Finished Craft):** Elaborate artisan craftsmanship, carved leather handles, brass fittings, rich bubbling liquid (e.g. Iron Shield, Healing Potion, Knight's Sword).
4. **Tier 4 (Infused / Enchanted):** Magical aura, glowing runic inscriptions, elemental flames or frost trails (e.g. Flame Sword, Phoenix Draught).

### 6.3 Missing Phase 7 Definitions (Replacement Checklist)
The following definitions currently reuse placeholders and require bespoke 128x128 mid-res art:
- `ice_essence`: Sharp crystalline ice cluster with glowing cyan inner light and frost wisps.
- `shadow_essence`: Swirling dark violet ethereal flame orb with sharp amethyst highlights.
- `holy_essence`: Radiant warm white/gold sacred relic fragment emitting soft light rays.
- `frost_blade`: Slender runic steel broadsword rimmed with crystalline frost spikes.
- `holy_draught`: Ornate teardrop glass vial filled with glowing champagne-gold liquid.
- `nightshade_tonic`: Dark obsidian flask wrapped in bramble thorns containing deep purple elixir.

---

## 7. Combat Lines & Attack Heads

Dungeon combat uses dynamic directional lines drawn in GDScript (`dungeon/combat_lines.gd`) capped by stylized heads.

### 7.1 Line Construction
- **Style:** Smooth vector lines rendered with clean anti-aliasing and solid color ramps (`PARTY_RAMP`, `ENEMY_RAMP`, `CRIT_RAMP`, `LETHAL_RAMP`).
- **Thickness:** 4 px to 16 px optical thickness based on the proportion of target max HP the attack inflicts. Crits are always wide with bright pulses.

### 7.2 Head Sprites
- **Native Resolution:** **48x48 px** (or 64x64 px) smooth vector-style sprite with transparent background.
- **Format:** White and light-grey core with a clean dark outline. The combat renderer automatically tints the white pixels to match the attack line ramp.
- **Orientation Requirements:**
  - *Straight Heads (`line_slash_head.png`, `line_arrow_head.png`):* Drawn pointing directly **right**. Rotated by code in 90-degree increments (down, left, up).
  - *Diagonal Heads (`line_slash_head_diagonal.png`, `line_arrow_head_diagonal.png`):* Drawn pointing **down-right** (45 degrees) with dedicated smooth artwork to prevent rotation resampling distortion.

---

## 8. AI Prompting & Asset Generation Pipeline

This section provides actionable templates and strict workflows for AI model generation (Midjourney, Stable Diffusion, DALL-E) to produce mid-resolution stylized 2D assets matching MergeForge standards.

### 8.1 Prompting Formulas

#### Customer Portraits (512x512 target)
```text
Positive Prompt:
stylized 2D digital game art, bust portrait of a [character archetype, e.g. dwarven armorer / elven herbalist / rogue merchant], [facial expression, e.g. friendly confident grin], detailed fantasy attire with [leather straps / brass buckles / hood], warm top-left key lighting, smooth clean line art, soft cel shading, painterly textures, cozy fantasy RPG mobile game aesthetic, centered composition, isolated on solid plain green background #00FF00, no frame, no text --ar 1:1

Negative Prompt:
pixel art, pixelated, 8-bit, 16-bit, chunky pixels, dithering, photorealistic, 3d render, complex background, modern clothing, cropped head, blurry, noisy lines, sketch, watermark, signature
```

#### Items & Reagents (128x128 / 256x256 target)
```text
Positive Prompt:
stylized 2D digital game asset icon of a [item description, e.g. glowing frost sword / bubbling health potion vial / iron anvil], fantasy RPG inventory item, 2.5D slight isometric tilt angle, clean smooth outline, vibrant colors, rich material highlights, soft cel shading, hand-painted digital illustration, isolated on solid plain green background #00FF00, centered, no drop shadow --ar 1:1

Negative Prompt:
pixel art, pixelated, low resolution, 8-bit, dithering, 3d model render, photorealistic, noisy textures, cropped, modern, messy sketch, textured background, complex scene
```

#### Badges & Combat Glyphs (128x128 target)
```text
Positive Prompt:
stylized 2D heraldic vector icon glyph of [symbol, e.g. crossed knight swords / recurve hunting bow / radiant holy sun], clean solid white and light silver metallic fill, smooth dark perimeter outline, centered, minimalist fantasy combat badge, clean geometric silhouette, isolated on plain black background --ar 1:1

Negative Prompt:
pixel art, pixelated, jagged edges, colorful, complex gradient, realistic metal photo, 3d render, messy lines, circular frame, outer border, blur
```

#### UI Panel Textures (400x400 target)
```text
Positive Prompt:
hand-painted 2D game UI panel texture, medieval artisan workshop aesthetic, polished warm dark oak wood planks, beveled edges, brass studs in corners, subtle chiseled drop shadow, seamless interior space for text, top-down view, cozy fantasy mobile RPG interface style, high detail --ar 1:1

Negative Prompt:
pixel art, pixelated, low resolution, photorealistic photo, 3d perspective, noisy, cluttered, text, buttons inside, icons, angled view
```

### 8.2 Post-Processing & Ingestion Checklist
1. **Background Removal:** Use high-quality alpha extraction or clean color-keying to remove the green background. Ensure **no green fringe pixels, haloing, or harsh jagged edges** remain. The edge should have a clean, subtle 1 px anti-aliased transition.
2. **Resizing & Downsampling:**
   - Downscale using **Lanczos** or **Bicubic** filtering to preserve smooth lines and gradients.
   - Target resolutions: 512x512 for portraits (scaled to 200-260px in-game), 128x128 for items, 128x128 for badges.
3. **Godot Texture Import Settings:**
   - **Texture Filter:** `Linear` (smooth bilinear interpolation). Mipmaps enabled (`compress/channel_pack=0` or standard VRAM compression).
   - Verify that textures look crisp and smooth across all mobile screen aspect ratios without pixel stepping or blurriness.
