# AI diagnostic evidence — 2026-10-23

Compatibility note (arena experiment2026-10-26): these measurements refer to1000×800. Current route/diagnostic scripts default to1400×1000; append `-- --old` to the route command, or add `--old` among user arguments after the diagnostic script's `--`, to load the preserved1000×800 fixture and its original route coordinates. Historical logs were not overwritten.

All final tests: isolated `/tmp/metal-road-deep-cRUfIj`, Godot4.7.2, headless/fixed-fps60. Report: [diagnosis](../METAL_ROAD_AI_NAVIGATION_DIAGNOSTICS.md).

## Files

- `ai-baseline-1..20.log`: original unchanged arena_navigation_routes_smoke;17 PASS,3 FAIL.
- `ai-diagnostic-full-1..20.json/log`: original full run with measurement override;16 PASS,4 FAIL. These are NOT the same process runs as baseline.
- `ai-diagnostic-control-{seed}-{pad}-{policy}.json/log`:12 group-only controlled geometry/ID-side runs.
- `ai-diagnostic-repeat-1..3.json/log`: three further4217/native/pad0 repetitions.
- `ai-diagnostic-remove-{seed}.json/log`: arrived cars removed instead of parked (native policy).
- `ai-diagnostic-detail-full-1..5.json/log`: further5 full runs with traffic snapshots (3 PASS,2 FAIL).
- `ai-diagnostic-detail-{park,remove}-{seed}.json/log`: stable policy, paired counterfactual parking.
- `ai-diagnostic-recovery-{seed}.json/log`: request/cancellation counter without changing returned driving commands.
- `ai-diagnostic-destroy-{seed}.json/log`: crate destroyed, NEAREST→EXACT,18-unit physical goal area.
- `ai-diagnostic-pilot.json/log`: initial4217/native pilot, kept separate from20-run statistics.

56 JSON files. Each contains options, wall_seconds, rows and failures. Group diagnostic exits0 after collecting data even if its row.passed=false: **inspect JSON, not the process exit code**, for outcome. Full mode retains original smoke's failure exit code. Expected diagnostic failure is not a GDScript error.

Telemetry full1..20/pilot/control/repeat/native remove was captured before extra traffic fields were added. Detailed/recovery/destruction include traffic_speed_cap, nearby peers/driver_active, point_clear and name. Script revisions changed diagnostic observation only, not production algorithms; ID allocation may still change, hence separate baseline. Fixed geometry controls keep MapProp rotations reproducible. The final checked-in script may not reproduce historical numeric instance_id; compare recorded side/priority/geometry rather than assuming identical IDs.

## Reproduction

Populate a separate project copy including current scripts/tests/imports. Original baseline:

```sh
flatpak run --filesystem=/tmp/metal-road-deep-cRUfIj org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-deep-cRUfIj --script res://tests/arena_navigation_routes_smoke.gd
```

Full telemetry: replace script with `res://tests/ai_navigation_diagnostic.gd`, append `-- mode=full id=your-run-id` (use a new id to avoid overwriting retained evidence).

Group controls: `-- mode=group seed=4217 pad=0 policy=native arrival=park id=your-id`. Seeds4217/104729/8675309; pad0/1; policy native/stable; arrival park/remove. Stable is a **fixture-only controlled side/reaction assignment**, not a shipped fix. Removing arrived cars tests open transit and must not replace parked-blocker stress.

Destruction: `-- mode=destroy seed=4217 id=your-id`. Recovery requests: use `res://tests/ai_navigation_recovery_probe.gd -- mode=group seed=4217 policy=stable id=your-id`.

No timeout increase, production geometry edits, Vehicle/AI/weapon/wave/bonus changes. No manual play or GPU performance conclusion.

## Production SHA256 before/after diagnosis

```text
801e76d24dfce5b152115bff02af0e43239a11f41288f8c96235ed393e16caad  scripts/arena_bot.gd
06d1d18473b0f54cc80fc1e31b54b50a47c602fe8370044195857bb99ad677f4  scripts/arena_navigation.gd
56d1bedb34943e512917fd3f189cd5d5fa69cc68a72d985fa505797442345ada  scripts/arena.gd
3942d6283c2c4c5f1511f670d57a539049033c4d789aefeeedeb3fd7186c72e2  scripts/vehicle.gd
79ef01367b00746fbf7c9085fde9aa048968bef80c0aeb97996579b52a0ef554  resources/default_arena.tres
```
