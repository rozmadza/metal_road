# Phase P Report — Weaponless Vehicle Base Art

## Что изменено

- Созданы новые базовые спрайты автомобилей без заранее нарисованного оружия.
- Старые исходные изображения сохранены, а `VehicleConfig` переключены на новые `_clean.png`.
- Очищены Raider, Viper, Crusher, Wasteland GT и запасной Sport.
- Оружейный модуль в Garage размещается строго в центре области preview.
- Масштаб модулей уменьшен, чтобы вокруг крепления оставалась читаемая крыша.

## Новые assets

- `assets/vehicles/raider/raider_clean.png`
- `assets/vehicles/viper/viper_clean.png`
- `assets/vehicles/crusher/crusher_clean.png`
- `assets/vehicles/wasteland_gt/wasteland_gt_clean.png`
- `assets/vehicles/sport/sport_clean.png`

Изображения отредактированы встроенным `image_gen` в режиме `precise-object-edit`. Общая prompt-спецификация: удалить только существующие пушки и их крепления, восстановить чистую бронепанель крыши в исходном материале, сохранить top-down проекцию, силуэт, цвета, повреждения, остальные детали и прозрачность без изменений. Для Wasteland GT отдельно сохранён открытый двигатель и удалены только две боковые пушки.

## Изменённые файлы

- `resources/vehicles/raider.tres`
- `resources/vehicles/viper.tres`
- `resources/vehicles/crusher.tres`
- `resources/vehicles/wasteland_gt.tres`
- `resources/default_vehicle.tres`
- `resources/weapons/machine_gun.tres`
- `resources/weapons/heavy_machine_gun.tres`
- `resources/weapons/shotgun.tres`
- `scripts/garage_vehicle_preview.gd`
- `tests/vehicle_visuals_smoke.gd`

## Проверка

- Все selectable vehicle configs используют `_clean` base art.
- Default vehicle также использует weaponless asset.
- Weapon mount расположен точно в центре preview.
- `vehicle_visuals_smoke.gd`: PASS.
- `garage_loadout_smoke.gd`: PASS.
- `weapon_smoke.gd`: PASS.
- Полный набор smoke-тестов: **33/33 PASS**.
- Ручная проверка Crusher + Machine Gun: крыша чистая, модуль центрирован и не перекрывает штатное оружие.
