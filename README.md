# Flood Drop

A fast-paced 2D arcade **tapping game** built in Godot. Liquid drops fall from the top of
the screen; tap them to pop them before they reach the bottom. Every drop that lands raises
the **Flood Level** — if the flood reaches the top, it's game over. Popping drops earns score
and currency to spend in the shop on active and passive abilities.

> Full design and roadmap: **[docs/flooddrop_gdd.md](docs/flooddrop_gdd.md)**

---

## Tech stack

| | |
|---|---|
| **Engine** | Godot **4.3** (mobile renderer) |
| **Language** | GDScript (one experimental C# file, `ShaderTest.cs`) |
| **Target** | Android — portrait, `720 × 1280`, touch input (also runs on PC/Web) |
| **Main scene** | `scenes/Main.tscn` |

## Running the game

1. Install **Godot 4.3** (standard build; the experimental `ShaderTest.cs` is not wired into
   the project and does not require the .NET/Mono build).
2. Open this folder as a project in the Godot project manager.
3. On first open, Godot imports all textures and shaders (this generates the `.godot/` cache —
   it is intentionally git-ignored).
4. Press **Play** (F5) to launch `Main.tscn`.

### Android export

The game targets an Android APK (`Flood Drop` / `Flood_Drop.apk`). Both the export config
(`export_presets.cfg`, which can hold local keystore paths) and the build artifacts
(`*.apk`, `*.aab`, `*.apk.idsig`) are git-ignored, so they are **not** committed — configure
the Android export templates and a debug/release keystore in your local Godot to produce a build.

## Project structure

```
.
├── project.godot              # Engine config, autoloads, display/input settings
├── scenes/                    # .tscn scenes (Main, Gameplay, Shop, Settings, GameOver, …)
│   ├── autoloads/             # BackgroundManager scene
│   └── backgrounds/           # Animated background scenes
├── scripts/                   # GDScript logic
│   ├── autoloads/             # Singletons: EventBus, GameManager, SaveManager,
│   │                          #   AudioManager, ThemeManager, BackgroundManager
│   └── backgrounds/           # Per-theme animated background controllers
├── assets/                    # Imported art + custom .gdshader files
│   └── backgrounds/, icons/, passives/
├── docs/                      # Design documentation (GDD)
├── All_Generated_Game_Assets/ # Raw generated art for the roadmap — NOT yet imported
│                              #   or wired in. See docs/ASSETS.md.
└── icon.svg
```

## Key systems

- **`scripts/Gameplay.gd`** — the main loop: spawns drops, tracks the flood level, handles
  taps, and drives the turret/laser mechanics.
- **`scripts/Drop.gd`** — falling-drop logic via a `FORMING → FALLING → POPPING → INACTIVE`
  state machine.
- **`scripts/PoolManager.gd`** — object pooling for drops and particles (recycles instances
  instead of allocating/freeing each frame — important for mobile performance).
- **`scripts/Shop.gd`** — shop UI and the purchase/economy logic.
- **Autoloads** (registered in `project.godot`): `EventBus`, `GameManager`, `SaveManager`
  (persists score/currency/unlocks), `AudioManager`, `ThemeManager`, `BackgroundManager`.

## Assets

The `assets/` folder holds the **currently-used** art and shaders. The
`All_Generated_Game_Assets/` folder holds **148 generated PNGs** intended for the roadmap
features (bosses, parallax backgrounds, new drop types, expanded power-ups, cosmetics). They
are a raw dump — not yet organized, imported, or referenced by any scene or script. See
**[docs/ASSETS.md](docs/ASSETS.md)** for the catalog and integration notes.

## Roadmap

Boss rounds, advanced defenses (missile batteries, helper drones, barricades), complex drop
modifiers (clockwork / swarm / shielded / shadow), weather events, expanded power-ups, and
cosmetics. Details in **[docs/flooddrop_gdd.md](docs/flooddrop_gdd.md)** §4.
