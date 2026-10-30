# Destroyed Vehicle Wrecks v1

Дата: 2026-10-30. Godot4.7.2. Ветка codex/destroyed-vehicle-wrecks-v1 создана от актуального рабочего состояния codex/ballistic-visual-overhaul-v1; HEAD95914638b21f87b44503066d271268216ff45572. После fetch main/origin/main/HEAD совпадали, уникальных коммитов нет. Незакоммиченные Rocket v3, Ballistic v1, Driving/Wave Recovery и предыдущие отчёты сохранены. Commit/push/merge не выполнялись. Before — снимок рабочего дерева с этими принятыми задачами, не старый HEAD без них.

## 1. Фактическая архитектура до изменения

| Вопрос аудита | Ответ |
|---|---|
| Что остаётся после гибели? | Сам Vehicle/RigidBody2D, а не отдельный остов. Survival сохранял его в _enemies до следующей волны. |
| Есть отдельный Node2D/PNG остова? | Нет. Vehicle рисует исходный config.texture; AnimationPlayer destroyed за0.8с меняет modulate до(0.32,0.28,0.24). VehicleEffects/DamageOverlay добавляют прежние копоть, дым, огонь. |
| Есть коллизия? | ConvexPolygonShape2D остаётся, но Vehicle._disable_destroyed_physics deferred устанавливает collision_layer=0/mask=0/freeze=true. Она перестаёт участвовать в контактах. |
| Взрыв? | VehicleEffects.explode плюс Survival._on_vehicle_died→CombatVFX.spawn_explosion и audio.play_explosion. Новая система второй взрыв не добавляет. |
| Удаление по таймеру? | Отдельного TTL нет. _clear_enemies скрывает/queue_free при старте следующей волны или полном Restart. |
| Повторная смерть? | Vehicle._die проверяет alive, но повторное ручное died.emit не имело отдельной защиты координатора. |
| Разные классы? | Размеры/текстуры исходного VehicleConfig и octagonal hull, включая элит, байкеров и Арбитра. Обработчик Survival общий. |
| Race/Career? | Общий Vehicle._die выключает коллизии. Новая механика подключена только при пустом career_event; Race и Career остаются на прежнем пути. |

Центральная груда scrapyard, ArenaConfig и experiments/movable_wreck не используются как замена уничтоженному боту. Их код не изменён.

## 2. Воспроизведение дефекта и production GUI

В before через реальные InputEvent/hit test выполнен Main Menu→Survival→«Выйти на арену». Штатный бот перемещён в контролируемую открытую нижнюю полосу(700,850), rotation0, затем уничтожен настоящими снарядами Heavy MG без изменения HP/урона/скорострельности. Оружие выдано тестом вместо ожидания случайного pickup; это автоматизированная графическая проверка, не ручное прохождение.

До смерти тело layer1/mask1; после смерти тот же Vehicle существовал в(700,850), но layer0/mask0. Игрок начал наезд от(595,860) и прошёл к(812.05,860), затем остановился около(852.45,860). Физического отдельного остова не было. Графика: [before](destroyed-vehicle-wrecks-v1-evidence/before-1280/push.png), исходные координаты в before-1280/telemetry.json.

После изменения погибший Vehicle передаёт неизменный hull и ресурсы отдельному RigidBody2D на deferred idle. Его старый physics disable уже поставлен в очередь раньше handoff. Старый Vehicle скрывается и освобождается, удаляясь из _enemies через tree_exiting; навигация и подсчёт живых врагов используют новый cover и оставшихся живых соответственно. Старый Vehicle больше не хранит невидимое физическое тело до конца волны.

GUI после изменения подтверждает body_entered, перемещение/поворот и сохранение зазора между корпусами. В одном сохранённом проходе игрок(707.57,857.51) толкал остов(771.19,837.71), затем остов остановился около(782.45,834.93), angle−0.17154rad. Старый Vehicle уже отсутствовал. Финальные повторения содержат отдельные точные координаты/скорости/формы/physics-frame/tick-us/AI goals в final-1280 и final-800/telemetry.json; они могут отличаться от раннего прохода из-за момента первого контакта.

Обычный оставшийся ArenaBot из штатного спавна включён снова и преследует реального игрока с другой стороны остова. Проверены фактическое приближение, Restart через GUI, выход в меню и повторный вход без старых тел. В1280×720 Start нажат мышью; в800×600 использованы настоящие клавиатурные GUI-события для Start, поскольку временный viewport resize меняет соответствие экранных координат. Производственный UI этим заданием не изменялся.

Кадры: [последовательность1280](destroyed-vehicle-wrecks-v1-evidence/GUI-sequence-1280.png), [800](destroyed-vehicle-wrecks-v1-evidence/GUI-sequence-800.png), [before/after](destroyed-vehicle-wrecks-v1-evidence/before-after.png). Листы компонуют настоящие игровые пиксели без дорисовки и масштабирования.

## 3. Новый объект и контакты

scripts/destroyed_vehicle_wreck.gd — отдельный RigidBody2D без Vehicle controls, боевого HP, take_damage, группы combatants и повторной смерти. snapshot берёт position/rotation, конфигурацию, копию исходного ConvexPolygonShape2D и material damage overlay. Разные классы сохраняют собственные габариты; одного большого прямоугольника на всех нет.

Текстура кузова/ориентация/размер Vehicle.VISUAL_SCALE и burnt tint сохранены, включая self_modulate обычных ботов и прежний damage shader. Дым, огонь, взрывные particles и искры переподчиняются новому физическому телу вместо создания дубликатов; shader/Texture2D разделяются, новые PNG не генерируются. Chassis локально в(0,0), движется и поворачивается с телом. z_index−1, z_as_relative=true — рисунок ниже исправных машинz0; это дополнение к настоящей коллизии, не способ скрыть проезд.

| Параметр | Значение |
|---|---|
| collision_layer | 5 = обычный body bit1 + отдельный cover bit4 |
| collision_mask | 1, контакты с машинами/стенами/другими остовами |
| масса | max(1400, исходная масса×1.6) |
| gravity | 0 |
| linear/angular damping | 4 / 7 |
| friction/bounce | 0.65 / 0 |
| CCD | CAST_SHAPE |
| предел скорости остова | 120units/s, angular≤2rad/s |
| начальная скорость | 0, соответствует прежней остановке Vehicle._die |

Характеристики исправных Vehicle не изменены. Идентичная прежнему Vehicle форма заменяется после отключения старой: нет одновременно двух solid hulls на месте одной машины. Ограничители скорости самого остова сдерживают depenetration при рамминге/глубоком начальном пересечении. Отдельно проверено искусственное совпадение центров погибающего врага и игрока: скорости конечны/ограничены, объект не запускается произвольным сильным импульсом. Контактные исключения, телепортация при ударе и отключение коллизий для проезда не используются.

Физический тест на реальном default_arena, обычная физика60Hz:

| Толкающая машина | исходная скорость | сдвиг после удара | после продолжительного толкания | финальный угол, rad | остаточная скорость |
|---|---:|---:|---:|---:|---:|
| Raider | 18 | 1.183 | 36.646 | −0.0966 | 0.00085 |
| Raider | 165 | 12.581 | 46.297 | −0.1146 | 0.00085 |
| Behemoth | 18 | 1.949 | 42.992 | −0.0781 | 0.00098 |
| Behemoth | 165 | 14.498 | 55.628 | −0.0975 | 0.00098 |

Во всех четырёх случаях зарегистрированы body contacts, нет кадров с центром машины внутри wreck hull. Проверены второй тяжёлый автомобиль, остановка после контакта, вращение и физическая граница арены. Это не доказательство нулевой микропенетрации контактного solver во всех возможных столкновениях.

## 4. Снаряды и урон

Bullet._hits_wreck(previous_position) делает segment ray query только по cover bit4. Поэтому live Vehicle/RigidBody2D не превращаются в статические стены, а узкий байкерский кузов не пропускается быстрым снарядом между двумя physics ticks. Место попадания — contact.position; затем используется прежний _impact/_detonate один раз. Legacy static point queries и порядок destructible damage сохранены.

Проверены MG, Heavy MG, Shotgun, Rocket Launcher, Flamethrower, EMP Cannon: снаряд останавливается/детонирует и создаёт один event в пределах фактической поверхности. Rocket сохраняет splash/TTL/урон/ослабленное homing и профиль; ballistic profiles сохранены. Mine Layer сохраняет прежнюю модель: мины реагируют на живые combatants, не на остов. Остов не имеет HP, не взрывается повторно и не получает дополнительного explosion impulse. Существующий splash damage живым машинам не получил новой проверки LOS; укрытие блокирует прямые снаряды, не вводит новую модель распространения взрыва.

При физическом контакте новый wreck передаёт импульс штатным solver; новый HP-урон от удара о dynamic cover не добавлялся. CombatVFX budget48 и его приоритеты не изменены. Снаряды погибшего стрелка продолжают жить по старым TTL: добавлены is_instance_valid guards в передаче shooter к destructible/splash damage и _same_squad. Удаление старого Vehicle не создаёт stale Node аргументов.

## 5. Динамическая навигация

ArenaNavigation хранит отдельные _dynamic_rects для группы vehicle_wrecks только своей Arena. Раз в physics-frame при первом запросе считываются актуальные мировые AABB исходных polygon points (максимум5 объектов). point_clear/segment_clear/free_distance видят новое положение; старое освобождается на следующем physics tick. В статический _rects wreck не добавляется, поэтому фантомного исходного препятствия нет.

Radius AStarGrid2D создаются как раньше. Для каждого cached grid хранятся исходные static-solid cells и overlay dynamic cells. При изменении poses обновляется только объединение изменившихся ячеек около текущих/прошлых AABB; старые клетки восстанавливаются с учётом static-solid. Полное построение сетки на каждом tick не добавлено. Сам объект grid сохраняется при движении wreck — это проверено. Traffic snapshots сохраняют свои временные автомобильные blockers, а динамические остовы читают из общего текущего source; moving wreck не замораживается в старом detour snapshot.

ArenaBot, tactical roles, yielding/reverse/recovery не менялись. Его существующие periodic path update и clearance queries используют новый слой. Fresh snapshot BonusSpawner тоже видит wreck: проверены успешное размещение пяти кандидатов и свободные позиции вне тел. Маршруты к нижнему supply hotspot проверены, пока укрытия ещё активны.

Замер30движений одного wreck и обращения к cached radius48 grid+point_clear при1/3/5телах; времена CPU, headless, не GPU:

| Остовов | mean ms | p95 | max | тот же grid |
|---|---:|---:|---:|---|
| 1 | 0.100 | 0.219 | 0.230 | да |
| 3 | 0.110 | 0.364 | 0.376 | да |
| 5 | 0.183 | 0.527 | 0.547 | да |

Другие повторы дали меньшие числа; все сохранены. Стадия не включает дорогой initial static grid build. Это один radius-cache, а не оценка всех возможных размеров одновременно.

### Проверка8AI и известное ограничение

Шесть физических сценариев1/3/5wreck × seed4217/7124 со штатным TTL25с прошли:8/8 машин достигли целей за лимит5400ticks/90simulated seconds. Использован headless --fixed-fps60 для ускоренного исполнения фиксированного timestep, не графического профилирования. Логи содержат frames/max_stop/reverse_attempts. Некоторые завершения происходят после TTL; PASS не означает, что каждая машина объехала все пять ещё существующих тел. Штатное исчезновение и обновление геометрии — часть проверенного lifecycle.

Первый дополнительный стресс удерживал wreck120с, чтобы не открывать маршруты по TTL. С1/3 все8доехали, но с5в каждом из двух seed доехали6/8; были остановки до61.2с и13reverse attempts. Этот **FAIL сохранён** в AI-extended-ttl-FAIL.log, режим воспроизводится `--extended-ttl`. Его не исправляли изменением tactics, физики, таймаута90с или штатного TTL. Это подтверждённый риск длительных плотных заторов: увеличивать lifetime/лимит сверх5/25 без отдельной работы с recovery нельзя. Нет заявления об универсально решённой навигации вокруг произвольного числа постоянных тел.

Проверены изолированные counterfactual margins12/24units вокруг dynamic AABB.12снизил число недостигших целей,24изменил траектории, но оба режима сохранили FAIL хотя бы в одном из6сценариев. Они не приняты и production margin не увеличен. Raw AI-margin12/24-extended.log сохранены; исходники финального after восстановлены к проверенному общему overlay без этих экспериментов.

## 6. TTL, лимит и сессия

scripts/destroyed_vehicle_wrecks.gd принадлежит текущей Arena и подключается Survival только при пустом career_event. MAX_ACTIVE5/LIFETIME25 централизованы. Передача deferred, очередь snapshot ограничена5на один handoff; duplicate meta и защита Survival от повторного died предотвращают повторный wreck/награду.

При лимите освобождается самый старый wreck без контакта с живым Vehicle. Если все5в контакте, новый wreck не создаётся, исходный dead Vehicle удаляется: занятые укрытия имеют приоритет, новая очередь не растёт. Это явное исключение «каждая смерть оставляет wreck» из-за заданного бюджета. По TTL объект ждёт окончания контакта максимум2с, затем fade0.35с и queue_free. Поэтому фактическое максимальное время до удаления≈27.35с, а не бесконечное продление. Визуал и physical body принадлежат одному объекту и удаляются вместе.

Между волнами контейнер сохраняется. Исключение безопасности: если wreck перекрывает обязательную authored spawn point игрока/обычного бота/Арбитра, clear_spawn_area удаляет только такой wreck перед появлением машины. Координаты, количество и расписание спавна не меняются; нельзя создавать новый Vehicle внутри старого solid hull. Байкерские позиции уже проверяются navigation.point_clear. Это правило явно оговорено вместо скрытого переноса spawn points.

Полный Restart пересоздаёт Arena и уничтожает контейнер/состояние динамического overlay. Старые deferred методы привязаны к уничтоженному контейнеру; после поражения stop() меняет generation/active и замораживает тела, поэтому ожидавшая передача не создаёт новый wreck. Выход в меню удаляет всё дерево. Сохранены существующие round/session guards, crew creation и full body HP перед новой волной.

При handoff Арбитра Survival очищает _boss до освобождения Vehicle: прежний HUD мог хранить dead Vehicle до следующей волны, а теперь эта ссылка стала бы stale. HUD, boss schedule, music cues и победные правила не переписывались.

## 7. Производительность и память

Настоящий OpenGL Compatibility, AMD RX580/radeonsi, Mesa26.2.4, Linux6.8.0-138. Один8-AI/5смертей fixture before/after, VSync выключен, каждое cold/warm окно8с. Смерти в этом нагрузочном fixture принудительные через take_weapon_damage, исходные8AI и игрок получили тестовый высокий HP; стрельба MG/Heavy и физика работают. Это не естественное прохождение и не сравнение идентичного потока выстрелов: укрытия закономерно меняют движение и стрельбу.

| Фаза | mean frame ms | p95 | p99 | max |
|---|---:|---:|---:|---:|
| before cold | 3.484 | 4.793 | 5.107 | 606.835 |
| after cold | 3.625 | 5.132 | 5.760 | 606.861 |
| before warm | 3.452 | 4.514 | 4.951 | 8.134 |
| after warm | 3.339 | 4.402 | 5.352 | 7.285 |

До5wreck,8activeAI,28PhysicsBody2D, до3снарядов/5CombatVFX в after; beforeдо5снарядов,0новыхwreck (старые frozen Vehicles ещё есть). Крупный стартовый пик≈607мс воспроизведён before/after и отдельно не атрибутирован, исчезнувшим не объявляется. Mean не доказывает ускорения; p99 вырос. GPU timestamps/процент аппаратной загрузки не измерены. Фоновые headless/import процессы могли влиять на короткие окна.

Godot TIME_PHYSICS_PROCESS monitor sampled из render loop: warm after p95/max10.515мс, before9.111мс. Cold monitor содержит старые/setup показания вплоть до5430мс и повторяет последнее значение между physics updates; его нельзя трактовать как чистую стоимость одного physics step нового wreck. Полные raw counters/условия сохранены, а стоимость dynamic overlay измерена отдельно выше.

MEMORY_STATIC before59,577,300bytes, active63,799,722. После первого/двадцатого Restart59,863,532/59,877,832; nodes198→198, resources207→207, orphan0. Godot video counter после первого и двадцатого Restart одинаков389,838,133bytes; active390,357,853, before370,519,869. Прогрев/driver allocations остаются после первого матча, причина остаточной разницы не атрибутирована. Это не доказательство отсутствия всех runtime-утечек. После20Restart active wreck0. RSS отдельно не измерен. Существующие shutdown ObjectDB/resources warnings сохранены и не выдаются за подтверждённую runtime-утечку.

## 8. Файлы текущей задачи

- Новые scripts/destroyed_vehicle_wreck.gd и destroyed_vehicle_wrecks.gd (+UID).
- scripts/survival.gd: контейнер обычного Survival, once-death handoff, spawn-overlap cleanup, session stop и очистка _boss.
- scripts/arena_navigation.gd: общий bounded dynamic overlay и совместимость traffic snapshots.
- scripts/bullet.gd: cover sweep и stale shooter guards.
- Новые tests/destroyed_wrecks_lifecycle_smoke.gd, destroyed_wrecks_physics_smoke.gd, destroyed_wrecks_combat_navigation_smoke.gd, destroyed_wrecks_ai_smoke.gd (+UID).
- Этот отчёт, QA, improvement plan и evidence с .gdignore; графические fixtures сохранены как .txt в evidence.

Vehicle physics, Arena/центральный объект/MapProps/default_arena, Tactical Waves/ArenaBot, музыка, оружейные configs/visuals, BonusPickup/BonusSpawner и full-wave HP implementation сохранены. Их SHA против before: preserved-sha256.json. Большой общий git status включает предшествующие незакоммиченные принятые задачи, а не только этот этап; raw status сохраняется в evidence. Исходная AI-ветка/main не перемещались.

## 9. Итоги проверок и границы приёмки

Финальный полный последовательный tests/run_vehicle_catalog_regressions.sh **19/19 PASS** на последней версии source (regressions-complete): VehicleCatalog, profile recovery, Garage/loadout, PreRace, Career, Race finish, controls, Survival/playability, boss schedule1–15, biker crew, roguelite, round guards, Restart100, reward feedback, tactical arsenal, release v1/release candidate. Предварительные серии сохранены отдельно, они не заменяют финальную.

Дополнительно **17/17 PASS** (extra): handling_collision_smoke, collision_damage_smoke, damage_contract_smoke, traffic_yield_policy_smoke, traffic_recovery_smoke, tactical_wave_identity_smoke, bonus_placement_smoke, arena_expansion_smoke, rocket_visual_profile_smoke, rocket_homing_v3_smoke, ballistic_visual_profile_smoke, combat_vfx_budget_smoke, weapon_smoke, race_combat_smoke, survival_full_wave_recovery_smoke, driving_reverse_response_smoke, arena_music_smoke.

Новые tests: lifecycle **PASS** (обычный/элита/Арбитр/байкер, duplicate signal, pose, TTL, capacity, межволновое сохранение, same-frame Restart, stale creation после поражения, глубоко пересекавшиеся исходные машины, scene disposal); physics **PASS** (4контактных сценария); combat/navigation/supply **PASS** (6летающих видов оружия и прежнее поведение мины, contact VFX/cap, cached-grid identity, перемещение/удаление, fresh placement, освобождённый shooter); AI с production TTL **PASS6/6сценариев по8машин**. Реальный graphical Menu→Survival→Start/убийство/контакт/толкание/AI/Restart/Menu/повторный вход **PASS** в1280×720 и800×600.

Restart100: nodes200→198/orphans0; графические20Restart:198→198, resources207→207, wrecks0. Ни один существующий regression test не ослаблен и не изменён в этой задаче. Оружейные параметры, physical masks исправных машин и TTL/cap VFX не менялись. Финальные production-файлы рабочего дерева совпадают с /tmp/destroyed-wreck-after.

Сохранённые неудачи разработки: два Parse Error новых test fixtures (неявный Variant/тип path), неверный typed empty traffic array, первый GUI-target reset поверх pending spawn reset, вызов typed telemetry с освобождённым Vehicle, mouse-coordinate mismatch при800viewport, stale _boss в HUD после нового handoff. Первые пять исправлены в fixtures, stale boss — в production coordinator. Отдельный FAIL120s/5covers не закрыт и вынесен в ограничение навигации выше. Тест TTL учитывает штатный contact grace; раннее ожидание0.6с было неверным при активном контакте. Raw failed logs не удалены.

Результат покрывает штатный режим5/25 с настоящей production физикой и динамическими grids. **Полная приёмка длительных плотных заторов остаётся открытой**: расширенный120s стресс не пройден, некоторые штатные цели достигаются после исчезновения cover. Не представлять это как универсальное устранение заторов. Ручная оценка массы/темпа/визуала, длительный многочасовой бой и аппаратный gamepad не выполнялись. Стартовый кадр≈607мс и shutdown ObjectDB/resources warnings требуют отдельных исследований, а не оптимизации AI/VFX ради PASS.
