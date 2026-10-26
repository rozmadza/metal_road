# Survival playability QA — 2026-10-26

Godot4.7.2 Flatpak. All24 final `*smoke.log` files PASS. Main report: [QA](../METAL_ROAD_QA_REPORT.md).

Isolated project `/tmp/metal-road-playability-JY5wXv` has config/name `Metal Road Playability QA` and custom user directory `metal-road-playability-JY5wXv`; test profile/loadout overrides are local to that copy. Do not point smoke tests at personal saves.

```sh
flatpak run --filesystem=/tmp/metal-road-playability-JY5wXv org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-playability-JY5wXv --script res://tests/survival_playability_smoke.gd
```

Other smoke files use the same command, except results_navigation_smoke (omit fixed-fps to allow threaded scene loading real-time). Editor import/parse diagnostic in import.log. The final new smoke checks real5-second reinforcement timing and actual InputEventKey/InputEventJoypadButton, not just direct confirm calls. The game sees joypad device0; no operator hardware button presses were performed. PS square glyph is checked using a supplied controller name; not a real PS controller test.

GUI: `DISPLAY=:0` with no headless flag, script `res://tests/playability_visual.gd`; a copy of this staging helper is included. Images show wave1, E prompt, controller prompt, and a mine under the opaque car roof plus an adjacent visible mine. Automatic scene composition and visual inspection, NOT manual first-wave completion or a balance/TTK evaluation. The helper temporarily freezes AI, equips a weapon, positions offers/mines and changes camera zoom for inspection only.

Known ObjectDB/resources shutdown warnings remain; distinguish them from GDScript/parse errors. Known independent group8 navigation instability was not fixed or reclassified as passing. All results concern the current dirty working copy, not pristine HEAD.

Unchanged production hashes (match prior diagnostics):

```text
3942d6283c2c4c5f1511f670d57a539049033c4d789aefeeedeb3fd7186c72e2 scripts/vehicle.gd
3d5dcc55b028c01d7557bda8518b6f0a74e560f6d92486b1d78d996dce6d325e scripts/vehicle_config.gd
801e76d24dfce5b152115bff02af0e43239a11f41288f8c96235ed393e16caad scripts/arena_bot.gd
06d1d18473b0f54cc80fc1e31b54b50a47c602fe8370044195857bb99ad677f4 scripts/arena_navigation.gd
56d1bedb34943e512917fd3f189cd5d5fa69cc68a72d985fa505797442345ada scripts/arena.gd
79ef01367b00746fbf7c9085fde9aa048968bef80c0aeb97996579b52a0ef554 resources/default_arena.tres
```
