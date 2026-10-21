# Sprint Report

SPRINT 1 — Visual & Damage Foundation, 2026-09-21.

## 1. Изменённые файлы

- `scripts/vehicle.gd`, `vehicle_config.gd`: совместимый health/Body, модульные коэффициенты физики, блокировка управления после смерти, сигнал impacted.
- `scripts/game.gd`, `survival.gd`: подключение collision audio; wreck противников очищается при следующем раунде (раньше умерший враг терялся из списка и оставался в дереве).
- `scripts/audio_manager.gd`, `audio_config.gd`: отдельный impact player, громкость по силе удара, cooldown и buses.
- `scripts/debug_hud.gd`, `arena_hud.gd`, `scenes/HUD.tscn`, `ArenaHUD.tscn`: компактные индикаторы модулей, общий стиль.
- `scenes/Vehicle.tscn`: wreck больше не исчезает до 25% opacity.
- `resources/default_vehicle.tres`, `project.godot`: растровый Sport и общая Theme.
- Новые `scripts/vehicle_damage.gd`, `vehicle_effects.gd`, `module_status.gd`.
- Baseline, логи, review-кадры и этот отчёт в `docs/sprints/`.

## 2. Добавленные ресурсы

- `resources/ui/main_theme.tres`: металлические панели, жёлтые кромки, cyan focus/hover.
- `assets/vehicles/sport/sport.png`: оригинальный RGBA Sport Car; происхождение описано рядом в README.
- `default_bus_layout.tres`: Master, Music, Engine, Weapons, Impacts, Environment, UI.
- Эффекты создают ограниченное число GPU emitters с мягкой процедурной текстурой; новые внешние зависимости не нужны.

## 3. Реализованные системы

`VehicleDamage` хранит Body/Engine/Wheels на экземпляр. API: `take_damage(amount, module = &"body")`, `damage.ratio(module)` и коэффициенты состояния. Прежний `take_damage(amount)` и `health` сохранены. Базовая физика на здоровой машине не изменена. Shared Resource не мутируется.

Три стадии повреждений (75%, 50%, 25%) плюс wreck; дым с 50% Body или Engine, огонь с 25% Body, искры при попаданиях и столкновениях. Эффекты отключаются конфигом. После смерти управление и оружие заблокированы; reset восстанавливает модули и эффекты.

## 4. Изменения gameplay

- Engine: `0.3 + 0.7 * engine_ratio` для тяги и максимальной скорости.
- Wheels: steering до 45%, traction до 25%; больше бокового скольжения.
- Обычный Body-урон дополнительно повреждает Engine на 55% и Wheels на 45% от суммы попадания. HP модулей: 70/60. Все значения в VehicleConfig.
- Body HP и прежний таранный урон сохранены. Collision feedback работает и в Race, но combatants по-прежнему только в Survival.
- Weapon damage, круги, respawn, progression не входят в Sprint 1.

## 5. Изменения art/audio

Новый растровый Sport, отключённые по умолчанию debug-векторы, процедурные шрамы/повреждённые панели, дым/огонь, непрозрачный обгоревший корпус. Меню и HUD используют единую Theme. Доступна замена texture и отключение VFX через конфиг.

Collision SFX подключён игроку и ботам в обоих режимах. Отдельный player не прерывается выстрелами; частые удары ограничены cooldown. Использован существующий WAV: это подключение звуковой основы, а не завершённый production sound pack. Музыка, двигатель и оружие маршрутизированы по buses.

Review: [damage states](damage-preview.png), [Race](main-preview.png), [Arena](arena-preview.png), [Menu](mainmenu-preview.png).

## 6. Новые тесты

- `damage_contract_smoke.gd`: добавлен и пройден ДО рефакторинга; legacy HP, отрицательный урон, однократная смерть, группы, коллизии, reset.
- `damage_modules_smoke.gd`: независимые модули, shared-resource isolation, стадии, dead controls, reset, NaN; реальный разгон и боковое скольжение на физических кадрах.
- `feedback_smoke.gd`: smoke/fire, отключение частиц, Race collision без урона, независимые показания HUD.
- `audio_smoke.gd`: buses, collision wiring, stream, громкость по интенсивности, независимость impact/gun, отсутствующий config.
- `visual_damage_preview.gd`: оконная review-сцена, сохраняет кадры damage/menu/Race.
- `sprint_performance.gd`: воспроизводимый оконный stress sample.

## 7. Результаты всех smoke-тестов

Baseline: **11/11 PASS**. После Sprint 1: **15/15 PASS**, exit 0.

| Тест | Результат |
|---|---|
| arena_smoke | PASS |
| assets_smoke | PASS |
| audio_smoke | PASS |
| bot_smoke | PASS |
| controls_smoke | PASS |
| damage_contract_smoke | PASS |
| damage_modules_smoke | PASS |
| derby_smoke | PASS |
| feedback_smoke | PASS |
| game_smoke | PASS |
| menu_smoke | PASS |
| survival_smoke | PASS |
| track_smoke | PASS |
| vehicle_smoke | PASS |
| weapon_smoke | PASS |

Полные логи: `baseline-logs/`, `sprint-1-logs/`. Запуск: Godot `--headless --path . --log-file /tmp/metal-smoke.log --script res://tests/<test>.gd`. После новых class_name/ассетов сначала `--headless --editor --import --quit`.

## 8. Performance

Godot 4.7.2 / GL Compatibility / Intel HD 4000. Оконный обзор всей арены, 6 машин одновременно, критическое повреждение, дым/огонь, непрерывная стрельба, существующие static obstacles. 2 секунды прогрева + 10 секунд измерения:

- средний кадр **16.64 ms**, p95 **16.67 ms**;
- средняя частота **60.1 FPS**;
- максимум 11 пуль, 18 emitters (6 × 3), максимум 276 частиц;
- результаты сохранены в `performance.txt`.

Для сохранения шести машин в течение замера урон отключён удалением из combatants; это stress sample отрисовки/физики, не проверка AI-balancing. Debris и destructible props ещё не реализованы, полный целевой сценарий vertical slice пока не проверен. Pooling не добавлялся.

## 9. Известные проблемы

- Сохранились baseline exit-предупреждения ObjectDB/resources в части старых тестов; не являются новыми runtime script errors. Полные логи приложены. Новый audio smoke также воспроизводит эту проблему: после запуска четырёх WAV остаются 9 audio instances / 4 streams; verbose указывает на AudioStreamWAV/PlaybackWAV.
- Карта и арена пока используют прежнее окружение; Sport — первый производственный растровый ассет.
- При 40×24 px мелкие повреждения читаются слабее крупных дымовых/огненных состояний; нужен человеческий playtest читаемости в движении.
- Оконная проверка и замер выполнены автоматически; субъективное качество звука и ощущение управления требуют playtest.

## 10. Technical debt

- Нужны production engine/impact/fire audio и пространственное затухание удалённых событий.
- HUD ещё использует фиксированные отступы для текущего 800×600; полноценная адаптивная раскладка — следующий UI проход.
- Прямые попадания в модули поддержаны API; текущие пули/таран распределяют Body-урон по коэффициентам, без hit zones.
- Модуль Weapon, detachable debris и общий пул environmental FX остаются отдельными будущими задачами.
- Не устранены существующие exit leaks; git изначально показывал весь Godot-проект untracked, коммит не создавался.

## 11. Следующий спринт

Сначала короткий playtest новой физики повреждений и читаемости, затем Phase C: WeaponConfig extension, второе оружие, VFX/SFX и тесты. Дальше Phase D: checkpoint/lap/ranking/finish/results, Combat Race с предпочтительным arcade respawn. Garage, Scrap, upgrades и новые карты — после стабилизации этой основы.
