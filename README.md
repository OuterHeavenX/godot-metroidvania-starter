# Metroidvania Starter

A tight 2D metroidvania starter built in Godot 4.7: run, coyote-time jumps,
wall-jump shaft, dash, ground pound, and a double-jump ability gate.

Play it: https://outerheavenx.github.io/godot-metroidvania-starter/

## Repository layout

```
project.godot            Project settings, input map, autoloads
icon.svg

src/                     All game code, one folder per feature
  audio/
    audio_man.gd         Autoload: AudioMan
  juice/
    juice_man.gd         Autoload: JuiceMan (screen shake, hitstop)
  player/
    player.gd            Movement, jump/dash/pound state
    player_visual.gd     Sprite + animation driving
    player.tscn
  enemies/
    walker.gd
    walker_visual.gd
    walker.tscn
  levels/
    level_01.gd          Main scene
    level_01.tscn
  pickups/
    orb.gd / orb.tscn
  checkpoint/
    checkpoint.gd / checkpoint.tscn
  goal/
    goal.gd / goal.tscn
  world/
    cracked_floor.gd     Ground-pound breakable
  ui/
    hud.gd / hud.tscn
    hearts_bar.gd
    touch_controls.gd / touch_controls.tscn
    float_joystick.gd

assets/
  audio/                 Sound effects and music loop (.wav)
  sprites/hero/          Idle, Run, Jump, Fall, Attack1/2, Death, Take Hit

tests/
  hero_test.gd           Movement and ability checks
  polish_test.gd
  pound_test.gd
  shot_test.gd

docs/                    Published web build (GitHub Pages source)
```

## Autoloads

| Name     | Script                    |
| -------- | ------------------------- |
| AudioMan | `src/audio/audio_man.gd`  |
| JuiceMan | `src/juice/juice_man.gd`  |

Main scene: `src/levels/level_01.tscn`

## Input map

`move_left`, `move_right`, `jump`, `dash`, `attack`, `pound` — each bound to two
keys. Touch input is emulated from mouse and vice versa, so the on-screen
controls in `src/ui/touch_controls.tscn` work on desktop too.

## Running locally

Open the project folder in Godot 4.7 or later and press F5. The renderer is
GL Compatibility, stretch mode `canvas_items` with `expand` aspect.

## Publishing a web build

The web export preset writes into `docs/`, which GitHub Pages serves. Export
with the filename `index.html` so the output matches the tracked filenames:

```
docs/index.html
docs/index.js
docs/index.wasm
docs/index.pck
docs/index.png            splash
docs/index.icon.png
docs/index.apple-touch-icon.png
docs/index.audio.worklet.js
docs/index.audio.position.worklet.js
docs/.nojekyll            keeps Pages from running Jekyll over the build
```

Commit the whole `docs/` folder — Pages serves it directly, there is no build
step on GitHub's side.

### Pages configuration

Settings → Pages → Build and deployment → Source: *Deploy from a branch*,
Branch: `main`, Folder: **`/docs`**.

## Adding the project source

Only the web build has been committed so far. To add the Godot project itself,
copy these from your local project folder into the repo root and commit:

```
project.godot
icon.svg
icon.svg.import
src/
assets/
tests/
```

Do not copy `.godot/` — it is editor cache, it is gitignored, and Godot
regenerates it the first time the project is opened.
