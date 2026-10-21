# Phase W — Release acceptance and Metal Road 1.0.0

## Delivered

- Promoted the project from `1.0.0-rc1` to `1.0.0`.
- Added three isolated player-profile slots with version-7 migration, atomic writes and automatic `.bak` recovery.
- Added a progress hub with lifetime statistics, career completion, medals, bosses and six achievements.
- Added standard gamepad controls (sticks, triggers, A/Y) and a keyboard-rebinding screen; custom keys persist in settings.
- Added 1280×720, 1600×900 and 1920×1080 window presets plus fullscreen selection.
- Added Russian/English localization for the main navigation and settings shell.
- Added release splash configuration, visible version marker and an in-game credits screen.
- Installed official Godot 4.7.2 Linux/Windows export templates and created release presets/builds.

## Acceptance

- `release_v1_smoke.gd`: PASS.
- `release_candidate_smoke.gd`: PASS.
- Settings, career, career gameplay, race finish, survival results, controls and boss/replayability regression tests: PASS.
- Visual review at 1280×720: Main Menu, Settings, Progress and Controls fit without clipping.
- Performance: mean 6.90 ms, p95 6.94 ms, 144.9 mean FPS (target p95 < 16.7 ms).

## Release artifacts

- `build/linux/MetalRoad.x86_64`
- `build/windows/MetalRoad.exe`

## Season 1 roadmap

1. Rust Frontier biome and three new arenas/tracks.
2. Four new class-defining vehicles and upgrade branches.
3. Seasonal rival team and a multi-phase boss.
4. Mines, pulse module, harpoon and armor plate.
5. Branching seasonal career with special conditions and rewards.
6. Weekly challenges, personal records, collection and New Game+.
7. Balance, localization, accessibility, performance and seasonal release polish.
