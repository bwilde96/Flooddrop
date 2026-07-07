# The Gauntlet — Challenge Mode & Economy Design

Synthesised from a 3-lens design pass (spectacle/intensity, retention/fair-monetisation,
progression/mastery) plus feasibility and player-experience critiques, grounded in the
actual codebase. **✅ = implemented and E2E-verified** on `feat/p0-gameplay-polish`;
everything else is the tuning/roadmap layer on top of that foundation.

---

## 1. The pitch

The Gauntlet is Flood Drop's **best-designed content**: short (45–120s), authored,
*intense* challenge runs — the biome weaponised. Water drowns you, slime multiplies, lava
burns double, acid punishes greed, gold tempts it, rainbow blinds you, neon lies to you,
galaxy throws everything at once. Access is metered by **tickets**; mastery pays out the
only currency that buys **power** — and money can never touch it.

**One-line economy:** money buys *attempts and appearance*; power is earned by *playing*.

---

## 2. The fairness contract (the soul of the system) ✅

These rules are implemented and non-negotiable — they're what make the paid layer feel
generous instead of extractive:

1. **First attempt of every challenge is FREE.** 32 free tastes across the whole game.
   Tickets meter *repetition* (grinding, retrying), never *access* to content.
2. **Cleared challenges are free to practice forever** (25% droplets, no Cores).
   You never pay to replay something you've beaten.
3. **Second Wind:** fail at ≥70% progress → one free instant retry (per challenge/session).
   The near-miss is the most valuable emotion in the game; charging at that exact moment
   converts excitement into resentment.
4. **Fast-fail refund:** fail inside 10s → ticket back. Mis-taps and phone calls don't count.
5. **Stranded-ticket refund:** a ticket spent on an attempt that never resolved (process
   killed) is refunded on next launch.
6. **Honest boss pity:** −2 boss HP per 3 failed attempts (cap −6). Nobody is walled;
   spending is never the answer to being stuck.
7. **Cores are never purchasable and never drop from repeat clears.** Paying compresses
   the calendar; it never raises the ceiling.
8. **Sudden-death challenges zero banked shields** (loadout rule) so one tuning works for
   every player. Otherwise the player's full kit is allowed — challenges are tuned
   assuming it.

## 3. Tickets ✅

| Parameter | Value | Why |
|---|---|---|
| Daily grant | **3/day** (device clock, monotonic — rollback never re-grants, never punishes) | An attempt is 45–120s: 3 tickets ≈ a 5-minute daily "espresso shot" of the most intense content |
| Wallet cap | **9** | ~2 missed days bankable; bounds clock-abuse; keeps gentle daily pull without FOMO punishment |
| Cost | **1 ticket flat** — challenges *and* bosses | Zero mental accounting; taxing bosses puts friction on the best moment |
| Buy | 1 ticket = **10 Prisms** | ≈ £0.17/attempt at the anchor pack — arcade-credit pricing |

## 4. Currencies — three lanes, hard-walled ✅ (earn tables = tuning targets)

### 💧 Droplets (soft — time)
- **Earn:** main runs (existing formula; rebalance to `score*0.3 + time + 40×deepest-level`
  when tuning — pays *depth* legibly, matching "levels are the progression"), challenge
  first-clears (150–2500 by stage), free practice (25%), fail consolation (`score*0.15`).
- **Spend:** existing Shop (abilities/passives/upgrades) → early game; **ability-tree node
  droplet costs** → late game. Never purchasable with money or Prisms.

### ◆ Prisms (premium — money & style)
- **Earn free (deliberate):** boss first-clears (15–30 by stage, ~150 lifetime in v1;
  target ~400 lifetime with achievements/streaks) — free players learn what Prisms feel
  like to spend, which *raises* conversion.
- **Spend:** tickets and cosmetics **only** (flood skins 80–150, hats 40–80, trails 40–60).
- **Packs (when Play Billing lands):** £1.99→120 · £4.99→340 (+13%) · £9.99→750 (+25%).
  No whale packs — their absence is a trust signal.
- **Supporter Pack £7.99 (one-time, the LTV anchor):** permanent +2 daily tickets,
  exclusive "Molten Core" flood skin, +100 Prisms. Must restore via `queryPurchases()`
  after reinstall — the one thing that can never be lost.

### ⬡ Cores (mastery — power)
- **Earn:** challenge first-clears only (1 each; bosses 3–4). ~50 lifetime in v1.
- **Spend:** ability-tree nodes (with a droplet co-cost: Cores gate by skill, droplets
  sink time). Total tree cost (30) < total supply (50) — **completion is finishable**,
  with slack reserved for future tree expansions.
- v1.5: **Ace conditions** (a second, harder objective per challenge shown up front) pay
  +1 Core — the replay hook for mastery players.

## 5. Structure ✅

**8 stages × (3 challenges + boss) = 32.** A stage unlocks in the Gauntlet when you *reach
that level in a main run* (`max_stage_reached`); challenges unlock sequentially within a
stage. A skilled player always has 2+ live goals (deeper main runs *and* the next challenge).

Difficulty inside a stage: **C1** teaches the biome's signature threat isolated (~80% clear
by attempt 2) → **C2** escalates/combines (~50%) → **C3** mastery test, usually
sudden-death or resource-denial (~30%, the clip-worthy one) → **Boss** = execution + drama
(2–4 attempts). Win conditions rotate across 4 types (survive / score / pops / combo,
optionally with max-misses) so no stage is survival-timer soup.

The 32 authored challenges live in `ChallengeManager.CHALLENGES` (all data). Stage
fantasies: The Deluge · The Bounce House · The Furnace · The Refinery · The Vault ·
The Dark Prism · The Grid · The Void.

## 6. Bosses

**v1 ✅ — "The Warden" template:** three announced waves (banner + shake + escalating
spawn pressure via the existing event system) → a **titan drop** finale: giant, glowing,
slow-descending multi-tap orb (24 HP, pity-adjusted) that prowls side-to-side, is immune
to AoE cheese (turret ignores it, bombs/lightning do 1 tick), and **returns angrier if it
reaches the flood**. The descent *is* the enrage timer.

**v2 — per-biome bosses (needs art, see ASSET_SHOPPING_LIST):** Rainfather (tutorial
tank), Slime King (splits into real phases), Magma Titan (vulnerability windows between
eruptions), The Hydra Vat (pop the *wrong* head and it heals), The Mint (steals score per
missed coin), Prism Warden (blackout — only lantern-lit windows), The Mainframe
(teleports; interrupt windows), The Kraken (tentacle cycle, final exam). Feel kit for all:
phase banners at 75/50/25% HP, hit-pause on phase change, slow-mo killing blow.

**Boss reward cadence (v2):** bosses alternate **new ability** / **keystone tree node**:
Freeze Bomb (stage 2) · Black Hole (4) · Neutral Field (6) · **Time Rewind (8)** — a
game-over *intercept* that pops the killing drop and drains flood (the rewind fantasy at
a tenth of the engineering cost of a true rewind). Final capstone carrot, visible from day
one: a **second ability slot**.

## 7. Ability tree ✅ (5 abilities × 3 sequential nodes)

Per-ability cooldowns shipped with it (time_warp 25s · evaporation 30s · tidal_wave 45s ·
midas 40s · turret 35s — replacing the flat 30s). Nodes: power → efficiency → cooldown,
each costing Cores + droplets. v2: tier-3 A/B exclusive choices with cheap respec
(buildcraft without regret).

## 8. Retention layer (v1.5 roadmap)

- **Daily Featured challenge:** rotating pointer into existing content; first attempt
  free, 2× droplets. Even a 0-ticket player has a reason to open the app.
- **Login streak:** 7-day milestone pays Prisms; **one grace day**; explicit ban on
  streak-restore purchases.
- **Fail-screen ordering rule ✅:** the near-miss stat ("you reached 84%") always renders
  before any price. Hope first, commerce second.
- **Mutation Week (later):** weekly modifier twist on the whole Gauntlet for evergreen
  novelty without new content.

## 9. Guardrails & compliance

- **Google Play:** no randomised paid items (no loot-box disclosures needed); Play
  Billing for Prisms/Supporter only; restore path tested against reinstall.
- **Accessibility:** reduced-flash toggle required before shipping blackout/strobe/glitch
  challenges wide; every "don't tap" type marked by symbol, not colour alone.
- **Clock abuse:** accepted at the margins (bounded by cap 9; single-player; the abuser
  was never a payer). Never punish suspected rollbacks — travel/DST false-positives are
  worse than the fraud.
- **Save integrity:** plaintext JSON is casually editable — add a lightweight HMAC later;
  don't over-invest (offline, single-player).
- **Pause abuse** in sudden-death/timed challenges (pause-to-scan): blur or hide the
  field behind the pause menu (backlog).
- **Tuning harness:** the debug panel + `force_drop_type` is halfway to a challenge
  auto-runner; finish it before hand-tuning 32 configs.

## 10. Build phasing

- **✅ Phase 1 (done):** foundation — currencies, tickets + fairness contract, 32 defs,
  challenge gameplay layer, Warden boss template, Gauntlet + Powers UI, result flow,
  save v2.
- **Phase 1.5:** tune stages 1–2 by playtest → Daily Featured → Ace conditions → login
  streak → reduced-flash toggle → challenge HUD (live objective progress bar in-run).
- **Phase 2:** per-biome bosses with real art → 4 new abilities → second ability slot →
  Play Billing + Supporter Pack → cosmetics store (Prism sink).
- **Ship rhythm:** stages 1–4 tuned at launch, 5–8 as the first content drop — the
  cadence is itself a retention hook.
