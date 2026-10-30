# Destroyed Vehicle Wrecks v1: evidence

Baseline is the accepted dirty working snapshot including Rocket v3, Ballistic v1 and Driving/Wave Recovery; it is not plain Git HEAD9591463. No user art or mechanics from those tasks were discarded.

before-1280 contains a real GUI-launched Survival weapon kill and pass-through. final-1280/final-800 contain GUI launch, real Heavy MG kill, physical contacts/push/rotation, native ArenaBot pursuit, Restart, menu exit and re-entry. Scripts grant the weapon and arrange controlled positions; this is not manual play or a natural pickup/run. Native screenshots retain original viewport pixels. Boards only tile screenshots.

regressions-complete is the final19-test runner. Earlier runner directories are retained. extra contains17 additional regression logs. lifecycle-accepted, physics, combat-nav-final-all-weapons and AI-production-final are the independent new checks. AI fixed-fps60 runs use real physical Vehicle movement at a fixed simulated timestep, not graphical FPS measurements.

AI-extended-ttl-FAIL is the additional diagnostic with120s cover lifetime. It must not be confused with the production25s lifecycle tests or omitted from QA. Any margin experiments are isolated counterfactuals unless the main report explicitly states they were adopted.

performance-final/performance-before and wreck-perf/perf-before.json record real OpenGL cold/warm8s phases with8AI and5forced deaths; data also include20Restart counters. Initial cold monitor values may include scene setup and stale repeated physics-monitor readings. These do not provide GPU timestamps or hardware load percentages.

All source PNG/config references remain shared. preserved-sha256.json checks unchanged accepted subsystems against the initial snapshot. .gdignore excludes evidence fixtures/artifacts from production imports. Existing ObjectDB/resources shutdown warnings are retained, not reclassified as proven runtime leaks.

Headless reproduction in a clean copy of the current accepted working tree:

```bash
bash tests/run_vehicle_catalog_regressions.sh /absolute/project /absolute/logs
flatpak run --filesystem=/absolute/project org.godotengine.Godot --headless --path /absolute/project --script res://tests/destroyed_wrecks_lifecycle_smoke.gd
flatpak run --filesystem=/absolute/project org.godotengine.Godot --headless --path /absolute/project --script res://tests/destroyed_wrecks_physics_smoke.gd
flatpak run --filesystem=/absolute/project org.godotengine.Godot --headless --path /absolute/project --script res://tests/destroyed_wrecks_combat_navigation_smoke.gd
flatpak run --filesystem=/absolute/project org.godotengine.Godot --headless --fixed-fps 60 --path /absolute/project --script res://tests/destroyed_wrecks_ai_smoke.gd
```

Use `-- --extended-ttl` for the120s-cover diagnostic. The graphical fixtures are preserved here with .gd.txt extensions; execute copies under tests/ in an isolated project, with an existing writable output directory exported to Flatpak.
