# Report

Sprint B–C–D, 21–22 сентября 2026. Завершение проверки после прерванной сессии.
[Восстановленное состояние](recovery.md), [аудит](audit.md),
[Phase B](phase-b.md), [Phase C](phase-c.md), [Phase D](phase-d.md).

## 1. Что изменено

Race получил законченный цикл: старт → бой и три круга → FINISHED либо DNF →
результат → повтор/гараж/меню. Существующие физика, сцены, ресурсы и контракты
управления сохранены. Survival использует прежние правила раундов.

## 2. Исправления HUD

Компактные status сверху, скорость слева внизу, оружие по центру внизу,
Body/Engine/Wheels справа внизу. F1 отделён от игровых панелей.
Общий `Vehicle.get_hud_state()` передаёт реальные значения обеим сценам через
VehicleReadout. Сохранены `update_info` / `update_status`.

Проверены 800×600, 1024×768, 1366×768: spawn и центр камеры свободны,
панели внутри viewport, debug не пересекает HUD. Широкий viewport проверен
отдельно; исправление fullscreen/aspect ratio в этот sprint не входит.

## 3. Race Combat

Участники входят в `combatants`, если `TrackConfig.combat_enabled` включён.
Общие Bullet / MachineGun / Vehicle обрабатывают пули и таран в обоих режимах.
Столкновения со статическими препятствиями наносят урон боевым участникам.
Shooter игнорирует себя; проверены player→bot, bot→player, bot→bot.

Смерть отключает управление, стрельбу, коллизии; остаётся wreck, запускаются
общий взрыв VFX и настраиваемый SFX. Race фиксирует DNF и авторство убийства.
Автоматического respawn нет; восстановление только через Restart/Retry.

## 4. Race Lifecycle

- Три круга из TrackConfig; расчёт через существующие Track helpers.
- Последовательные checkpoints, направление и минимальный путь для зачёта.
- Обратный круг, качание через финиш и shortcut не дают ложного круга.
- Позиция по кругам и прогрессу; FINISHED сохраняет порядок финиша, DNF ниже живых.
- Таймер MM:SS.xx останавливается с заездом.
- Result: позиция, время, круги, kills, damage dealt, Credits.
- Credits равны 0 до реализации экономики; награда и сохранение не имитируются.
- Retry сбрасывает здоровье, прогресс, статистику, пули и состояние участников.

## 5. Новые файлы

- `scenes/VehicleReadout.tscn`, `scenes/RaceResults.tscn`.
- `scripts/vehicle_readout.gd`, `scripts/race_progress.gd`, `scripts/race_results.gd`.
- `assets/sounds/combat/vehicle_explosion.wav` — оригинальный синтез короткого взрыва.
- Четыре regression smoke и два review-скрипта, перечисленные ниже.
- `docs/sprints/bcd/`: отчёты, логи и доказательные кадры.

## 6. Изменённые файлы

По сравнению с состоянием Phase A (восстановлено по отчётам; Git не содержит
отслеживаемой исходной версии проекта):

- `scenes/HUD.tscn`, `ArenaHUD.tscn`, `Main.tscn`.
- `scripts/debug_hud.gd`, `arena_hud.gd`, `module_status.gd`.
- `scripts/vehicle.gd`, `bullet.gd`, `machine_gun.gd`, `vehicle_effects.gd`.
- `scripts/game.gd`, `survival.gd`, `track_config.gd`, `weapon_config.gd`.
- `scripts/audio_config.gd`, `audio_manager.gd`, `resources/default_audio.tres`.
- `resources/iron_circuit.tres`, `pasport.md`.

После восстановления не переписывалась игровая реализация: повторены проверки,
завершена документация. Старые smoke-тесты не заменялись ослабленными проверками.

## 7. Новые tests

| Тест | Проверяет |
|---|---|
| hud_race_smoke | actual Player binding, speed/modules, spawn/центр/bounds/debug, 3 разрешения и оба режима |
| race_combat_smoke | реальные пули во всех направлениях, физический таран, смерть, DNF, input/gun, reset, combat flag |
| race_progress_smoke | 3 круга, reverse crossing, качание на финише, shortcut |
| race_finish_smoke | ranking, finish/result, остановку времени, Retry, летальный projectile/DNF, Garage/Menu |

Дополнительно `hud_layout_review.gd` рендерит HUD при разных разрешениях;
`race_playthrough.gd` водит машину через InputMap, не меняя HP/позиции/круги.
`-- --solo` отключает ботов для контрольного заезда; `-- --review` оставляет
окно результата для проверки UI мышью.

## 8. Smoke results

Phase B: **18/18 PASS**. Phase C: **19/19 PASS**. Phase D: **21/21 PASS**.
После восстановления: **21/21 PASS**, exit 0; [актуальные логи](resumed-logs/).
Сохранены также `phase-b-logs/`, `phase-c-logs/`, `phase-d-logs/`.

Исходные 17: arena, assets, audio, bot, controls, damage_contract,
damage_modules, derby, feedback, game, garage, menu, menu_visual,
survival, track, vehicle, weapon — все PASS.

В 9 из 21 headless-процессов остаются предупреждения ObjectDB/resources at exit.
Они не скрыты из логов и не равнозначны полностью чистому shutdown.
Ошибок GDScript в повторном suite не выявлено.

## 9. Manual playtest

Godot 4.7.2, GL Compatibility, Intel HD Graphics 4000.
Ручная проверка агентом через X11/XTest и визуальный осмотр кадров:

- Race/Survival spawn виден, F1 отдельно: `manual/B-*.png`.
- Управление, стрельба и runtime-урон: `manual/C-*.png`.
- DNF и все модули после смерти: [кадр](manual/resumed-DNF.png).
- Реальный клик «Заново»: [кадр](manual/resumed-Retry.png), LAP 1/3,
  время 00:00.23, все модули 100%, результат скрыт.
- Реальный клик «Гараж»: [кадр](manual/resumed-Garage.png), открывается Garage
  с preview и характеристиками; прежняя гонка закрывается.
- Реальный клик «Главное меню»: [кадр](manual/resumed-Menu.png), открывается
  Main Menu. Логи оконных прогонов: `resumed-logs/window-*.log`.

Оконное автоматизированное вождение (отдельно от ручной проверки):

- Соло: FINISHED, 3 круга, 24,73 с — [кадр](playthrough-solo.png).
- Combat: FINISHED, место 3/3, 3 круга, 37,52 с, урон 100 —
  [лог](race-playthrough-combat.log).
- Повторный боевой прогон после восстановления: DNF за 10,45 с, урон 30.
  Итог зависит от столкновений и стрельбы; гарантированная победа не требуется.

Субъективное качество звука на слух, человеческий финальный acceptance и
60 FPS с шестью машинами не подтверждены этими проверками.

## 10. Regression risks

- Баланс Race с включённым уроном требует playtest: возможен ранний DNF.
- ИИ сохраняет прежнее наведение на игрока; свободный взаимный урон работает.
- Проверка кругов валидирована на Iron Circuit; новые треки требуют своих тестов.
- Визуальная читаемость мелких машин и старые пороги повреждений 75/50/25%
  остаются задачами polish; целевые 70/40/15% пока не внедрены.
- Известный долг освобождения audio-ресурсов при завершении headless-процессов.

## 11. Остались проблемы

Настройки не сохраняются, fullscreen сохраняет прежний aspect ratio.
Garage остаётся preview одной машины/оружия. Нет экономики, покупки, upgrades,
OilSpot/ExplosiveBarrel, полного environment/audio pass, camera shake и debris.
Survival сохраняет баннер результата; отдельный RaceResults добавлен только Race.
Масштаб машин и баланс Survival не менялись до принятия P1.

## 12. Следующий этап

Пользовательская приёмка Race/HUD, затем Phase E: ConfigFile settings_version,
Master/Music/SFX/Engine и widescreen. Фазы F–I не начинались.

Самостоятельный запуск из корня проекта:

```bash
/home/andrey/applications/Godot/Godot_v4.7.2-stable_linux.x86_64 --path .
```

Все smoke-тесты (после `--headless --path . --import` на свежей копии):

```bash
GODOT=/home/andrey/applications/Godot/Godot_v4.7.2-stable_linux.x86_64
for test in tests/*_smoke.gd; do
  "$GODOT" --headless --path . --log-file /tmp/metal-smoke.log --script "$test" || exit 1
done
```
