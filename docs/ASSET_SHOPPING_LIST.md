# Asset Shopping List — with Gemini 3 Pro prompts

Everything the game needs generated, with copy-paste prompts. Ordered by impact.

## ⚠️ Format rules (read first — this is why the last batch couldn't be used)

The previous library came out as **opaque JPEG renamed to .png with no alpha channel** and
inconsistent backgrounds (white/black/grey/fake checkerboards), which made almost all of it
unusable as sprites. To avoid a repeat, every generation must obey:

1. **Ask for a true transparent background first.** If the tool honours it, export **PNG
   with a real alpha channel** and spot-check one file: opening it over any image must show
   the image through, not white/black/checkerboard.
2. **If transparency fails**, fall back to a *keyable* flat backdrop and the game's keyer
   will handle it: **solid `#00B140` green** for normal sprites, **pure `#000000` black**
   for glowing/additive FX (beams, sparks, flares — black adds nothing in additive blend).
3. Never accept: baked checkerboard patterns, drop shadows on the backdrop, vignettes,
   gradients behind the subject, watermarks, or text.
4. **1024×1024**, single centred subject filling ~85% of frame unless stated otherwise.

**Append this suffix to EVERY prompt below:**

> …isolated on a fully transparent background (true PNG alpha). If transparency is not
> supported, use one perfectly uniform flat #00B140 green background instead. No drop
> shadow, no reflection, no vignette, no checkerboard pattern, no text, no watermark, no
> border. Single subject, centred, filling about 85% of a 1024×1024 frame.

**House style block (include in every prompt):**

> Style: premium mobile arcade game art, vibrant neon-noir, painterly-realistic hybrid
> with crisp silhouettes, saturated jewel tones, strong rim lighting from the top-left,
> soft internal glow, high contrast, reads clearly at 100px. Consistent with a game about
> luminous liquid droplets in glowing fantasy environments.

---

## A. Challenge mode ("The Gauntlet") — HIGHEST PRIORITY

| File | Purpose | Prompt core (add style block + suffix) |
|---|---|---|
| `ticket_icon.png` | Ticket currency icon (HUD, menus, buttons) | "A single arcade admission ticket made of storm-blue crystal glass, glowing from within with electric cyan energy, a stylised lightning bolt perforation line across the middle, slight 3/4 tilt, game UI currency icon" |
| `prism_icon.png` | Premium currency icon | "A floating refractive prism shard of iridescent crystal, splitting a beam of white light into a rainbow inside itself, luxurious and precious, subtle purple-magenta outer glow, game premium-currency icon" |
| `core_icon.png` | Cores (mastery/tree currency) icon | "A hexagonal energy core of teal-green plasma contained in a dark metallic hex frame, pulsing inner light, arcane and earned-looking, game mastery-currency icon" |
| `gauntlet_emblem.png` | Challenge mode logo/entry emblem | "An ornate emblem of two crossed neon energy swords over a stylised storm wave, dark gunmetal frame with cyan and magenta neon inlays, esports badge quality, game mode emblem" |
| `stage_emblem_water.png` …`_slime/_lava/_acid/_gold/_rainbow/_neon/_galaxy.png` (8) | Stage card emblems | "A circular medallion emblem for a water trial: a perfect luminous water droplet at the centre of concentric rippling rings, deep ocean blues with glowing aqua rim light, embossed dark metal ring border" — then re-run swapping the theme: slime (bulbous green ooze blob, toxic bubbles), lava (magma orb, obsidian cracks, ember glow), acid (hazard droplet, caustic yellow-green fizz), gold (molten gold coin-drop, mint lustre), rainbow (prismatic drop refracting spectrum bands), neon (glitching digital droplet, magenta/cyan scanlines), galaxy (droplet containing a nebula and stars) |
| `challenge_complete_banner.png` | Victory banner art | "A wide ornate victory banner frame, dark metal with glowing teal-green neon filigree, radiating light burst behind it, centre left empty for text, triumphant but sleek, mobile game victory banner, 1536×640" |
| `second_wind_icon.png` | Second Wind badge | "A small badge icon of a phoenix-like swirl of wind and light forming an upward arrow, warm gold and amber glow, hopeful energy, game bonus-retry icon" |

## B. Bosses (multi-part, one file per part) — needed for v2 bosses

Shared prompt frame: *"Boss art for a neon-noir liquid arcade game, [PART], menacing but
readable silhouette, painterly-real hybrid, dramatic rim light…"* Generate each part
separately so they can be animated independently:

1. **Rainfather (water)**: `boss_rainfather_cloud.png` (colossal storm-cloud face, glowing
   blue eyes, rain streaming), `boss_rainfather_heart.png` (exposed luminous water-core orb).
2. **Slime King**: reuse/regenerate `boss_slime_core/crown/outer_layer` **with alpha**.
3. **Magma Titan (lava)**: `boss_magma_fist_l/r.png`, `boss_magma_head.png` (obsidian
   crust, magma veins), `boss_magma_core.png`.
4. **The Hydra Vat (acid)**: `boss_hydra_head_a/b/c.png` (three distinct toxic serpent
   heads rising from a vat), `boss_hydra_vat.png`.
5. **The Mint (gold)**: `boss_mint_press.png` (ornate coin-press machine), `boss_mint_coin.png`
   (giant imperial coin with an angry embossed face).
6. **Prism Warden (rainbow)**: `boss_prism_body.png` (obsidian angel of black crystal),
   `boss_prism_lantern.png` (caged rainbow light source).
7. **The Mainframe (neon)**: `boss_mainframe_core.png` (monolithic server obelisk, magenta
   glitch), `boss_mainframe_shield.png` (hex-grid hologram barrier panel).
8. **The Kraken (galaxy)**: regenerate `boss_kraken_body/eye/tentacle` **with alpha**,
   cosmic nebula skin variant.

## C. New ability icons (boss rewards) + existing set with alpha

| File | Prompt core |
|---|---|
| `icon_freeze_bomb.png` | "A spherical ice grenade of glacial blue crystal, frost mist leaking from a glowing fissure, sharp icy facets, neon-on-dark ability icon" |
| `icon_black_hole.png` | "A miniature black hole with a glowing violet accretion ring bending light around a perfect dark sphere, ominous gravity, neon-on-dark ability icon" |
| `icon_neutral_field.png` | "A protective dome of soft teal hexagonal light over a small water droplet, calm and stabilising energy, neon-on-dark ability icon" |
| `icon_time_rewind.png` | "An hourglass wrapped in a glowing clockwise-reversing arrow of amber light, sand flowing upward, neon-on-dark ability icon" |
| Existing 5 (`time_warp`, `evaporation`, `tidal_wave`, `midas_touch`, `auto_turret`) | Re-export the current neon icon art **with real alpha** (the in-game versions are JPEG; additive blending hides it, but proper alpha unlocks non-additive UI uses) |

## D. Gameplay art gaps (from IMPROVEMENT_PLAN — still open)

- **Turret with alpha:** `turret_base.png`, `turret_barrel.png` — regenerate the existing
  mech-turret designs (circular emplacement + orange-core cannon) as true-alpha sprites,
  killing the chroma-key pipeline. Also `turret_adv_base/twin_barrel` for the tree-upgraded look.
- **Splash sheets (per biome ×8):** `splash_<theme>_sheet.png` — "4×2 sprite-sheet grid of
  a stylised liquid splash crown erupting and subsiding, [theme colour/material], frames
  evenly spaced on transparent background, 2048×1024".
- **Parallax layers:** for each biome, `bg_<theme>_mid.png` and `bg_<theme>_near.png`
  (2048×1280, seamlessly tileable horizontally) to pair with the existing `*_far` plates.
- **Cosmetics (Prism sinks):** flood skins (`flood_skin_molten_core.png` for the Supporter
  Pack, plus matrix-code and blood variants), drop hats (top hat, halo, crown, propeller),
  tap trails (rainbow, fire, star).
- **Soft FX dot:** `glow_dot_128.png` — "a perfectly smooth radial white glow fading to
  transparent, no banding, 128×128" (replaces the procedural 64² particle texture).

## E. Audio (not images — commission or license separately)

Music loops per biome (or one adaptive track with intensity layers) + a real SFX set:
pop ×4 variations, splash, power-up, laser, bomb, boss roar/phase sting, challenge
complete fanfare, ticket spend, UI taps. This remains the single biggest quality gap in
the whole game.

---

### Suggested generation order
1. **A** (Gauntlet UI — the new mode deserves its icons; currently text/emoji placeholders)
2. **D turret + splash sheets** (kills the chroma-key + biggest gameplay juice)
3. **C new ability icons** (needed when v2 boss rewards land)
4. **B bosses** (one biome at a time, starting with Rainfather + Slime King)
5. **D parallax + cosmetics** (beauty + the Prism sink)
