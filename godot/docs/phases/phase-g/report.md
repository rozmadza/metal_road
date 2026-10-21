# Phase G — Credits, покупки и апгрейды

## Что изменено

- добавлен `PlayerProfile` на `ConfigFile` (`user://profile.cfg`);
- добавлены Credits, цены техники и награды за Race/Survival;
- Raider и Machine Gun выдаются бесплатно, остальные варианты имеют стоимость;
- Garage показывает баланс, статус владения и кнопки покупки;
- правая колонка Garage уплотнена для 1280×720, все кнопки остаются в окне;
- запуск Race/Survival блокируется для некупленной связки техники;
- добавлены шесть Resource-based апгрейдов: Engine, Armor, Handling,
  Durability и два оружейных;
- апгрейды применяются через копию `VehicleConfig`/`WeaponConfig`, поэтому
  исходные `.tres` не мутируют во время игры;
- Race начисляет награду за место и уничтоженных соперников;
- Survival начисляет Credits за уничтожение врага и пройденный раунд;
- Garage получил выбор апгрейда и кнопку установки.

## Добавленные файлы

- `scripts/player_profile.gd`;
- `scripts/economy_config.gd`;
- `scripts/upgrade_config.gd`;
- `resources/economy_config.tres`;
- `resources/upgrades/*.tres`;
- `tests/economy_smoke.gd`.
- `tests/garage_layout_smoke.gd`.

## Изменённые файлы

- `scripts/garage.gd`;
- `scripts/game.gd`;
- `scripts/survival.gd`;
- `scenes/Garage.tscn`.

## Проверка

- `economy_smoke.gd`: PASS;
- `garage_smoke.gd`: PASS;
- `garage_loadout_smoke.gd`: PASS;
- `game_smoke.gd`: PASS;
- `survival_smoke.gd`: PASS;
- `race_finish_smoke.gd`: PASS;
- `garage_layout_smoke.gd`: PASS;
- полный набор из 26 smoke-тестов: PASS.

Оставлены стандартные предупреждения Godot о неосвобождённых ObjectDB в
отдельных старых headless-тестах; ошибок GDScript нет.

## Ограничения

Покупки и апгрейды пока представлены компактным Garage UI. Отдельное дерево
уровней 1–5 для каждого оружия и полноценный Result Screen Survival относятся
к следующему этапу.

## Следующий этап

Phase H — интерактивное окружение арены: OilSpot, ExplosiveBarrel, props и
radial damage.
