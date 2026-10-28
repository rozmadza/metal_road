# Metal Road — QA-отчёт

## Устранение холодных загрузок BonusPickup — 2026-10-28

[Отчёт с архитектурой, графическими таблицами и ограничениями](METAL_ROAD_BONUS_PICKUP_CACHE_FIX.md), [первичные данные](bonus-pickup-cache-evidence/README.md). Семь штатных WeaponConfig подготовлены однократно под loading overlay и удерживаются общей сильной ссылкой; Race и Survival используют одни ресурсы. В новом полном графическом Survival 25 обращений за WeaponConfig занимали 1–3 мкс каждое; исходные холодные обращения достигали 25.021 мс. Два неинструментированных VSync-повтора первых поставок: max кадра до 49.029/48.679 мс, после 25.448/25.522 мс. Вход в матч стал дольше примерно на 0.08–0.11 с, что измерено отдельно и не скрывается как выигрыш FPS. Раздельный профиль памяти с уже действующим VehicleCatalog: после 10 Restart nodes/resources/video оставались 206/191/365.73 МиБ; после пяти menu reentry 206/208/382.61 МиБ, RSS стабилизировался после второго входа. Это автоматические проверки, не ручное прохождение.

Исходный полный wave5-профиль новой версии прервался поражением игрока через 3.13 с сектора байкеров; последующее длинное окно было неактивным и исключено из A/B. Результат сохранён. Повторный одинаковый тестовый fixture с приватным высоким HP получил полные 11 с Арбитра и 12 с семи AI в обеих версиях. Начальная чистая тестовая копия выявила Parse Error по имени нового глобального класса; заменено на явный preload, импорт проекта повторно успешен. Окончательный полный последовательный headless runner: **19/19 PASS, 216 с**; отдельные bonus_weapon_cache_smoke, bonus_pickup_smoke, arena_bonus_batch_smoke и bonus_placement_smoke PASS. В сопоставимом 60-секундном графическом бою волны 4 с пятью AI новый lookup WeaponConfig max0.004 мс (28 вызовов) против холодного max24.931 мс; max кадра35.891→10.822 мс. Mean/p95/p99 новой версии немного выше при большем числе выстрелов/подборов, поэтому общего прироста FPS не заявляем. Нет SCRIPT ERROR, Parse Error или тестовых FAIL. В 8 из 19 логов сохраняются shutdown ObjectDB/resources warnings; они не трактуются как runtime-утечка.


## Финальная приёмка VehicleCatalog и профиль BonusPickup — 2026-10-28

[Подробный отчёт с таблицами и ограничениями](METAL_ROAD_BONUS_PICKUP_PROFILE.md), [логи и графические JSON](bonus-pickup-evidence/). Полный последовательный tests/run_vehicle_catalog_regressions.sh на окончательном содержимом runner и исправленных тестов: **19/19 PASS, exit 0, 212 с**. Нет SCRIPT ERROR/Parse Error/тестовых FAIL; в 11 из 19 headless-логов остались shutdown ObjectDB/resources warnings. Предыдущий результат 18/19 и отдельный повтор исправленного теста ниже — история первичной приёмки; новый полный запуск выполнен.

Несколько независимых графических процессов RX580/radeonsi, 1280×720/VSync: у двух baseline окон первых партий mean кадра16.680/16.694 мс, p95 16.918/16.915, p99 17.158/17.125, max48.708/56.186. У instrumented seed4217 первого входа mean16.691, p95 16.912, p99 17.196, max56.905 мс. Синхронный cache miss WeaponConfig в 17 измеренных вызовах: mean20.364/max25.041 мс; cache hit в 22 вызовах: mean0.005/max0.007 мс. Поиск позиции mean1.482/max1.751, instantiate mean0.021/max0.034, add_child вместе с ready mean0.201/max0.293 мс. Отдельный resource probe: холодный rocket_launcher.tres25.354 мс; предварительная загрузка его roof PNG25.133 мс и последующий .tres0.218 мс. Это подтверждает транзитивную загрузку текстуры как источник данного класса пиков при поставках; точный источник прежнего одиночного stock-кадра35.457 мс остаётся не доказанным напрямую.

Графический lifecycle probe без накопления кадров: 10 Restart — nodes206→206, resources182→182, RENDER_VIDEO_MEM_USED321.55→321.55 МиБ; 5 повторных входов после первого — nodes206→206, resources199→199, video340.45→340.45 МиБ. Удержание всех семи оружейных ресурсов в отдельном probe стоило +56.00 МиБ по Godot video monitor и155.631 мс синхронной подготовки. Это оценка движка, не hardware VRAM occupancy. Диагностические скрипты и инструментация находятся отдельно от production-кода. Оптимизация бонусов и игровой баланс в этой задаче не менялись; программное управление и принудительный ремонт в профиле не являются ручным playtest.

## Кэш VehicleCatalog и задержки создания AI — измерения 2026-10-26, сверка 2026-10-28

[Полный отчёт](METAL_ROAD_VEHICLE_CATALOG_CACHE_FIX.md), [методика, графические raw и логи](vehicle-catalog-cache-evidence/README.md). Проверка `weakref`/`ResourceLoader.has_cached` подтвердила, что каталог после краткого вызова без сильной ссылки освобождался; повторный probe дал192.690/190.788/184.120/185.957мс на четыре последовательные загрузки. Добавлена одна ленивая статическая ссылка в `LoadoutProfile`, а `vehicle_config()` возвращает копию отдельного VehicleConfig. Исходные ресурсы/характеристики и логика Vehicle/AI/оружия/волн не менялись.

Графический OpenGL/RX580 тест через штатное меню: новый процесс→Survival6.278→0.750с; третий AI `_spawn_bot`275.142→0.659мс, кадр появления273.428→2.565мс; переход волны2 после принудительных убийств и выбора перка885.770→2.874мс. Restart после победного состояния волны1, достигнутого принудительными убийствами,498.929→20.918мс до `frame_post_draw`; после60с боя480.538→25.541мс. Один фактический `ResourceLoader.load` каталога191.651мс остаётся во время первичной подготовки PreRace, дальнейшие обращения — cache hit. Максимум всего окна первой волны после изменения35.457мс произошёл до подкрепления; в отдельном detailed повторе похожий кадр содержал `bonus.create`26.352мс. Точное происхождение stock-кадра не доказано. Кадр подкрепления укладывается в целевые33.33мс. Боевой FPS в одной парной серии вариативен и не является точным доказательством улучшения или регрессии по AI/VFX.

Оценка Godot `RENDER_VIDEO_MEM_USED` после входа выросла на55.35MB (удерживаются artwork каталога); это не аппаратный VRAM occupancy. RSS в двух коротких межпроцессных графических прогонах после входа288984→278024КБ, что не доказывает экономию RAM. Повторный headless100 Restart 2026-10-28:197 nodes/177 resources, RSS395788КБ с10-го по100-й снимок, без обнаруженного накопления. Headless memory не подменяет графическую VRAM. Shutdown ObjectDB/resources warnings продолжают встречаться; они не подтверждают runtime leak.

Предварительный uncapped `controls_smoke` упал на порогах торможения и на текущем коде, и на копии со старым `LoadoutProfile`; тест считает render frames при физике60Hz. При `--max-fps 60` обе версии прошли. Исходный `survival_reward_feedback_smoke` не учитывал отложенного третьего врага и падал на обеих версиях; затем тест считывал HUD после кадра, когда сообщение уже обновлялось. Тестовый сценарий скорректирован без изменений игровой логики и отдельно повторён: PASS. В последовательном наборе18/19 PASS до последней правки теста; после неё последние результаты всех19 тестов PASS, полный повтор после неё 2026-10-28 — 19/19 PASS за 212 с. Расширенный `survival_boss_schedule_smoke` прошёл волны1–15, включая Арбитра на5/10/15; `survival_restart_smoke` PASS100; `release_candidate_smoke` PASS. Editor import без ошибок GDScript. Программная проверка joypad event прошла, физический геймпад и новое ручное прохождение не тестировались. Логи и ограничения — в evidence.

## Графический аудит производительности и темпа — 2026-10-26

[Полный отчёт и рекомендации](METAL_ROAD_SURVIVAL_PERFORMANCE_AUDIT.md), [raw54 окон/методика](survival-performance-evidence/README.md). RX580/radeonsi, i7-10700K,1280×720, debug Godot4.7.2; реальные render intervals и штатные viewport CPU/GPU queries. Без VSync:8 AI259.7FPS/p99 5.68ms, Arbiter+6 riders248.6FPS/p99 6.07ms, AI+48 VFX214.7FPS/p99 6.86ms в первом stock прогоне. VSync-контроль около60FPS. Это численные результаты конкретной среды, не универсальная сертификация производительности.

Подтверждён редкий stall270–276ms при подкреплении, в том числе через штатные меню. Detailed spawn275.142ms, два LoadoutProfile.vehicle_catalog/load вместе274.320ms; после Restart тот же источник. Deferred Restart до frame_post_draw477.46/486.03ms в двух stock runs, arena restore scope9.042ms в detailed. Detour23 attempts/4 accepted, mean1.477/max2.434ms; AStar grid cache-miss mean1.065/max1.629ms. Навигация не подтверждена главным stall. Pickup creation max25.719ms при position search≤1.982ms требует отдельной атрибуции.

Ручная обратная связь пользователя: первая волна проходится, размер комфортен, AI/динамика воспринимаются нормально. Аудит включает программное управление и отдельные стресс-условия с бесплатным ремонтом/forced wave entry; они не выдаются за естественное прохождение. Три попытки автопилота без таких вмешательств завершились поражением, оружие не подобрано; это ограничение оценки темпа человека. Некоторые baseline пики32–87ms ещё не атрибутированы.

Игровые scripts/resources/scenes не изменялись, сравнение с baseline копией без различий. Добавлены только тестовый сборщик/анализатор, воспроизводимый instrumentation patch для disposable копии и документы/данные. Оптимизация, перенастройка AI/физики/баланса не выполнялись. Исторические указания «профилировщик не использовался» ниже относятся к прежним задачам.

## Динамические заторы и recovery AI — 2026-10-26

[Алгоритмы, все прогоны, сравнение до/после и ограничения](METAL_ROAD_AI_TRAFFIC_RECOVERY_FIX.md), [evidence](traffic-recovery-evidence/README.md).

Production изменения: scripts/arena_bot.gd и scripts/arena_navigation.gd. Общий traffic blocker с ориентированными габаритами; временный local detour, не меняющий общий AStar cache; preflight реального rear hull/начала дуги; ограниченная память неудачного/просроченного yield; активный/неактивный peer и стабильные priority/side без incidental instance_id. Physics, геометрия, оружие, damage, волны/бонусы/input/Race не правились.

До: неподвижный/косой replay60.20с с16 запросами; inactive-priority FAIL90с с72 запросами/20 мгновенными отменами; wall replay FAIL90с с75/75. После: соответственно14.38с/1,30.18с/5,14.38с/1,7.37с/2 (из них1 заранее отклонён и1 реально выполнен). Во всех четырёх replay0 мгновенных отмен. Занятая yield-площадка прежде принималась, теперь отклоняется; unit-тесты памяти отказа/освобождения пространства/истечения yield PASS.

Приёмка:20 независимых полных физических runs1400×1000 —20 PASS,320 одиночных маршрутов четырёх классов, повреждённые колёса, встречные тяжёлые пары и8 AI с припаркованными блокировщиками. Group8 max stop4.083с,0 мгновенных отмен, максимум8 requests и2 safety cancellations на actor;90s/55-unit условия неизменны. Дополнительные20 parked/20 transit сохранены отдельно от финальной acceptance; после последней правки transit повторён на3 seeds. Старые4217/104729/8675309 и полный1000×800 suite PASS. Destroyed crate→EXACT→физическое прибытие на обеих картах:6/6 PASS. Pad1 не изменил контрольные side/arrival frames.

24 разных регрессионных теста прошли (Survival/Race/Career/Garage/Restart/VFX/bonus/release и контроллеры; список в полном отчёте). Исходный results_navigation один раз FAIL при uncapped headless600 process frames, затем PASS с --max-fps60 и прежним лимитом; оба лога сохранены, UI/тест не правились. Финально повторены Survival, Restart100 (197→197 nodes/orphan0), release candidate. Editor import без ошибок GDScript.

GUI на RX580:8/8 физически прибывших, затем15s Survival с движущимся игроком (548.18units) и≥2 движущимися AI794/900 кадров, стрельбой/попаданиями. В графическом стенде выданы пулемёты, Input программный; ручное прохождение и GPU/CPU profiler не выполнялись. GUI снят до финального дополнения памяти истёкшего yield; эта ветвь проверена unit/acceptance. Shutdown ObjectDB/resources warnings остаются и не считаются подтверждёнными runtime-утечками.20 PASS не гарантируют отсутствие всех возможных заторов; встречаются лишние реверсы и групповой проезд до64.85с.

Актуализация: 2026-10-26. Проверки выполнены на Godot 4.7.2 через Flatpak, OpenGL `radeonsi` на AMD Radeon RX 580, kernel 6.8.0-138-generic. Ниже сохранены также исторические результаты от2026-10-23.

## Scrapyard1400×1000 — эксперимент2026-10-26

Локальная HUD-адаптация: только основной structured scrapyard включает arena_hud.avoid_tutorial_overlap. При перекрытии машины нижней обучающей плашкой последняя перемещается на y180..236; исходный слот проверяется без осцилляции. Найдено при GUI800×600, исправлено и повторно снято; все12 camera checks дают tutorial_clear=true. Playability,100 Restart, roguelite и release candidate повторно PASS после этой правки. Дополнительный production файл: scripts/arena_hud.gd; итоговый rollback patch включает6 файлов.

[Полный отчёт с координатами/проездами/каждым прогоном/кадрами/откатом](METAL_ROAD_SCRAPYARD_EXPANSION.md), [данные](arena-expansion-evidence/).

Основной default_arena.tres увеличен1000×800→1400×1000 (+75% площади). Те же5 основных hull,2 crates,1 MapProp tire cluster,2 concrete blocks,3 barrels,1 oil,1 spikes. Ни машины, ни препятствия не увеличены. Центральный остов перенесён к(700,420), контейнеры разнесены поy265/505, ящики вынесены над верхним контейнером, опасный сектор справа и нижняя свободная полосаy780..1000. Шипы(240,720) теперь data-driven; default позиции прочих арен сохраняют прежние(150,650). Dressing привязан к реальным layout/hazards/hotspots, без новых коллизий. Основное описание арены обновлено, wave_plan не изменён.

Измеренные промежутки между реальными hull/AABB: западный проход123.02→238.02, межконтейнерный147.93→202.93 (теперь без ящиков), правый обход автобуса142.21→222.21. Эти ширины не заменяют driving checks/turn radius. Spawn anchors автоматически используют новую size;192 body queries (4 chassis×12 points×4 heading) не нашли пересечений, отрицательный контроль распознал collision центра. Штатные2+1,5s и generation guards сохранены. На wave5 создан Arbiter и6 riders без физических наложений.12 партий/36 placements распределились по всем4 pads,9 на каждую. Реальные oil/spike sensors и crate/barrel destruction/Restart PASS.

FollowCamera не перенастраивалась: zoom1.23→1.0 и динамика прежние. Только Survival structured scrapyard margin40→20 (толщина стены), чтобы не показывать лишнюю пустую полосу.12 GUI checks фактического visible rect прошли на1280×720/800×600, включая физическое движение со speed≈125.06 и camera zoom≈1.056. HUD осмотрен. Статические обзорные схемы используют отдельную камеру.65 без машин, одинаковую для обеих карт; gameplay cars не уменьшались ради обзора.

Проверки:

- Новый arena_expansion_smoke PASS0; cold import/parse и финальный GUI runner без GDScript ошибок.
- По20 полных физических route runs old/new:16 одиночных маршрутов Raider/Bastion/Behemoth/Arbiter, обе встречные пары и critical wheels проходят. Group8: **17/20 PASS old,19/20 new** (3 FAIL→1 FAIL). Это не доказанное устранение AI-риска: в новом FAIL actors4/6 остались EXACT/yield6; даже успешный прогон содержал17.53s остановки. Таймауты/goal radius/парковка доехавших не менялись.
- Group-only private seeds4217/104729/8675309, stable side fixture: old FAIL/PASS/FAIL, new PASS/PASS/PASS. Это контрольный тест, не production AI patch.
- 25 regression scripts PASS: arena_smoke, arena_run_variation_smoke, survival_playability_smoke, survival_smoke, survival_round_guard_smoke, survival_restart_smoke, survival_boss_schedule_smoke, survival_roguelite_smoke, biker_boss_navigation_integration, survival_biker_crew_smoke, results_navigation_smoke, bonus_placement_smoke, arena_bonus_batch_smoke, combat_vfx_budget_smoke, tactical_arsenal_smoke, race_finish_smoke, career_gameplay_smoke, garage_smoke, garage_layout_smoke, garage_loadout_smoke, controls_smoke, release_v1_smoke, release_candidate_smoke, rolling_steering_smoke, brake_reverse_recovery_smoke. Restart100 nodes197→197/orphan0.

Не смешивать25 PASS с whole navigation-suite PASS: stress failures сохранены. Сохраняются известные shutdown audio ObjectDB/resources warnings, не подтверждение runtime leak. Прямое расстояние до ближайшей поставки от старта240.21→386.39; интервалы/количество/TTL не компенсировались без отдельного баланса. Natural TTK, аппаратный gamepad/ручное прохождение не выполнялись. Графика и программная поездка не являются ручным playtest. Сетка AStar24 выросла1428→2478cells; profiler/FPS/CPU p95 не измерены, производительный прирост не заявляется.

Изменены resources/default_arena.tres, scripts/arena_config.gd, arena_dressing.gd, survival.gd, survival_run_data.gd (только description),4 существующих теста (arena_smoke, arena_navigation_routes_smoke, ai_navigation_diagnostic, survival_playability_smoke),2 новых expansion smoke/visual и2 before fixtures. Данные/QA/план/deep dive и compatibility note исторической диагностики обновлены. Physics/VehicleConfig/AI/navigation/weapons/input/Race source не правились. Other arenas resources не менялись; Career scrapyard использует общий default_arena и наследует новый размер при прежних правилах контракта. Reverse Git patch проверен --check, не применён, коммит не создавался.

## Начальная играбельность Survival — 2026-10-26

### Волны и отложенное подкрепление

| Волна первого цикла | Всего основных | Элит из них | Начало/финал |
|---|---:|---:|---|
| 1 | 3 | 0 | 2 сразу,1 после5s активной игры |
| 2 | 4 | 0 | сразу, прежний supply_rate1.8 |
| 3 | 4 | 1 | сразу |
| 4 | 5 | 1 | сразу |
| 5 | 3 | 1 | после основных Арбитр, затем ожидание активной поддержки |

Выбрана нижняя допустимая граница1 elite для волн4/5, без изменения HP/урона/оружия/поведения AI. Tier=floor((wave−1)/5): основные min(3+t,7)/min(4+t,7)/min(4+t,6)/min(5+t,8)/min(3+t,4); элиты min(t,2)/0/min(1+t,4)/min(1+t,3)/min(1+t,4). Прежние caps7/7/6/8/4 сохранены, supply_rate и характеристики Арбитра не изменены. Boss flag по-прежнему определён только wave_plan:5/10/15/…; Career requires_arbiter и внутренний legacy override сохранены.

Survival._pending_enemies учитывает ещё не созданного противника. `_round_enemy_total` резервирует всех3, HUD «ОСТАЛОСЬ» включает pending, «УНИЧТОЖЕНО» исключает pending; два ранних убийства не завершают волну и не запускают Арбитра/награду. Таймер5s обновляется в physics только во время активного матча. Spawn выполняется deferred с generation guard, вне physics flush. Используются штатные spawn anchors; если они заняты живыми машинами в радиусе100, следующая ограниченная попытка через.5s (появление может быть позже5s, но не поверх машины). Pause не расходует время. Restart/Retry очищают очередь/таймер, stale callbacks отвергаются. Поражение отменяет pending без фиктивного «убийства» непоявившегося противника. Новая арена между обычными волнами не создаётся.

### Подбор, лечение и интерфейс

Новые правила ограничены автомобилем игрока Survival через meta survival_pickups; обычный Race player и AI сохраняют прежний автоматический подбор/замену. `BonusPickup.collect(vehicle,confirm_weapon_swap=false)` отказывает контакту с оружием при активном временном оружии; бонус остаётся активным, сигнал collected не испускается, TTL не продлевается. Один nearest overlapping weapon offer выбирается по фактическому Area2D.overlaps_body, не по произвольному дальнему радиусу. Подтверждение использует **одно InputMap action interact**, считываемое InputHandler через is_action_just_pressed. Можно заменить оружие в движении; удержание и keyboard echo не повторяют замену. Если оружие отсутствует, контакт остаётся автоматическим; дополнительно проверяется уже перекрытый бонус после истечения старого оружия. Неактивные/собранные/удаляемые предложения не используются.

Repair игрока Survival вызывает прежний Vehicle.repair с body_amount=current config.max_health: кузов до максимума без переполнения, engine+22/wheels+24 с прежними cap/feedback. Максимум с armor_skin учитывается. HUD/readout обновляется в обработчике collected сразу. Race/AI сохраняют body+28. Межволновые30%/45% и взаимное исключение speed/ram не менялись. Интервалы/batches/max_active/lifetime/placement BonusSpawner, параметры оружия и начисление награды не правились.

Подсказка — отдельный небольшой Label в ArenaHUD между обучением и нижними панелями, без перезаписи центральных объявлений. Отображается только для активного оружейного предложения при уже установленном оружии. Последний значимый клавиатурный/мышиный или joypad event переключает способ отображения. Label читает текущий InputMap, включая rebinding клавиатуры. Xbox→X, PlayStation (DualSense/DualShock/PS4/PS5/Sony/Wireless Controller name)→□, неизвестное пустое имя→X / □. Начальное состояние — клавиатура до первого события управления в Survival. На Results/draft подсказка скрыта.

### Назначения до/после

| Действие | Клавиатура до → после | Геймпад до → после |
|---|---|---|
| Газ | W/↑ → без изменений | RT → без изменений |
| Тормоз/задний ход | S/↓ → без изменений | LT → без изменений |
| Руль | A/←,D/→ → без изменений | L-stick X и D-pad ←/→ → без изменений |
| Огонь | Space/Ctrl → без изменений | A/× → без изменений |
| Restart | R → без изменений | Y/△ → без изменений |
| Замена оружия Survival | не было → E (interact) | свободно → X/□ (interact, button_index2) |
| Подтверждение меню | прежнее ui_accept → без изменений | A/× → без изменений |
| Отмена/пауза | прежнее ui_cancel (Esc) → без изменений | B/○ и Start → без изменений |
| Навигация меню/Garage | прежние ui_* → без изменений | D-pad и L-stick → без изменений |
| Debug | F1 → без изменений | отдельного назначения не было/не добавлено |

Отдельного action «ручник» в проекте нет: сохранена прежняя обработка интенсивности brake в Vehicle; физика/пороги не менялись. X/□ не назначены ни fire/restart, ни ui_accept/ui_cancel. В Controls появилась строка interact через существующий список ACTIONS и штатное сохранение keyboard binding; основной экран меню/Garage не перерабатывался. Произвольные пользовательские переназначения могут создать конфликт, как и ранее; глобального нового менеджера конфликтов не добавлено.

### Мина

Причина: Bullet и Vehicle имели одинаковый effective z=0, а Bullets находится после Player в дереве; поздняя созданная мина могла рисоваться поверх кузова. Mine setup теперь задаёт z_index=−1 (z_as_relative остаётся штатным, Bullets z=0). Ground/dressing ниже, Vehicle z=0 перекрывает установленную мину. Остальные projectiles остаются0, отдельный CombatVFX layer4 не менялся. Коллизии, mine targeting/damage/friendly fire, скорость/TTL снарядов не изменены.

### Проверки

Все финальные запуски в изолированной копии `/tmp/metal-road-playability-JY5wXv`, с отдельными config/name/custom_user_dir и test profile/loadout. Первичные ошибки стенда (старые ожидания5 стартовых врагов/4 elites, ручное размещение до завершения pending physics reset, ожидание одновременных speed+ram) исправлены под новый контракт, не ослабляя проверки урона/слоёв/навигации/награды. Полные итоговые логи: [playability-evidence/](playability-evidence/).

| Тест/сценарий | Итог |
|---|---|
| survival_playability_smoke (новый) | PASS0: реальное ожидание~5s, ранние убийства,3/4/4/5/3 и elites0/0/1/1/1 в ресурсах и runtime, flags1–30, single reward/draft, stale reinforcement/defeat/Retry, автоматический контакт, E/X в движении и удержание, prompt E/X/□ helper, HP/HUD/engine/wheels, Race/AI compatibility, слои mine/MG/rocket/flame/EMP |
| survival_smoke, survival_round_guard_smoke | PASS: урон/снаряд, начало2+1, polling fallback, next wave4, финал5 |
| survival_boss_schedule_smoke | PASS1–15, riders после смерти босса, rewards/perks, Restart/Retry, Career actual contracts и explicit requires_arbiter |
| survival_roguelite_smoke | PASS: первый elite Vanguard, поздние разные squad roles, сохранённые boss stats48 legacy/92 wave5, warning/flame |
| survival_restart_smoke | PASS100 Restart, nodes197→197, orphan0, восстановление арены/объектов, queue2+1 |
| survival_transition_stability_smoke, survival_session_end_smoke, survival_biker_crew_smoke | PASS |
| controls_smoke, release_v1_smoke | PASS: WASD physical command chain, InputMap/controller/UI/analogue contracts |
| garage_smoke, garage_loadout_smoke, garage_layout_smoke | PASS |
| race_finish_smoke, career_gameplay_smoke, results_navigation_smoke | PASS, включая Menu/Garage/Retry/pause; results navigation без accelerated fixed-fps |
| release_candidate_smoke | PASS, существующие пороги сохранены |
| bonus_pickup_smoke, bonus_placement_smoke, combat_vfx_budget_smoke | PASS |
| tactical_arsenal_smoke | PASS: прежняя механика оружия/мин |
| rolling_steering_smoke, brake_reverse_recovery_smoke | PASS; Vehicle/VehicleConfig не редактировались |
| Graphical RX580/radeonsi | Запущен GUI, осмотрены старт, E/X prompts и установленная own mine под кузовом + соседняя видимая мина |
| git diff --check | PASS |

Итого24 финальных headless smoke-файла PASS. Нет новых parse/GDScript errors в их логах. Сохраняются ранее исследованные shutdown ObjectDB/resources warnings (например playability20/7, Restart18/7); они не объявляются подтверждённой runtime-утечкой. Ранее выявленный AI group8 риск не исправлялся и не выдаётся за зелёную регрессию в этой задаче;20-кратная навигационная серия заново не выполнялась.

Управление проверено настоящими программными InputEventKey и InputEventJoypadButton, а не только прямым вызовом collect(true). Input сообщает connected joypad[0], но аппаратные нажатия контроллера оператором не выполнялись; не считать это полноценной hardware-проверкой Xbox/PlayStation. PS glyph проверен через name helper, не через физический PlayStation controller. Графические кадры — автоматизированная постановка, не ручное прохождение первой волны. Новая численность соответствует заданию, но реальная проходимость/комфорт первого цикла потребуют повторного ручного теста. GPU-профилирования и измерения естественного TTK не было.

### Изменённые файлы этого задания

- Игровая логика/конфигурация: project.godot; scripts/survival_run_data.gd; scripts/survival.gd; scripts/bonus_pickup.gd; scripts/input_handler.gd; scripts/input_bindings.gd; scripts/arena_hud.gd; scripts/bullet.gd.
- Новый tests/survival_playability_smoke.gd; обновлены tests/survival_smoke.gd, survival_round_guard_smoke.gd, survival_restart_smoke.gd, survival_transition_stability_smoke.gd, survival_boss_schedule_smoke.gd, survival_roguelite_smoke.gd, combat_vfx_budget_smoke.gd. Проверка поздней восьмёрки перенесена14→19, где новое плавное расписание достигает того же cap8; проверка ролей сохранена на wave8.
- QA, improvement plan, заметка в deep dive и playability-evidence (логи/кадры/GUI staging helper). Прежние незакоммиченные изменения проекта не удалялись.

Оставшиеся риски: занятые anchors могут задержать reinforcement позже5s; влияние полного body repair на экономику/TTK пока не измерено; имя неизвестного controller требует универсального X/□; известные отдельные AI parked-blocker/recovery дефекты остаются вне scope. Arena/physics/AI и weapon resource hashes соответствуют прежним исходникам; изменения размеров арены не выполнялись.

## Диагностика нестабильности AI — 2026-10-23

Проведена без правки игровых исходников/ресурсов. [Подробный отчёт](METAL_ROAD_AI_NAVIGATION_DIAGNOSTICS.md), [сырые данные](ai-navigation-evidence/). Исходный arena_navigation_routes_smoke:20 независимых запусков,17 PASS/3 FAIL (15%), все FAIL в group8. Отдельная инструментированная серия20 запусков:16 PASS/4 FAIL (20%); эти выборки не объединяются. Дополнительно проверены fixed seeds4217/104729/8675309, instance_id, припаркованные машины, отмены recovery и освобождение пути после разрушения ящика.

Подтверждены: остановившиеся в исходном тесте машины остаются блокировщиками с отключённым AI; traffic braking работает для большего набора углов, чем head-on yield, поэтому EXACT static path не обеспечивает объезд неподвижного трафика. При неисполняемом yield у нижней границы повторяются отмены reverse: в воспроизводимой контрольной сцене60 запросов/57 мгновенных отмен/3 видимых реверса, maxstop62.78s. Исходный счётчик такие мгновенные отмены не видит. Глобальный seed не задаёт private Arena RNG, passing side зависит от instance_id; реакционный интервал в GoalDriver обходится и не объясняет этот тест.

Одиночные маршруты, heavy head-on, контейнерная пара и critical wheels прошли20/20 инструментированных повторов. Разрушение stock crate: NEAREST→EXACT и физическое достижение18-unit области,3/3 seed. Ни статическая непроходимость, ни связь с расписанием Арбитра не доказаны. Добавлены только два диагностических теста и отчёт/данные; предложения исправлений ожидают отдельного задания. Нового ручного/GUI теста не было.

## Арбитр каждые пять волн — 2026-10-23

### Контракт и изменение

Прежние `_on_vehicle_died` и `_process` независимо требовали босса после каждой зачистки, игнорируя существующее поле `SurvivalRunData.wave_plan.boss`. Теперь оба пути вызывают `_complete_combat_phase`: обычная волна завершается прежним `_end_round(true)`, boss-wave запрашивает deferred Арбитра и затем ожидает нуля всех живых врагов, включая байкеров. `_spawn_referee` и `_request_referee_spawn` также отвергают обычные волны. На них boss/biker timers обнуляются. Правило 5/10/15/… остаётся только в плане; отдельного modulo в HUD или спавнере нет.

Сохранены generation guards, one-shot награда, задержка1.2s, draft и ремонт30%/45%, характеристики/фазы/оружие/поддержка босса. Первая встреча теперь wave5 с прежними для wave5 HP1378/speed92; ослабление или усиление самого босса не вводилось. Волны1–4/6–9/11–14 не ожидают босса и не создают его riders. Ранее исправленные VFX, BonusSpawner, Restart, навигация/физика, ресурсы арены не перерабатывались.

Career: фактические arena-контракты `scrapyard_contract` и `oil_cauldron` требуют target_rounds2/3, не требуют босса явно и по-прежнему заканчиваются VICTORY. Явный `requires_arbiter=true` в event нормализует тот же wave_plan.boss; предусмотрен отдельный тест такого контракта. Существующие Race boss_duel не изменены. Внутренний `@export referee_every_wave=false` нужен только для A/B старого расписания, пользовательского переключателя нет.

Изменённый игровой исходник: scripts/survival.gd. Новые тесты: tests/survival_boss_schedule_smoke.gd и tests/survival_wave_cycle_metrics.gd. Скорректированы ожидания/fixtures существующих survival_smoke, survival_round_guard_smoke, survival_roguelite_smoke, survival_biker_crew_smoke, biker_boss_navigation_integration и arena_behavior_soak: ручное staging босса теперь начинается с boss-wave5, либо использует явно включённый legacy режим для проверки прежних wave1 stats. Остальные проверки в этих тестах не ослаблялись.

### Проверки

Запуски выполняются в изолированной копии `/tmp/metal-road-deep-cRUfIj`, с отдельными profile/loadout файлами и user directory. Результаты относятся к текущей рабочей копии, не к чистому HEAD.

| Сценарий | Результат |
|---|---|
| survival_boss_schedule_smoke | PASS: волны1–15, однократные rewards/HUD/draft, ожидание riders, Restart/Retry/stale spawn, Career |
| survival_smoke, survival_round_guard_smoke | PASS: обычный финал, polling fallback, boss-wave5, поражение |
| survival_roguelite_smoke | PASS: перки, draft, масштабирование legacy wave1 и обычной boss-wave5 |
| survival_biker_crew_smoke | PASS: поддержка/crew при staging на wave5 |
| referee_flamethrower_smoke, biker_boss_navigation_integration | PASS: реальные flame projectiles, движение босса и сохранение riders за12s |
| career_gameplay_smoke | PASS |
| race_finish_smoke | PASS |
| release_candidate_smoke | PASS, без изменения порогов |
| combat_vfx_budget_smoke, bonus_placement_smoke | PASS |
| results_navigation_smoke (без fixed-fps) | PASS: Retry/Menu/Garage, pause Restart/Continue/Menu |
| arena_navigation_routes_smoke | Первый запуск FAIL: group8 — 7/8 доехали за90s, одна машина осталась у(673,231),21 recovery. Повтор PASS, включая8/8. Одиночные маршруты всех4 chassis, повреждённые колёса и оба встречных разъезда PASS в обоих запусках |
| Графический сценарий на RX580/radeonsi | Сняты и осмотрены завершение wave1 без boss bar, draft и wave5 с boss bar. Автоматизированная постановка, не ручное прохождение |

Фиксировать общий результат как «все регрессии стабильно PASS» нельзя. Навигационный сценарий создаёт Arena/Vehicle/GoalDriver напрямую, без Survival; его код и исполняемые алгоритмы навигации/Vehicle в данной задаче не менялись. Один FAIL и один PASS показывают нестабильность проверенного сценария; не доказывают ни новую регрессию расписания, ни её полное отсутствие. Обнаруженный затор не исправлялся в рамках изменения расписания. Исходный accelerated `results_navigation_smoke --fixed-fps60` также упёрся в ожидание threaded загрузки сцены (600 ускоренных кадров), после чего проверка Garage получила Nil; повтор с обычным временем прошёл. Это ограничение стенда, а не основание увеличивать пороги или менять UI.

В конце некоторых запусков сохраняются ранее исследованные предупреждения ObjectDB/resources (например, metrics18/7, UI22/8). Они не являются новым доказательством runtime-утечки. Ошибки загрузки/парсинга GDScript отдельно проверяются в логах.

### Методика сравнения

`survival_wave_cycle_metrics.gd`: seed4217, десять последовательных волн через штатный end/draft/start, реальные AI/physics/projectiles/supply. Но игрок заморожен и тестово усилен до HP/engine/wheels50000; по8s на основную фазу и дополнительно12s на boss-фазу, затем оставшиеся враги уничтожаются `take_damage(100000)` от игрока. Каждые4s первый доступный pickup принудительно collect. Поэтому секунды в таблице — заданные окна симуляции, **не естественное время зачистки**. Headless draft выбирает автоматически. Сценарии не эквивалентны ручному прохождению и не доказывают приемлемость баланса.

Метрики сохраняют каждую волну: seconds, destroyed, boss, score, credits, perks_before_draft, collected, AI_created, VFX_created/VFX_peak, scripted_kills. Дополнительно combat_deaths — смерти за пределами принудительной зачистки; clear_deaths_including_chains — смерти внутри неё, включая цепные. Их нельзя смешивать: scripted_kills считает только прямые принудительные вызовы. Даже combat_deaths происходят с тестовым игроком/автоматическим collect. Seed не делает весь прогон битово одинаковым: собственный RNG draft и зависящие от instance_id решения AI не синхронизированы между A/B.

| Первые10 волн | Старое расписание | Новое расписание |
|---|---:|---:|
| Арбитров | 10 | 2 |
| Выдано перков | 10 | 10 |
| Сумма заданных боевых окон, s (без draft/паузы) | 200 | 104 |
| Создано/уничтожено AI, включая riders | 124/124 | 68/68 |
| Прямые scripted kills | 107 | 62 |
| Смерти внутри scripted clear, включая цепные | 123 | 66 |
| Смерти вне clear в тестовом бою | 1 | 2 |
| Очки | 481656 | 273135 |
| Кредиты за прогон | 26800 | 15700 |
| Получено pickups всеми машинами | 106 | 66 |
| Из них принудительно collect игроком | 41 | 17 |
| Создано VFX / peak active | 489/14 | 363/9 |
| Ошибки состояния/перехода | 0 | 0 |

Покадровый мониторинг peak не заменяет замер CPU/GPU. Общий VFX_created включает startup и переходы между окнами (в отличие от суммы per-wave VFX_created); считаются вызовы создания, а не только принятые budget-события. Наблюдаемые pickups/очки включают вклад AI и принудительного добивания; A/B не изолирует влияние выбранных случайных перков. Десятый draft переводит сценарий в волну11; все10 наград получены один раз. Для окна104s темп перков выше, но нельзя переносить отношение200/104 на реальный матч: длительности заданы тестом.

| Волна | s старое/новое | Уничтожено старое/новое | Кредиты старое/новое | Очки старое/новое |
|---|---|---|---|---|
| 1 | 20/8 | 12/5 | 2070/810 | 32601/8560 |
| 2 | 20/8 | 13/6 | 2390/1130 | 42522/17443 |
| 3 | 20/8 | 11/4 | 2350/1010 | 38528/14603 |
| 4 | 20/8 | 13/6 | 2670/1370 | 48382/23750 |
| 5 | 20/20 | 11/11 | 2670/2670 | 47498/49059 |
| 6 | 20/8 | 13/6 | 2670/1190 | 47326/17034 |
| 7 | 20/8 | 14/7 | 2810/1350 | 51873/25104 |
| 8 | 20/8 | 12/5 | 2890/1430 | 51919/25022 |
| 9 | 20/8 | 14/7 | 3290/1750 | 64476/35898 |
| 10 | 20/20 | 11/11 | 2990/2990 | 56531/56662 |

Полные per-wave данные и логи: [boss-schedule-evidence](boss-schedule-evidence/). Повторное воспроизведение: `flatpak run --filesystem=/tmp/metal-road-deep-cRUfIj org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-deep-cRUfIj --script res://tests/survival_wave_cycle_metrics.gd`; для старого расписания добавить `-- --legacy`. Тестовая копия должна содержать актуальные scripts/tests/imports; графический runner сохранён рядом с кадрами. Архивы содержат оба навигационных результата и UI realtime/accelerated logs.

Оценка без перенастройки: четыре обычные волны на цикл стали короче; награда и перк за волну прежние, но потенциальный темп их получения и межволнового ремонта в минуту выше. Убраны восемь boss-боёв на первые10 волн и связанная поддержка: меньше возможностей набрать boss score/kill credits и получить поставки за дополнительное время. Первая встреча босса сразу использует wave5 scaling вместо прежнего постепенного знакомства48→92. Фактическая сложность десяти волн и длительность матча требуют ручного прогона; компенсирующие HP/урон/численность сейчас не менялись.

## Исправление VFX budget — 2026-10-23

Текущее состояние: дефект исправлен в scripts/combat_vfx.gd. Нижеописанный первоначальный FAIL сохранён как история аудита.

Причина подтверждена git show HEAD:godot/scripts/combat_vfx.gd: прежний FIFO _trim_events удалён из рабочей копии вместе с вызовами. Все emitters проверены: Bullet (impact/explosion), RefereeBoss (impact), Game/Survival (explosion/pickup). Общая точка добавления теперь ограничивает MAX_EVENTS=48.

Политика: explosion/pickup > large impact > ordinary impact. При заполнении вытесняется старейший эффект самого низкого приоритета, только если приоритет входящего не ниже. Иначе входящий отклоняется. При равных приоритетах остаются последние48. Важные эффекты защищены от менее важных, но burst из70 одинаково важных взрывов неизбежно оставляет48. В текущих emitters отсутствует признак тяжести impact, поэтому их поведение не менялось; spawn_impact получил необязательный large_hit для явной маркировки без вывода тяжести из цвета/урона. Изображение и TTL эффектов сохранены.

Повторные проверки в изолированной копии проекта с отдельным user directory:

| Проверка | Результат |
|---|---|
| tests/combat_vfx_budget_smoke.gd | PASS:70 impacts,70 explosions, смешанный burst, защита important/large effects, FIFO равного приоритета, TTL, возобновление после idle, Survival restart |
| tests/release_candidate_smoke.gd | PASS, прежний порог48 сохранён |
| tests/survival_smoke.gd | PASS,0 failures |
| tests/race_finish_smoke.gd | PASS |
| Графический сценарий Survival | RX580/radeonsi, боты стреляют; после injected70 impacts важные explosion+pickup видимы, всего48 |
| git diff --check | PASS |

Ошибок parse/GDScript в этих запусках нет. Исходные regression scripts по-прежнему сообщают shutdown ObjectDB/resources (release2/1, Survival22/8, Race6/2); это ранее исследованный аудиопорядок завершения, в рамках этого исправления не изменялся. Новый budget smoke завершился без этих предупреждений.

Кадр: [vfx-budget-fixed.png](survival-deep-evidence/vfx-budget-fixed.png). Это автоматизированный GUI-рендер с осмотром кадра, не ручное прохождение. GPU profiler/frame-time сравнение до/после не выполнялось; headless PASS не является доказательством прироста FPS.

Restart сохраняет прежнюю семантику: уже живые события могут кратковременно пережить reset, но остаются в бюджете и истекают по TTL. Риски: при перегрузке часть sparks не отображается, при48 important новые important вытесняют старые; линейный поиск ограничен48 элементами. Нельзя гарантировать отображение всех одновременных важных событий сверх бюджета.

## Исправление размещения Survival — 2026-10-23

Изменения: scripts/bonus_spawner.gd и новый tests/bonus_placement_smoke.gd; документация deep dive/план/QA; обзорный кадр в evidence. ArenaNavigation, физика, AI и damage не менялись.

Поиск ограничен48 кандидатами на слот. Результат Dictionary: success=false либо success=true/position. _create_pickup проверяет его до instantiate, загрузки оружия и выбора случайного типа. Неудача не увеличивает spawn_index и не расходует мешок типов. Полный отказ объявленной партии переводит спавнер на прежний spawn_interval; immediate spawn также ставит cooldown. Частично успешная партия доставляет только найденные точки; гарантированные weapon slots считаются по успешным объектам, а не по числу попыток.

Штатные интервалы, batch_size, minimum_weapons_per_batch, max_active, lifetime, warning, separation и вероятностный мешок не изменены. Формула координат Race прежняя, обёрнута явным success. Не следует ожидать прежней последовательности RNG для конкретного seed: выбор weapon теперь происходит после успешного поиска координат, распределение видов сохранено.

Проверки кандидата:

1. Отступ от границ не менее75 (или clearance машины, если больше); прежний запас layout.grow86; расстояния от reserved и active.
2. Свежий отдельный ArenaNavigation snapshot для размещения, без изменения AI-кэша. point_clear учитывает MapProps и живые barrels; уничтоженные props исключены сразу при новой попытке, без ожидания45 frames AI cache.
3. Physics circle радиус max(53,clearance) не пересекает StaticBody;53 соответствует pickup radius50×max pulse1.06.
4. Шипы отдельно проверяются по transformed RectangleShape, включая расстояние от площадки до рёбер: collision_layer0 делает их невидимыми для обычного physics query.
5. Путь от стартового anchor игрока до точки для placement_vehicle_config (по умолчанию Raider) должен существовать, заканчиваться в пределах4 units (контракт существующего route) и иметь свободные сегменты, включая последний до самой цели. Arbiter не используется как collector.

Масло остаётся проезжаемым, машины не считаются постоянными препятствиями; поэтому возможен немедленный подбор стоящим рядом ботом. Будущие случайные press/rockfall не прогнозируются: постоянного запрета на их площадки ранее не было, а новые правила hazards не вводились.

| Новые/повторные проверки | Результат |
|---|---|
| bonus_placement_smoke: все48 кандидатов закрыты большим реальным StaticBody | PASS:0 созданных объектов, явный отказ, cooldown и отсутствие повторных поисков до истечения cooldown |
| Закрытый и свободный hotspots | PASS: ящик блокирует первую точку, выбирается свободная |
| MapProp/barrel/spike | PASS: точки внутри запрещены, шипы layer0 учтены |
| Разрушение crate | PASS: после обновления physics область снова доступна |
| Изолированная камера за непрерывной стеной planner | PASS: недостижимая площадка отвергнута |
| 5 арен × Raider/Needle/Behemoth/Bastion, seed4217 | PASS: валидные партии; штатный Raider получает3 на каждой арене; проверены pending/active separation210 и cap6 |
| arena_bonus_batch_smoke | PASS: штатные партии на всех пяти аренах |
| bonus_pickup_smoke | PASS: Race placement и pickup lifecycle |
| survival_smoke / race_finish_smoke / release_candidate_smoke | PASS |
| git diff --check | PASS |

Ошибок GDScript в финальных запусках нет. У существующих Race/release regression по-прежнему возможны ранее описанные shutdown audio ObjectDB/resources warnings; к новому размещению не отнесены.

Графическая проверка на RX580/radeonsi: создана партия в (500,130),(90,320),(910,350); площадки не накладываются на статические укрытия, один бонус сразу собран соперником. [Кадр](survival-deep-evidence/bonus-placement-fixed.png). Это автоматизированный GUI-запуск и осмотр кадра, не ручное прохождение.

Ограничения: проверка пути геометрическая, не доказательство физического проезда каждого авто в живом встречном трафике. Большой clearance может уменьшить партию; на плотных аренах безопасный отказ предпочтительнее недоступного объекта. Проверяется связность со стартовой областью, а не индивидуальный путь от текущей позиции каждой машины. Движущиеся машины и будущие hazards могут временно занимать площадку после её выбора. Консервативный layout.grow86 сохранён; новая физическая проверка лишь дополняет его. GPU/CPU-профилирование не выполнялось.

## Жизненный цикл и Restart Survival — исправление 2026-10-23

Изменены scripts/survival.gd, scripts/cinematic_fx.gd, tests/results_navigation_smoke.gd; добавлены tests/survival_restart_smoke.gd и tests/survival_session_end_smoke.gd. Обновлены QA, deep dive, improvement plan; добавлены два графических кадра в evidence. Остальные задачи плана не выполнялись.

Причины: прежний start_round(1) сбрасывал счётчики/машину, но сохранял Arena с разрушенными props и hazards; deferred crew не имел токена поколения; завершение не выключало producers. Дополнительно обнаружен продолжающийся tween finish_amount, который мог вернуть старое затемнение после reset.

Выбран локальный rebuild вместо reload всего Survival. Исходный ArenaConfig сохраняется при _ready; повторный start_round(1) удаляет старую Arena и создаёт новую из снимка ресурса. Восстанавливаются все её коллизии, props, бочки, масло, декор, погода, шипы и ArenaHazardDirector. Перепривязываются BonusSpawner, камера, weather/hazard/barrel signals. Существующие Player/HUD/Results сохраняют идентичность; Player reset и восстановление базового config очищают временное оружие, boosts, EMP, урон и particles; координатор дополнительно очищает старые surface modifiers и collision cooldowns. World VFX очищается сразу, TireTracks принадлежит новой арене.

Обычный переход на wave2+ не пересоздаёт Arena: разрушения сохраняются. Это проверено отдельно от полного Restart. Вариативность арены сохраняет прежний алгоритм: исходный resource тот же, но случайные повороты/варианты декора могут отличаться в новой сессии.

Retry и клавиатурный Restart используют coalesced deferred request вне physics flush. _round_generation инвалидируется при запросе Restart, начале волны и финальном завершении; устаревшие deferred callbacks Арбитра/crew/автоматического draft/остановки мира отвергаются. Для сигналов crew захвачен generation, для Arena действует собственный generation, старые enemy callbacks проверяют принадлежность текущему списку.

При defeat/финальном Career victory _session_finished немедленно блокирует изменение счётчиков/сообщений из gameplay. После physics flush останавливаются Arena/hazards/weather, bonus spawner/pickup sensors, bullets, crew, AI/оружие и физические тела. UI не останавливается, SceneTree не ставится на глобальную паузу. CinematicFX хранит текущий finish tween и отменяет его при reset/новом finish; формулы физики, характеристики/баланс и Race logic не изменены.

| Проверка | Результат |
|---|---|
| survival_restart_smoke: разрушить crate → wave2 → Restart | PASS: wave2 сохраняет разрушение, Restart восстанавливает |
| Взрыв barrel → Restart; шипы | PASS: исходное количество бочек и ровно одна полоса шипов |
| Hazard warning/active/timer; временное оружие, boost/ram, поверхность | PASS: начальное состояние после Restart |
| Projectile/VFX → Restart | PASS: старые объекты и events удалены |
| Enemy death + Restart в одном кадре | PASS: нет stale crew и старого score/kills |
| Defeat → Retry | PASS: живая машина, скрытые Results, wave1/enemies5 |
| 100 последовательных Restart, два прогона | PASS: nodes baseline232/final232, orphan0; counts props/barrels/enemies проверены после каждого |
| survival_session_end_smoke | PASS:1800 physics frames/30s simulation после defeat без новых объектов и изменения результата; world/crew stopped, Results can_process |
| Старые generation crew/Arbiter после Restart | PASS: объекты не созданы |
| survival_smoke | PASS,0 failures |
| survival_round_guard_smoke, survival_transition_stability_smoke | PASS |
| survival_biker_crew_smoke | PASS: текущие crew/biker механики совместимы |
| results_navigation_smoke | PASS: Retry/Menu/Garage после defeat, pause Continue/Restart/Menu, Race results routes |
| race_finish_smoke, release_candidate_smoke | PASS |
| combat_vfx_budget_smoke, arena_bonus_batch_smoke | PASS |
| git diff --check | PASS |

Навигационный тест ранее мог вернуть PASS после ошибки Nil.hud: он продолжал сценарий во время смены сцены. Исправлен только harness: ожидает окончание SceneTransition и устойчивый current_scene после следующего кадра, отсутствующий Survival фиксирует failure. Финальный запуск прошёл без GDScript errors. У ряда старых smoke по-прежнему shutdown audio ObjectDB/resources warnings, описанные выше; два новых lifecycle tests завершились без них.

Графическая проверка RX580/radeonsi: автоматизированный GUI-сценарий уничтожает игрока, показывает Results, нажимает сигнал Retry и проверяет кадр новой сессии через.5s. alive=true, finished=false, results=false, finish_amount=0, enemies5. Кадры: [поражение](survival-deep-evidence/restart-defeat.png), [новая сессия](survival-deep-evidence/restart-new-session.png). Выполнен осмотр кадра новой сессии; это не ручное прохождение.

Ограничения:100 повторов проверяют узлы/группы/orphans, не RSS/VRAM и не доказывают отсутствие любых resource leaks. Основная серия — scrapyard; synthetic hazard fields проверены на сброс, длительное прохождение всех биомов после Restart не выполнялось. После результата визуальные хвосты существующих VFX могут естественно доживать, но producers остановлены; Restart удаляет их сразу. Восстановление коллизий выполняется на deferred boundary, поэтому assertions следует делать после обработки запроса. Длительность rebuild и frame-time не профилировались; сложные арены могут давать короткую паузу. Прямое синхронное start_round остаётся внутренним API для тестов/координатора — физические callbacks должны использовать deferred request.

## Навигация и встречное движение — 2026-10-23

Изменения: scripts/arena.gd (get_navigation_obstacles), scripts/arena_navigation.gd, scripts/arena_bot.gd; новый tests/arena_navigation_routes_smoke.gd; QA/deep dive/план. Физика Vehicle, ресурсы арены/автомобилей, оружие/волны и механика бонусов не перенастраивались.

Причины:

- AStar обходил крупные layout slots, а физика — более узкие alpha-derived hull. Особенно сильно это отличалось у центра. Одновременный трафик направлялся в обходные узкие участки.
- Ближайшая открытая клетка около goal могла лежать в другой связной компоненте; Array пути не объяснял caller, куда он фактически ведёт.
- Recovery длинной машины проверял задний ход окружностью вместо ориентированного корпуса; в некоторых позах консервативный запас запрещал даже физически свободное отступление.
- Две встречные машины имели одинаковую стратегию остановки/реверса без права преимущественного проезда.

Новый контракт:

- route_result(start,goal,radius) возвращает status, path, requested, resolved. EXACT заканчивается строго в goal; NEAREST заканчивается в доступной точке; NONE содержит пустой path. Старый route() возвращает path этого результата и сохраняет совместимость с bonus placement и тестами.
- Если ближайшая клетка цели недостижима, flood fill по компоненте старта выбирает ближайшую достижимую клетку. Начальное соединение с сеткой проверяется; при необходимости выбирается другая видимая свободная клетка. Не выдаётся маршрут из-за пределов arena bounds.
- Основные envelopes теперь AABB настоящих collision hull, MapProps и barrels учитываются как раньше. Расчёт clearance дополнен max с половиной диагонали физического footprint: длина корпуса учитывается при повороте. Grid всё ещё консервативен; это не поиск в пространстве (x,y,heading).

Реакция ArenaBot: NEAREST задаёт конечную точку торможения и исключает бессмысленный reverse у её достижения; недоступный supply снимается с фиксации на7s. NONE останавливает движение, а если машина уже находится внутри консервативной зоны, допускает до двух попыток recovery до получения нового EXACT. Нет цели «ехать сквозь препятствие». Не-EXACT проверяется заново каждые.65s, поэтому разрушение препятствия может открыть путь.

Локальная встречная уступка: opposing headings dot<−.35, сосед впереди ближе200 и в общей полосе; задержка низкой скорости .9s. Из пары уступает больший instance_id, поэтому два AI не начинают одинаковый манёвр одновременно. Выбирается проверенная боковая/задняя площадка, строится альтернативный путь; используется прежний reverse control (не телепорт/поворот на месте). Intent уступания ограничен6s, повтор не ранее12s; цель clamped до проверки. Неподходящая площадка отвергается. Текущий _victim не рассматривается как обычный traffic peer, чтобы сохранить боевой таран.

Задний габарит: cast_motion реального ConvexPolygonShape2D с margin2, исключением собственного RID и учётом динамических тел. Дополнительно вычисляется предел по границам арены с учётом текущего угла корпуса; это сохраняет wall-braking contract. Физические коллизии/CCD остаются включены.

### Проверки движения

Изолированная копия, Godot4.7.2, headless, fixed-fps60. Тест создаёт настоящую Arena из resources/default_arena.tres и реальные Vehicle/ArenaBot. GoalDriver меняет только выбор тактической цели, сохраняя driving, avoidance, traffic, damage factors и recovery. Оружие не используется; здоровье тестовых акторов повышено, чтобы не смешивать уничтожение с проходимостью. Целевая область radius55; это физическое прибытие в область, не требование остановиться точно в математической точке.

Маршруты для Raider/Bastion/Behemoth/Arbiter:

| Сектор | Start → Goal |
|---|---|
| Центр | (350,520) → (650,180) |
| Контейнеры | (120,320) → (410,160) |
| Внешний путь от правого входа | (900,100) → (900,650), начальный угол PI |
| Нижний коридор | (350,650) → (850,650) |

Все16 достигнуты. Внешний путь Arbiter проходит через подходящие обходы, а не обязательно через физически узкий зазор справа от автобуса. До изменения envelope восемь перекрёстных машин в исследовательском прогоне достигали лишь2/8 целей за90s; после —8/8. Эти прогоны диагностические, не строгий benchmark: случайные углы props и instance_id влияют на результат.

В подтверждённом прогоне:

- critical wheels Bastion: нижний маршрут5.53s, объезд центра21.77s; longest stop.18/.25s, reverse0.
- Встречная пара Bastion/Behemoth: обе области достигнуты за15.87s; longest stop1.53/1.03s; по1 reverse, один yield. Коллизии не отключались.
- Дополнительная встречная пара у контейнеров: (375,160) ↔ (375,500), обе области достигнуты за19.55s; longest stop1.43/1.47s, reverse2/1. Машины использовали подходящие обходы вместо попытки протиснуться через узкую щель.
- Восемь одновременно пересекающих арену машин:8/8 за39.92s; longest stop от.6 до4.73s; reverse attempts0–5.
- В финальном прогоне с добавленной контейнерной парой группа8 снова достигла всех целей, за61.77s; longest stop≤1.8s. Один участник использовал14 reverse attempts, остальные0–3. Instance_id и случайные углы props меняют ход трафика; быстрый первый прогон не является гарантией времени разъезда.
- Arbiter к недоступному центру:40s наблюдения, NEAREST, итоговая скорость≈.12; у конечной точки нет повторного reverse.
- arena_driver_regression: все7 контрольных car/bike/boss маршрутов и wall-braking PASS; arena_bot_navigation_integration: distance816.78, hard-steer flips0, PASS.

Дополнительные регрессии: bonus_placement_smoke (5 арен/4 размера), survival_smoke, survival_round_guard_smoke, survival_transition_stability_smoke, race_finish_smoke, release_candidate_smoke, combat_vfx_budget_smoke (Restart), idle_steering_smoke, arena_bot_ai_smoke — PASS. Новых GDScript errors в финальных запусках нет. У отдельных старых smoke сохранены известные audio shutdown ObjectDB/resources warnings.

### Ограничения

Глобального диспетчера/резервирования полос нет. При настоящем физическом тупике, недоступной площадке уступания или постоянном внешнем толчке универсальный выход не гарантирован. В диагностике Arbiter, поставленный в тесную правую область (900,180) носом в стену, мог застрять; это не использовано как доказательство внешней проходимости — финальный внешний тест начинается на свободном верхнем въезде. NONE ограничивает попытки восстановления, но не создаёт пространство, которого нет. Изменение препятствий не потребовалось для перечисленных свободных маршрутов.

Критические колёса проверены при штатном auto-repair (малая доля от увеличенного тестового HP колёс); сложные столкновения с большими повреждениями всех модулей не моделировались. Остановкой считается speed<12; reverse attempt — вход в reversing, не обязательно неудача. Результаты относятся к этим траекториям и выбранному seed4217, не гарантируют все случайные матчи. Полный100-Restart soak после этого AI-изменения не повторялся; короткий Restart и переходы волн проверены. Нового GUI/manual playtest и GPU profiling в этой задаче не было.

Геометрия/оформление основной арены сохранены. Другие задачи дорожной карты не выполнялись.

Сырые логи: [navigation-evidence/](navigation-evidence/). Продолжительность в них — physics frames/60, не замер wall-clock времени.

## Выполненные проверки первоначального аудита

| Проверка | Результат | Что подтверждает |
|---|---|---|
| `tests/survival_smoke.gd` | PASS, 0 failures | старт Survival, 5 врагов, HUD, bullet damage, Arbiter, переход раунда, поражение |
| `tests/race_finish_smoke.gd` | PASS | 3 круга, позиция, ремонт, finish, DNF, Retry/Menu |
| `tests/release_candidate_smoke.gd` | FAIL | падает только assertion `VFX budget cap`; остальные проверки скрипта выполняются до него |
| `tests/arena_smoke.gd` | ранее PASS | конфигурация арены, препятствия и supply pads |
| `tests/arena_bot_navigation_integration.gd` | ранее PASS | реальное физическое движение бота и navigation recovery |
| `tests/rolling_steering_smoke.gd` | ранее PASS | скорость-зависимый руль, инерция, reverse, idle steering |
| `tests/survival_art_review.gd` | ранее PASS | рендер Survival 1280×720/800×600 и визуальная читаемость |
| `git diff --check` | ранее PASS | отсутствие whitespace-ошибок |

## Обнаруженная проблема

`tests/release_candidate_smoke.gd` создаёт 70 impact events и ожидает `CombatVFX.events.size() <= 48`. Фактически assertion `VFX budget cap` не проходит. Это регрессия/несогласованность между release-критерием и текущим runtime; код игры во время этого аудита не изменялся. Рекомендуемая проверка: сопоставить лимит в `scripts/combat_vfx.gd` с тестом и решить, должен ли лимит быть жёстким при 70 синхронных событиях.

## Тестовые ограничения

- PASS smoke-теста не означает визуальный ручной playthrough.
- Headless Godot завершает некоторые тесты с `ObjectDB instances leaked` и `resources still in use`; exit code у проверенных Race/Survival равен 0, но cleanup требует отдельного расследования.
- Не проверялись вручную все разрешения, все биомы, длительная волна с активным AI, gamepad, звук на реальном устройстве и восстановление после принудительного завершения.

## Приоритеты рисков

- **P1:** release-gate не проходит из-за VFX budget assertion.
- **P1:** утечки ObjectDB/resources на завершении headless-тестов могут маскировать lifecycle-проблемы.
- **P2:** крупные координаторы `Game`/`Survival` и прямые node-path связи повышают риск регрессий.
- **P2:** долгий баланс AI, оружия и волн покрыт слабее, чем deterministic smoke.
- **P3:** часть визуальных review-скриптов проверяет кадр, но не субъективную читаемость при движении.

