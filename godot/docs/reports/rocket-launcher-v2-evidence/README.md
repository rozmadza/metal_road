# Rocket Launcher v2 — evidence

All game images come from real Godot/OpenGL captures on RX580. Owner-provided
source art was deterministically cropped/resampled/repacked; no new art or
duplicate animation was generated. All four game textures are assigned.

- `asset-preparation.json`: original paths/dimensions/alpha/SHA256; preparation
  anchors, fade values, output sizes, per-frame bounds, unique frame hashes.
- `baseline/`, `current/`: four resolution/zoom captures and two uncapped timings
  per version. Full PNGs from the matrix; manifests retain raw timing samples.
- `acceptance/`: Survival-derived fixtures at each resolution/zoom. Actual
  projectile/hit/restart checks; manual timer poses inspect every atlas frame.
  AI and cars are stopped for repeatability; one extra target is test-only.
- `modes/`: actual Survival/Race/Career with live AI and forced rocket shots.
- `comparison*.png`: crops/labels of real gameplay, native or explicit2x nearest.
- `muzzle-godot-frames.png`, `explosion-godot-frames.png`: real renderer poses.
- `regressions/`: final19-test runner +4 additional tests, all PASS.
- `logs/`: complete outputs, including the initial test-only SHA API parse error.
- `frame-timings.json`, `loading-memory.json`, `rss-samples.json`: raw metrics.
  RSS is host PID sampling; wrappers are retained, never summed as engine RSS.
- `preservation.json`: untouched source art and v1 gameplay/renderer validation.
- `tested-source-sha256.json`: working-tree assets/resources/code match tests.
- `*.txt`: reproducible preparation/capture/measurement scripts, not game code.

Graphical commands (replace variant/output as needed):

```sh
flatpak run --filesystem=/tmp/metal-road-rocket-v2-current org.godotengine.Godot \
  --disable-vsync --delta-smoothing disable --max-fps 60 \
  --path /tmp/metal-road-rocket-v2-current \
  --script res://tests/rocket_v2_capture.gd -- 800 res://rocket-v2-output/800-z1.23/ 1.23
# Omit --max-fps for the independent uncapped timing runs.
flatpak run --filesystem=/tmp/metal-road-rocket-v2-current org.godotengine.Godot \
  --disable-vsync --path /tmp/metal-road-rocket-v2-current \
  --script res://tests/rocket_v2_acceptance.gd -- 1280 1.0
bash tests/run_vehicle_catalog_regressions.sh /tmp/metal-road-rocket-v2-current /tmp/logs
```

Measurement limitations and remaining manual art judgement are in the main
report. Pose sampling is not natural playback; forced shots are not normal fire
rate or a natural wave clear. No images are substituted for manual testing.
`.gdignore` excludes evidence from game imports. No commit/push/merge performed.
