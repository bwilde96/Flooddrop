# Flooddrop — Improvement Action Plan

A deep, prioritised plan across three pillars: **Beautiful graphics**, **Enjoyment (game feel)**,
and **Addictiveness (retention)**. Written after reading every script/shader/scene and seeing the
game running (screenshots). It builds on work already shipped in PR #2 — it does not repeat it.

> Already done (PR #2): bloom/glow, drop-feel fixes (tappable while forming, velocity bounce),
> magnetic-tap, exciting level-up reveal, turret rebuilt with real art + homing bullets + better
> laser, tidal wave restored (crashing_wave shader). Those are the baseline this plan extends.

---

## 0. The vision (what we're optimising for)

Flooddrop's fantasy: **popping beautiful, physical liquid with deeply satisfying feedback, riding
an escalating wave of chaos through gorgeous, distinct worlds — and never wanting to stop.**

Three pillars, in tension and balance:
- **Beauty** — hyper-real liquid, cohesive neon-vibrant biomes, glow.
- **Feel** — every tap is tactile and juicy; the game is readable and fair.
- **Addiction** — tight reward loops, visible progression, "one more run" hooks.

The codebase is a strong foundation: sophisticated metaball drop + flood shaders, object pooling,
robust save, real juice fundamentals (hit-pause, shake, squash/stretch, haptics, streak
multiplier), gorgeous biome backgrounds, polished shop cards. The gaps are concentrated and very
addressable.

---

## 1. ⚠️ Three cross-cutting enablers (unblock everything else)

These gate large parts of the plan. Do them first / in parallel.

### 1.1 Regenerate the asset library as **transparent RGBA PNGs**
The entire `All_Generated_Game_Assets/` library is **opaque JPEG with a `.png` extension** (verified
in Godot — JFIF, RGB, 1024², inconsistent solid/checkerboard backgrounds). This blocks clean
integration of turret/boss/drop/cosmetic/UI art. Fix at the generation source: export true RGBA
PNGs with real transparency. (Additive glow FX on a *black* background are the only exception that
work as-is.) **This is the single biggest unblocker** for the content in Phases 2–3.

### 1.2 Audio production — music + real SFX
**There is no music** (the BGM slider controls nothing) and **all SFX are synthesised beeps**
(`AudioManager._generate_placeholder_sounds`). Audio is the highest enjoyment-per-effort upgrade in
the entire project. Needs: per-biome music loops (or one adaptive track), and a real layered SFX
set (pop variations, splash, power-up, laser, bomb, level-up sting, game-over, UI). Add `Music` /
`SFX` buses so the two sliders are real.

### 1.3 Performance budget + quality settings
The drop and flood shaders sample `hint_screen_texture` (refraction) — beautiful but expensive, and
multiplied across 20+ drops in the endless chaos floor (0.05s spawn). Before adding more, **profile
on a real mid-tier Android**, and add a **quality setting** (refraction on/off, glow levels,
particle counts, GPU vs CPU particles) so the game is gorgeous on flagships and smooth on low-end.
Also: turret art currently loads via `Image.load` (won't work in an exported APK) — move to
pre-keyed imported PNGs once 1.1 lands.

---

## 2. Pillar I — Beautiful graphics

### 2.1 Liquid contact & splash system  ★ highest visual leverage
Right now drops **just vanish** when they hit the flood or get popped. The "natural liquid" feel
lives or dies here. Add:
- **Pop → liquid burst**: squash, then shatter into a few themed liquid shards + a soft splat decal
  + a 1-frame light flash. Replace/augment the 12-particle `PopParticles` burst.
- **Drop enters flood → splash crown + ripple ring** on the flood surface at the impact x, plus a
  brief disturbance in the flood shader (a localised wave). The `crashing_wave`/`flood_pool` foam
  vocabulary is already there to reuse.
- **Contact shadow** softly under each drop, and a faint **caustic** it casts on the flood.

### 2.2 Juicier, more physical drops
- **Size/weight**: drops read a touch small; scale up modestly (tuned with the new glow) so they
  feel like substantial liquid. (Task already queued.)
- **Motion**: subtle trail / elongation on fast drops (water already stretches — extend tastefully),
  a gentle wobble at rest, and squash on the formation "drip".
- **Per-type signature pops**: each special drop bursts in its own way (freeze → ice shards +
  frost; bomb → fireball; rainbow → prismatic confetti; gold → coin shower; acid → toxic splatter).

### 2.3 Living flood surface
The `flood_pool.gdshader` is already excellent (waves, bevel, caustics, meniscus, per-liquid
materials). Push it: a brighter **animated foam line** at the exact waterline, faint **reflections**
of falling drops, and a stronger **danger state** (already shifts red — make it pulse + emissive as
it nears the top).

### 2.4 Backgrounds → parallax + animated
Backgrounds are **static JPEGs + a few CPUParticles** (`WaterBG`, `MainMenuBG`, etc.). Rebuild as
**multi-layer parallax** (slow drift, depth) using the `bg_*_far` plates (need mid/near layers
generated — see §6) plus a subtle **animated shader overlay** per biome (drifting fog, embers,
bubbles, twinkles, heat shimmer). Animate the **main-menu** background too (it's a flat JPEG).

### 2.5 Per-biome identity & cohesion
Make each of the 8 worlds feel like a distinct, cohesive place: palette + background + drop look +
splash colour + particle colour + **music** all tuned together. Unify the **lighting direction**
across drops, flood, splashes, and turret so highlights agree — that's what sells "real."

### 2.6 Glow/grading polish (extend what's shipped)
Bloom is in. Next: per-biome **colour grading + vignette** via the `Environment` (adjustments,
gentle tonemap), and tune glow per-effect so bright full-screen effects (tidal wave, freeze,
evaporation, midas overlays) bloom tastefully rather than blocky (we already learned this on the
tidal wave). Consider a subtle screen-edge glow that intensifies with the multiplier.

### 2.7 UI / HUD beautification
- **Ability button**: add a dark backing disc so the additive icon reads crisply (it currently
  washes out over bright backgrounds), plus a clean charge ring and a ready-flash.
- **HUD frame**: use the `ui_frame_*` art for a cohesive frame; animate the **score counter**
  (count-up, punch on big gains); juice the multiplier further.
- **Particle textures**: the `_create_soft_particle_texture` is 64² — bump to 128² and smoother;
  move heavy emitters to `GPUParticles2D`.
- **Tap feedback**: a small ripple/splash at the touch point on every tap (ties into cosmetics —
  cursors/trails).
- **Fonts/styling**: one consistent neon font system with proper outlines/kerning across all
  screens.

### 2.8 Game Over screen — full visual redo (also §4)
Currently static labels. Make it a **moment** (see §4.1).

---

## 3. Pillar II — Enjoyment (game feel)

### 3.1 Audio (see §1.2) — the biggest single feel upgrade
Music that escalates with intensity; pop SFX that pitch-climb with the streak (the hook exists);
**combo/streak audio layers** that stack as the multiplier rises; a satisfying level-up sting and a
weighty game-over. Bubble-wrap-grade pop feedback.

### 3.2 Tactile pop & combo escalation
Hit-pause, shake, haptics, squash/stretch already exist — tune and layer them. As the multiplier
climbs (2x→5x), escalate: bigger pops, screen-edge glow, audio layers, an "ON FIRE" state at max.
Make popping a drop feel as good as popping bubble wrap.

### 3.3 Readability & fairness
- **Telegraph** special drops unmistakably (colour + centred symbol + glow) — and fix the bug where
  special drops don't always take the parent-liquid form and symbols aren't centred (queued).
- **Danger feedback**: as the flood nears the top, add a red vignette pulse + heartbeat audio + a
  subtle slow-mo tell, so death never feels cheap.
- **Event clarity**: each event (eruption, toxic, blackout, overdrive, chaos) should announce itself
  clearly and read at a glance. Ensure **blackout** always provides enough rainbow "light" to be
  fair.

### 3.4 Onboarding / first run
There is **no tutorial**. New players need a 15-second guided first run (tap to pop → watch the
flood → use your ability), ideally diegetic (no walls of text). First-session clarity is the
biggest lever on new-player retention.

### 3.5 Pacing & difficulty curve
Audit the ramp (`spawn_ramp_speed`, `speed_ramp_speed`, `power_up_spawn_ramp`) for a fair early
game and escalating chaos; add **breathers** after intense events; sanity-check the endless chaos
floor (0.05s spawn) for both fairness and performance. Consider difficulty that adapts slightly to
skill to keep everyone in flow.

### 3.6 Ability feel
One fixed 30s cooldown for all abilities is undifferentiated. Give **per-ability cooldowns** and/or
a **charge-that-fills-from-popping** model (more agency, tighter dopamine loop). Make each ability's
activation feel powerful and distinct (most already have good FX — extend).

### 3.7 Reward cadence
Frequent micro-rewards (score popups with punch, coin pickups, streak ups) + periodic big rewards
(level-up celebration — done; jackpot piñata — exists). Keep the screen alive with positive
feedback.

---

## 4. Pillar III — Addictiveness (retention)

### 4.1 The "one more run" loop  ★ highest retention leverage
Fast restart exists. Add the psychology around death:
- **Near-miss framing** on Game Over: "You were 240 from your best!" / "One drop from Galaxy!"
- **Animated reward**: count-up droplets, a rank/grade, and **progress toward the next unlock**
  ("420 / 500 → unlocks Tidal Wave") — so every death visibly advances you.
- A big, immediate **RETRY** as the default action.

### 4.2 Cosmetics economy (assets already designed!)
The roadmap art includes **flood skins** (lava/matrix/blood), **drop hats**, **custom cursors**, and
**trails**. Wire a cosmetics system: earn/buy, equip, show off. This is huge for retention *and* a
clean monetisation path — and it's low gameplay risk. (Art needs the §1.1 regen, but the *system*
can be built now.) Note: themes are the moving-level/progression system (not a store) — cosmetics
are the customisation layer on top.

### 4.3 Daily engagement
- **Daily reward / login streak** (escalating, with a visible streak counter).
- **Daily challenge** — a rotating modifier or goal with a reward.
- **Missions / objectives** — "pop 500 drops", "survive to Galaxy", "use Tidal Wave 10×", "3000 in
  one run" — persistent and rotating, each granting droplets/cosmetics.

### 4.4 Goals, milestones & achievements
An achievement system (the `ui_achievement_banner`/`ribbon` art exists) with milestone celebrations
and a stats/profile screen. Players need a constant sense of "next thing to chase."

### 4.5 Meta-progression depth & visibility
Audit the shop/upgrade/passive curve so each run meaningfully advances the player; add **per-ability
upgrade paths** (currently binary unlock); and **always show what's next** (next biome, next
unlock, next ability) on the menu and game-over.

### 4.6 Variable & surprise rewards
Gold/jackpot drops exist — expand: rare drop types, occasional mystery/loot drops, lucky streaks.
Unpredictable upside is a core addiction mechanic (kept fair, not predatory).

### 4.7 Boss rounds  ★ big retention bet (GDD roadmap)
Periodic multi-part bosses (Kraken, Mothership, Rogue Mech, Slime King) that halt the flood and
demand tapping weak points. Memorable, varied, share-worthy — a strong reason to keep playing toward
"the next boss." Art exists (needs §1.1 regen).

### 4.8 New content cadence
New drop types already arted (shielded/shadow/clockwork/swarm), new events, new biomes — establish a
pipeline so there's always something new. Steady content is what sustains long-term retention.

### 4.9 Score chase & social (later)
Online leaderboards, a "ghost" of your best run, and a one-tap **share score image**. Local high
score already exists as the seed.

---

## 5. Prioritised roadmap

Effort: S(mall) / M(edium) / L(arge). Impact: ★ (1–3).

### Phase 0 — Enablers (do first / in parallel)
| Item | Effort | Impact |
|---|---|---|
| Regenerate assets as transparent PNGs (§1.1) | L (external) | ★★★ |
| Music + first real SFX pass (§1.2) | M | ★★★ |
| Quality settings + device profiling (§1.3) | M | ★★ |

### Phase 1 — Feel & beauty quick wins (highest ROI)
| Item | Effort | Impact |
|---|---|---|
| Liquid contact splash + ripple system (§2.1) | M | ★★★ |
| Juicier pop + per-type pop FX + particle upgrade (§2.2, §2.7) | M | ★★★ |
| Game Over redo: count-up, near-miss, next-unlock, retry (§4.1) | M | ★★★ |
| Fix special drops (form + centred symbols) (queued) | S | ★★ |
| Ability button readability + charge (§2.7, §3.6) | S | ★★ |
| Per-biome glow/grading + vignette tune (§2.6) | S | ★★ |
| Bigger/juicier drops (queued) | S | ★★ |

### Phase 2 — Retention systems & deeper beauty
| Item | Effort | Impact |
|---|---|---|
| Daily reward + missions/challenges + achievements (§4.3, §4.4) | L | ★★★ |
| Cosmetics system: flood skins / hats / cursors / trails (§4.2) | M–L | ★★★ |
| Onboarding tutorial (§3.4) | M | ★★★ |
| Parallax animated backgrounds + animated menu (§2.4) | M–L | ★★ |
| Per-ability upgrades + progression teasers (§4.5) | M | ★★ |
| Combo/streak audio-visual escalation (§3.2) | S–M | ★★ |

### Phase 3 — Big content bets
| Item | Effort | Impact |
|---|---|---|
| Boss rounds (§4.7) | L | ★★★ |
| New drop types & events (§4.8) | M each | ★★ |
| Leaderboards + share (§4.9) | M | ★★ |
| New biomes (§4.8) | M each | ★★ |

---

## 6. Assets to generate (precise spec for the regen)

Generate as **true transparent RGBA PNGs** (power-of-two where practical, e.g. 512²/1024²):

**Liquid/FX (Phase 1):** per-biome splash crown sprite-sheets; ripple-ring sheet; soft contact
shadow blob; pop-shatter shard sheets per biome; tileable foam-line + caustics textures per biome;
a 128² soft glow dot (replace the 64² one).

**UI (Phase 1):** ability-button backing disc + charge ring; HUD frame set (`ui_frame_*` as alpha);
animated score/coin pickup; rank/grade badges for game-over.

**Backgrounds (Phase 2):** mid + near parallax layers to pair with the existing `*_far` plates, per
biome; animated overlay textures (fog/embers/bubbles/twinkles) per biome.

**Cosmetics (Phase 2):** finalised flood skins, drop hats, cursors, trails (alpha).

**Turret/laser:** transparent turret base + barrel (replace the chroma-key) + adv/twin variants;
muzzle-flash + impact + charge-tell sheets.

**Bosses (Phase 3):** Kraken / Mothership / Rogue Mech / Slime King multi-part sprites (alpha).

> Also: identify/rename the 38 unnamed `media_*` files (catalogued in `ASSETS.md`) and dedupe the
> duplicate icon variants.

---

## 7. The 10 highest-leverage moves (if time is short)

1. **Music + real SFX** — instantly transforms feel (§1.2).
2. **Liquid splash/ripple on contact** — sells the hyper-real liquid (§2.1).
3. **Game Over → "one more run" machine** — count-up, near-miss, next-unlock, retry (§4.1).
4. **Juicier pops** (per-type burst + better particles) (§2.2).
5. **Daily reward + missions** — the retention backbone (§4.3).
6. **Cosmetics system** — retention + monetisation, low risk (§4.2).
7. **Onboarding** — protects new-player retention (§3.4).
8. **Regenerate transparent assets** — unblocks everything else (§1.1).
9. **Parallax animated backgrounds** — depth + beauty (§2.4).
10. **Boss rounds** — the marquee long-term hook (§4.7).
