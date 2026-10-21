# Phase O Report — Garage Weapon Art

## Что изменено

- Отдельный графический preview оружия удалён из правой панели Garage.
- Выбранное оружие теперь устанавливается прямо на крышу выбранной машины.
- Смена оружия обновляет модуль на автомобиле без смены сцены.
- Характеристики оружия и selector сохранены в правой панели.
- В `WeaponConfig` добавлены настраиваемые `texture` и `preview_scale`.

## Новые assets

- `assets/weapons/machine_gun/machine_gun_roof.png`
- `assets/weapons/heavy_machine_gun/heavy_machine_gun_roof.png`
- `assets/weapons/shotgun/shotgun_roof.png`

Ассеты созданы встроенным `image_gen` в строгой top-down проекции с прозрачным фоном. Общая prompt-спецификация: компактный интегрированный roof-модуль в industrial demolition-derby стиле, scratched gunmetal/rust, читаемый силуэт, направление вправо, без длинных выступающих стволов, текста и фона. Для вариантов отдельно заданы compact machine gun, reinforced triple-port heavy machine gun и twin-port shotgun с shell drum.

## Новые файлы

- `scripts/garage_vehicle_preview.gd`

## Изменённые файлы

- `scenes/Garage.tscn`
- `scripts/garage.gd`
- `scripts/weapon_config.gd`
- `resources/weapons/machine_gun.tres`
- `resources/weapons/heavy_machine_gun.tres`
- `resources/weapons/shotgun.tres`
- `tests/vehicle_visuals_smoke.gd`

## Проверка

- Все три оружия имеют отдельные RGBA assets.
- `vehicle_visuals_smoke.gd`: PASS.
- `garage_layout_smoke.gd`: PASS.
- `garage_loadout_smoke.gd`: PASS.
- Полный набор smoke-тестов: **33/33 PASS**.
- Ручная проверка Garage: heavy machine gun корректно установлен на Viper, отдельный preview справа отсутствует.
