# Phase M Report — Speedometer HUD

## Что изменено

- Текстовый показатель скорости заменён на аналоговый спидометр.
- Добавлены дуговая шкала, деления, стрелка, цветной сектор и цифровое значение.
- Шкала автоматически использует `VehicleConfig.max_speed` выбранной машины.
- Один компонент используется в Race и Survival через общий `VehicleReadout`.
- При высокой скорости цвет активного сектора меняется с cyan на warning orange.

## Новые файлы

- `scripts/speedometer.gd`
- `tests/speedometer_smoke.gd`

## Изменённые файлы

- `scenes/VehicleReadout.tscn`
- `scripts/vehicle_readout.gd`

## Проверка

- `speedometer_smoke.gd`: PASS.
- `hud_race_smoke.gd`: PASS на 800×600, 1024×768 и 1366×768.
- `feedback_smoke.gd`: PASS.
- Полный набор smoke-тестов: **33/33 PASS**.
- Ручная визуальная проверка выполнена в Race и Survival.
