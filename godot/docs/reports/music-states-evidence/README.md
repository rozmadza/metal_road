# Music states evidence — 2026-10-28

See [implementation and QA report](../METAL_ROAD_MUSIC_STATES.md).

- `*_smoke.log`: 15 headless regression results and graphical music smoke.
- `editor-import.log`: successful import with native OGG looping.
- `graphical.log`: GPU information and actual loop playback positions.
- `01`–`07` PNG: scripted graphical menu/Garage/Survival/boss/pause/restart captures.
- `*-boundary.wav`: PCM16 recordings from Godot's Music Bus across the three loop boundaries, with the final state-specific gains.
- `boundary-analysis.json`: measured PCM peaks, clipping count and zero 10-ms windows. Rebuild using `python3 tests/analyze_music_boundaries.py`.
- `full-loop.log`: separate natural full Menu cycle, with no seek near its end. The large full recording is kept at `/tmp/metal-road-music-full-loop.wav` rather than added to the repository; the report retains its numeric analysis.

These are automated graphical and audio-graph captures. Subjective listening and final loudness acceptance remain separate. Several existing smoke scripts emit ObjectDB/resources warnings at process shutdown; logs retain them.
