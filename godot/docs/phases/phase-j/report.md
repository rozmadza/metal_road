# Phase J — World Expansion и AI hazards

## Что изменено

- добавлен переиспользуемый `MapProp` компонент;
- в Arena добавлены Crate, TireWall, Wreck, ConcreteBlock и MetalFence;
- Crate входит в группу destructibles и разрушается от двух попаданий;
- новые props и hazard positions вынесены в `ArenaConfig`;
- ArenaBot теперь избегает OilSpot и активных ExplosiveBarrel;
- collision props остаются простыми StaticBody2D и не меняют базовую Vehicle-физику.

## Добавленные файлы

- `scripts/map_prop.gd`;
- `scenes/MapProp.tscn`;
- `tests/environment_smoke.gd`.

## Изменённые файлы

- `scripts/arena.gd`;
- `scripts/arena_config.gd`;
- `scripts/arena_bot.gd`;
- `resources/default_arena.tres`.

## Проверка

- `environment_smoke`: PASS;
- `arena_smoke`: PASS;
- `survival_smoke`: PASS;
- `bot_smoke`: PASS;
- `game_smoke`: PASS.
- `derby_smoke`: PASS после переноса fence из тестовой линии тарана;

Всего текущий smoke-набор: **29/29 PASS**.

Следующий контентный шаг — расширить AI threat evaluation и добавить второй
визуально законченный Arena layout.
