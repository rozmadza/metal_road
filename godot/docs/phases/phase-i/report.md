# Phase I — Audio / VFX Polish

## Что изменено

- добавлен короткий time-based camera shake;
- лёгкий shake используется при столкновениях и таране;
- сильный shake подключён к взрыву бочки в Survival;
- взрыв бочки теперь проигрывает существующий explosion audio contract;
- горящий корпус бочки сохраняется достаточно долго для читаемого feedback;
- VehicleEffects продолжают показывать дым, огонь и искры по стадиям damage;
- barrel explosion сохраняет читаемый fire/debris-like burn burst;
- сохранены отдельные AudioBus для Weapons, Impacts, Environment и UI.

## Изменённые файлы

- `scripts/camera.gd`;
- `scripts/game.gd`;
- `scripts/survival.gd`;
- `scripts/explosive_barrel.gd`;
- `tests/audio_smoke.gd`.

## Проверка

- `audio_smoke`: PASS;
- `feedback_smoke`: PASS;
- `game_smoke`: PASS;
- `survival_smoke`: PASS;
- `explosive_barrel_smoke`: PASS.
- `environment_smoke`: PASS.

Предупреждения ObjectDB в старых headless-тестах не изменились; ошибок
GDScript нет.

## Ограничения

Новые индивидуальные WAV для tire screech, oil slide и barrel impact пока не
добавлялись: используются существующие collision/explosion streams. Полный
набор debris и skid mark decals остаётся следующим polish-подэтапом.
