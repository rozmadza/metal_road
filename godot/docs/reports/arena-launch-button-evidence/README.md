# Arena launch button — evidence

The bug was reproduced in the actual working project, without first importing
that project. Previous v2 checks imported separate copies and missed this state.

- `logs/arena-launch-root-before.log`: unknown WeaponVisualProfile breaks compile.
- `logs/arena-launch-gui-user-final.log`: after explicit preloads, true GUI input
  reaches Start, but four missing `.ctex` cause BonusCache.prepare to fail.
- `import-state.json`: all four missing before / present after; PNGs unchanged.
- `logs/arena-launch-working-import.log`: standard import of the actual project.
- `editor-f5/`: cropped game-window images from editor F5 and native XTest input.
  One complete native route succeeded. The repeat attempt is explicitly not
  counted; other windows changed focus. Unrelated desktop screenshots omitted.
- `fresh/`, `user-final/`, `stale-class/`: final successful Input.parse_input_event
  GUI routes. Mouse click is hit-tested, Enter/Joypad accepted; no pressed.emit()
  or direct launch-handler call. Private profile/settings files are not included.
- `negative/`: visible error, GUI OK, valid retry; intentional missing-scene
  ResourceLoader errors are expected. They are not a positive-run regression.
- `regressions/`: full19/19 and extra5/5 PASS, including Restart100.
- `task-only-source.patch.txt`: four production scripts changed in this task.
- `initial-*`, `preservation.json`: initial dirty tree and preserved v1/v2/art.
- `tested-source-sha256.json`: exact tested production scripts and final tests.
- `*.gd.txt`, `native-x11-input.py.txt`: reproduction sources. Native window IDs
  and desktop coordinates are session-specific; do not blindly replay them.

Final portable GUI command (create the host output directory before Flatpak):

```sh
mkdir -p /tmp/arena-launch-gui
flatpak run --filesystem=/home/andrey/PycharmProjects/metal_road/godot \
  --filesystem=/tmp/arena-launch-gui org.godotengine.Godot --max-fps 60 \
  --path /home/andrey/PycharmProjects/metal_road/godot \
  --script res://tests/arena_launch_gui_smoke.gd -- /tmp/arena-launch-gui
```

Negative test (expected missing-scene ERROR lines):

```sh
mkdir -p /tmp/arena-launch-failure
flatpak run --filesystem=/home/andrey/PycharmProjects/metal_road/godot \
  --filesystem=/tmp/arena-launch-failure org.godotengine.Godot --max-fps 60 \
  --path /home/andrey/PycharmProjects/metal_road/godot \
  --script res://tests/scene_transition_failure_smoke.gd
```

Initial infrastructure FAILs are retained: test variable inference, queued input,
embedded-window coordinate handling, and Space state using Viewport.push_input.
These were corrected in test input, never by changing gameplay to force PASS.
Godot shutdown warnings remain in logs and are not confirmed runtime leaks.
`.gdignore` keeps this documentary evidence outside game resource imports.
