# Flooddrop: Game Design & Technical Document

This document serves as the master blueprint for **Flooddrop**. It details the core gameplay, the technical architecture, currently implemented features, and the extensive roadmap for future updates based on the massive library of generated assets.

---

## 1. Game Overview
**Flooddrop** is a fast-paced, 2D arcade tapping game primarily targeted at mobile devices (Android/iOS). 

**The Core Loop:**
1. Drops of various liquids fall from the top of the screen.
2. The player must tap/click the drops to "pop" them before they hit the bottom.
3. Every drop that reaches the bottom causes the "Flood Level" to rise. 
4. If the Flood Level reaches the top of the screen, it's Game Over.
5. Popping drops awards points and currency, which can be spent in the Shop to buy Active and Passive abilities to survive longer.

---

## 2. Technical Architecture

### Engine & Tech Stack
* **Game Engine**: Godot 4.x
* **Language**: GDScript (with some experimental C# shader testing in `ShaderTest.cs`).
* **Platform**: Primarily Android (`Flood_Drop.apk` export configuration), but playable on PC/Web.
* **Version Control**: Git / GitHub.

### Core Systems & Scripts
* **`Gameplay.gd`**: The brain of the game. It controls the main game loop, spawns drops, tracks the flood level, handles player input (taps), and manages the Turret/Laser mechanics. It also contains a custom runtime image processing loop (`_make_transparent`) that strips solid backgrounds from dynamically loaded JPG assets.
* **`Drop.gd`**: The logic for the falling drops. It utilizes a state machine: `FORMING` -> `FALLING` -> `POPPING` -> `INACTIVE`.
* **`PoolManager.gd`**: A critical performance optimization system. Instead of constantly instancing and deleting objects (which causes lag on mobile), it pre-loads drops and particles into a "pool" and recycles them.
* **`Shop.gd`**: The UI and logic for the in-game store where players purchase upgrades.
* **Autoloads (Singletons)**:
  * `AudioManager.gd`: Global sound effects and music.
  * `BackgroundManager.gd`: Handles dynamic/scrolling backgrounds.
  * `SaveManager.gd`: Serializes and saves player progress, high scores, currency, and unlocked abilities to the device.

### Visuals & Shaders
* **Aesthetic**: Neon, vibrant, high-contrast, sci-fi/arcade.
* **Custom Shaders**: The game utilizes Godot shaders for dynamic visual effects, including `crashing_wave.gdshader`, `speed_lines.gdshader`, and `fluid_drop.gdshader`.

---

## 3. Currently Implemented Features

### Drops
* **Water Drops**: The standard, baseline enemy.
* **Slimes**: Bouncy, specialized drops with unique collision/movement behavior.
* **Weighted Drops**: Heavy drops that fall faster and require quicker reaction times.

### The Turret System
The player controls a turret situated at the bottom of the screen to help manage the drops. It has two modes of operation based on equipped abilities:
1. **Passive Mode (Mini Turret)**: Automatically aims and fires physical, glowing projectile bullets at drops.
2. **Active Mode (Instant Laser)**: When triggered, it fires a massive, instant red laser beam from the `Muzzle` (a Marker2D node ensuring perfect rotation origin). The laser instantly vaporizes any drop it touches (checking that the drop's state is not `INACTIVE` or `POPPING`).

### The Shop & Economy
Players collect currency to purchase various power-ups. The game includes a robust UI with cards and icons for:
* Time Warp (Slows down time)
* Evaporation (Lowers the flood)
* Tidal Wave (Screen clear)
* Midas Touch (Turns drops to gold)
* Score Boosts & Streak Accelerators
* Toxic Immunity & Juicy Drops

---

## 4. Future Development Roadmap (The "Maximalist" Expansion)

Thanks to the generation of over 100+ new assets stored in the `All_Generated_Game_Assets` folder, the game is primed for a massive expansion. Here are the planned features:

### A. Boss Rounds
Periodically, the flood will halt, and a multi-part Boss entity will emerge. Players must tap specific weak points to defeat them.
* **The Kraken**: A cybernetic squid whose tentacles must be popped before attacking the main eye.
* **The Alien Mothership**: A UFO that uses an abduction tractor beam to pull drops upward or steal player currency.
* **Rogue Purifier Mech**: A heavy machine with laser arms and thrusters.
* **Slime King**: A massive blob with a glowing radioactive core and a melting golden crown.

### B. Advanced Player Defenses & Structures
Players will be able to upgrade their base beyond just the main turret.
* **Missile Batteries**: Turrets that fire homing rockets.
* **Helper Drones**: Small flying companions that auto-tap drops that get too close to the flood line.
* **Buildable Barricades**: Metal walls the player can place to temporarily block drops from hitting the flood (featuring dynamic damage overlays).

### C. Complex Drop Modifiers
* **Clockwork Drops**: Steampunk puzzle orbs that require rhythmic, timed tapping.
* **Swarm Drops**: Alien eggs that, when popped, explode into dozens of tiny, fast-moving droplets.
* **Shielded Drops**: Drops covered in a blue forcefield that require two taps to destroy.
* **Shadow Drops**: Fast, invisible/stealth drops with a subtle purple aura.

### D. Environmental & Weather Events
Random events that alter gameplay for a short duration.
* **Thunderstorms & Acid Rain**: Obscures vision and alters drop physics.
* **Parallax Backgrounds**: Transitioning from a cyberpunk city skyline to a deep space nebula or an ocean abyss as the player survives longer.

### E. Expanded Power-ups (Active & Passive)
* **Orbital Strike**: A massive screen-clearing laser from space.
* **Time Rewind**: An hourglass ability that saves the player from a Game Over by reversing time by 5 seconds.
* **Black Hole**: Sucks all drops into the center of the screen.
* **Freeze Bomb**: Ices over the edges of the screen and halts drop movement.

### F. Deep Customization & Cosmetics
A premium/end-game economy where players can customize their experience.
* **Flood Skins**: Replace the water with molten lava, blood, or falling Matrix code.
* **Drop Hats**: Silly cosmetics (top hats, halos, propeller hats) that randomly spawn on drops.
* **Custom Cursors & Trails**: Magic wands, crosshairs, and rainbow/fire trails for the player's interactions.

---

### Conclusion
Flooddrop is structurally sound, utilizing object pooling, separated logic controllers (`Gameplay.gd` vs `Drop.gd`), and a robust saving/autoloading backend. With the turret physics and laser visuals fully stabilized, the game is now ready to begin integrating the massive library of new visual assets, starting with Boss Rounds, complex UI expansions, and new drop types.
