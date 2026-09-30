# Art Style Guidelines — Decision Record

Date: 2026-09-30
Topic: Art Style Guidelines & Asset Production Standards

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Document Scope | Authoritative Art Bible (`docs/ART_STYLE_GUIDE.md`) | Single source of truth for both humans and AI generation. | Visual pipeline significantly branches into 3D. |
| Overall Aesthetic | Mid-Resolution Stylized 2D Fantasy Illustration | Clean, illustrated/painterly storybook workshop aesthetic with smooth antialiased contours and rich cel/painterly shading, completely replacing retro pixel art. | Fixed virtual retro resolution is requested. |
| Native Resolutions | Mid-Res (Portraits 512x512, Items 128x128, Badges 96x96/128x128) | High-DPI mobile clarity; items fit 128x128 cells natively, portraits scale smoothly into 260x260 UI frames. | Texture memory budget demands mipmap reductions. |
| Portrait Rules | Bust composition, 100% transparent alpha | Required for dynamic queue silhouette shadow in `shop_session.gd`; clean stylized character art; warm top-left key lighting. | Portrait UI frame geometry is redesigned. |
| Badges & Icons | Modular 2-part design (Backplate + Glyph) | Clean beveled backplates serving as vertical windup gauges with smooth antialiased party/enemy/crit fills + sharp white/silver glyphs. | Badges stop functioning as combat gauges. |
| UI & Material Theme | Medieval Fantasy Workshop hierarchy | Polished warm oak & brass CTAs, aged parchment card surfaces, dark iron secondary controls, recessed gemstone liquid bars. | Game theme departs from workshop/forge setting. |
| Filtering & Import | Linear / Smooth filtering with Mipmaps | Supports crisp scaling on modern mobile displays without pixelation or aliasing artifacts. | Nearest neighbor is specifically requested for retro effects. |
| AI Generation Pipeline | Mid-res stylized 2D prompts + clean alpha masking | Explicit positive/negative prompt recipes eliminating pixelation/dithering in favor of clean cel-shaded digital game illustration. | AI generation stack changes drastically. |
| Color Palette | Explicit core hex palette table | Establishes strict material harmonies (Oak, Brass, Iron, Parchment, HP Ruby, Lapis, XP Gold/Emerald, Crit/Alert). | New visual biomes or faction palettes are added. |

## Open / Deferred
- None.
