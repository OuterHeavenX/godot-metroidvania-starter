# Gameplay audit and improvement pass

**Architecture follow-up implemented:** see [ARCHITECTURE.md](ARCHITECTURE.md) for the current state machine, shared combat, builders, save migration and presentation boundaries. The original observations below describe the audit baseline.

Reviewed origin/main at aa20e1c. Work branch: codex/gameplay-improvements.

## What the game actually is

A two-area action-platformer with metroidvania ability gates. Run, variable-height jump, coyote time, wall slide/jump and an invulnerable dash are available immediately. Double jump opens traversal; ground pound breaks stone and dispatches nearby enemies. Checkpoints heal, hearts restore health, and death returns the player to their last spawn while leaving the current area's world state intact. The opening route leads through the Undercroft to the Warden, then into the Sunken Works with shielders and chargers. Progress and best times persist through SaveMan.

Its strongest feature is movement variety. Its weakest design feature is that progression mostly advances through a sequence of gates: there is little route choice, return-path discovery or build experimentation. The data-driven level resources are already a useful foundation; rewriting them would waste good work.

## Three immediate code flaws, fixed

1. **An unintended air jump bypasses the ability contract.** Walking off terrain leaves jumps_used at zero. After coyote time expires, the generic air-jump branch still accepts a jump with no ability. Consume the grounded jump on grace expiry; an unlocked double jump still supplies one recovery jump.
2. **Visible sword activity and damage disagree.** ATTACK_ACTIVE drives animation, but damage previously ran only on the press frame. Resolve targets throughout that window, once per target per swing. A 140ms buffer also accepts slightly early follow-up presses without enabling held-button autofire.
3. **Camera shake fights camera lead.** JuiceMan replaces Camera2D.offset while the player interpolates that same property. JuiceMan now supplies a shake offset and the player composes it with an independently smoothed lead.

## Additional changes delivered

- Death recovery clears buffered jumps/attacks, cooldown state and stale landing state, restores dash availability, and resets camera smoothing.
- Level-defined start positions now also initialize the respawn point.
- Damage interrupts ground pound so its movement branch cannot erase knockback. Nonpositive damage is ignored.
- Descending hits resolve before contact damage even if physics delivers the hurtbox signal first. This matters when a fast pound crosses both hit areas in one tick; the automated boss fight reproduced the failure.
- Warden horizontal scale survives base enemy facing updates.
- Enemy attacks, shots and charge windups show a filling indicator and an exclamation mark. These expose existing timings rather than secretly changing difficulty.
- A proximity-limited boss HUD reports health, phase, guard status and when to evade. It disappears while paused or after the boss dies.
- Running dust now activates at normal running speed; its previous threshold exceeded SPEED.
- Two existing tests accessed nodes before setup or after scene removal. Their lifecycle errors are fixed. The traversal suite now excludes incidental enemy damage and stale buffered inputs so it measures geometry; separate combat suites retain damage.
- tools/verify.py runs suites with isolated save directories, timeouts, success markers and script-error detection. Logs go to build/test-results.

## Top three bold proposals: next design milestones

### 1. Make the world fold back on itself

Turn each new ability into a shortcut home and two optional discoveries. Show an unreachable relic before its movement ability is acquired, then open a return route after acquisition. Use permanent world IDs for opened shortcuts and collected rewards, plus an explored-room map. Begin with one loop connecting the Undercroft back to the opening shaft; test traversal geometry before expanding the map.

Success criterion: players identify somewhere they want to revisit when they acquire an ability. These routes and persistence are proposals, not included in this pass.

### 2. Give the Warden a combat identity

Build around bait, evade, break, punish. Add a directional sweep, a clearly marked ground shockwave to jump, and a committed lunge with a recovery opening. Require ground pound for a special stagger rather than letting ordinary stomps solve the entire mechanic. Keep attacks deterministic and readable; shorten recovery only after players have demonstrated the first phase. The current fight explicitly permits ordinary stomps to break guard, despite older README wording.

This pass adds readable tells and boss feedback. New moves and changed guard rules need encounter playtesting and are not implemented.

### 3. Make mastery optional and rewarding

Add shrine challenges for dash-through attacks, consecutive aerial kills and timed traversal, awarding one of two equipable movement modifiers rather than flat damage inflation. Offer an explicit assist option after repeated deaths: longer telegraphs or extra checkpoint healing. Preserve an unassisted time category instead of silently adjusting ranked runs.

Validate with completion rate, damage sources and replay choice. No automatic difficulty or reward economy is implemented yet.

## Architectural direction — implemented

All five recommendations are now implemented and documented in [ARCHITECTURE.md](ARCHITECTURE.md): explicit player actions, shared combat components, focused level builders, versioned persistent run snapshots and local presentation signals. The larger world/progression proposals above remain design milestones.

## Validation limits

Automated physics suites cover movement, health, saves, transitions, both areas, boss mechanics and an input-driven boss fight. The boss-fight harness teleports into tactical positions: it is useful regression coverage, not proof of human difficulty balance. New combat-contract checks cover ledge recovery, active hits, duplicate-hit prevention, buffering, damage interruption, respawn and camera recovery. A native rendered arena screenshot was inspected for boss HUD placement. Human keyboard/touch playtesting remains necessary before calling this a finished redesign.

Final validation: 17/17 suites passed with Godot 4.7.2; the web export completed without errors. Browser navigation loaded the canvas and captured console errors/warnings were empty, but browser screenshot capture timed out, so full browser playability is not claimed.

The rebuilt docs/ export is prepared locally. Nothing in this pass changes GitHub Pages settings or publishes to main.
