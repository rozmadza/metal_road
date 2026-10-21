# Metal Road — Codex handoff

Документ для продолжения работы над проектом на другом компьютере.

## Проект

- Движок: Godot 4.7.2.
- Рабочая папка: `godot/`.
- Главная сцена: `res://scenes/MainMenu.tscn`.
- Окно: 1280×720.
- Запуск: `/home/andrey/applications/Godot/Godot_v4.7.2-stable_linux.x86_64 --path .`.

## Реализовано

### Карьера и персонажи

- Добавлен первый сюжетный эпизод «Железный старт».
- Перед гонкой появляется диалог выбранного героя с Рэйзором.
- После финиша реплики зависят от победы, поражения или схода.
- В HUD отображаются герой и Рэйзор.
- Над машиной Рэйзора есть метка.
- При смене позиций появляются короткие радиореплики.

Основные файлы: `scripts/career_story.gd`, `scripts/career_dialogue.gd`, `scenes/CareerDialogue.tscn`, `scripts/pre_race.gd`, `scripts/race_results.gd`, `scripts/debug_hud.gd`, `scripts/game.gd`.

### Портреты и столкновения

- Портреты вписываются целиком и не обрезаются сверху.
- Физический контур машин синхронизирован с видимым корпусом.
- Пули проверяют попадание по ориентированному контуру машины.
- Стартовая решётка переразмещена: машины не накладываются.
- Навигация ботов учитывает габариты машин.

Основные файлы: `scripts/vehicle.gd`, `scenes/Vehicle.tscn`, `scripts/track.gd`, `scripts/game.gd`, `scripts/bullet.gd`, `scripts/arena_navigation.gd`, `scripts/arena_bot.gd`.

## Проверенные тесты

Прошли успешно:

```bash
godot --headless --path . --script tests/career_story_smoke.gd
godot --headless --path . --script tests/vehicle_footprint_smoke.gd
godot --headless --path . --script tests/handling_collision_smoke.gd
godot --headless --path . --script tests/race_combat_smoke.gd
godot --headless --path . --script tests/track_smoke.gd
godot --headless --path . --script tests/race_progress_smoke.gd
godot --headless --path . --script tests/arena_bot_navigation_integration.gd
```

Если команда `godot` отсутствует, используйте полный путь к Godot 4.7.2.

Добавленные тесты: `tests/career_story_smoke.gd`, `tests/vehicle_footprint_smoke.gd`.

## Ручная проверка

1. Открыть «Карьера» → выбрать героя → «Железный старт».
2. Проверить, что лица полностью помещаются в диалоге.
3. Нажать «Далее» и проверить переход на гонку.
4. Проверить панель героя/Рэйзора и метку над его машиной.
5. Столкнуться с другой машиной боком и бампером: корпуса должны встречаться без наложения.
6. После финиша нажать «Разговор · Карьера» и проверить соответствие реплики результату.

## Ограничения

- Полный сюжет пока реализован только для `iron_open` («Железный старт»).
- Остальные события используют существующие экраны карьеры.
- Сохранения `user://` не входят в Git.
- Headless Godot иногда сообщает об освобождении ObjectDB, но проверенные тесты завершаются с кодом 0.

## Следующий этап

Расширить сюжет на второе и третье события: диалог с Болтом для «Последней передачи», диалог с Никс для «Битвы за поставку», новости соперников между раундами и соперник в карточке события до старта.

## Передача через Git

На текущем компьютере:

```bash
git status
git add .
git commit -m "add Codex handoff and career story collision fixes"
git push
```

На новом компьютере:

```bash
git clone <URL_РЕПОЗИТОРИЯ>
cd metal_road/godot
git status
```

Запрос для Codex:

> Прочитай `CODEX_HANDOFF.md`, проверь текущий Git diff и продолжи со следующего этапа развития карьеры.
