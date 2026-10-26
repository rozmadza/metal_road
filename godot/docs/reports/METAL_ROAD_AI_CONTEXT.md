# Metal Road — контекст для внешнего AI

Metal Road — Godot 4.7.2 top-down 2D arcade combat racing game. Главная сцена `MainMenu.tscn`; рендерер `GL Compatibility`; окно 1280×720, `canvas_items`. Режимы: Race и Survival, плюс Garage, Career, Progress и настройки.

## Быстрая карта

- Race: `scenes/Main.tscn`, `scripts/game.gd`, `scripts/track.gd`, `scripts/bot_controller.gd`.
- Survival: `scenes/ArenaBattle.tscn`, `scripts/survival.gd`, `scripts/arena.gd`, `scripts/arena_bot.gd`.
- Машина: `scenes/Vehicle.tscn`, `scripts/vehicle.gd`, `scripts/vehicle_config.gd`, `scripts/vehicle_damage.gd`.
- Оружие: `scripts/machine_gun.gd`, `scripts/bullet.gd`, `scripts/weapon_config.gd`.
- HUD: `scripts/debug_hud.gd`, `scripts/arena_hud.gd`, `scripts/vehicle_readout.gd`.
- Данные: `resources/vehicles/`, `resources/weapons/`, `resources/*arena.tres`, `resources/*track.tres`.

## Фактическая механика

`Vehicle` — `RigidBody2D`. Управление передаётся как throttle/brake/steer/fire. Тяга ограничена `max_speed`, отпускание газа сохраняет инерцию через drag, боковая скорость гасится traction, steering зависит от продольной скорости и ослабляется на высокой скорости. При смене вперёд/назад действует торможение до остановки. Урон хранит body/engine/wheels; body-hit распределяется по внутренним модулям, двигатель снижает performance до 15%, колёса снижают steering/traction. Это аркадная физика, не симуляция шин.

Survival создаёт игрока и волну; все живые машины находятся в `combatants`. В первом раунде 5 врагов, затем число растёт до 6; после обычной группы появляется Arbiter. Оружие включает machine gun, heavy MG, shotgun, rocket, mine, flamethrower, EMP и referee/biker варианты. `Bullet` проверяет swept hit, препятствия и crew/vehicles.

## Автомобили

Основные resources: `raider`, `nomad`, `dustfox`, `needle`, `phantom`, `viper`, `marauder`, `warhound`, `wasteland_gt`, `crusher`, `bastion`, `behemoth`; elite: Cerberus Flanker/Support/Vanguard, Referee Biker и Arbiter. Классы: Raider, Interceptor, Assault, Juggernaut. Отличия задаются ресурсами (speed, mass, health, passive, weapon modifiers), а не отдельной физикой классов.

## Race и прогресс

Race подтверждает 3 круга, позиции, финиш, DNF, results, Retry и Menu. Survival даёт очки/волны/бонусы и экран результата. Garage хранит выбранный loadout и upgrade resources; Career имеет полноценную историю только для первого события, остальные ветки менее полны.

## Главные ограничения

1. Release smoke сейчас падает на `VFX budget cap`.
2. Headless завершение сообщает ObjectDB/resource leaks.
3. AI и баланс требуют длительных игровых проверок.
4. Не считать наличие `.gd` доказательством полной функции: сверять координатор, сцену, ресурс и тест.

## Правила безопасных изменений

Сначала проверять соответствующий `*Config` и существующие тесты. Не мутировать shared Resource во время матча без duplicate. Сохранять группы `combatants`, `bullets`, `bots`, сигналы `Vehicle.died` и переходы через `Transition`. Для новой механики добавлять deterministic smoke и отдельный visual review; после изменений запускать Race/Survival regression и `git diff --check`.

Подробности: [архитектура](METAL_ROAD_ARCHITECTURE.md), [матрица](METAL_ROAD_FEATURE_MATRIX.md), [QA](METAL_ROAD_QA_REPORT.md), [полный аудит](METAL_ROAD_FULL_AUDIT.md).

