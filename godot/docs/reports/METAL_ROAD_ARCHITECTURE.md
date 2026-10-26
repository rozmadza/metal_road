# Metal Road — архитектурная карта

Дата аудита: 2026-10-23. Ветка: `main`. Анализируемый коммит: `13f16a727183498c2dbf0ee539a035fbf7349e6a`. Godot 4.7.2, `GL Compatibility`.

## Точки входа

- `project.godot`: главная сцена `res://scenes/MainMenu.tscn`, viewport 1280×720, `canvas_items`, Input Map.
- `scenes/MainMenu.tscn` + `scripts/main_menu.gd`: меню, запуск Race/Survival, настройки.
- `scenes/Main.tscn` + `scripts/game.gd`: Race.
- `scenes/ArenaBattle.tscn` + `scripts/survival.gd`: Survival.
- Autoload: `Accessibility` (`scripts/accessibility_settings.gd`) и `Transition` (`scripts/scene_transition.gd`).

## Слои архитектуры

`*Config` Resource в `scripts/*_config.gd` и `resources/` хранит данные; сцены `scenes/` задают состав узлов; координаторы `Game`/`Survival` управляют сессией; `Vehicle` реализует общую физику; `BotController` и `ArenaBot` подают одинаковый контракт управления; HUD читает координатор и машину.

```text
MainMenu -> Main / ArenaBattle -> Track / Arena
                         |             |
                  Game + BotController  Survival + ArenaBot
                         \             /
                         Vehicle(RigidBody2D)
                           |-- MachineGun -> Bullet
                           |-- VehicleDamage / VehicleEffects
                           \-- HUD / Camera / AudioManager
```

## Главные связи и сигналы

- `Vehicle.died(vehicle)` сообщает координатору завершение участника.
- `MachineGun.fired` используется для боевого feedback.
- `Survival` добавляет игрока и врагов в группу `combatants`; `Bullet` и таран используют её как контракт целей.
- `bullets` — контейнер снарядов; `bots` — гонщики Race.
- `Track`/`Arena` создают стены и препятствия, а не управляют матчем.

## Жизненный цикл

Главное меню меняет сцену через `Transition`. В Race `Game` создаёт игрока и ботов, запускает `Track`, отслеживает прогресс/круги и открывает `RaceResults`. В Survival `Survival` создаёт арену, игрока, волну, бонусный спавнер и AI; гибель всех целей переводит раунд дальше, гибель игрока показывает `SurvivalResults`/сообщение.

## Ключевые каталоги

`assets/` — спрайты, музыка и SFX; `resources/` — конфигурации арен, трасс, машин, оружия, UI и улучшений; `scenes/` — переиспользуемые сцены; `scripts/` — runtime-логика; `tests/` — `SceneTree` smoke/visual/integration тесты; `docs/` — отчёты и результаты проверок.

## Ограничения архитектуры

1. Координаторы режимов крупные и напрямую создают/настраивают много дочерних узлов.
2. `Vehicle` совмещает физику, урон, оружие, визуальные эффекты и часть звука.
3. Часть UI обновляется через прямой поиск узлов и текстовые строки, поэтому переименование узлов рискованно.
4. Тесты преимущественно headless и программно управляют объектами; они не заменяют длительный ручной playthrough.

