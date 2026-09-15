# Metroidvania Starter

A tight 2D metroidvania starter built in Godot 4.7: run, coyote-time jumps,
wall-jump shaft, dash, ground pound, and a double-jump ability gate.

Play it: https://outerheavenx.github.io/godot-metroidvania-starter/

## Repository layout

```
project.godot            Project settings, input map, autoloads
icon.svg
index.html               Redirect to docs/, only used if Pages serves the root
.nojekyll                Serve files verbatim if Pages serves the root

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
    level.gd             Generic builder: turns an MVLevelData into an area
    level_01.tscn        Main scene (player + HUD + touch controls + data)
    level_01.tres        The area itself, as data
    data/
      level_data.gd      MVLevelData: terrain, actors, bounds, dressing
      enemy_spawn.gd     MVEnemySpawn: position + kind
      orb_spawn.gd       MVOrbSpawn: position + ability + tint
      hint.gd            MVHint: text + position
  pickups/
    orb.gd / orb.tscn     Ability orbs
    heart.gd              Health pickup, script-built like cracked_floor
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
  skeleton_test.gd
  health_test.gd         Hearts, checkpoint healing, full-health refusal
  pause_test.gd          Pause, resume and restart (survives the scene reload)
  undercroft_test.gd     Drives the new region's jumps against real collision
  script_check.gd        Loads every script so a syntax error fails the build
  runners/               Scenes CI launches with --scene

docs/                    Committed web build — this is the live site
tools/recover/           Scripts that rebuilt this source from the exported build
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

`.github/workflows/build.yml` builds and checks the project on GitHub's
runners. It does **not** publish: Pages serves the committed `docs/` folder
straight off the branch, so the build in `docs/` is the live site.

| Trigger              | What runs                    |
| -------------------- | ---------------------------- |
| Push to `main`       | Build and verify             |
| Pull request         | Build and verify             |
| Manual (Actions tab) | Build and verify             |

Until the project source is pushed there is nothing to export, so the workflow
reports a skip and passes rather than failing. A repo containing `src/` but no
`project.godot` is treated as an error, not a skip.

The job:

1. Installs Godot 4.7.2 and the web export templates, cached between runs.
2. Loads every script inside the running project, so a syntax error fails the
   build. This needs doing properly: `godot --export-release` exits 0 on a
   broken script, and `--check-only --script` cannot resolve `class_name` or
   autoload references file-by-file.
3. Runs every suite in `tests/runners/`.
4. Exports the `Web` preset and checks the output is non-empty.
5. Checks `docs/` matches that fresh export, so the published game can never
   silently lag the source.

To move to a newer engine, change `GODOT_VERSION` at the top of the workflow.
The preset name is `EXPORT_PRESET` in the same block.

### export_presets.cfg must be committed

CI reads the `Web` preset from it. It is deliberately not gitignored — keep
signing keys and passwords out of it.

The preset sets `exclude_filter="docs/*,tests/*"`, and `docs/.gdignore` keeps
Godot's importer out of the build folder entirely. Both matter:

- The build output lives inside the project. Without excluding it, Godot
  imports the previous build's own icons and packs them into the next build,
  so the export depends on its own prior output instead of only on the source.
- Test runner scenes re-resolve their references on each import, which made the
  `.pck` differ between two clean builds of identical source. Players do not
  need the tests anyway, and dropping them makes the export byte-reproducible —
  which is what lets CI compare `docs/` against a fresh build.

It also sets `variant/thread_support=false`. A threaded web build needs
cross-origin isolation headers, which GitHub Pages cannot send, so a threaded
build will not boot there.

### Pages configuration

Settings → Pages → Build and deployment → Source: **Deploy from a branch**,
Branch: **`main`**, Folder: **`/docs`**.

The folder matters. With Folder set to **`/ (root)`** there is no `index.html`
at the top of the repo, so Jekyll renders `README.md` and you get this page
instead of the game. As a safety net the root carries a small `index.html`
that forwards to `docs/`, plus a `.nojekyll` so Pages serves files verbatim —
so the published URL works under either setting. With Folder set to `/docs`
neither of those root files is served at all.

### Updating the published game

`docs/` is the live site, so a source change is not published until the build
is rebuilt and committed. CI fails if they drift apart.

```
godot --headless --import .
godot --headless --export-release Web build/web/index.html
cp build/web/* docs/
```

The export is byte-reproducible, so rebuilding with no source change produces
no diff.

## Camera framing

The camera lives on the player (`src/player/player.tscn`) at `zoom = 1.4`, with
position smoothing and a horizontal drag margin already set.

Stretch is `canvas_items` with aspect `expand` and no explicit viewport size, so
the base is Godot's default 1152x648. On anything 16:9 or wider the height stays
648 canvas units and the width grows with the aspect; on narrower windows the
width holds at 1152 and the height grows. So at zoom 1.4:

- vertical view is 463 world px, putting the 44px character at ~9.5% of screen
  height, which is the usual range for a 2D platformer;
- horizontal view is at least 823 world px, so half-width is at least 411px.

The camera also leads by `CAM_LOOKAHEAD` (60px) in the facing direction. That
is not only feel: the drag margin makes the camera *trail* the player by about
62px, showing where you have been rather than where you are going. Leading by
roughly the same distance re-centres the view, which widens the worst-case
sightline from 349px to about 409px — so the lookahead buys headroom for enemy
reach rather than spending it.

That half-width is the constraint on enemy reach. An archer's `shoot_range`
must stay inside it or arrows arrive from off screen — with the camera's drag
margin letting the player sit off-centre, the usable budget is about 350px,
which is why `shoot_range` is 340. **Raising the zoom means lowering that
range.** `tools/recover/jumpsim.py` has nothing to say here; the numbers above
are just viewport arithmetic, but they are easy to get wrong by eye.

## Health, pause and restart

Health only ever went down: `respawn()` restored it, so dying was the only way
to heal. Over a level this long that does not hold up, so:

- reaching a **checkpoint** restores health as well as setting the spawn point;
- **hearts** (`HEARTS` in the level) restore one point each, and refuse to be
  picked up at full health so they stay on the ground until they are worth
  taking.

`Esc` or the PAUSE button pauses the run; reaching the goal pauses it too and
offers PLAY AGAIN. Both panels live on a child `CanvasLayer` at layer 20
because the on-screen touch controls sit at layer 10 and would otherwise render
over them, and the touch controls are hidden while a panel is up rather than
left tappable underneath. The HUD runs with `process_mode = ALWAYS` so its
buttons still work while the tree is paused — and so do the test runners, which
would otherwise freeze the moment a test reaches the goal.

## Level layout

An area is a **resource**, not code. `src/levels/level.gd` is a generic builder
that turns an `MVLevelData` into terrain, actors, camera bounds and signs;
`src/levels/level_01.tres` is the area itself. A level scene is just a player,
a HUD, the touch controls, and a `data` resource.

So a new area is a new `.tres` — editable in Godot's inspector, and a readable
text diff — rather than new GDScript. The fields are grouped: Terrain
(`platforms`, `cracked`), Actors (`player_start`, `enemies`, `orbs`,
`checkpoints`, `hearts`, `goal_position`), Bounds (`camera_limits`, `kill_y`)
and Dressing (`hints`, `background_span`).

The run goes: opening ground, the wall-jump shaft, the double-jump orb, the
gated chamber, the ground-pound orb, and then the cracked span that drops you
into **the Undercroft** — a second half gated behind ground pound, running east
from the vault basement through a tunnel, a pit jump, a wall-jump chimney, a
climb over floating ledges, and a final cracked span above the goal vault.

`tools/recover/jumpsim.py` simulates the player's exact `_physics_process` arc.
Use it before placing a ledge: it reports how far a platform can sit for a
given rise, which is what the numbers below mean.

| rise | single jump | double jump | double + dash |
| ---- | ----------- | ----------- | ------------- |
| 0px | 286px | 481px | 546px |
| 120px | 221px | 442px | 503px |
| 240px | out of reach | 386px | 429px |
| 295px | out of reach | 321px | out of reach |

A single jump peaks at 157px, a double at 298px. Every hop in the Undercroft
sits at or under 70% of the available reach, and `tests/undercroft_test.gd`
re-checks each one against real collision rather than trusting the arithmetic.

## Provenance of this source

The repository previously contained only the exported web build. The source
here was reconstructed from `docs/index.pck` with the scripts in
`tools/recover/`, and verified three ways:

1. Every `.gd` recompiles to a **token stream identical** to the `.gdc` in the
   shipped pack, so the code is semantically the original.
2. The rebuilt project exports an `index.js`, `index.wasm` and both audio
   worklets that are **byte-identical** to the published build.
3. The game's own four test suites pass (81 assertions).

What did not survive: **comments and original formatting**, which the exported
token stream does not carry. If you still have the original project, prefer it
over this reconstruction and treat this as a fallback.

Audio is stored as `assets/audio/*.res` rather than `.wav`. The exported pack
only contained Godot's QOA-compressed streams; saving them as resources keeps
them bit-exact, where decoding back to WAV would have altered them. Dropping
the original `.wav` files in and pointing `AUDIO_DIR` back at them is a safe
swap if you have them.
