# Driving Feel, Movable Wreck & Wave Recovery v1

Дата: 2026-10-30. Godot4.7.2. Рабочая ветка codex/ballistic-visual-overhaul-v1, HEAD95914638b21f87b44503066d271268216ff45572. Исходное дерево уже содержало принятые Rocket v3 и Ballistic v1, их отчёты, PNG и незакоммиченные правки. Они сохранены. Отдельные before/after снимки для измерений созданы в /tmp/driving-v1-before и /tmp/driving-v1-after. Commit/push/merge не выполнялись.

## 1. Реверс: причина и минимальное изменение

Vehicle.apply_player_control требовал get_speed()<=2units/s непрерывно0.35с перед включением _player_reverse. get_speed — модуль полной скорости: остаточное боковое скольжение сбрасывало таймер даже при нулевой продольной скорости. Затем прежний throttle_response дополнительно постепенно подавал отрицательную тягу. AI вызывает apply_control со знаковым throttle напрямую и эту player-паузу не использует.

Теперь PLAYER_REVERSE_DELAY=0.15с и PLAYER_REVERSE_STOP_SPEED=2units/s, проверяется abs(get_forward_speed()). Обе константы рядом с остальными Vehicle constants. Выбранные0.15с сохраняют остановку и короткую смену передачи. Газ/отпускание тормоза по-прежнему сбрасывают выбор реверса. Нет изменения acceleration, brake_force, traction, ограничения торможения, handbrake, steering, throttle_response или recovery AI. При высокой передней скорости S сначала тормозит.

Измерены12сценариев: Raider/Bastion/Behemoth × keyboard/программный RT/LT × здоровый/engine0+wheels0. Реальный Vehicle/RigidBody2D, InputHandler и события фактического InputMap,60physicsHz. Машины стартуют с заданной максимальной скоростью; это контролируемое торможение, не ручное вождение. Полная таблица: [reverse-table](driving-wreck-wave-v1-evidence/reverse-table.md), сырые before/after JSON рядом.

| Сценарий | stop от начала торможения, с | старая задержка тяги от stop | новая | старая задержка до v<−2 | новая |
|---|---:|---:|---:|---:|---:|
| Raider здоров | 1.017 | 0.333 | 0.133 | 0.417 | 0.217 |
| Raider повреждён | 0.883 | 0.333 | 0.133 | 0.433 | 0.233 |
| Bastion здоров | 0.800 | 0.333 | 0.133 | 0.433 | 0.233 |
| Bastion повреждён | 0.683 | 0.333 | 0.133 | 0.433 | 0.233 |
| Behemoth здоров | 0.767 | 0.333 | 0.133 | 0.433 | 0.233 |
| Behemoth повреждён | 0.650 | 0.333 | 0.133 | 0.433 | 0.233 |

Keyboard и RT/LT совпали. Уменьшение0.20с; stop и скорость через0.3с в before/after совпадают. Таймер0.15с, а измеренная разница0.133с возникает из-за выборки скорости послеphysics tick, передачи команды до следующего tick и порога2units/s; точность1/60с. Под «устойчивым назад» стенд использует v<−2, выбор реверса при удержанном тормозе остаётся включён. Быстрый S→W проверяет немедленный сброс селектора; полноценный разгон W→S также покрыт controls_smoke. Отдельная проверка показывает, что боковая скорость15 при нулевой продольной больше не мешает выбору задней передачи. Аппаратный геймпад не использовался; проверены синтетические осевые события.

## 2. Центральный остов и слои

Это не MapProp.kind=wreck: resources/default_arena.tres имеет пустой wrecks. Центральный объект — obstacles[0]=Rect2(630,360,140,120), center(700,420), texture slot3=crushed_cars_topdown.png. Arena создаёт StaticBody2D ObstacleCollisions/Obstacle0, alpha-derived convex CollisionPolygon2D Silhouette и отдельные ObstacleFootprint/ObstacleShadow/ObstacleArt. Видимый масштаб1.03 и collision silhouette0.9 не изменены.

Ранее ObstacleArt и автомобиль имели одинаковый z0: порядок CanvasItem и позднее создание арены при Restart позволяли рисунку остова перекрывать машину. Y-sort выключен, z_as_relative=true; отдельный Sprite2D не был дочерним узлом физического препятствия. Теперь только центральный scrapyard slot имеет footprint−4, shadow−3, art−2 при car0. Контактная подложка также опущена, чтобы не затемнять рисунок остова. Остальные препятствия/арены/размеры/коллизии не менялись.

wreck_layer_smoke намеренно создаёт машину раньше Arena, проверяет полный порядок слоёв, исходный polygon и реальное блокирование автомобиля. Графические кадры показывают контакт: машина остаётся сверху, остов не стал проходимым.

## 3. Подвижный остов: изолированный прототип

Production остов остаётся статическим. Изолированные experiments/movable_wreck.gd и movable_wreck_arena.gd нигде не подключены к shipped scenes/ресурсам. В sandbox тот же полигон центрируется относительно RigidBody2D; три исходных визуальных узла переподчиняются телу с сохранением позиции. Удаляется только старый StaticBody2D №0. Навигационный список экспериментальной Arena исключает исходный slot, а тело входит в существующую группу arena_obstacles с size/destroyed контрактом.

Физические настройки: масса5000, gravity0, linear_damp5/s, angular_damp7/s, friction0.8, bounce0, CCD_CAST_SHAPE. Нет дополнительных импульсов/ускорителей/телепортаций при контакте. Движение обеспечивается обычным физическим контактом Vehicle и RigidBody2D, затухание физического сервера останавливает объект.

| Проверка | Результат |
|---|---|
| Низкая скорость18units/s | сдвиг0.450units, поворот0.00463rad, остаточная скорость0.215 |
| Сильный удар, запрошено210units/s | штатный Vehicle ограничил до165; сдвиг6.116units, поворот0.05923rad≈3.4°, остаточная скорость0.308 |
| Последовательная графическая проверка | сдвиг6.143units, поворот0.05901rad, velocity≈0.036units/s |
| Повторное создание sandbox | исходная позиция/ориентация, нулевые скорости |
| Граница Arena | удерживает тело; оно останавливается внутри1400×1000 |
| Навигация после контролируемого смещения220units | старая точка свободна, новая заблокирована после47physics ticks |
| Физический ArenaBot вокруг нового положения | достиг целевой области, минимальная дистанция74.03units при пороге75 |

Смещение220 в проверке навигации задано тестом для изоляции кэша; оно не выдаётся за результат одного удара. Сама физическая коллизия проверена отдельно. Графические кадры прототипа: [prototype](driving-wreck-wave-v1-evidence/prototype/physical-impact.png).

Почему эксперимент не включён: ArenaNavigation обновляет snapshots раз в45physics ticks (~0.75с), сбрасывая все radius-grids при любом изменении Rect2. Для движущегося препятствия это означает задержку актуализации и повторные построения сеток; local traffic detour предназначен для других автомобилей, не произвольного динамического укрытия. Bullet._hits_obstacle сейчас признаёт StaticBody2D, поэтому простая подмена на RigidBody2D меняет защиту от снарядов. Урон от столкновения с dynamic body тоже имеет иной контракт, чем static cover. Разрешение требует отдельного согласованного изменения cover/navigation/damage и измерения rebuild. Production-only z-fix сохраняет эти контракты. Нет полного AStar rebuild на каждом tick; sandbox использует прежний45-tick refresh.

Production Restart уже пересоздаёт Arena: статический остов восстанавливается автоматически. Между волнами состояние арены сохраняется. Sandbox тестирует повторное создание, но не заявляет включение movable wreck в штатный Restart Survival.

## 4. Кузов перед новой волной

Прежний reset_for_next_wave добавлял30% недостающего здоровья кузова, двигателя и колёс; с wave_repair45%. Например body40/100 переходил в58/100 или67/100. Это не30/45% от полного HP.

Обычный Survival теперь в start_round после проверки spawn points и применения выбранного перка, перед созданием противников, вызывает reset_for_next_wave(...,0): сохраняет оба модуля и повреждённый кузов при reposition/transient reset. Затем один раз для нового номера волны присваивает player.health=player.config.max_health. Нет сложения старого частичного и нового полного ремонта. Поле _body_recovery_round предотвращает повторный heal при повторном старте того же номера и сбрасывается новым матчем. Волна1/Retry используют прежний полный reset. Отрицательные/устаревшие session callbacks отсеиваются существующим generation guard; start_round для последующих волн и _on_perk_selected дополнительно отклоняют мёртвого игрока/завершённую сессию.

Перк меняет копию VehicleConfig до старта волны, поэтому max_health уже эффективный. Двигатель и колёса не восстанавливаются новым правилом; прежний штатный autorepair колёс в активном времени не затрагивался. HUD обновляется после присваивания HP. Upgrade overlay теперь сообщает «КУЗОВ ДО100% В НАЧАЛЕ ВОЛНЫ». Текст касается кузова, не полного ремонта всех систем.

Career arena различается непустым career_event и сохраняет старую ветку30/45% ремонта модулей. Race не использует этот координатор. Repair Pickup не изменён и по-прежнему полезен в бою. Нет нового постоянного auto-heal во время волны.

survival_full_wave_recovery_smoke: переходы1→2,2→3,3→4,4→5,5→6 через выбор перка; актуальный max с+28HP; отсутствие лечения до старта; модули19/23 неизменны; повторный вызов того же номера не лечит; повторный выбор не запускает новую волну; здоровый игрок не переполняет HP; pickup лечит в бою; dead/stale callbacks не воскрешают; Retry чистый; HUD ratio1; Career сохраняет старую формулу. Переходы принудительно подготовлены стендом, естественное прохождение boss не заявляется. Boss schedule/regression отдельно проверяют обычные правила.

**Последствие баланса:** field_mechanic «+15% ремонта между волнами» в обычном Survival стал неэффективным, потому что кузов и так полон, а модули новый переход не ремонтирует. Описание/предложение этого перка не меняли по ограничению задания. Рекомендуемая отдельная задача: согласовать замену эффекта на пользу внутри волны (например усиление Repair Pickup), либо исключение из предложений обычного Survival; проверить старые сохранения и Career. Никакой вариант здесь не реализован. Kill repair остаётся полезным во время боя, armor_skin по-прежнему увеличивает максимум.

## 5. Графика, измерения и ограничения

Реальный Godot4.7.2/OpenGL Compatibility, AMD RX580/radeonsi, Mesa26.2.4, Linux6.8.0-138. Сравнения before/after в1280×720 и800×600: столкновение с центральным остовом, повреждённый игрок и начало второй волны. [Лист1280](driving-wreck-wave-v1-evidence/comparison-1280.png), [лист800](driving-wreck-wave-v1-evidence/comparison-800.png). Листы компонуют настоящие пиксели без изменения масштаба. Отдельный sandbox запущен графически и сохранены before-impact/physical-impact/settled. Ручная оценка управления/художественная приёмка остаётся владельцу.

Графический fixture замораживает AI и вручную вызывает переход, поэтому не подменяет прохождение. В180кадрах с лимитом60FPS:

| Снимок | mean ms | p95 | p99 | max | physics p95 ms | resources |
|---|---:|---:|---:|---:|---:|---:|
| before1280 | 16.567 | 16.897 | 17.108 | 27.589 | 10.906 | 205 |
| after1280 | 16.566 | 16.853 | 17.101 | 26.789 | 10.181 | 205 |
| before800 | 16.570 | 16.869 | 17.038 | 25.985 | 9.623 | 205 |
| after800 | 16.573 | 16.895 | 17.057 | 26.485 | 9.879 | 205 |

Сырые manifest и кадры сохранены. Замеры выполнялись с фоновыми regression-процессами и ограничением60FPS; это ориентир короткого GUI-сценария, не изолированный профиль GPU или AI-боя. Нельзя заключать об ускорении или свободной GPU мощности. Ресурсы стабильны205; Godot video counter before/after менялся при прогреве, новая production-физика не добавляет тел или текстур. Цена потенциального динамического rebuild в живом бою не измерена — ещё одна причина оставить prototype изолированным.

## 6. Изменённые файлы текущей задачи

- scripts/vehicle.gd: две константы и longitudinal reverse gate.
- scripts/arena.gd: только explicit layers центрального static wreck.
- scripts/survival.gd: body-only recovery, once-per-wave marker и death guards; Career partial repair сохранён.
- scripts/survival_upgrade_overlay.gd: точное сообщение о новом правиле.
- experiments/movable_wreck.gd, movable_wreck_arena.gd (+UID): opt-in sandbox.
- tests/driving_reverse_response_smoke.gd, survival_full_wave_recovery_smoke.gd, wreck_layer_smoke.gd, movable_wreck_prototype_smoke.gd (+UID).
- tests/brake_reverse_recovery_smoke.gd и survival_roguelite_smoke.gd: старые требования0.35с/partial заменены точными новыми контрактами; остальные проверки сохранены.
- Этот отчёт, QA, improvement plan и evidence с .gdignore.

Принятые оружейные configs/visual profiles, Bullet/CombatVFX, ArenaBot/ArenaNavigation, default_arena, BonusPickup и SurvivalRunData проверены побайтово против before: [SHA256](driving-wreck-wave-v1-evidence/preserved-sha256.json). Общий git diff также содержит предшествующие задачи — их не приписываем текущей.

## 7. Итоговые проверки

Финальный последовательный regression runner **19/19 PASS**, failures0, включает VehicleCatalog, profile recovery, Garage/loadout, PreRace, Career gameplay, Race finish, controls, Survival/playability, boss schedule1–15, biker crew, roguelite, round guards, Restart100, reward feedback, tactical arsenal, release v1/release candidate. Логи каждого теста: evidence/regressions-final. Первоначальная серия также прошла; результат приёмки относится к финальной серии после изменения всех слоёв.

Дополнительная последовательная серия **23/23 PASS**: vehicle_smoke, vehicle_foundation_smoke, handling_collision_smoke, brake_reverse_recovery_smoke, reverse_steering_smoke, rolling_steering_smoke, idle_steering_smoke, handbrake_smoke, traffic_yield_policy_smoke, traffic_recovery_smoke, arena_bot_navigation_integration, tactical_wave_identity_smoke, arena_expansion_smoke, bonus_pickup_smoke, bonus_placement_smoke, survival_transition_stability_smoke, damage_modules_smoke, rocket_homing_v3_smoke, rocket_visual_profile_smoke, ballistic_visual_profile_smoke, weapon_smoke, combat_vfx_budget_smoke, race_combat_smoke. Логи: evidence/extra.

Независимые новые reverse(before+after), full-wave-recovery, wreck-layer и movable-wreck-prototype **PASS**. Отдельный полный arena_navigation_routes_smoke **PASS**, включая16маршрутов Raider/Bastion/Behemoth/Arbiter, критические колёса, недостижимую цель, встречные пары и8одновременно движущихся машин. Это фактическая физика, а не только AStar path. Детальные frames/stop/reverse_attempts в navigation-routes.log. AI-код и арена сохранены без изменений. Нет обещания отсутствия заторов во всех возможных seed.

Restart100: nodes199→197/orphans0. Графический arena_launch_gui_smoke **PASS** через InputEvent/hit-test, путь menu/Garage/«Выйти на арену»/бой/Restart/menu и Race/Career; кадры и records в evidence/gui. Два разрешения дополнительно проверены отдельным driving_visual fixture. Финальный root editor import без GDScript/Parse ошибок, новые UID присутствуют. Проверяемые production-файлы root побайтово совпадают с финальным after-снимком. git diff --check PASS.

Изначальный reverse-response fixture не передавал keyboard events с правильными полями InputMap, поэтому были FAIL маршрута ввода; тест исправлен копированием реального mapped event. Следующая итерация выявила неверный универсальный stop>0.7с для повреждённых тяжёлых машин: у них ниже начальная скорость. Критерий нового теста уточнён к положительному инерционному интервалу и отсутствию reverse до остановки; реальные замеры приведены полностью. Существующие тесты менялись только там, где старый контракт0.35с/partial heal прямо противоречит новому требованию. Исходные неудачные логи сохранены.

Оставшиеся ограничения: shutdown ObjectDB/resources warnings сохраняются и отдельно не атрибутированы; runtime-утечки не доказаны. Ручное управление/настоящий gamepad/естественная сложность волн не оценивались. Полное лечение меняет ценность field_mechanic и общий Survival темп — это согласованное новое правило, не основание автоматически менять баланс. Прототип не обеспечивает production dynamic-cover contract и не включён в игру. Длительный профиль динамического навигационного rebuild и многопользовательские заторы вокруг подвижного препятствия не измерены.
