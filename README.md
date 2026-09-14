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

docs/                    Legacy committed build; removable once CI deploys
.github/workflows/       Export and deploy to GitHub Pages
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

## Continuous integration

`.github/workflows/deploy.yml` builds the web export on GitHub's runners and
publishes it to Pages. Builds no longer need to be committed.

| Trigger              | What runs                          |
| -------------------- | ---------------------------------- |
| Push to `main`       | Export, then deploy to Pages       |
| Pull request         | Export only — verifies, publishes nothing |
| Manual (Actions tab) | Export, then deploy                |

Until the project source is pushed there is nothing to export, so the workflow
reports a skip and passes rather than failing. The deploy step is skipped in
that case too — publishing an empty artifact would blank the live site. A repo
containing `src/` but no `project.godot` is treated as an error, not a skip.

The export job:

1. Installs Godot 4.7.2 and the web export templates, cached between runs.
2. Parses every `.gd` file under `src/` and `tests/` with `--check-only`,
   failing on a syntax error.
3. Checks `export_presets.cfg` contains a preset named `Web`.
4. Runs `godot --headless --import .` then
   `godot --headless --export-release Web build/web/index.html`.
5. Verifies `index.html`, `index.js`, `index.wasm` and `index.pck` are non-empty
   before uploading.

To move to a newer engine, change `GODOT_VERSION` at the top of the workflow.
The preset name is `EXPORT_PRESET` in the same block.

### export_presets.cfg must be committed

CI reads the `Web` preset from it. It is deliberately not gitignored — keep
signing keys and passwords out of it.

### Pages configuration

Settings → Pages → Build and deployment → Source: **GitHub Actions**.

Once the first Actions deploy succeeds, the tracked `docs/` folder is no longer
serving anything and can be deleted — CI rebuilds the game from source on every
push to `main`.

## Exporting locally

Open the project in Godot 4.7 or later and export the `Web` preset to any path.
There is no need to commit the result.

## Adding the project source

Only the web build has been committed so far. To add the Godot project itself,
copy these from your local project folder into the repo root and commit:

```
project.godot
export_presets.cfg       needed by CI to build the Web export
icon.svg
icon.svg.import
src/
assets/
tests/
```

Do not copy `.godot/` — it is editor cache, it is gitignored, and Godot
regenerates it the first time the project is opened.

Once that lands on `main`, the Actions workflow takes over building and
publishing the game.
