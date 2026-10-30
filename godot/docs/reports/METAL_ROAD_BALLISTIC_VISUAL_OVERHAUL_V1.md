# Ballistic Weapons Visual Overhaul v1

Дата: 2026-10-30. Ветка: codex/ballistic-visual-overhaul-v1, база HEAD 95914638b21f87b44503066d271268216ff45572. Feature-ветка создана с сохранением исходного незакоммиченного Rocket v3, отчётов и семи подготовленных PNG. main/AI совпадали по SHA; Tactical Waves уже в main. Принятый Rocket v3 ещё является рабочей зависимостью, а не отдельным коммитом: для публикации нужно сначала сохранить и интегрировать именно этот принятый срез, затем данный diff. Merge/push/commit не выполнялись.

## Архитектура и аудит

Оба оружия имеют weapon_type=BALLISTIC, но разные weapon_id и WeaponConfig. Ранее Bullet._draw рисовал круг с белым центром и линией trail_length, MachineGun._draw — процедурную вспышку, CombatVFX._draw — семь линий impact. Теперь каждый WeaponConfig ссылается на свой resources/weapon_visuals/{machine_gun,heavy_machine_gun}.tres. Выбор по enum не различает два оружия и не используется для назначения профиля.

WeaponVisualProfile расширен опциональными ballistic/tracer/impact полями. Bullet использует готовый профиль без runtime load. MachineGun уже умел рисовать профильную вспышку; его код не менялся. CombatVFX.spawn_impact получил необязательный последний аргумент profile, старые вызовы совместимы. Один impact содержит профиль и заменяет legacy sparks, не рисует обе версии. При отсутствующем или неполном projectile/impact/muzzle соответствующий компонент сохраняет legacy fallback. Проверки корректности сетки и положительных размеров обязательны.

## Исходные изображения

Все семь PNG RGBA; SHA-256 и фактические размеры сохранены в [inventory](ballistic-visual-v1-evidence/ballistic-inventory.json). README/ASSET_MANIFEST в каталоге не найдено.

| Изображение относительно assets/vfx/weapons | Размер | Разметка |
|---|---:|---|
| machine_gun/projectile_core.png | 64×32 | один снаряд +X |
| heavy_machine_gun/projectile_core.png | 96×32 | один снаряд +X |
| shared/tracer_strip.png | 128×16 | один след, яркий конец справа |
| machine_gun/muzzle_sheet.png | 128×128 | четыре различных кадра 2×2 |
| heavy_machine_gun/muzzle_sheet.png | 128×128 | четыре различных кадра 2×2 |
| shared/impact_metal_light_sheet.png | 384×256 | шесть различных кадров 3×2 |
| shared/impact_metal_heavy_sheet.png | 384×256 | шесть различных кадров 3×2 |

Вспышки имели разные левый край и вертикальный центр в своих ячейках. Производные muzzle_aligned_sheet.png сохраняют каждый исходный кадр без масштабирования, выравнивая его левую границу в x=6 и центр bounding box в y=32 каждой ячейки64×64. Это техническая нарезка принятой графики, не генерация новой. Оригиналы неизменны. Impact центрирован в каждой ячейке128×128, порядок row-major сохранён. Ударные атласы имеют заметное оранжевое ядро: окончательная оценка сходства с металлическими искрами остаётся художественной приёмкой.

## Настройки

| Параметр, игровые units | Machine Gun | Heavy MG |
|---|---:|---:|
| полотно снаряда | 10×5 | 15×5 |
| полотно следа | 16×2.5 | 23×3.5 |
| полотно вспышки | 18×18 | 25×25 |
| полотно impact | 24×24 | 34×34 |

Полотна включают прозрачные поля: видимый корпус меньше. Heavy заметнее при той же физической области попадания. Pivot снаряда0.5/0.5; след направлен к−X с концом x=−2, alpha0.7. Pivot muzzle6/64,0.5 совпадает с выровненным краем. Вспышка использует прежние65мс, четыре настоящих кадра и fade(1−progress)^1.6. Impact использует прежние240мс и fade1−progress²; рамка не растёт. Никаких новых Area2D, коллизий, шейдеров, частиц или источников света.

VFX cap48, приоритеты, урон и TTL не менялись. Vehicle/crew/статическое препятствие используют прежнюю позицию обнаруженного контакта Bullet; точность ограничена существующей дискретной проверкой, raycast/swept collision здесь не добавлялись. Разрушаемые объекты ранее не имели projectile impact: добавлен один только для этих двух профилей, отдельно от возможного взрыва бочки. Физическая обработка и damage pipeline сохранены.

## Файлы текущего изменения

- scripts/weapon_visual_profile.gd, scripts/bullet.gd, scripts/combat_vfx.gd.
- resources/weapons/machine_gun.tres, heavy_machine_gun.tres: только ссылки на visual_profile и load_steps.
- resources/weapon_visuals/machine_gun.tres, heavy_machine_gun.tres.
- Два производных muzzle_aligned_sheet.png и Godot .import. Семь исходных PNG уже существовали untracked; их также необходимо включить при будущей адресной публикации вместе с импортами.
- tests/ballistic_visual_profile_smoke.gd (+UID); tests/rocket_visual_profile_smoke.gd уточняет прежнее ожидание «все остальные оружия процедурные» для двух новых профилей, остальные проверки сохранены.
- Этот отчёт, QA, improvement plan и evidence с .gdignore.

Общий git diff также содержит предшествующий Rocket v3. Он не является частью выполненной сейчас художественной интеграции. Побайтово проверяются исходные Rocket configs/visual profile и AI/Survival против снимка до задачи; параметры обоих WeaponConfig сравниваются без новых ссылок на графику.

## Метод графической проверки

Настоящий Godot/OpenGL, реальные Vehicle, MachineGun._shoot и Bullet, Arena, CombatVFX. Матрица1280×720/800×600 × zoom1/1.23 × MG/Heavy × before/after. Каждый процесс сохраняет fire/flight/impact/moving/turning/obstacle/overview и manifest. Кадры имеют настоящий масштаб viewport, без дорисовки ассетов поверх скриншота. Сравнительные листы только компонуют исходные кадры без изменения масштаба.

Это управляемый стенд: автомобили заморожены кроме движения/поворота в отдельных фазах, оружие запускается программно. Четыре машины, включая одновременно MG/Heavy, заменяют естественную перестрелку AI. Частота принудительных выстрелов в нагрузочной фазе задана стендом; это не изменение production fire_rate. Скриншоты не подтверждают натуральное прохождение или ручную художественную приёмку.

Сравнения: [MG до/после](ballistic-visual-v1-evidence/mg-old-new.png), [Heavy до/после](ballistic-visual-v1-evidence/heavy-old-new.png), [MG против Heavy](ballistic-visual-v1-evidence/mg-vs-heavy.png). Полные кадры и manifest находятся в [evidence](ballistic-visual-v1-evidence/).

## Риски и ручная приёмка

Проверить, достаточно ли читается тонкий MG на тёмном и светлом фоне; заметна ли тяжесть Heavy на zoom1; не выглядит ли оранжевое ядро impact миниатюрным взрывом; нравится ли темп четырёх кадров muzzle при65мс. Формальное совпадение размеров не считается художественным одобрением.

Общее ресурсное удержание ограничено уже существующим BonusWeaponCache и VehicleCatalog, профили immutable. Общие tracer/impact Texture2D разделяются загрузчиком; отдельные текстуры для каждого снаряда не создаются. Это добавляет небольшой постоянный объём текстур. Предупреждения ObjectDB/resources при shutdown требуют отдельной атрибуции и не являются доказательством runtime-утечки; короткие прогоны не доказывают отсутствие всех утечек.

## Результаты тестов

Окончательный последовательный tests/run_vehicle_catalog_regressions.sh: **19/19 PASS**, failures=0. Поимённые логи находятся в evidence/regressions: vehicle_catalog_cache_smoke, profile_recovery_smoke, garage_loadout_smoke, garage_smoke, pre_race_smoke, career_gameplay_smoke, race_finish_smoke, controls_smoke, survival_smoke, survival_playability_smoke, survival_boss_schedule_smoke, survival_biker_crew_smoke, survival_roguelite_smoke, survival_round_guard_smoke, survival_restart_smoke, survival_reward_feedback_smoke, tactical_arsenal_smoke, release_v1_smoke, release_candidate_smoke. Первая предварительная серия также19/19, но начата до исправления Resource; результатом приёмки является финальная серия.

Дополнительно **6/6 PASS**: ballistic_visual_profile_smoke, rocket_visual_profile_smoke, weapon_smoke, combat_vfx_budget_smoke, race_combat_smoke, rocket_homing_v3_smoke (864cases/failures0). Новая проверка сравнивает урон с/без ассетов, размеры/ссылки/уникальность кадров, неполный fallback, ровно один event на контакт машины и препятствия, TTL и70→48. Rocket smoke адаптирован только к осознанному появлению двух профилей. Финальный editor import без ошибок GDScript; UID нового теста создан. git diff --check PASS.

Первоначальный ballistic smoke FAIL: поле visual_profile в .tres было расположено до script, поэтому не назначалось. Исправлен порядок полей, финальный smoke PASS. Первый временный графический стенд имел ошибку переменной i; исправлен до всех сохранённых измерений. Эти ошибки разработки не скрываются. Shutdown ObjectDB/resources warnings присутствуют в логах и остаются ограничением, а не установленной новой runtime-утечкой.

arena_launch_gui_smoke: **PASS** на настоящем OpenGL через InputEvent и hit test кнопок, включая вход через меню/Garage, бой, Restart, Race/Career и возврат. Полные кадры и записи в evidence/gui. Это автоматизированная GUI-проверка. Отдельный графический lifecycle20 с выстрелами MG/Heavy и impacts: после каждого Restart bullets0/events0. Штатный survival_restart_smoke проверяет100 Restart.

## Производительность и память

Godot4.7.2/OpenGL Compatibility, AMD Radeon RX580/radeonsi, Mesa26.2.4, Linux6.8.0-138. В графической матрице VSync ограничивал измерения примерно60FPS. Полная таблица mean/p95/p99/max, video memory и ресурсов: [tables.md](ballistic-visual-v1-evidence/tables.md), сырые интервалы в manifest.json каждого процесса. Первые16 процессов частично совпадали с регрессиями: before max51.274мс, after max84.711мс сохранены и не удалены из статистики. Причина этих отдельных пиков не атрибутирована; нельзя приписать их новым PNG или объявить устранёнными.

Дополнительная серия: четыре реальных gun, смешанный MG/Heavy, принудительные выстрелы каждые333мс и физический backstop для всех полос;10сек измерения каждого процесса, VSync выключен. PNG кодируются после замера. Две пары выполнялись последовательно после runner/GUI; короткий editor-import мог совпасть с частью первой серии. Вторая пара без параллельных тестов. Это нагрузочный fixture с фиксированными машинами, не естественный AI бой.

| Серия | mean ms | p95 | p99 | max | Max impact events |
|---|---:|---:|---:|---:|---:|
| before1 | 0.820 | 0.929 | 1.055 | 5.136 | 8 |
| after1 | 0.788 | 0.893 | 0.989 | 1.199 | 8 |
| before2 | 0.811 | 0.943 | 1.078 | 3.103 | 8 |
| after2 | 0.798 | 0.903 | 1.031 | 6.382 | 8 |

Средние и p99 не показывают роста затрат в этом коротком стенде, но max after2 выше. Это не доказательство ускорения, отсутствия всех кадровых пиков или конкретной GPU стоимости: GPU timestamps/процент загрузки не измерены. Перестройка AI/физики и оптимизация ради PASS не выполнялись. Полный VFX budget48 отдельно покрыт smoke, нагрузочный fixture достигает8.

В сопоставимом MG mixed графическом процессе1280/zoom1: video counter before253.33MiB/145resources, after254.52MiB/154resources. Это показатели одного процесса с двумя weapon profiles, а не сумма разных процессов; разница≈1.19MiB и9resources. Значения включают арену и модели, не только оружейные текстуры. Другие строки меняют используемое оружие/кадры и не являются точной ценой кэша.

Графический lifecycle20: nodes197→197, resources205→205, orphans0→0; MEMORY_STATIC58,573,421→58,499,953bytes. RENDER_VIDEO_MEM_USED374,850,309→385,501,269bytes, причём последние7циклов одинаковы. Это прогрев/изменение выделенной памяти в короткой серии; причину≈10.16MiB прироста отдельно не атрибутировали, бесконечную стабильность не заявляем. Все20сбросов bullets/events=0. Сырые counters — ballistic-lifecycle.json. RSS внутри Flatpak недоступен из fixture и не заменён MEMORY_STATIC. Долгая сессия и аппаратный gamepad этой задачей не проверены.

Все исходные7PNG проверены SHA-256 после работы; Rocket configs/visual-profile и AI/Survival побайтово совпадают со снимком до задачи. Боевые поля обоих пулемётов совпадают после исключения новой ссылки visual_profile. Временные профили тестов перенесены из корня в evidence/test-artifacts; производственных тестовых ресурсов нет. .godot и временные инструменты в коммит не включались. Существующее незакоммиченное дерево сохранено.
