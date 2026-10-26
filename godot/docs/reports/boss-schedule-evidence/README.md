# Survival boss schedule — 2026-10-23

Godot4.7.2 Flatpak; source snapshot is the current dirty working tree, not HEAD alone.
Tests ran in `/tmp/metal-road-deep-cRUfIj`, with independent user directory/profile overrides.

- `schedule-final.log`: schedule1–15, rewards, HUD, draft, riders, Retry/Restart and Career.
- `wave-metrics-{old,new}.json`: controlled10-wave runs, with real AI but frozen durable player, scripted8s/12s combat windows and forced clears/collects. Not natural TTK or a manual balance test.
- `metrics-{old,new}.log`: run completion,0 state errors.
- `navigation-final.log`: group8 FAIL (7/8 arrivals within90 simulated seconds).
- `navigation-repeat.log`: repeated same script PASS (8/8). Do not conceal the first result or call navigation consistently green.
- `schedule-results_navigation_smoke.log`: accelerated-frame threaded scene-load timeout, subsequent Nil error in test.
- `schedule-results-realtime.log`: same UI navigation test with real-time pacing PASS.
- Other `schedule-*.log`: regression tests, including flame and boss/biker integration.
- `boss-schedule-*.png`: rendered GUI completion/draft/boss HUD. Reviewed visually, not manual play.
- `boss_schedule_visual.gd`: staging helper used for those images. Copy into isolated project's tests/ to reproduce; no production dependency.

Headless command (except results_navigation_smoke, which omits fixed-fps):

```sh
flatpak run --filesystem=/tmp/metal-road-deep-cRUfIj org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-deep-cRUfIj --script res://tests/survival_boss_schedule_smoke.gd
```

Metrics: replace script with `res://tests/survival_wave_cycle_metrics.gd`; append `-- --legacy` for old schedule. Seed4217 does not synchronize all private RNGs or instance-id-dependent AI decisions. Profile files are separate for old/new runs. Shutdown ObjectDB/resources warnings remain as previously investigated; these logs do not establish runtime leaks. GUI runner omits headless, uses DISPLAY=:0/RX580/radeonsi.
