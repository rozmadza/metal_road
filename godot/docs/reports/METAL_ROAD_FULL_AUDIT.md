# Metal Road — полный технический и геймдизайнерский аудит

Дата аудита: 2026-10-23. Ветка `main`; коммит `13f16a727183498c2dbf0ee539a035fbf7349e6a`. Godot 4.7.2 stable, `GL Compatibility`, GDScript, Linux x86_64. Проанализированы `project.godot`, `scenes/`, `scripts/`, `resources/`, `assets/`, `tests/`, `docs/`, `pasport.md`, `CODEX_HANDOFF.md`. Исходники, ресурсы, сцены и постоянные сохранения не изменялись; созданы только отчёты в этом каталоге.

## Паспорт и пользовательский путь

Жанр — top-down аркадные боевые гонки/дерби. Отличительная связка — управление тяжёлой машиной, оружие, таран, модули повреждений, волны Survival, трассовый Race и классы машин с passive/upgrade tuning.

Фактический путь: запуск → `MainMenu` → Race или Survival либо Garage/Career/Progress/Settings → матч → RaceResults или Survival result/defeat → Retry, Garage или Menu. Предварительная формула «выбор автомобиля перед каждым режимом» не полностью подтверждается одним линейным экраном: loadout хранится отдельно и используется координаторами.

## Архитектура

Данные отделены в Resource; сцены переиспользуемые; `Game` и `Survival` — координаторы сессий; `Vehicle` — общий физический/боевой объект. Autoload два: `Accessibility`, `Transition`. Группы: `bullets`, `bots`, runtime `combatants`. Схема и ограничения приведены в [METAL_ROAD_ARCHITECTURE.md](METAL_ROAD_ARCHITECTURE.md).

## Автомобиль и физика

Физический узел — `RigidBody2D`, CCD shape cast, zero-gravity world. Базовые значения `VehicleConfig`: `max_speed=160`, `acceleration=800`, `brake_force=1200`, `brake_deceleration_limit=140`, `drag=0.98`, `traction=15`, `mass=1000`, `steer_rate=5`, `steering_stop_speed=1.5`, `steering_full_speed=45`, `steering_high_speed_start=80`, `steering_high_speed_factor=0.5`, `steering_input_rate=4`, `steering_yaw_response=10`, `angular_damping=0.95`. Машины реально не вращаются на месте в текущем steering smoke; управление сохраняется накатом; reverse учитывает знак forward speed; high-speed yaw ослабляется. Боковое скольжение физически гасится traction, handbrake временно снижает grip и повышает yaw. Это приятная аркадная модель с ограниченным отсутствием колёсной геометрии, дифференциала и surface-specific tire model.

## Повреждения и бой

Путь: источник → `Vehicle.take_damage`/`VehicleDamage.apply` → body/engine/wheels → performance factors/visual stage → HUD and `died`. Body damage распределяется по engine/wheels; armour resistance и class multipliers учитываются; wheels repair с delay/rate. Машина умирает при body≤0, отключает оружие/коллизии и emits `died`.

Пули — `Node2D`, проверяют swept segment, ориентированный footprint машины, препятствия и crew; mine срабатывает по наезду, а не по соседству. Базовые resources: MG 3 shots/s, 5 damage; heavy MG 1.8/13; shotgun 1.2/4.5 burst; rocket .55/42; mine .7/52; flamethrower 7/2.8; EMP .65/8. Настройка и эффекты находятся в `resources/weapons/*.tres` и `scripts/bullet.gd`/weapon scripts.

## AI

Race AI (`BotController`) следует траектории Track. Survival AI (`ArenaBot`) выбирает живую цель, строит steering/navigation вокруг препятствий, управляет throttle/brake/steer/fire и имеет recovery. Есть Cerberus роли, biker и Arbiter boss. Не найдено отдельного пользовательского уровня сложности AI; сложность в основном идёт через состав/число волн, ресурсы и boss phases. Возможные редкие застревания остаются предметом soak-тестирования.

## Race

`TrackConfig`/`Track` создают кольцевую геометрию и checkpoints; `Game` создаёт игрока и ботов, ведёт elapsed/laps/positions, принимает lethal damage как DNF и открывает результаты. Фактический finish lifecycle подтверждён `tests/race_finish_smoke.gd`. В отличие от старого `pasport.md`, утверждение об отсутствии финиша устарело.

## Survival и арена

`ArenaConfig` задаёт размер, wall thickness, препятствия, hazards, biome и supply hotspots; `Arena` строит физические стены/объекты. Основная scrapyard-арена имеет структурированные центр, левую контейнерную группу, правую опасную группу, бетонные укрытия и нижний манёвренный коридор; `arena_dressing.gd` рисует следы, пятна, разметку и лампы без collision. `BonusSpawner` использует hotspot-кандидаты с проверкой свободного пространства. `Survival` управляет волнами, score/combo, crew events, bonus pickups, Arbiter и defeat.

Геймдизайнерски цикл уже рабочий: игрок маневрирует, стреляет, таранит, ищет бонусы и переживает увеличивающиеся волны. Разнообразие ограничено количеством базовых AI-ролей и арен; баланс/темп требуют длительного ручного прохождения.

## UI, камера, графика, звук

Главное меню и экраны Garage/Career/Results собраны сценами с общей темой. Survival HUD показывает wave, score, enemies, speed, module health, weapon/ammo, combo, bonus/status. `FollowCamera` следует за игроком, поддерживает zoom/limits/shake. Визуально есть top-down vehicle sprites, арена/биомы, tire tracks, dust/smoke/sparks, explosions, weapon feedback и структурированный Survival dressing. `AudioManager` подключает engine, fire, collision, finish, explosion, UI SFX и music; `AudioConfig` задаёт уровни и cooldown.

## Гараж, прогресс и сохранения

`vehicle_catalog.tres`, vehicle resources и `upgrade_config` описывают fleet/classes/upgrades. `PlayerProfile`, `LoadoutProfile`, `CareerSession`, economy/progress scripts реализуют выбор и сохранение состояния. Проверены smoke для garage, economy, progression, settings и recovery; повреждённый реальный пользовательский файл вручную не проверялся в этом аудите.

## Готовность и риски

Сводная матрица находится в [METAL_ROAD_FEATURE_MATRIX.md](METAL_ROAD_FEATURE_MATRIX.md). Наиболее существенные проблемы:

1. P1: `release_candidate_smoke` падает на VFX budget cap.
2. P1: headless shutdown сообщает ObjectDB/resource leaks.
3. P2: AI и баланс не покрыты длительным реальным playthrough.
4. P2: крупные координаторы и прямые node paths создают регрессионный риск.
5. P2: Career и разнообразие контента неравномерны между ветками/ аренами.

## Рекомендованный порядок развития

1. Разобрать VFX budget и lifecycle leaks (Medium/High).
2. Добавить длительный deterministic soak для волн, AI, бонусов и collision (Medium).
3. Закрепить контентный контракт арены/биомов и добавить больше тактических вариаций (Medium).
4. Расширить Career-события и экономическую мотивацию (Medium/High).
5. Затем улучшать звук, feedback, accessibility и производительность на целевых разрешениях (Low/Medium).

## Самопроверка

Основные режимы, сцены, классы, физика, повреждения, оружие, AI, арены, HUD, звук, сохранения, тесты и риски отражены. Не подтверждены ручное прохождение всех биомов, gamepad, длительный матч, реальная поломка сохранения и визуальная оценка каждого оружия; эти пробелы явно оставлены в QA-отчёте.
