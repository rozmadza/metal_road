# Metal Road — P0: исправление запуска через «Выйти на арену»

Дата: 30 октября2026. Godot4.7.2, RX580/radeonsi, Compatibility. Проект: `/home/andrey/PycharmProjects/metal_road/godot`.

## Результат

**Дефект воспроизведён в фактической рабочей папке и устранён.** Проверен запуск проекта через F5 в настоящем редакторе, нативное X11-нажатие мышью «Выживание» → «Выйти на арену», появление боя и возврат через паузу в главное меню. Дополнительно GUI regression проходит на новом профиле, копии профиля пользователя и при намеренно устаревшем кэше нового класса.

Причина — неполный импорт рабочего проекта после v1/v2: отсутствовала регистрация нового `WeaponVisualProfile` и все четыре импортированные `.ctex` новых PNG. Предыдущие проверки импортировали отдельные диагностические копии; фактическая рабочая папка оставалась без этих результатов импорта. Это пропущенный этап предыдущей интеграции, а не изменение поведения кнопки или боевого баланса.

## Сохранение рабочего дерева

На старте: ветка `codex/tactical-wave-identity-v1`, HEAD `3b8a9bc747539470326e907b15b4ceb5d674018e`. Существовали незакоммиченные v1/v2, QA и файлы арта владельца. Сохранены исходные status/diff и полная копия дерева вместе с прежним `.godot` в `/tmp/metal-road-arena-launch-before`. Reset/checkout/commit/push/merge мной не выполнялись. Во время завершения документации обнаружен внешний commit `2bd1a1acb75f20ae7e59cbe69d8b3d0276e3a100` (автор в Git: Andrey Kitaev); HEAD изменился, содержимое проверенных production-скриптов осталось тем же. Внешний commit не отменялся и не переписывался.

[Исходный status](arena-launch-button-evidence/initial-status.txt), [исходный diff](arena-launch-button-evidence/initial-diff.patch.txt), [только изменения исходников этой задачи](arena-launch-button-evidence/task-only-source.patch.txt), [проверка сохранности](arena-launch-button-evidence/preservation.json). Из772 ранее существовавших файлов scripts/resources/scenes/assets/tests768 совпадают побайтно, изменены только четыре скрипта, перечисленные ниже. Ни один из десяти PNG ракетницы — концепт, roof, четыре авторских исходника и четыре подготовленных изображения — не изменён. Все прежние отчёты сохранены; QA дополнен новой записью.

## Воспроизведение и подтверждённая причинная связь

### 1. Запуск исходного рабочего проекта без предварительного импорта

Обычный графический запуск текущего пути проекта, без тестового создания ArenaBattle и без `--editor --import`, дал:

```text
Parse Error: Could not find type "WeaponVisualProfile" in the current scope.
  res://scripts/weapon_config.gd:44
Compile Error: Failed to compile depended scripts.
  res://scripts/bonus_weapon_cache.gd
  res://scripts/scene_transition.gd
```

Аналогичный новый тип использовался в `bullet.gd` и `combat_vfx.gd`. В исходном `.godot/global_script_class_cache.cfg` записи `WeaponVisualProfile` действительно не было. Это ломало зависимости autoload Transition и интерфейса ещё до успешной подготовки боя. [Исходный лог](arena-launch-button-evidence/logs/arena-launch-root-before.log).

### 2. GUI-нажатие после устранения зависимости от кэша классов, до импорта PNG

После добавления явных preload, без обновления исходного кэша и без импорта PNG, меню и PreRace успешно принимали GUI input. В графическом тесте нажаты настоящие Button через hit-test; журнал подтвердил:

```text
clickable ВЫЖИВАНИЕ
pressed received through GUI hit test
selected vehicle owned
clickable ВЫЙТИ НА АРЕНУ
pressed received through GUI hit test
Unable to open file: res://.godot/imported/projectile_body.png-....ctex
Could not prepare bonus weapon: res://resources/weapons/rocket_launcher.tres
Scene load failed: res://scenes/ArenaBattle.tscn
```

То же отсутствующее импортированное представление было у exhaust/muzzle/explosion. Четыре исходных PNG и `.import` **существовали**, а remap-цели `.ctex` отсутствовали. Сообщение ResourceLoader про несуществующий `resources/weapon_visuals/rocket_launcher.tres` являлось следствием не загруженных зависимостей: сам `.tres` находился на диске. [Полный лог](arena-launch-button-evidence/logs/arena-launch-gui-user-final.log), [проверка remap до/после](arena-launch-button-evidence/import-state.json).

Ключевая цепочка: `WeaponConfig(rocket_launcher)` → visual profile → четыре Texture2D → отсутствующие `.ctex` → `BonusCache.prepare()==false` → `_fail_transition()`. Кэш готовит **все семь** штатных конфигураций, поэтому ошибка Rocket Launcher блокировала и старт с обычным сохранённым machine_gun. Отдельные прежние тесты, напрямую создававшие ArenaBattle в импортированных копиях, этот путь не проверяли.

### 3. Контрольный эксперимент с типами

В изолированной копии с уже исправными импортированными PNG удалена **только** запись нового класса из кэша. Возврат исходных трёх аннотаций воспроизвёл `Could not find type WeaponVisualProfile`. Те же PNG, те же сцены и тот же кэш без этой записи с явными preload прошли полный GUI маршрут, включая выстрел Rocket Launcher. Кэш по завершении по-прежнему не содержал новую запись; повторный импорт для положительного контроля не выполнялся.

[Отрицательный контроль](arena-launch-button-evidence/logs/arena-launch-class-negative-control.log), [положительный контроль](arena-launch-button-evidence/logs/arena-launch-class-positive-verified.log), [input trace](arena-launch-button-evidence/stale-class/input-trace.json). Это подтверждает самостоятельную зависимость ошибки компиляции от реестра класса, а не от содержимого PNG, AI, музыки или профиля.

## Проверка кнопки и всей цепочки

Сцена: `scenes/PreRace.tscn`; узел `Margin/Layout/Footer/StartButton` (описание около строки309), runtime `/root/PreRace/Margin/Layout/Footer/StartButton`.

| Этап | Что установлено |
| --- | --- |
| Доступность | owned-автомобиль выбран; disabled=false, mouse_filter=STOP. У заблокированного автомобиля прежняя надпись о покупке/disabled, правила не менялись |
| Сигнал | `PreRaceSetup._ready()` подключает pressed к `_start_mode()`; GUI trace фиксирует существующие connections и реальное поступление pressed |
| Перекрытия | LoadingOverlay скрыт до старта; input проходит hit-test. Декоративные Control не блокировали подтверждённые нажатия |
| Валидация | `PlayerProfile.is_owned` положителен, ID машины существует; LoadoutProfile сохраняет машину режима и прежний weapon ID |
| Запрос | `_start_mode()` вызывает `SceneTransition.go()` с ArenaBattle; `_go()` выставляет busy, рисует overlay и запускает запрос/использует warm cache |
| Подготовка | `_commit_scene()` вызывает BonusCache.prepare до смены сцены. Именно здесь до исправления отсутствовали Texture2D-зависимости |
| Смена сцены | После импорта change_scene_to_packed успешен; ровно одно scene_changed на старт даже при двойном GUI-клике |
| Бой | Ровно одна match scene, player.alive=true, конфигурация машины есть, первая волна началась |
| Загрузка/музыка | busy=false и overlay.visible=false; проверены логические состояния Menu/Survival/Race, затем возврат к Menu |

Классификация: подтверждён **E — отказ подготовки зависимостей**, плюс исходная проблема компиляции класса. Не подтверждены блокировка мыши/disabled, неверный автомобиль или profile/loadout как причина. Это не случай D с успешно загруженным боем под зависшим overlay: до отказа BonusCache игровая сцена ещё не активировалась. Старый `_fail_transition()` скрывал overlay и оставлял PreRace, выводя ошибку только в Output, что объясняет внешнее «ничего не происходит».

## Минимальное исправление

1. В `scripts/weapon_config.gd`, `scripts/bullet.gd`, `scripts/combat_vfx.gd` новый тип теперь берётся как `const VisualProfile = preload("res://scripts/weapon_visual_profile.gd")`. Аннотации, export-поле, argument/cast используют этот alias. Существующий class_name, ресурсный формат, поля, renderer, физика и вызовы событий сохраняются. Это тот же GDScript-класс, без копирования текстур и без новой архитектуры.
2. В **фактической рабочей папке** выполнен штатный Godot import:

```sh
flatpak run --filesystem=/home/andrey/PycharmProjects/metal_road/godot   org.godotengine.Godot --headless --editor   --path /home/andrey/PycharmProjects/metal_road/godot --import
```

Созданы четыре отсутствовавших `.ctex`, обновлён реестр скриптов. Это штатные игнорируемые данные `.godot`, их не следует коммитить или заменять runtime-загрузкой сырых PNG. Редактор также автоматически восстановил отсутствовавшие `.gd.uid` и импорт-метаданные ранее добавленных источников; пользовательские исходники/арт не откатывались.

3. В `scripts/scene_transition.gd` отказы начала загрузки, загрузки/подготовки и переключения сцены показывают один переиспользуемый AcceptDialog. Старый экран остаётся, busy/overlay освобождаются; сообщение закрывается кнопкой OK и допускает новую попытку. Подробного постоянного логирования не добавлено: существующие ошибки остаются в Output. Это отдельное требуемое улучшение сообщения об отказе, а не подмена восстановления отсутствующих ресурсов.

Сцены `.tscn`, `pre_race.gd`, `main_menu.gd`, `garage.gd`, музыкальные скрипты, конфигурация оружия, волны, физика и PNG не изменялись в этой задаче.

## Проверка из редактора и реальный input

Открыт именно рабочий путь проекта в настоящем редакторе Godot, затем подано нативное X11-событие **F5**, не прямое создание сцены. Использована отдельная копия пользовательских данных через XDG_DATA_HOME; окно1280×720, без вмешательства в основные сохранения. XTest mouse down/up прошли через ОС к кнопкам: главное меню → Выживание → PreRace → Выйти на арену → бой. Escape открыл паузу; нативный клик «В главное меню» вернул стартовый экран.

[Меню из F5](arena-launch-button-evidence/editor-f5/main-window.png), [PreRace](arena-launch-button-evidence/editor-f5/pre.png), [фактический бой](arena-launch-button-evidence/editor-f5/fight.png), [пауза](arena-launch-button-evidence/editor-f5/pause.png), [возврат в меню](arena-launch-button-evidence/editor-f5/returned-menu.png). Сохранены только кадры окна игры; остальной рабочий стол в отчёт не включён. Embedded-game warnings о невозможности resize/fullscreen — ограничения окна редактора, не ошибки скриптов.

Это автоматизированный нативный GUI-проход, **не ручное прохождение Survival**. Засчитан один полный контрольный маршрут из F5. Второй OS-проход не засчитывался: фокус/перекрытие окон изменились, контрольный кадр остался меню; повторные клики без актуального видимого состояния прекращены. Повторный вход в бой отдельно многократно проверен portable GUI-тестом ниже, без зависимых от рабочего стола координат.

## Новые автоматические GUI-тесты

### tests/arena_launch_gui_smoke.gd

Работает через `Input.parse_input_event`: мышь проходит Control hit-test, Enter — обработку клавиатуры, JOY_BUTTON_A — ui_accept. Не использует `pressed.emit()`, `_start_mode()` или вызов обработчика перехода как замену нажатия. Для вложенного Window координаты пересчитываются в native window; учитывается асинхронная очередь Input. Удержание Space проверяет реальное появление Bullet после запуска.

Проверены:

- обычное меню → Survival, двойной клик Start → один переход и одна сцена;
- выход через Escape/кнопку паузы в меню → повторный вход;
- Menu → Garage → PreRace → бой, Enter;
- Restart через GUI паузы → новая session generation и волна1;
- сохранённый legacy weapon ID rocket_launcher не теряется при запуске;
- четыре Rocket Texture2D готовы из общего кэша; после тестовой выдачи штатного временного оружия Space создаёт ракету;
- Race через GUI и возврат;
- Career через GUI, при необходимости выбор пилота, экран подготовки и пропуск story-кнопкой, затем Career match и возврат.

В текущем дизайне PreRace выбирает **автомобиль**, а не стартовое оружие: игра начинается без установленного оружия. Поэтому тест legacy weapon ID не объявляется новым выбором ракетницы в UI. Выдача временной ракетницы после GUI-старта — явно обозначенная тестовая подготовка, не изменение правил бонусов. Исходные владение автомобилем/выбор режима/owned-ограничения сохранены.

Финальные прогоны: [чистый профиль](arena-launch-button-evidence/logs/arena-launch-gui-clean-verified.log), [копия профиля пользователя](arena-launch-button-evidence/logs/arena-launch-gui-user-verified.log), [устаревший реестр класса](arena-launch-button-evidence/logs/arena-launch-class-positive-verified.log): **3/3 PASS, failures0**. Это синтетические события устройства; физический геймпад не испытывался. Исходные fullscreen1920 настройки пользователя сохранены, но эти прогоны и редакторский контроль выполнялись в окне1280×720; отдельная full-screen матрица не заявляется.

### tests/scene_transition_failure_smoke.gd

Отдельный отрицательный тест намеренно запрашивает несуществующую сцену. Проверяет visible error dialog, освобождение busy/overlay, сохранение старого экрана, реальный GUI-клик OK и последующий успешный Menu→PreRace→Arena launch. **PASS**; ResourceLoader ERROR с именем `__missing_launch_regression__.tscn` в его журнале ожидаемы. [Диалог](arena-launch-button-evidence/negative/load-error-dialog.png), [окончательный лог](arena-launch-button-evidence/logs/arena-launch-negative-verified.log).

Интерфейс не предлагает выхода/отмены в loading overlay. Отмена во время загрузки не добавлялась и не заявляется проверенной возможностью. Возврат из активного боя и повторный старт проверены.

При разработке тестов сохранены исходные FAIL: явный тип тестовой переменной; ошибочная маршрутизация embedded-dialog координат/проверка pressed до обработки очереди; Space через Viewport.push_input не менял глобальное Input-состояние. Исправлены только тестовые события/синхронизация, игровые механики ради PASS не менялись. Эти логи находятся в evidence и отделены от исходных производственных ошибок отсутствующих класса/.ctex.

## Полная регрессия

**19/19 существующего последовательного runner PASS**, включая Survival, Race, Career, Garage, Restart100 и release candidate; **5/5 дополнительных smoke PASS**. Новые GUI-проверки выше выполнялись отдельно графически, их не подменяет headless-runner. Снимок production-исходников в runner побайтно совпадает с окончательными четырьмя исправленными скриптами.

| Тест | Результат | Teardown ObjectDB/resources |
| --- | --- | --- |
| `vehicle_catalog_cache_smoke` | PASS | 4/2 |
| `profile_recovery_smoke` | PASS | 4/2 |
| `garage_loadout_smoke` | PASS | 0/0 |
| `garage_smoke` | PASS | 5/2 |
| `pre_race_smoke` | PASS | 8/4 |
| `career_gameplay_smoke` | PASS | 8/4 |
| `race_finish_smoke` | PASS | 23/7 |
| `controls_smoke` | PASS | 8/2 |
| `survival_smoke` | PASS | 12/4 |
| `survival_playability_smoke` | PASS | 12/3 |
| `survival_boss_schedule_smoke` | PASS | 8/4 |
| `survival_biker_crew_smoke` | PASS | 19/6 |
| `survival_roguelite_smoke` | PASS | 16/5 |
| `survival_round_guard_smoke` | PASS | 8/4 |
| `survival_restart_smoke` | PASS | 4/2 |
| `survival_reward_feedback_smoke` | PASS | 0/0 |
| `tactical_arsenal_smoke` | PASS | 4/2 |
| `release_v1_smoke` | PASS | 4/2 |
| `release_candidate_smoke` | PASS | 6/3 |
| `rocket_visual_profile_smoke` | PASS | 0/0 |
| `weapon_smoke` | PASS | 4/2 |
| `combat_vfx_budget_smoke` | PASS | 0/0 |
| `race_combat_smoke` | PASS | 2/1 |
| `menu_smoke` | PASS | 6/3 |

Restart100: nodes199→197, orphan0. В финальных положительных логах нет GDScript parse/compile/runtime ошибок, отсутствующих текстур или зависших переходов. В части прежних тестов остаются shutdown ObjectDB/resources warnings; новые положительные GUI-прогоны тоже имеют ObjectDB teardown warnings. Их количество сохранено в логах; это не утверждение о подтверждённых runtime-утечках или об их устранении. Негативные controls/намеренно отсутствующая сцена имеют ожидаемые ошибки и не смешиваются с положительными результатами.

## Файлы и оставшиеся ограничения

Production: четыре скрипта `weapon_config.gd`, `bullet.gd`, `combat_vfx.gd`, `scene_transition.gd`. Добавлены два GUI regression `.gd` с `.uid`, этот отчёт и evidence; QA дополнен. Штатный импорт обновил игнорируемый `.godot` и создал недостающие метаданные `.uid`/`.import`; изображения не редактировались.

Старая причина требует импорта именно запускаемого проекта после появления новых ассетов. Явный preload устраняет зависимость **нового типа** от записи реестра, но не отменяет штатный импорт PNG и вообще не делает любой произвольный неимпортированный Godot-проект готовым к runtime. При свежем checkout следует дать редактору закончить импорт либо выполнить штатную import-команду перед CLI-запуском. В экспортированную игру зависимости должны входить через обычный Godot export, не копированием случайного `.godot`.

Оставшиеся ограничения: один подтверждённый нативный маршрут F5; повторяемые маршруты — автоматические Input-event проверки; нет физического геймпада, ручной художественной приёмки, полного fullscreen-набора или длительного прохождения волн. Ни графическая переработка других оружий, ни изменение баланса, ни дополнительная оптимизация не выполнялись.
