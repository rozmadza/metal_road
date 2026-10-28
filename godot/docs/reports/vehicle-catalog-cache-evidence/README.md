# VehicleCatalog cache: воспроизводимые данные

Измерения сделаны 2026-10-26 на Godot 4.7.2 Flatpak, RX 580/radeonsi, i7-10700K, Linux 6.8, окно1280×720. В исходной рабочей папке игровые scripts/resources/scenes не менялись во время измерений; использованы отдельные копии проекта. `before` содержит прежнюю реализацию `LoadoutProfile`, `after` — статический кэш и копию выдаваемого VehicleConfig. `detail-after` дополнительно содержит только таймеры для `catalog.get`, фактического `catalog.resource_load`, `_spawn_bot` и других методов. Графические прогоны сделаны без VSync, без `--fixed-fps` и с `--delta-smoothing disable`.

## Состав

- `raw/*-manifest.json`: контекст запуска, setup/restart events, счётчики scripted kills/repairs, таймеры функций. `raw/*-<phase>.json`: все интервалы реально отрисованных кадров, native мониторы и счётчики объектов.
- `before-4217`/`after-4217`: полный парный сценарий — меню, третье подкрепление, ранний Restart, переход волны2 через принудительные убийства/выбор перка, волна5 с штатным Arbiter/байкерами,60с боя волны4 с бесплатным ремонтом, Restart, повторный вход.
- `before-complete-4217`/`after-complete-4217`: дополнительно проверяет победное состояние волны1 после трёх **принудительных** убийств и Restart, а также точный кадр появления третьего AI. `wave1_window_state` подтверждает неизменное поколение матча и3 активных AI до forced kills.
- `before-104729`/`after-104729`: короткие контрольные прогоны. `after-104729` не дошёл до третьего AI за5.5с wall time (3.48с активного игрового времени); это ограничение явно сохранено, его максимальный кадр не используется как измерение spawn.
- `detail-after-4217`: один реальный `catalog.resource_load` во время первого входа; дальнейшие `catalog.get` — cache hit. Внутренние timings включают измерительную обёртку и применяются для атрибуции, основной FPS взят из неинструментированных парных прогонов.
- `regression/`: stdout тестов. Файлы с `.initial.log` сохраняют первоначальные FAIL/timeout; `controls_baseline_uncapped.log` и `reward_baseline_original.log` подтверждают те же ограничения на исходной версии. `survival_boss_schedule_retry.log` и финальный `survival_boss_schedule_smoke.log` — PASS1–15. `catalog_lifetime_baseline.log` — эксперимент со слабой ссылкой, `restart_memory_100.log` — повторяемая серия100 Restart с RSS, `editor_import.log` — финальная проверка GDScript.
- `regression-suite-summary.log`: последовательный набор18/19 PASS до последней коррекции только `survival_reward_feedback_smoke.gd`. Последняя версия этого теста затем отдельно прошла (`regression/survival_reward_feedback_smoke.log`), остальные18 скриптов не менялись. Это **последние19 успешных результатов**, но не один полностью зелёный повтор всей последовательности.

Важно: первоначальный full-run collector два раза вызывал `restart_measure()` и записывал оба окна под именем `post_restart`. В full-run manifests две записи ссылаются на один, **последний**, JSON кадра. Не считать их двумя независимыми измерениями. Времена обоих Restart отдельно сохранились в `setup_events`; для чистых кадровых данных раннего Restart использовать `before-complete-4217`/`after-complete-4217` (у них разные имена окон). Скрипт `tests/survival_catalog_comparison.gd` впоследствии исправлен и теперь именует Restart окна уникально.

## Метрика

Wall frame interval: `Time.get_ticks_usec()` между `_process`, средний FPS=`1000/mean(frame_ms)`, p95/p99=nearest rank `ceil(q*n)` без исключения пиков. Кадры >16.67/>33.33/>100мс подсчитаны по каждому окну. `Performance.TIME_PROCESS`/`TIME_PHYSICS_PROCESS` — максимумы последней секунды в этом Godot, не покадровые средние. `RENDER_VIDEO_MEM_USED` — оценка выделенной видеопамяти движка, не аппаратный VRAM occupancy; RSS считывался из `/proc/<Godot PID>/status`, если доступен. Первый full-run collector не извлёк RSS, поэтому для межпроцессного сравнения RAM взяты короткие прогоны104729 и отдельный100-Restart тест. Headless измерения не выдаются за графическую производительность.

Начальное построение сцены, `SceneTransition` и первый синхронный load входят в время первого входа. В игровых FPS окнах JSON пишется только после окончания измерения. Частный RNG Arena и фоновые OS/GPU caches не полностью фиксированы, поэтому это сопоставимые сценарии, а не точный идентичный покадровый replay. Нет ручного прохождения или физического gamepad; автопилот использует обычные Input actions и один дополнительный тест input mappings.

## Повторить

Для исходной версии восстановить один старый метод `LoadoutProfile.vehicle_catalog()` (`return load(VEHICLE_CATALOG_PATH) as VehicleCatalog`) в одноразовой копии и прежний `vehicle_config()` без дополнительного `duplicate()`. Для новой версии использовать текущий script. Каждая копия должна иметь отдельные `res://perf-output/` и пользовательские профили.

```sh
DISPLAY=:0 flatpak run --filesystem=/tmp/metal-road-cache-current org.godotengine.Godot \
  --disable-vsync --delta-smoothing disable --max-fps 0 \
  --path /tmp/metal-road-cache-current \
  --script res://tests/survival_catalog_comparison.gd \
  -- id=after-4217 seed=4217
```

Для победного состояния волны1: `quick=1 complete_before_restart=1 wave1_seconds=6`. Для таймеров функций использовать одноразовую инструментированную копию; source `tests/survival_performance_instrumentation.patch.txt` задаёт исходные обёртки, `catalog.resource_load` после исправления измерялся только на cache miss. Инструментированный файл в рабочем игровом дереве не размещён.

Тесты `vehicle_catalog_lifetime_probe.gd`, `vehicle_catalog_cache_smoke.gd`, `vehicle_catalog_restart_memory_smoke.gd` проверяют weakref/cache lifetime, статическую ссылку/защиту12 конфигов и100 Restart. Headless regression список воспроизводится `tests/run_vehicle_catalog_regressions.sh`; для `controls_smoke.gd` использовать `--max-fps 60`, поскольку тест опирается на число render frames при физике60Hz.
