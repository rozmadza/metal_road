# Metal Road 1.0.0 — release checklist

## Content

- Nine authored career events, including two three-phase boss duels and the three-event Rust Frontier chapter.
- Deterministic daily contract with once-per-day reward and best-time record.
- Race, elimination, bonus hunt, two arena survival locations, championship and boss duel.
- Four vehicle classes, eight vehicles, seven temporary weapons and four biomes.

## Player experience

- First-run contextual tutorial and persistent completion state.
- Pause menu in race and arena: continue, restart and return to menu.
- Assisted, standard and hardcore balance presets.
- Adjustable screen shake; reduced flashes; high-contrast feedback; optional tutorial.
- Separate music, effects, engine and master volume controls.
- Keyboard rebinding and standard gamepad support.
- Three independent profile slots with automatic backup recovery.
- Progress, lifetime statistics and six achievements.
- Russian/English main interface and three validated display resolutions.

## Release gates

- Run `release_candidate_smoke.gd` and the full gameplay regression suite.
- Run `sprint_performance.gd`; target p95 below 16.7 ms at 1280×720.
- Window-review Main Menu, Settings, Career, PreRace, Race, Arena and results.
- Verify a clean profile migration from save version 6 to 7.
- Build Linux and Windows presets from `export_presets.cfg` when export templates are installed.
