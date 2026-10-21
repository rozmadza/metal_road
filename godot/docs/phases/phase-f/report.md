# Phase F — Garage / Vehicles / Weapons

## Что изменено

Garage расширен до четырёх Resource-based машин:

- Raider — сбалансированная;
- Viper — лёгкая и быстрая;
- Crusher — тяжёлый таран;
- Wasteland GT — универсальная.

Добавлены три вида оружия:

- Machine Gun;
- Heavy Machine Gun;
- Shotgun.

У каждого варианта собственные параметры `VehicleConfig`/`WeaponConfig`.
На этом этапе все варианты доступны для выбора; цены и покупки относятся к
Phase G и намеренно не добавлялись.

Garage получил два OptionButton. Выбор меняет preview, класс, характеристики,
урон и темп оружия. Выбранные ID сохраняются через `ConfigFile` в
`user://loadout.cfg`.

Визуальный слой теперь также меняется вместе с конфигурацией:

- для Raider, Viper, Crusher и Wasteland GT добавлены отдельные top-down PNG;
- `VehicleConfig.texture` у каждого класса указывает на собственный силуэт;
- игровой `Vehicle` рисует увеличенный читаемый силуэт, сохраняя прежние
  collision shape и физические размеры;
- в Garage добавлен `WeaponPreview` с отдельными визуальными модулями для
  Machine Gun, Heavy Machine Gun и Shotgun;
- в игре оружейный модуль на машине меняется вместе с выбранным WeaponConfig.

Race и Survival в обычном оконном запуске применяют сохранённый loadout к
игроку перед стартом. Headless smoke сохраняет базовую конфигурацию для
детерминированности старых тестов; `garage_loadout_smoke` отдельно вызывает
применение выбранных Resources и проверяет интеграцию.

## Файлы

Добавлены:

- `scripts/loadout_profile.gd`;
- `resources/vehicles/raider.tres`;
- `resources/vehicles/viper.tres`;
- `resources/vehicles/crusher.tres`;
- `resources/vehicles/wasteland_gt.tres`;
- `resources/weapons/machine_gun.tres`;
- `resources/weapons/heavy_machine_gun.tres`;
- `resources/weapons/shotgun.tres`;
- `tests/garage_loadout_smoke.gd`;
- `tests/vehicle_visuals_smoke.gd`;
- `scripts/weapon_preview.gd`;
- `assets/vehicles/raider/raider.png`;
- `assets/vehicles/viper/viper.png`;
- `assets/vehicles/crusher/crusher.png`;
- `assets/vehicles/wasteland_gt/wasteland_gt.png`;
- `docs/phases/phase-f-logs/`.

Изменены:

- `scripts/garage.gd`;
- `scripts/vehicle.gd`;
- `scripts/game.gd`;
- `scripts/survival.gd`;
- `scenes/Garage.tscn`;
- `tests/hud_race_smoke.gd` — проверка runtime body теперь не зависит от
  выбранного максимального HP.

## Проверка

Полный набор smoke-тестов: **24/24 PASS**.
Новые проверки визуальных конфигураций: **PASS** (`vehicle_visuals_smoke`).
Отдельный smoke выбора loadout: **PASS** (`garage_loadout_smoke`).
Проверены наличие четырёх уникальных текстур машин, трёх конфигураций оружия,
переключение preview в Garage и смена оружейного модуля.

Новый `garage_loadout_smoke` проверяет:

- четыре пункта машин;
- три пункта оружия;
- фиксацию выбранных Crusher/Shotgun в текущем Garage;
- обновление реальных характеристик Garage;
- применение выбранных конфигов в Race.

Известные предупреждения Godot о неосвобождённых ObjectDB/resources при
завершении headless-процессов сохраняются; GDScript errors нет.

## Manual playtest

Оконное тестирование выполнено на 1280×720:

- [меню](../../sprints/bcd/manual/phase-f-menu.png);
- [Garage](../../sprints/bcd/manual/phase-f-garage.png);
- [список машин](../../sprints/bcd/manual/phase-f-vehicle-menu.png);
- [Crusher](../../sprints/bcd/manual/phase-f-crusher.png);
- [список оружия](../../sprints/bcd/manual/phase-f-weapon-menu.png);
- [итоговый Crusher + Shotgun](../../sprints/bcd/manual/phase-f-shotgun.png).

Дополнительный playtest после visual pass:

- [Garage с Viper и Heavy Machine Gun](../../sprints/bcd/manual/garage-open.png);
- [Crusher](../../sprints/bcd/manual/garage-crusher.png);
- [Crusher + Shotgun](../../sprints/bcd/manual/garage-crusher-shotgun.png);
- [Race с выбранным loadout](../../sprints/bcd/manual/race-started.png).

PNG-модели сгенерированы в рамках imagegen pipeline и импортированы как обычные
Godot Texture2D; runtime-логика не зависит от генератора.

Выборы реально изменили экран характеристик и сохранились между сценами.

## Ограничения

Визуальные модели сейчас представлены импортированными top-down PNG без
покомпонентной деформации кузова. Повреждения и оружейные состояния остаются
частью общего runtime-рендера Vehicle.
Покупки, Credits, уровни апгрейдов и блокировка техники не реализованы.
Shotgun пока использует общий одиночный projectile contract; полноценный
burst из нескольких pellets относится к следующему gameplay-этапу.

## Следующий этап

После пользовательской проверки Phase F — Phase G: Credits, покупки машин и
оружия, upgrade categories и сохранение прогресса профиля.
