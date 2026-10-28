# Metal Road — приёмка VehicleCatalog и атрибуция задержек BonusPickup

Дата: 2026-10-28. Godot 4.7.2 Flathub, OpenGL Compatibility, AMD Radeon RX 580 / radeonsi, Linux 6.8.0-138, окно 1280×720, VSync около 60 FPS. Это автоматические графические прогоны, не ручное прохождение. Игровые скрипты и ресурсы рабочего проекта не менялись.

## Полный регрессионный набор VehicleCatalog

Полный tests/run_vehicle_catalog_regressions.sh запущен **один раз последовательно** в копии окончательного рабочего дерева: **19/19 PASS, exit 0, 212 секунд**. Содержимое runner и исправленных тестов после запуска не менялось. Добавленные позднее диагностические тесты в его список не входят.

| Тест | Результат | Тест | Результат |
|---|---|---|---|
| vehicle_catalog_cache_smoke | PASS | profile_recovery_smoke | PASS |
| garage_loadout_smoke | PASS | garage_smoke | PASS |
| pre_race_smoke | PASS | career_gameplay_smoke | PASS |
| race_finish_smoke | PASS | controls_smoke | PASS |
| survival_smoke | PASS | survival_playability_smoke | PASS |
| survival_boss_schedule_smoke | PASS | survival_biker_crew_smoke | PASS |
| survival_roguelite_smoke | PASS | survival_round_guard_smoke | PASS |
| survival_restart_smoke | PASS | survival_reward_feedback_smoke | PASS |
| tactical_arsenal_smoke | PASS | release_v1_smoke | PASS |
| release_candidate_smoke | PASS | — | — |

Ошибок GDScript, Parse Error и тестовых FAIL нет. В 11 из 19 headless-логов Godot напечатал при выходе ObjectDB leaked instances / resources still in use at exit. Это сообщения teardown, они не доказывают утечку во время игры. controls_smoke выполнялся с предусмотренным runner --max-fps 60; boss schedule имел штатный timeout 300 секунд, остальные тесты — 120 секунд. Timeout не сработал. [Общий лог](bonus-pickup-evidence/regression-summary.log), [тайминг](bonus-pickup-evidence/regression-timing.txt), [19 отдельных логов](bonus-pickup-evidence/regressions/), [снимок Git diff перед запуском](bonus-pickup-evidence/git-diff-before.patch).

Предыдущие 18/19 и отдельный PASS исправленного survival_reward_feedback_smoke остаются историей первичной приёмки; этот полный запуск закрывает недостающую последовательную проверку. По текущему Git diff сам scripts/loadout_profile.gd не изменён относительно HEAD: кэш VehicleCatalog уже содержится в базе рабочей копии. Итоговый diff и untracked files фиксируются отдельно в evidence.

## Путь создания поставки

Survival задаёт первую поставку через 2.8 с с предупреждением 1.0 с, затем интервал 5.0 с, обычную партию из трёх ящиков (минимум два оружейных) и max_active=6 при отсутствии модификатора. В BonusSpawner._announce_next_pickup объекты создаются **до** предупреждения, а через 1 с _arm_announced_pickup включает сенсоры и регистрирует активные ящики. Race использует тот же spawner с другими настройками; они не менялись.

Рабочая цепочка: BonusSpawner._create_pickup → _next_position (новый snapshot ArenaNavigation, проверки геометрии, hazards и пути) → PackedScene.instantiate (BonusPickup.tscn: Area2D и CircleShape2D радиусом 50) → выбор kind → для оружия load(resources/weapons/*.tres) → pickup.setup → add_child → BonusPickup._ready (группа, collision mask, body_entered, monitoring, Label badge) → позиция/сигнал → HUD/audio объявления → через 1 с set_armed и регистрация. SUPPLY_CRATE — preload в скрипте BonusPickup; он не загружается при каждом spawn. Оружейный .tres ссылается на отдельный PNG крыши; BonusPickup._draw показывает его на ящике. При **подборе**, а не создании, collect активирует оружие/ремонт/boost, после чего Survival обновляет счёт, HUD, audio и VFX. В первых партиях игрок обычно не собирал ящики, поэтому ветка подбора не приписывается spawn-пику.

Этапы измерены Time.get_ticks_usec вокруг существующих вызовов в **одноразовой копии**. [Инструментатор](../../tests/instrument_bonus_pickup_profile.py) и [diff spawner](bonus-pickup-evidence/spawner-instrumentation.diff) / [diff pickup](bonus-pickup-evidence/pickup-instrumentation.diff) воспроизводят замеры. Дополнительный ResourceLoader.has_cached служит меткой холодного/тёплого обращения. tree_add_including_ready включает вложенный _ready: эти строки **нельзя складывать**. Нативная физическая регистрация, отложенная движком до следующего physics tick, отдельно не измерена. Прямые вызовы создания CircleShape2D входят в instantiate, настройка/активация сенсора — в ready/set_armed.

## Графические прогоны и кадры

Каждый bonus-* ID — новый процесс Godot. Все первые окна длиной 13 с (около 780 кадров) включают две естественные партии по три ящика, двух начальных и третьего отложенного AI. Чтобы матч не завершился, скрипт вызывает repair_full каждые 0.25 с: это **тестовый fixture**, не обычное выживание. При pilot=0 игрок не получает ввод, AI двигаются штатно. В combat программный водитель подаёт обычные Input actions, двигался/стрелял и подобрал один ящик; это также не ручной тест. После окна отдельный forced-types fixture вызывает spawn_random_bonus(kind) дважды для оружия и по разу для остальных трёх видов. Он отделён от естественных партий и не влияет на кадры таблицы.

mean/p95/p99/max — интервалы между SceneTree._process timestamps, мс; p95/p99 — nearest rank. VSync удерживает среднее около 16.7 мс и не раскрывает свободную производительность GPU.

| Процесс / окно | Инструм. | mean | p95 | p99 | max | AI max |
|---|---|---:|---:|---:|---:|---:|
| b4217-a / первый вход | нет | 16.680 | 16.918 | 17.158 | 48.708 | 3 |
| b4217-b / первый вход | нет | 16.694 | 16.915 | 17.125 | 56.186 | 3 |
| i4217-a / первый вход | да | 16.691 | 16.912 | 17.196 | 56.905 | 3 |
| i4217-b / первый вход | да | 16.682 | 16.923 | 17.245 | 49.214 | 3 |
| i104729-a / первый вход | да | 16.690 | 16.953 | 17.197 | 66.770 | 3 |
| i4217-menu / первый вход | да | 16.708 | 16.917 | 17.139 | 57.326 | 3 |
| i4217-menu / повторный вход | да | 16.685 | 16.956 | 17.151 | 55.223 | 3 |
| i4217-restart / до Restart | да | 16.686 | 16.930 | 17.156 | 48.885 | 3 |
| i4217-restart / после Restart | да | 16.667 | 16.949 | 17.112 | 44.454 | 3 |
| i4217-combat / движение+AI | да | 16.681 | 16.954 | 17.224 | 48.835 | 3 |
| i4217-post / побочные стадии | да | 16.684 | 16.956 | 17.144 | 49.241 | 3 |

В i4217-a первая партия включала холодный rocket_launcher.tres: его load занял 22.959 мс, весь первый _create_pickup — 24.751 мс, кадр партии — 48.975 мс. Во второй партии холодные flamethrower и machine_gun заняли 21.601+11.362 мс; кадр — 56.905 мс. В i104729-a две холодные загрузки в первой партии дали кадр 66.770 мс. Кадры выше затрат самого spawner, поскольку включают остальную физику, AI, отрисовку и ожидание VSync. В исходном профиле VehicleCatalog кадр 35.457 мс не был покадрово инструментирован; **именно его** нельзя ретроспективно объявить доказанным бонусным stall. Новые запуски подтверждают тот же механизм для повторяющихся пиков до подкрепления.

Два baseline и два instrumented запуска seed4217 имеют перекрывающиеся p95/p99 и max в обе стороны (48.708/56.186 против 56.905/49.214 мс). Инструментация **не создаёт** сама десятки миллисекунд задержки, но её точная стоимость здесь не изолирована: kind bag использует глобальный Array.shuffle, а прочие игровые события и instance IDs меняют последовательность выбора даже при одинаковом BonusSpawner._rng.seed. Это не строго парный A/B. Независимый resource-only probe ниже подтверждает источник.

## Стоимость стадий

Агрегация 48 естественных созданий в шести инструментированных процессах, мс. Малые выборки холодных загрузок не позволяют оценить долгосрочный p99.

| Стадия | n | mean | p95 | p99 | max |
|---|---:|---:|---:|---:|---:|
| Позиция и проверка маршрута | 48 | 1.482 | 1.662 | 1.751 | 1.751 |
| Выбор kind | 48 | 0.001 | 0.003 | 0.003 | 0.003 |
| PackedScene.instantiate | 48 | 0.021 | 0.032 | 0.034 | 0.034 |
| load(WeaponConfig), cache miss | 17 | **20.364** | 25.041 | 25.041 | 25.041 |
| load(WeaponConfig), cache hit | 22 | **0.005** | 0.007 | 0.007 | 0.007 |
| pickup.setup | 48 | 0.002 | 0.004 | 0.004 | 0.004 |
| add_child, включая _ready | 48 | 0.201 | 0.259 | 0.293 | 0.293 |
| _ready целиком, вложено | 48 | 0.176 | 0.220 | 0.263 | 0.263 |
| Позиция, connect, индекс после дерева | 48 | 0.005 | 0.006 | 0.006 | 0.006 |
| Первая _draw | 48 | 0.045 | 0.062 | 0.064 | 0.064 |
| _create_pickup целиком | 48 | 8.949 | 25.015 | 26.820 | 26.820 |

В выделенном i4217-post: ready.sensor_config mean 0.004/max 0.006 мс; ready.monitor mean 0.004/max 0.007; создание badge mean 0.119 мс в основной выборке. bonus_announced.emit с HUD/audio занял 0.466 и 0.027 мс (2 партии); set_armed mean 0.026/max 0.044 мс (6 ящиков); active registration max 0.003 мс, bonus_spawned.emit max 0.001. Нативная стоимость последующего physics solver остаётся внутри общего кадра. В forced-types fixture все 5 позиций успешны: два повторных оружейных rocket_launcher — cache hit по 0.006/0.005 мс, а ремонт/ускорение/таран созданы без load(WeaponConfig).

Отдельный графический [resource probe](../../tests/bonus_resource_probe.gd) в **трёх новых процессах** отделил текстуру от конфигурации:

| Режим | Холодное изображение | Затем .tres | Повтор .tres |
|---|---:|---:|---:|
| cold: сразу rocket_launcher.tres | внутри .tres | 25.354 мс | 0.004 мс |
| image_first: сначала PNG крыши | **25.133 мс** | **0.218 мс** | 0.006 мс |

PNG крыши Rocket Launcher — 1536×1024 RGBA; большинство roof PNG близкого размера. Подтверждённая причина данного класса stall — **синхронная первичная загрузка/создание текстур, транзитивно вызванная load(WeaponConfig) внутри _create_pickup**. Probe не разделяет чтение файла, декодирование/импорт и загрузку на GPU; утверждать, какая внутренняя операция доминирует, нельзя. Создание Label, сцены и сенсора не объясняет десятки миллисекунд.

## Память и жизненный цикл

В изолированном all_weapons probe удержание сильных ссылок на все 7 WeaponConfig/roof textures заняло 155.631 мс. RENDER_VIDEO_MEM_USED вырос с 13.17 до 69.17 МиБ (**+56.00 МиБ**), RENDER_TEXTURE_MEM_USED с 7.06 до 63.05 МиБ, число ресурсов 16→30. После освобождения ссылок и одного кадра video/texture monitors вернулись к исходному значению, resources 30→16. Это оценка Godot для выбранного renderer, не аппаратный счётчик VRAM. MEMORY_STATIC вырос примерно на 0.04 МиБ; он не учитывает всю память драйвера/OS. RSS после загрузки семи ресурсов вырос с 190.79 до 191.39 МиБ, после кадра до 192.20 МиБ; небольшой прирост RSS **не** означает, что текстуры стоят лишь 1.4 МиБ RAM. RSS включает резидентное пространство всего процесса, зависит от аллокатора/драйвера и не складывается с video monitor.

Графический [lifecycle probe без массивов кадров](../../tests/bonus_memory_soak.gd) запускал 10 Restart и 5 повторных входов через меню, ожидая первую партию в каждом цикле. После первого supply и 10-го Restart: nodes **206→206**, resources **182→182**, video **321.55→321.55 МиБ**, MEMORY_STATIC **49.42→49.40 МиБ**, RSS **255.79→255.99 МиБ**. При пяти menu reentry после первого: nodes **206→206**, resources **199→199**, video **340.45→340.45 МиБ**, MEMORY_STATIC около **52.04→52.10 МиБ**, RSS **280.51→281.41 МиБ** с плато после 1–2 входов. Меню и PreRace держат дополнительные ресурсы, поэтому сравнивать 182 с 199 как утечку нельзя. В instrumented memory-loop MEMORY_STATIC рос примерно на 0.14 МиБ на окно, потому что profiler сохранял кадры и события до конца процесса; его нельзя использовать как leak-test. Короткие серии не доказывают отсутствие долгосрочной утечки, но роста объектов/видеоресурсов в проверенных циклах нет.

После Restart и menu reentry ранее использованный rocket_launcher.tres снова имел ResourceLoader.has_cached=false и загружался за примерно 22–25 мс. Preloaded emp_cannon оставался cache hit. Выгрузка ресурсов между сессиями сейчас работает; будущая сильная ссылка сделает память постоянной до конца выбранного владельца/процесса и требует явного бюджета.

## Рекомендация, без внедрения

Минимальный вариант для отдельной задачи — **ограниченный набор ровно из семи WeaponConfig**, подготавливаемый один раз во время существующего перехода/загрузки и удерживаемый общей сильной ссылкой до выхода из процесса. Использовать те же ресурсы и weapon_paths; не менять выбор kind, равномерный выбор оружия, batch/interval/TTL, safe placement, E/X/□, авто-ремонт HP, статы оружия и Race. Вариант переносит измеренные около 156 мс суммарной подготовки из боевых кадров во вход и стоит около 56 МиБ по Godot video monitor в этом renderer. Простое lazy-кэширование после первого load устранит повторный stall при Restart/menu, **но оставит первый холодный stall**. Если дополнительные 0.16 с на входе неприемлемы, проверить ResourceLoader.load_threaded_request во время существующего перехода, затем измерить стоимость завершения/первой отрисовки на основном потоке. Не вводить бесконечный кэш видов или экземпляров ящиков.

Критерии отдельного исправления: в новом процессе и после 10 Restart/5 menu reentry нет холодного load на physics tick партии; количество/виды/позиции/длительность бонусов совпадают с baseline, Race/Survival/release regression PASS; mean/p95/p99/max измерены в графике; RSS/MEMORY_STATIC/RENDER_VIDEO_MEM_USED после прогрева ограничены и стабилизируются. Сначала измерить цену входа, затем выбирать sync preload или threaded путь. **Оптимизация здесь не внедрялась.**

## Фактический Git diff и файлы

Перед этой диагностикой рабочее дерево уже содержало семь изменённых tracked файлов: QA-отчёт, план Survival, отчёты о performance и кэше, tests/run_vehicle_catalog_regressions.sh, tests/survival_reward_feedback_smoke.gd и tests/vehicle_catalog_cache_smoke.gd; отдельно существовал untracked README прежнего VehicleCatalog evidence. Снимок непосредственно перед регрессией содержит также уже созданную папку для новых логов. Эти правки не были перезаписаны.

В рамках текущей задачи добавлены docs/reports/METAL_ROAD_BONUS_PICKUP_PROFILE.md, папка docs/reports/bonus-pickup-evidence/ с логами/JSON/diff и шесть диагностических файлов: tests/bonus_pickup_profile.gd, tests/bonus_pickup_probe_stats.gd, tests/instrument_bonus_pickup_profile.py, tests/analyze_bonus_pickup_profile.py, tests/bonus_resource_probe.gd, tests/bonus_memory_soak.gd. Актуализированы только QA-отчёт, план и историческая фраза в отчёте VehicleCatalog о статусе полного набора. Ранее изменённый отчёт performance, runner и два regression-теста не менялись в этой задаче после снимка перед запуском. Производственные scripts/bonus_spawner.gd, scripts/bonus_pickup.gd, scripts/loadout_profile.gd, игровые ресурсы и баланс не имеют нового Git diff. [Итоговый tracked diff](bonus-pickup-evidence/git-diff-final.patch), [полный статус включая untracked](bonus-pickup-evidence/git-status-final.txt), [статистика](bonus-pickup-evidence/git-diff-stat-final.txt).

MachineGun.equip при подборе оружейного бонуса лишь присваивает уже загруженный WeaponConfig и сбрасывает счётчики; этот путь не вызывает load. В программном бою одно оружие было подобрано на 8.626 с, в окрестности ±0.15 с максимальный кадр составил 19.693 мс против 48.835 мс максимума всего окна при первой партии. Это наблюдение не является отдельным детальным профилем HUD/оружия при подборе.

## Ограничения

- Все графические кадры сняты в автоматизированной игре при VSync; аппаратный FPS без VSync, ручная читаемость бонусов и hardware GPU occupancy не проверялись. Godot viewport GPU monitor не равен загрузке видеокарты.
- Программное управление, принудительный полный ремонт каждые 0.25 с и forced-type fixture не равны естественному прохождению. Движение AI проверялось, ручное управление — нет.
- Несколько фиксированных seed не гарантируют одинаковый набор оружия из-за глобального Array.shuffle, других случайных событий и геометрии. Разница max разных процессов не является строгой оценкой накладных расходов измерителя.
- Resource probe подтвердил текстуру как большую часть задержки для Rocket Launcher; внутренние шаги импорта/декодирования/driver upload не разделены. Один renderer/GPU и несколько партий не дают универсального p99.
- Shutdown ObjectDB/resources warnings сохранены в сырых логах; графический lifecycle probe не обнаружил роста nodes/resources/VRAM после повторов, но происхождение предупреждений отдельно не расследовалось.

Репродуктор и сырые результаты: [папка evidence](bonus-pickup-evidence/), [все окна и события JSON](bonus-pickup-evidence/raw/), [анализатор](../../tests/analyze_bonus_pickup_profile.py), [графический сценарий](../../tests/bonus_pickup_profile.gd), [список процессов и методика](bonus-pickup-evidence/README.md). Отчёт опирается на сохранённые численные JSON, не на headless FPS.
