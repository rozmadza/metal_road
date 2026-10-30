# Rocket Visual v1 evidence

All images are actual Godot graphical captures; no final art was generated.
The comparison is **baseline vs integration with legacy fallback**, not an
implemented artistic Variant A comparison. The approved concept remains intact.

- `baseline/` and `current/`: manifests for three independent processes each;
  full PNGs for the first1280×720 and800×600 runs (32 total).
- `comparison-native.png`: original pixels, same scale, labels/cropping only.
- `modes/`: actual Survival, Race, Career and Restart graphical shots + manifest.
- `capture-harness.gd.txt` and `modes-harness.gd.txt`: reproducible harnesses,
  run as `.gd` only in isolated project copies; not production scenes.
- `initial-regressions/`, `final-regressions/`, `logs/`: full logs, including
  original warning/compile-failure diagnostics, not only successful reruns.
- `frame-timing-summary.json`: summary; manifests retain raw frame intervals.
- `workspace-check.json`: original tracked-file/concept preservation check.
- `tested-source-sha256.json`: final tested sources match the working tree.
- `source-diff.patch.txt`: tracked-source diff; `added-source/*.txt`: new source.

Commands (substitute isolated project path and harness output):

```sh
flatpak run --filesystem=/tmp/metal-road-rocket-v1-current org.godotengine.Godot \
  --disable-vsync --delta-smoothing disable --max-fps 60 \
  --path /tmp/metal-road-rocket-v1-current \
  --script res://tests/rocket_visual_capture.gd -- 1280 res://rocket-visual-output/run/
bash tests/run_vehicle_catalog_regressions.sh /tmp/metal-road-rocket-v1-current /tmp/logs
```

Graphics timing is a six-second fixture with a60FPS limiter, not GPU timestamps,
not a full-match benchmark, and not the cost of yet-absent final textures.
Scene/vehicle positioning, direct weapon grants/shots and a temporary wall are
measurement fixtures. Multi-mode shots run real AI; neither test is manual play.
`.gdignore` keeps all documentary media outside Godot game resource imports.
