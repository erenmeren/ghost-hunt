# 👻 Ghost Hunt

**Reverse Pac-Man.** This time you are the ghost. Pac-Man plays by himself: he tries to clear the pellets and runs from you. Your job is to catch him.

Built with Flutter. One codebase runs on **web, iOS and Android**.

▶️ **Play in your browser:** https://erenmeren.github.io/ghost-hunt/

| Easy (2D) | Hard (3D) | Hell, mid-jump |
|---|---|---|
| ![Easy](docs/easy.png) | ![Hard](docs/hard.png) | ![Hell](docs/hell-jump.png) |

## Modes

| Mode | View | What helps you |
|------|------|----------------|
| **Easy** | Classic top-down 2D | Everything is on screen. After a power pellet, Pac-Man chases you. |
| **Hard** | First-person 3D, through the ghost's eyes | A yellow beam of light rises from Pac-Man above the walls. It pulses faster and brighter as he eats, like a heartbeat. A "waka" sound changes with his direction and distance. A toggleable map in the bottom-right shows the trail of eaten pellets. No direction arrow. |
| **Hell** | 3D, red, dark, flickering light | No visual hints; the map shows only the walls and you. Sound only, and you can **jump** to look over the walls. |

- Pac-Man starts with 3 lives. If you and the other ghosts take them all, you win. If Pac-Man clears the pellets, he wins.
- Each win takes you to the next level. Every level, Pac-Man gets faster and smarter.
- The other three ghosts are in the game too, each chasing Pac-Man with its own personality.

The **How to play** screen in the main menu explains all of this inside the game.

## Coins, shop and packs

Coins exist only inside the game. Nothing is sold for real money.

- **Earning:** catch Pac-Man yourself for 20–40 🪙 (the sooner, the more). A teammate's catch gives you 5 🪙. Clearing a level gives a bonus.
- **Mode multiplier:** Easy ×1, Hard ×2, Hell ×4. New players start with 150 🪙.
- **Saving:** coins and purchases are stored on the device (in the browser's localStorage on the web).

| Pack | Price | Effect |
|---|---|---|
| ⚡ Speed pack | 60 | Move 40% faster for 5 seconds |
| 👻 Invisibility | 120 | For 5 seconds Pac-Man can't see you or run from you |
| 🧱 Wall pass | 150 | Pass through inner walls for 3 seconds |
| 📡 Sonar | 90 | See Pac-Man's light and his spot on the map for 2 seconds (Hard/Hell) |

There are also permanent upgrades, 3 levels each: 🏃 Base speed, 👂 Sharp ears (hear Pac-Man from farther away), 🎒 Big bag (one more pack per level). By default you can use up to 2 packs per level.

## Controls

| | Keyboard | Phone |
|---|---|---|
| Turn (at the next junction) | ← → | Swipe left/right or the turn buttons |
| Turn back | ↓ | Swipe down or the ↶ button |
| Jump (Hell) | Space | ⏫ button |
| Use a pack | 1–4 | Pack buttons on the left |
| Show/hide map | M | Button in the bottom-right |
| Pause | P / Esc | ⏸ |

## Running it

Requires [Flutter](https://docs.flutter.dev/get-started/install) 3.x.

```bash
flutter pub get
flutter run -d chrome          # web
flutter run                    # connected phone or simulator
flutter test                   # tests
flutter build web              # static site in build/web
```

On the web you can skip the menu and jump straight into a mode: `?mode=easy|hard|hell&level=2`.
If the 3D view stutters, `?renderer=ray` switches to the lighter fallback renderer.

Sound effects are synthesized from code: `python3 tool/gen_sounds.py` writes them to `assets/sounds/`.

Every push to `main` runs the tests and deploys the web build to GitHub Pages (`.github/workflows/pages.yml`).

## How it works

- **Pac-Man's AI** (`lib/game/pacman_ai.dart`): searches for paths to the nearest pellets and builds a danger map of where the ghosts can reach. At higher levels he looks further ahead and makes fewer mistakes. After a power pellet he switches roles and hunts you.
- **3D view** (`shaders/scene.frag`): no game engine. The maze is written into a tiny texture, and a fragment shader on the GPU casts a ray for every pixel. Pac-Man is the only light source and casts shadows on the walls. When you jump, the camera rises above the walls.
- **Fallback renderer** (`lib/ui/raycast_painter.dart`): a classic Wolfenstein-style raycaster for environments without shader support.

```
lib/
  game/      game logic: maze, movement, Pac-Man AI, economy (Flutter-independent, testable)
  ui/        2D painter, 3D shader scene, raycaster, minimap, game, shop and how-to-play screens
  audio/     sound effects
shaders/     3D scene (GLSL)
test/        game logic, economy, widget and rendering tests
tool/        sound generator
```

## Roadmap

- [ ] Flight pack
- [ ] Angled top-down 3D view for Easy
- [ ] Visual style overhaul (character models, textures, menu)
- [ ] Performance testing on real phones, App Store / Play Store builds

## License

[Apache License 2.0](LICENSE)
