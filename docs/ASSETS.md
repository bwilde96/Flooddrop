# Generated Asset Library — Catalog & Integration Notes

This catalogs the **148 PNGs** in [`../All_Generated_Game_Assets/`](../All_Generated_Game_Assets/),
the raw art generated for the roadmap in [flooddrop_gdd.md](flooddrop_gdd.md) §4.

**Status:** raw dump. These files are **not imported by Godot** (no `.import` sidecars) and are
**not referenced** by any scene or script. They sit outside `assets/`. Nothing in the game uses
them yet — this catalog is the map for wiring them in feature by feature.

Filenames carry a generation timestamp suffix (e.g. `boss_kraken_body_1782233495094.png`). When
integrating, copy the file into the relevant `assets/` subfolder under a clean name (strip the
suffix) so Godot imports it and the path is stable.

---

## Inventory by feature

### A. Boss Rounds → GDD §4.A
- **Kraken** (cybernetic squid): `boss_kraken_body`, `boss_kraken_eye`, `boss_kraken_tentacle`
- **Rogue Purifier Mech**: `boss_mech_core`, `boss_mech_arm_left`, `boss_mech_arm_right`, `boss_mech_thruster`
- **Slime King**: `boss_slime_core`, `boss_slime_crown`, `boss_slime_outer_layer`
- **Alien Mothership (UFO)**: `boss_ufo_chassis`, `boss_ufo_glass_dome`, `boss_ufo_abduction_ray`

Multi-part bosses — each part is a separate sprite, intended as tappable weak points.

### B. Backgrounds / Parallax → GDD §4.D
- `bg_city_skyline_far`, `bg_space_nebula_far`, `bg_ocean_abyss_far` — far parallax layers
- `main_menu_bg`

### C. New drop types → GDD §4.C
- `drop_clockwork_shell` — Clockwork (timed-tap) drops
- `drop_nest_egg` — Swarm (egg → droplets) drops
- `drop_shadow` — Shadow (stealth) drops
- `drop_shield_bubble`, `shield_bubble` — Shielded (two-tap) drops
- `drop_crystal` — crystal variant

### D. Turrets, defenses & projectiles → GDD §4.B + current turret system
- **Turrets**: `turret_base`, `turret_barrel`, `turret_adv_base`, `turret_adv_twin_barrel`, `auto_turret`
- **Missile battery**: `turret_missile_base`, `turret_missile_pod`
- **Projectiles / laser**: `turret_bullet_gold`, `laser_beam_red`, `laser_beam_blue`, `laser_impact`
- **Helper drones**: `drone_chassis`, `drone_rotor_blade`
- **Barricades**: `wall_barricade_center`, `wall_barricade_endcap`, `wall_barricade_damage_overlay`

### E. Power-ups — active & passive → GDD §2/§3/§4.E
Most power-ups come as a set (`_icon`, `_card`, `_large`, sometimes `_blank`):
- **Active**: `time_warp`, `evaporation`, `tidal_wave`, `midas_touch`, `mini_turret`,
  `chain_lightning` (+ `chain_lightning_arc`), `magnetic_tap`, `juicy_drops`,
  `streak_accelerator`, `score_boost`, `toxic_immunity`
- **Roadmap actives**: `icon_orbital_strike`, `icon_time_rewind`
- **Passives**: `icon_passive_armor`, `icon_passive_magnet`, `icon_passive_sponge`
- **Curse / misc**: `icon_curse_blindness`, `item_health_potion`
- **Splash FX**: `splash_lava`, `splash_toxic`

### F. Cosmetics → GDD §4.F
- **Flood skins**: `flood_skin_lava`, `flood_skin_matrix_code`
- **Drop hats**: `hat_tophat`, `hat_halo`
- **Cursors**: `cursor_magic_wand`, `cursor_neon_crosshair`
- **Trails**: `trail_rainbow`

### G. UI chrome
- **Shop**: `ui_store_awning`, `ui_store_neon_sign`, `ui_store_shelf`, `passive_shop_card_mockup`
- **HUD / frames**: `ui_bar_liquid_fill`, `ui_coin_gold`, `ui_btn_play`,
  `ui_frame_corner_tl`, `ui_frame_edge_top`, `ui_frame_center_fill`
- **Achievements**: `ui_achievement_banner`, `ui_achievement_ribbon`

### H. FX / overlays & particles
- `overlay_screen_frost` (Freeze Bomb), `overlay_speed_lines`, `overlay_vignette_red`
- `particles_smoke_spritesheet`, `particles_spark_spritesheet`

---

## Cleanup TODO before integration

- **38 `media_*.png` files** are generically named (`media_<timestamp>.png`) and unidentified —
  open each, figure out what it is, and rename/sort it into the categories above (or delete).
- **Duplicate icon variants**: several icons appear as two timestamped generations of the same
  logical name (`chain_lightning_icon`, `juicy_drops_icon`, `magnetic_tap_icon`,
  `mini_turret_icon`, `score_boost_icon`, `streak_accelerator_icon`, `toxic_immunity_icon`,
  `turret_base`, `turret_barrel`). Pick the keeper and drop the rest.
- Decide whether these live under `assets/generated/<category>/` (organized, version-controlled)
  once imported, and retire the flat `All_Generated_Game_Assets/` dump.
