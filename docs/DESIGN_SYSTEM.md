# Flood Drop — Premium Design System

The single source of truth for how everything looks. Goal: every screen reads like a
shipped, premium neon-arcade title. Nothing uses Godot defaults.

---

## 1. Brand & mood

**"Liquid light in a neon night."** Deep-ink darkness, luminous liquid, glass and glow.
Every surface is dark; every accent is *emissive* (it looks lit, not painted). White is
reserved for glare peaks — never for large areas. The bloom pass is part of the design:
bright accents are expected to glow.

## 2. Colour palette

### Core neutrals (backgrounds & text)
| Token | Hex | Use |
|---|---|---|
| `INK_0` | `#04070D` | deepest background, vignettes |
| `INK_1` | `#0A101C` | card/panel surfaces |
| `INK_2` | `#121A2B` | raised elements, chips |
| `TEXT_HI` | `#F2F7FF` | primary text |
| `TEXT_MID` | `#9FB0C8` | secondary text, descriptions |
| `TEXT_LOW` | `#5C6B82` | disabled, hints, footnotes |

### Accents (one per component — never mix two accents in one element)
| Token | Hex | Meaning |
|---|---|---|
| `CYAN` | `#37E6FF` | brand / primary actions / water |
| `TEAL` | `#2EFFC4` | success, Cores, "earned" |
| `GOLD` | `#FFC53D` | tickets, value, celebration |
| `VIOLET` | `#B879FF` | Prisms, premium, mystery |
| `CORAL` | `#FF5C4D` | danger, boss, fail states |
| Biome accents | from `ThemeManager.THEMES[*].drop_color` | stage identity |

**Rules**
- Background is always an INK tone; accents never fill large areas (borders, text, glow, icons).
- Accent-tinted fills use the accent at 30–35% value (e.g. filled buttons) so the pure accent
  stays reserved for borders/text/glow on top.
- Disabled = desaturate to `#484F5F` border + `TEXT_LOW` text. Never grey-out with opacity alone.

## 3. Typography — fonts are the #1 premium lever

Two families, both OFL-licensed (bundled in `assets/fonts/` with licenses):

| Role | Font | Where |
|---|---|---|
| **Display** | **Audiowide** | big moments: GAME OVER, CHALLENGE COMPLETE, screen titles, DANGER, level reveals. Matches the neon-sign lettering in the key art. |
| **UI / numbers** | **Rajdhani** (Regular/Medium/SemiBold/Bold) | everything else: buttons, body, HUD numbers, chips. Condensed, techy, crisp at small sizes. |

### Type scale (mobile 720×1280)
| Style | Font / weight | Size | Extras |
|---|---|---|---|
| Display XL | Audiowide | 58 | +2px letter-spacing, accent colour + glow |
| Display L (screen titles) | Audiowide | 34 | +2px spacing |
| Heading M (card titles) | Rajdhani Bold | 26 | ALL-CAPS, +3px letter-spacing |
| Button | Rajdhani SemiBold | 22–26 | ALL-CAPS, +2px spacing |
| Body | Rajdhani Medium | 19 | `TEXT_MID` for descriptions |
| Caption / tag | Rajdhani SemiBold | 15 | ALL-CAPS, +2px spacing, `TEXT_LOW`/accent |
| HUD number | Rajdhani Bold | 44 | white, subtle shadow — numbers are heroes |
| HUD label | Rajdhani SemiBold | 16 | ALL-CAPS +3px spacing, `TEXT_MID`, sits above its number |

**Rules**
- The Godot default font must never appear → a **global Theme** (set on the root window)
  carries Rajdhani Medium as the default for every Control, so even untouched scenes upgrade.
- ALL-CAPS text always gets letter-spacing (via `FontVariation.spacing_glyph`) — caps without
  tracking is the #1 "cheap" tell.
- Outlines only on text floating over gameplay (HUD, floating scores). UI text uses colour +
  weight, never outlines.

## 4. Spacing, shape & alignment

- **8px base grid.** All paddings/gaps are multiples of 8 (chips may use 4).
- Screen gutters: **20px** left/right. Headers: **72px** tall, back button left, title next
  (left-aligned), currencies right. Same on every screen.
- Cards: padding **18px**, corner radius **20**, section gap **16px**, in-card row gap **10px**.
- Buttons: radius **14**, border **2px**; heights 56 (standard), 64 (menu), 76 (CTA).
- One divider style: 1px accent at 14% alpha.
- Center-block screens (menu, game over): content max-width **520px**, centred.
- Numbers align right when in columns; text left; never centre body copy.

## 5. Components (implemented in `scripts/ui/UIKit.gd` + `ThemeFactory`)

| Component | Spec |
|---|---|
| **Neon button** | INK_1 glass + 2px accent border + accent shadow-glow; filled variant = accent@32% fill for the screen's single primary action. Pressed = brighter fill + white text. |
| **Chip** | INK_2 pill, 1px accent@45% border, shader icon + Rajdhani SemiBold value |
| **Electric card** | the Shop-card energy shader; biome/context accent; content-sized |
| **Tag** | small caps pill (BOSS coral, CLEARED teal, UNLOCK IN SHOP neutral) |
| **Header** | unified helper: back ‹, Display-L title, right-side chips |
| **Shader icons** | ticket / prism / core / droplet — no emoji anywhere in final UI |

## 6. Per-screen specs

- **Main menu** — Audiowide title with cyan glow (echoes the bg neon sign), centred 520 stack:
  START (filled CTA, 76) → THE GAUNTLET (gold, ticket count) → SHOP / SETTINGS (quiet). High
  score as caption chip under the title.
- **Gameplay HUD** — "SCORE" caption over hero number (top-left), "BEST" mirrored top-right;
  multiplier arc label in Rajdhani Bold; DANGER in Audiowide coral; pause = glass square.
  24px margins from safe edges.
- **The Gauntlet** — as built (electric stage cards) + fonts/tracking from this system;
  stage titles Heading-M with biome accent; descriptions Body/TEXT_MID.
- **Shop** — same header pattern; tabs = neon buttons (filled = active); item rows get
  Heading-M names, Body descriptions, price chips; passive cards already premium.
- **Settings** — header pattern; each setting on an INK_1 rounded row; slider = cyan grabber,
  INK_2 track; percentages in Rajdhani SemiBold.
- **Game Over / Challenge result** — Display-XL verdict with glow; stats as caption+number
  pairs; reward chips row; filled CTA + quiet secondary. Max-width 520 centred.
- **Pause** — dark blur/dim + centred glass card with three neon buttons (inherits theme).

## 7. Motion (existing + rules)

Screen transitions ≤ 400ms; button press = 0.95 scale snap; celebration moments may exceed
(level reveal, victory). Never animate body text. Bloom handles "glow pulses" — don't
hand-animate brightness on top of it.

## 8. Enforcement

- `ThemeFactory.build()` (global theme on the root window) sets: default font (Rajdhani
  Medium 19), Button styles for all states, Label colour, Slider/CheckButton styling, panel
  defaults — so **every** Control in every scene inherits the system.
- `UIKit` exposes the palette as constants; screens must use tokens, not ad-hoc hex.
- New screens: build from UIKit components; if a new pattern is needed, add it to UIKit
  first, then use it.
