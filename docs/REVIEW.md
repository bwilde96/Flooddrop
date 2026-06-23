# Flooddrop — Full Logic Review & Polish Plan

A complete pass over the current game logic with a focus on **mobile quality, hyper-real
liquid feel, and game psychology / enjoyment**. Written as the new maintainer's working map:
what exists, what's broken, what to improve, and in what order.

> Honesty note: this review is from reading the code, not running it. Godot isn't installed on
> the review machine, so behavioural claims (e.g. "feels unresponsive") are reasoned from the
> logic and should be confirmed in-editor. Line references are to the current `main`.

---

## 0. Verdict

Flooddrop is **much further along than the GDD implies** and structurally sound: clean autoload
separation, object pooling, a robust save system, a genuinely impressive metaball liquid shader,
and strong "juice" fundamentals (hit-pause, screen shake, squash-stretch, haptics, streak
multiplier). The problems are **not architectural** — they're concentrated in (a) drop
spawn/formation feel, (b) a hacked-together turret/laser, (c) several systems that are wired up
but inert (themes, magnetic tap, music), and (d) a real mobile-performance risk in the drop
shader. All fixable without a rewrite.

---

## 1. Architecture overview (how it currently works)

**Autoload singletons** (`project.godot` → `[autoload]`):
- `EventBus` — signal hub (lightly used; `game_over`).
- `GameManager` — score/time state + scene switching (`change_scene` frees current, instances next).
- `SaveManager` — JSON save at `user://save_data.json` with `.bak` recovery + schema validation. **Solid.**
- `AudioManager` — SFX via **procedurally generated** sine/noise `AudioStreamWAV` (placeholders).
- `ThemeManager` — the 8 liquid themes (colors + per-theme multipliers).
- `BackgroundManager` (`CanvasLayer`, layer -100) — themed background + the "plunge" wipe transition.

**Gameplay loop** (`scripts/Gameplay.gd`, ~1630 lines — the brain):
- 8 timed levels (30s each) → theme + a scripted event per level; level 8 = endless "Cosmic Chaos".
- `_process` ramps spawn interval & drop speed, runs flood drain, freeze, shake, abilities,
  events, tidal wave, and spawns drops on a timer.
- `spawn_drop()` picks type/position/speed and hands a pooled `Drop` its parameters.
- Drops emit `popped`/`missed`; `_on_drop_popped` applies score/effects per type;
  `_on_drop_missed` raises flood / ends game.

**Drop** (`scripts/Drop.gd`, `Area2D`): state machine `INACTIVE → FORMING → FALLING → POPPING`,
rendered by `fluid_drop.gdshader` on a child `FluidRect`. Special types are drawn with `_draw()`
symbols over the shader.

**PoolManager**: pre-warms 20 drops / 15 texts / 15 particles; recycles via
`on_pool_activate`/`on_pool_deactivate`. Note: **all three pools share `drop_container`**, so
`drop_container.get_children()` contains drops *and* texts *and* particles (the bomb/turret/tidal
loops filter by `has_method(...)`).

---

## 2. The three flagged bugs — root causes & fixes

### 2.1 Water drops "don't fall smoothly / don't work / animation replays"
Confirmed contributing causes:

1. **Forming drops are untappable.** `Drop._input_event` (Drop.gd:431) ignores taps unless
   `state == FALLING`. Formation lasts `spawn_formation_duration` × `form_mult`, and
   `spawn_formation_duration` is randomised **0.8–3.5 s** (Gameplay.gd:1139). So a drop is
   visible, dripping from the ceiling, for up to ~3.5 s while **taps do nothing** — this is
   almost certainly what reads as "doesn't work / doesn't drop right" on level 1 (water has the
   longest forms; `form_mult` = 1.0).
2. **Over-staggered release.** `next_available_fall_time` enforces a 0.35 s global gap between
   *any* two drops detaching (Gameplay.gd:1146), and forms are long + highly random → drops pile
   up at the ceiling and trickle out with an uneven rhythm.
3. **Release seam.** Two redundant `FORMING→FALLING` callbacks fire (Drop.gd:245 and 251), and
   the node starts translating at ~0.9× formation while the shader's internal `drop_y` finishes
   tweening at 1.0× → a subtle double-move at the moment of release.
4. **"Replays" / jitter** is most visible on **slime** (`s_type == 2`): on hitting the bottom it
   starts a `position:y` bounce **tween** (Drop.gd:404) while `_process` *also* writes
   `position.y` every frame (Drop.gd:349) — the two fight, producing stutter that looks like the
   animation restarting.
5. **"Don't work with power-ups":** the turret/bomb/tidal loops treat **FORMING** drops as valid
   targets (state check only excludes INACTIVE/POPPING), so a half-formed ceiling blob can be
   laser/bomb-killed even though the player can't tap it — inconsistent rules.

**Fix plan:**
- Make forming drops tappable (let `_input_event` accept `FORMING`, and on tap either pop or
  fast-forward to FALLING then pop). Single biggest responsiveness win.
- Shorten + tighten formation for water: cut the random range (e.g. 0.5–1.0 s) and reduce the
  global gap; consider spawning already-detaching at higher difficulty.
- Collapse to one release callback; start node translation exactly when `anchor_multiplier`
  hits 0 so the visual hand-off is seamless.
- Fix slime bounce: drive the bounce through `fall_velocity` / a gravity model in `_process`
  instead of a competing tween (see §3).
- Exclude FORMING drops from auto-target loops (or only target FALLING).

### 2.2 Laser turret "is a mess / doesn't work properly"
Current implementation (`_setup_turret` Gameplay.gd:1520, `_process_turret` :1559):
- Loads **`assets/turret_base.jpg` / `turret_barrel.jpg`** and strips the background with
  `_make_transparent` (Gameplay.gd:1510) — a **per-pixel CPU chroma-key** off the top-left
  pixel with a 0.15 threshold. Crude (halos, interior holes) and a main-thread hitch at load.
- The turret is a **`TextureRect` (Control) parented to the Node2D** gameplay root, positioned
  with manual world coords — fragile mixing of layout systems.
- The "laser" is a flat 8 px red `Line2D` shown for 0.1 s. No beam texture, glow, charge-up,
  muzzle flash, or impact.
- Aim origin uses `turret_base.global_position + Vector2(40,20)` while the `Muzzle` Marker2D is
  elsewhere → the beam doesn't start at the visible barrel tip.

**You already have the right assets** in `All_Generated_Game_Assets/` (real alpha PNGs):
`turret_base`, `turret_barrel`, `turret_adv_base`, `turret_adv_twin_barrel`, `auto_turret`,
`laser_beam_red`, `laser_beam_blue`, `laser_impact`, `turret_bullet_gold`.

**Fix plan (rebuild):**
- Rebuild the turret as a small **Node2D** with `Sprite2D` base + pivoting barrel using the PNGs
  (delete `_make_transparent` entirely — the PNGs have alpha).
- Render the beam as a **stretched `laser_beam_red` sprite or a shader'd `Line2D`** from the
  muzzle to the target, with additive blend + a short width-pulse, a **muzzle flash**, and a
  **`laser_impact`** sprite at the hit point.
- Add a brief charge-up tell (telegraph) before the beam for readability and game feel.
- Anchor the beam origin to the actual `Muzzle` global position so it lines up with the barrel.

### 2.3 Falling animation smoothness (general)
- Per-frame `queue_redraw()` + per-frame shader param writes on **every** drop even when nothing
  changed (Drop.gd:296-304) — wasteful; gate writes to "value changed".
- The water pre-stretch in FORMING (Drop.gd:309-318) and the FALLING stretch (Drop.gd:386-392)
  are near-identical but applied in different branches; unify so there's no scale pop at release.

---

## 3. Drop physics & types audit

Types: `NORMAL, DRAIN, FREEZE, BOMB, SHIELD, RAINBOW, GOLD, METEOR, ACID, NEUTRALIZER`.

- **Velocity model is inconsistent.** Normal drops fall at a flat `current_speed`; gold
  accelerates; rainbow sways; neon "stutters" by multiplying speed ±; slime bounces via tween;
  eruption shoots up with a hand-computed sqrt velocity. There's no single integrator, so each
  behaviour is a special case in `_process` (Drop.gd:332-371). **Recommend** one small physics
  core (velocity + gravity + optional horizontal), with per-type modifiers as data, so motion is
  consistent and tunable — and the slime/tween fight disappears.
- **Meteor splitting** (Drop.gd:487-517) is nice (generations 0→1→2) but spawns 2–3 children with
  big upward velocities; verify it can't cascade into a screen full of tiny drops at high levels.
- **Bounds are hardcoded** (`60` / `660`, screen `720` wide) throughout Drop.gd & Gameplay.gd —
  fine for the fixed portrait target, but centralise them as constants.
- **Collision radius** is `drop_radius * 2.5` — quite generous (forgiving taps). Good for mobile,
  but it's also the hook where **`magnetic_tap` should plug in** (see §4).

---

## 4. Power-ups, abilities & economy audit (+ game psychology)

### 4.1 Active abilities (equip ONE, shared 30 s cooldown)
`time_warp` (free), `evaporation` (1000), `tidal_wave` (2000), `midas_touch` (3000),
`auto_turret` (4000).
- **One fixed 30 s cooldown for all** regardless of power. Tidal Wave (full-screen clear) and Time
  Warp (a brief 50% slow) costing the same cooldown is unbalanced. **Recommend** per-ability
  cooldowns and/or an upgrade path (abilities are currently unlock-only — no scaling).
- Psychology: a single charge that takes 30 s to refill is a long dead stretch with no
  micro-feedback. Consider a visible charge that fills from popping drops (agency), or shorter
  cooldowns with weaker effects, to keep the dopamine loop tighter.

### 4.2 In-run drop power-ups (tap to collect)
`DRAIN, FREEZE, BOMB, SHIELD, RAINBOW` — weighted spawn after 5 s, max 2 active.
- Solid variety and feedback (each has text + particles + sfx + haptics). **BOMB** uses
  `bomb_radius = 2000` (whole screen) and only pops `NORMAL` drops — effectively a "clear all
  normals" button; fine, but the name implies a radius that doesn't matter.
- These are the strongest part of the moment-to-moment loop. Keep and expand (the asset folder
  has icons for many more — see §8).

### 4.3 Passive upgrades (permanent)
`score_boost` ✅, `streak_accelerator` ✅, `juicy_drops` ✅, `toxic_immunity` ✅,
`mini_turret` ✅, `chain_lightning` ✅ … and:
- **`magnetic_tap` is a dead purchase.** Sold for 1000 and unlocked by default, but **no code
  reads it** — tap radius is the fixed `drop_radius * 2.5`. Either implement it (scale the
  collision radius / add tap-snap to nearest drop) or remove it. Selling an inert item erodes
  trust — a real game-psychology negative.

### 4.4 The "upgrades" tab
`freeze_duration, bomb_radius, drain_amount, shield_capacity` — these scale (1.5–2.0× cost
curve). Note `shield_capacity` level seeds `shield_charges` at run start (Gameplay.gd:282-283).
Reasonable, but only 4 of the many systems are upgradeable; abilities/passives are binary.

### 4.5 Themes = the moving level/environment system (design intent)
**Design decision (confirmed by Ben):** buying themes was *intentionally removed*. Themes are no
longer a store — they are the **environments you move through as you survive longer**. The thrill
is *reaching a new level/environment*, and building that excitement is a first-class goal.

Given that intent, the current code is mostly right, with two cleanups:
- **Vestigial prices.** `ThemeManager.THEMES` still carries `price` fields (lava 250 … neon 3500)
  and there's no theme store in `Shop.gd` (tabs = upgrades / abilities / passives). The prices are
  dead data — remove them (or clearly mark themes as progression-only) so nothing implies a
  purchase.
- **Persisted `equipped_theme` is really "current environment."** Level-up writes the level's theme
  to `equipped_theme` on disk (`Gameplay.gd:932-934`), and `GameManager.trigger_game_over` reads its
  `score_mult` for the droplet payout. This actually *aligns* with the design — reaching deeper
  environments yields better rewards — but it's stored in the save slot, which is confusing. Treat
  it as the run's current-environment state; keep per-theme `score_mult` as the "deeper = more
  reward" lever, just document it as intentional rather than a side effect.

**The real opportunity here is feel, not economy:** the level-up moment (`_trigger_level_up`,
Gameplay.gd:930) is currently a text-label tween + background wipe + recolor. To deliver the
excitement Ben wants, make arriving in a new environment a genuine *event* — a bold "NEW
ENVIRONMENT" reveal with the biome name, a light/particle burst, an audio sting, and clear reward
feedback — synced with the existing plunge transition. (See §9, P1.)

### 4.6 Events & difficulty
8 scripted events (meteor, eruption, toxic, midas/piñata, blackout/prismatic, overdrive, chaos).
Rich and characterful. Watch-outs:
- **Blackout (level 6)** hides normal drops (only rainbow drops light up) — punishing; make sure
  the rainbow cadence guarantees enough light, and consider an easing/onboarding for new players.
- **Galaxy** theme stacks `damage_mult 3.0` + `size_mult 1.5` + `speed_mult 0.5`; **lava**
  `damage_mult 2.0`. Verify these don't spike difficulty unfairly at the fixed level timings.
- Endless "chaos" floor: `current_spawn_interval` hard-floored at 0.05 s (Gameplay.gd:789) — at
  that rate the shader load (see §6) will be the limiting factor on mobile.

---

## 5. Visual direction — hyper-real liquid in a 2D world

The good news: the foundation is already aimed at this. `fluid_drop.gdshader` is a **metaball /
2.5D** renderer — it builds a per-pixel normal, then does diffuse + specular + **fresnel** +
**screen-texture refraction** per liquid type (water lens, lava voronoi cracks, slime SSS, gold
env-mapping, etc.). That's the right strategy for "3D feel, 2D world."

To push it to genuinely hyper-real and cohesive:
- **Add a `WorldEnvironment` with Glow/Bloom.** The whole aesthetic is neon/emissive; mobile
  renderer supports glow in 4.3. A single bloom pass would elevate every drop, the laser, gold,
  rainbow and neon instantly. (Confirm none exists in `Main.tscn` and add one.)
- **Contact & impact:** drops currently just vanish at the bottom. Add **splash sprites** (you
  have `splash_lava`, `splash_toxic`), **ripple rings** on the pool surface, and a brief
  **surface-disturbance** where a drop enters the flood.
- **The flood pool** is a rising `ColorRect` + shader. Give its surface a **moving waterline**
  (foam line, small waves, caustics, faint reflections of falling drops) so the rising threat
  reads as real liquid, not a colored rectangle.
- **Drop polish:** soft contact shadow beneath each drop, subtle motion trail / elongation on
  fast drops (the water already stretches — extend tastefully), and better edge AA (the current
  `clamp((energy-1)*20)` edge is serviceable but can shimmer).
- **Cohesion:** unify lighting direction across drops, pool, splashes and turret so highlights
  agree — that's what sells "real" more than any single effect.

---

## 6. Mobile performance — the real risk

1. **Screen-texture refraction in the drop shader is the #1 concern.** `fluid_drop.gdshader`
   samples `hint_screen_texture` for water/slime/acid/gold/neon/bomb/freeze/shield/drain. Each
   unique on-screen drop sampling the back buffer forces a screen copy and texture reads; with
   20+ drops (and 0.05 s spawn floor in chaos) this can tank fps on mid/low-end Android.
   **Mitigations:** sample at lower precision, gate refraction to fewer types, use a downsampled
   copy, or replace refraction with a cheaper fake (normal-tinted gradient) on low-end via a
   quality setting. **Profile on a real mid-tier device early.**
2. **CPU pixel loops on the main thread:** `_make_transparent` (turret JPEGs) and
   `_create_ring_texture` (ability UI) run per-pixel at load → startup hitches. The turret one
   disappears when you switch to PNGs (§2.2); bake the ring texture as an asset.
3. **Per-frame churn:** every drop calls `queue_redraw()` + sets shader params each frame even
   when static (Drop.gd:296-304); `get_current_color()` re-reads the theme each frame. Gate to
   changes.
4. **`CPUParticles2D` everywhere** — consider `GPUParticles2D` for the heavy emitters
   (evaporation 400, midas 150, freeze 150) to move work off the CPU, keeping CPU ones only where
   compatibility matters.
5. Pools are pre-warmed (good) but 20 drops may be too few in chaos (it falls back to
   `instantiate()` mid-run → hitch). Make prewarm scale with expected peak.

---

## 7. Audio — a large, cheap win

- **No music at all.** `bgm_volume` is stored and there's a Settings slider, but nothing ever
  plays a track. Add a simple looping BGM per biome (or one adaptive track) through a dedicated
  music `AudioStreamPlayer`.
- **All SFX are synthesized beeps** (`AudioManager._generate_placeholder_sounds`). Functional
  placeholders, but real, layered SFX (pop, splash, power-up, laser, game-over) are one of the
  highest enjoyment-per-effort upgrades in the whole project.
- SFX bus uses `"Master"` directly; add `Music`/`SFX` buses so the two volume sliders are real.

---

## 8. Backgrounds — confirm: they need remaking

`BackgroundManager` swaps a script per theme. `WaterBG.gd` (representative) just loads a **static
JPEG** (`water_zen_garden_bg.jpg`) + a handful of `CPUParticles2D`. So "animated backgrounds" are
really static images with a few drifting sprites. The `*_bg.gdshader` files exist in `assets/`
but the BG scripts don't appear to use them.

**Plan:** rebuild backgrounds as **parallax** using the new far-layer art
(`bg_city_skyline_far`, `bg_space_nebula_far`, `bg_ocean_abyss_far`, `main_menu_bg`) — a slow
scroll + a subtle animated shader layer (drifting fog, twinkles, heat shimmer) per biome. The
existing "plunge" wipe transition (`_do_plunge_transition`) is good and can stay.

---

## 9. Prioritised roadmap

**P0 — fix what feels broken (the things you flagged):**
1. Make forming drops tappable + tighten water formation timing/rhythm (§2.1).
2. Rebuild the turret + laser using the PNG assets, with beam/muzzle/impact (§2.2).
3. Fix the slime bounce / velocity-vs-tween fight; unify the drop physics core (§2.1.4, §3).

**P1 — make it make sense & feel polished:**
4. Amplify the level-up moment into an exciting "new environment" reveal + remove vestigial theme
   prices (themes are the moving-level system, not a store) (§4.5).
5. Implement or remove `magnetic_tap` (§4.3).
6. Add `WorldEnvironment` bloom + splash/ripple contact FX (§5).
7. Add music + real SFX + proper audio buses (§7).
8. Per-ability cooldowns / charge-from-play (§4.1).

**P2 — depth & expansion (asset-backed):**
9. Rebuild backgrounds as parallax (§8).
10. New drop types already arted (shielded/shadow/clockwork/swarm) and boss rounds (GDD §4).

**Cross-cutting:** add a mobile **quality setting** (shader refraction on/off, particle counts)
and **profile on a real device** before building more content (§6).

---

## 10. Assets still needed to generate

The current `All_Generated_Game_Assets/` is broad guesswork. Concretely missing / worth
generating for the work above (and to retire the 38 unidentified `media_*` files):

**Liquid / FX (for hyper-real feel):**
- Splash sprite-sheets per biome (water, slime, lava, acid, gold) — not just `splash_lava/toxic`.
- Pool **surface foam line** + **caustics** texture (tileable) per biome.
- Ripple-ring sprite-sheet; drop **contact shadow** soft blob.
- Normal maps for the pool surface if going full PBR-ish.

**Turret / laser (P0):**
- Muzzle-flash sprite-sheet; laser **core + outer glow** as separate strips for additive layering;
  beam **start/end cap** sprites; charge-up telegraph ring.

**Backgrounds (P1):**
- Mid + near parallax layers to pair with the existing `*_far` plates (currently only far exists),
  for each biome (water, lava, slime, acid, gold, rainbow, neon, galaxy).
- Animated overlay textures (drifting fog, dust, embers, bubbles) per biome.

**UI / juice:**
- A real **theme/skin store** card frame + per-theme preview thumbnails.
- Combo / streak burst FX; "new high score" celebration; level-up banner art.

**Audio (not images, but the biggest gap):**
- Music loops per biome; layered SFX set (pop variations, splash, power-up, laser, bomb,
  game-over, UI).

> Recommendation: don't mass-generate yet. Lock the P0/P1 features first, then generate the
> *specific* assets each one needs at the right resolution/format, and identify/rename the 38
> `media_*` files as we go (tracked in `ASSETS.md`).
