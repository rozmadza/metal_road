# Rocket v3 evidence

All PNG game frames are actual Godot/OpenGL captures. Boards only crop/label those
pixels. Input art and the v2 game PNGs are unchanged; one new derived atlas is
prepared by deterministic resizing/alpha compositing, never runtime generation.

- `before/`, `current/`: matched resolution/zoom captures and raw frame intervals.
- `three-visual-options.png`: compact/medium/near scale+position alternatives.
- `acceptance/`: real ArenaBattle fixture, cluster, late smoke, Restart and48VFX.
  Its manually sampled animation poses are not natural play.
- `homing-results.json`:864 real Vehicle/Bullet collision/damage/TTL scenarios.
  Targets are frozen RigidBodies moved along controlled paths, not AI drivers.
- `homing-same-launch.png`: real rendered heading comparison baseline/A/B.
- `regressions/`: full19/19 +extra5/5; warnings retained.
- `gui/`: actual production Menu→PreRace→match input regression, PASS.
- `logs/`: complete logs, including the initial test dt type error and early
  visual experiments. Final tables use the selected atlas, not that experiment.
- `preserved-art-sha256.json`, `tested-source-sha256.json`: original artwork
  preservation and exact tested production/test bytes.
- `*.txt`: reproducible temporary graphical harnesses and atlas preparation.

Startup scripts and existing procedural renderers are retained. Atlas pixels are
prepared offline into one sheet/event; no second CombatVFX animation is spawned.

Run the full runner and `tests/rocket_homing_v3_smoke.gd` in an imported isolated
copy. Graphical harnesses use 1280/800 and zoom1/1.23; four forced gun instances
are intentionally a fixture, not normal fire-rate/balance measurements. Positive
GUI checks use true event routing, not direct Start-handler invocation.

Frame intervals are not GPU timestamps.60FPS-limited results cannot estimate GPU
headroom. RSS is from real host PIDs, not Flatpak launcher peaks. Separate marker
probes isolate before/after20Restart; they are not used for FPS comparisons.
`.gdignore` excludes all evidence from game imports. No commit/push/merge.
