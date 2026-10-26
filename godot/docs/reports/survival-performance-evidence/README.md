# Survival performance audit — 2026-10-26

Все кадровые измерения получены в реальном графическом Godot4.7.2, X11/OpenGL Compatibility, RX580/radeonsi. Headless не использовался как источник FPS/GPU/tempo. Рабочие scripts/resources/scenes не менялись: их равенство исходной QA-копии проверено diff.

## Данные

- raw/stock-4217 и stock-104729: два полных сценарных прогона без инструментирования игровых функций; collector v1. Счётчики AI/снарядов/VFX тогда снимались каждые100ms; пики снарядов — нижняя оценка из сэмплов.
- raw/sustain-4217:18s на каждой из волн1–4 с бесплатным полным ремонтом игрока каждые0.25s. Это контролируемая нагрузка, не баланс/естественное прохождение. Collector v2: снаряды/VFX каждую отрисовку, AI/nodes каждые100ms.
- raw/vsync-4217: тот же controlled sustain с обычным VSync. Остальные прогоны — --disable-vsync --max-fps0. Эти режимы сравнивают ограниченный FPS и запас производительности, не разные игровые настройки баланса.
- raw/observe-{4217,104729,8675309}: программный игрок без ремонта, грантов и принудительных убийств; метрики контакта/урона/паузы. Это не ручное прохождение. Старые natural-* с collector v1 сохранены как дополнительные наблюдения.
- raw/detail-4217: полная инструментированная копия. function_times_us — inclusive timers; slow_events — отдельные grid/detour и вызовы≥5ms. Родительские/дочерние времена нельзя складывать.
- raw/menu-stock и menu-detail: проверка через Main Menu → PreRaceSetup → Survival с настоящими SceneTransition и программной отправкой кнопок. Подтверждает, что spawn-пик не создан прямым запуском ArenaBattle.
- raw/range-stock и range-detail:8 неподвижных машин + игрок, штатные дробовики, штатные ограничения магазина/темпа/снарядов; AI отключены только в этом отдельном стенде, physics не отключается. Фиксированные позиции/начальные скорости задаются до окна измерения. Вместе с80 запросами VFX каждые0.5s это изолирует оружие/VFX от навигации. Отдельный eight_ai сохраняет реально работающие контроллеры.
- analysis/summary.json, windows.csv: воспроизводимая сводка; raw содержит все кадровые массивы и manifests, logs — stdout/предупреждения, captures — графические кадры.
- pilot/: короткий smoke collector со scale=.03; в итоговые статистики не включается.

JSON содержит schema fields в manifest, timestamp_us, интервалы кадров, native monitor values, CPU/GPU viewport timers, draw calls/physics counters, AI/projectile/CombatVFX/node counts, impact/damage signals, HP/скорость/perks и время собственного probe. Собственные дым/огонь VehicleEffects не входят в CombatVFX event count; их стоимость присутствует в реальном рендере.

## Правила измерения

Фактические интервалы между вызовами _process измеряются Time.get_ticks_usec(). Средний FPS =1000/mean(frame_ms), p95/p99 — nearest-rank ceil(q*N), без отсечения медленных кадров. Максимумы и количество кадров>16.67/33.33/100ms приводятся отдельно. Синхронные setup/forced wave selection и запись JSON лежат вне окон; все raw JSON записываются после окончания измерений. Внутриигровые появления, поставки, столкновения и нагрев ресурса в активном окне не исключаются.

Performance.TIME_PROCESS/PHYSICS_PROCESS в этой версии — **максимумы за последнюю секунду**, обновляемые примерно1Hz. Это установлено по исходнику того же commit ed1daf0bf001b61586d9930840f2f1394092c079: [Main::iteration](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/main/main.cpp#L4743). Их нельзя усреднять по render frames как отдельные CPU samples. В сводке peak after2s исключает старое setup-окно. У коротких окон этот показатель может отсутствовать. TIME_NAVIGATION_PROCESS NavigationServer не измеряет GDScript AStarGrid2D.

RenderingServer.viewport_set_measure_render_time включает штатные CPU/GPU viewport queries. Это время рендера viewport, не загрузка всей видеокарты в процентах и не полное время приложения. Frame intervals получены независимо от этих queries. Коллектор и GPU queries имеют собственную стоимость; probe_us показывает только непосредственно измеренную часть работы collector. Инструментированные данные используются для атрибуции, основной FPS — из stock/sustain без wrappers.

Фоновые приложения/композитор не изолировались, OS file cache/GPU driver cache не очищались. Это debug Godot editor executable с текущими исходниками, не экспортированный release binary. Результаты не являются универсальным пределом всех ПК.

## Воспроизведение

Создать одноразовую копию проекта с отдельным custom_user_dir. В этой сессии baseline: /tmp/metal-road-perf-zjKfDD; detailed: /tmp/metal-road-perf-detail-kL96qz. Файлы профиля тестовые, не пользовательские. Стандартная сложность1, Raider100HP без купленных апгрейдов. Arena1400×1000, viewport/window1280×720, physics60Hz, time_scale1, игровой zoom прежний.

```sh
DISPLAY=:0 flatpak run --filesystem=/tmp/metal-road-perf-zjKfDD org.godotengine.Godot --disable-vsync --delta-smoothing disable --max-fps 0 --path /tmp/metal-road-perf-zjKfDD --script res://tests/survival_performance_audit.gd -- id=stock-4217 seed=4217 shots=1
```

Другие варианты: mode=sustain, mode=natural, mode=menu_entry, mode=firing_range. Для VSync убрать --disable-vsync. Для ручного наблюдения доступно mode=natural pilot=0 — автоматика перестаёт подавать управление; такой ручной прогон в аудите не выполнялся. scale используется только для pilot smoke; полный аудит scale1. Никогда не добавлять --fixed-fps: он отключает синхронизацию с реальным временем.

Для detailed timings только в одноразовой копии применить tests/survival_performance_instrumentation.patch.txt, заменив <ROOT> абсолютным путём копии, и передать instrumented=1. Патч добавляет таймеры, переименовывает исходные тела в _audit_original_* и вызывает их с теми же аргументами. Код решения/физики не меняется. Рабочую игровую папку этим патчем не изменять.

```sh
python3 tests/analyze_survival_performance.py /tmp/metal-road-perf-zjKfDD/perf-output /tmp/metal-road-perf-detail-kL96qz/perf-output --output /tmp/metal-road-perf-zjKfDD/analysis
```

Seed контролирует global RNG и bonus RNG; private RNG Arena сохраняет штатное поведение, поэтому повороты props между процессами не полностью совпадают. Это ограничение парного сравнения instrumentation overhead; добавлять deterministic production hooks в рамках аудита не стали.

## Контроль вмешательства

wave2/3/4 создавались прямым start_round(w) на новой сцене и без заработанных перков: это snapshots состава волн, не прохождение предыдущих. Инициализация каждой сцены сначала штатно создаёт wave1, поэтому scene_build этих fixtures включает лишнюю начальную пару; её стоимость не выдаётся за обычный переход волн.

На wave5 три обычных врага уничтожены скриптом до измерения boss-entry; manifest.scripted_kills=3. Босс создан штатно, байкеры вышли по штатному10s таймеру. Награды от forced kills и0 перков не считаются естественным прогрессом. Во всех стресс-окнах с repair_fixture проводился бесплатный полный ремонт каждые0.25s; он не увеличивает repair_pickups и явно посчитан как scripted_repairs.

eight_ai — искусственные8 штатных ArenaBot вместо стартовой волны; правила обычных волн не менялись. collision_burst — те же машины с начальной скоростью160 к центру, далее настоящие управление/контакты. fire_vfx_burst — выданные стендом штатные пулемёты +80 синтетических VFX requests/.5s; лимит48 не менялся. endurance —60s настоящей активности wave4 с периодическим бесплатным ремонтом, затем настоящий deferred Retry/Restart. Это измерения нагрузки, не оценка выживаемости или длительности честного матча.

Предупреждения ObjectDB/resources при выходе сохранены; по ним runtime leak не объявляется. Все интерпретации, подтверждённые проблемы и рекомендации — в основном отчёте.
