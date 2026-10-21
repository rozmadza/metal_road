# Phase H — Интерактивное окружение арены

## Что изменено

- добавлен `OilSpot` как Area2D-компонент;
- масло уменьшает traction до 0.38 и steering stability до 0.72;
- восстановление сцепления после выезда занимает около 0.6 секунды;
- добавлен `ExplosiveBarrel` с health, радиусом и falloff урона;
- взрыв повреждает combatants и соседние бочки;
- добавлены `destroyed`/`exploding` guards для безопасной chain reaction;
- bullets теперь проверяют группу `destructibles`;
- ArenaConfig получил настраиваемые позиции oil spots и barrels;
- в default arena добавлены два масляных пятна и четыре взрывоопасные бочки;
- визуальные oil/barrel props рисуются непосредственно компонентами;
- базовая Vehicle-физика получила surface modifiers без изменения collision shape.
- surface modifiers теперь учитывают источник зоны: выход из одного OilSpot не
  сбрасывает эффект другой перекрывающейся зоны;
- рестарт Vehicle очищает активные surface modifiers.
- исправлено растянутое отображение OilSpot: scale применяется только к
  collision shape, а сама отрисовка использует явный размер пятна;
- OilSpot получил тёмную масляную заливку и тонкие янтарные блики;
- ExplosiveBarrel теперь оставляет заметный горящий корпус после вспышки,
  поэтому результат попадания читается во время playtest.
- таран на скорости выше `collision_min_speed` теперь повреждает бочки через
  общий `Vehicle._on_body_entered` contract;
- бочка от тарана использует тот же radial damage и chain reaction.
- правило разрушения бочки унифицировано: ровно два подтверждённых попадания
  (выстрелы или тараны) вызывают взрыв.

## Добавленные файлы

- `scripts/oil_spot.gd`;
- `scripts/explosive_barrel.gd`;
- `scenes/OilSpot.tscn`;
- `scenes/ExplosiveBarrel.tscn`;
- `tests/oil_spot_smoke.gd`;
- `tests/explosive_barrel_smoke.gd`.

## Изменённые файлы

- `scripts/vehicle.gd`;
- `scripts/bullet.gd`;
- `scripts/arena.gd`;
- `scripts/arena_config.gd`;
- `resources/default_arena.tres`.

## Проверка

- `oil_spot_smoke`: PASS;
- `explosive_barrel_smoke`: PASS;
- regression на фактический Area2D overlap и перекрывающиеся OilSpot: PASS;
- ручной playtest Survival: OilSpot выглядит компактно, попадание по бочке
  вызывает огонь, радиальный урон и поражение игрока в зоне взрыва.
- `explosive_barrel_smoke` отдельно проверяет damage от ram impact.
- `arena_smoke`: PASS;
- `survival_smoke`: PASS;
- `race_combat_smoke`: PASS;
- `game_smoke`: PASS;
- полный набор из 28 smoke-тестов: PASS.

## Ограничения

Взрыв пока использует существующий audio/VFX contract без отдельного barrel
SFX и полноценного particle burst. Это входит в Phase I. Дополнительные props
TireWall, Crate, Wreck и MetalFence подготовлены как следующий слой окружения.

## Следующий этап

Следующим этапом остаётся Phase I — audio/VFX polish: explosion particles,
smoke/fire, debris, skid marks, camera shake и отдельные звуки интерактивных
объектов.
