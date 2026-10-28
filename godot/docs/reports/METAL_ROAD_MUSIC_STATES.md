# Metal Road — три музыкальных состояния

Дата: 2026-10-28. Godot 4.7.2 stable, Flatpak, OpenGL Compatibility / Radeon RX580.

## Исходное состояние и база

Исходный HEAD `1f04e9610626184a585fc696b63cd2a2a6f4a432` совпадает с локальным main и удалённым `origin/main` (проверено через `git ls-remote`). Работа выполнена в существующей ветке `codex/tactical-wave-identity-v1`, без переключения ветки, commit, push и merge. Исходные незакоммиченные изменения тактики в `arena_bot.gd`, `survival.gd`, новые tactical-скрипты и evidence сохранены; они не относятся к музыкальной интеграции.

Раньше `AudioManager` создавался внутри Main/ArenaBattle. Музыка, двигатель и оружие имели дочерние проигрыватели. Survival заменял `theme.wav` тремя синхронными `foundry_verdict_*` stems, громкость которых обновлялась каждый кадр по интенсивности и живому боссу. Поэтому гибель босса выключала boss-слой ещё до завершения боя с байкерами. При уничтожении сцены музыка уничтожалась вместе с ней; постоянной музыки главного меню/Garage не было. `SceneTransition` уже управляет загрузкой и снимает pause при навигации. Settings регулирует Master/Music и шины эффектов. PauseOverlay ставит SceneTree на паузу. Race использовал `resources/default_audio.tres` → `assets/music/theme.wav`, адаптивные pitch/volume и дополнительный процедурный слой Rust Frontier.

## Ресурсы

| Состояние | Реальный путь | Длина | Уровень проигрывателя |
|---|---|---:|---:|
| MUSIC_MENU | `res://assets/music/metal_road_garage_warm_desert_groove_loop.ogg` | 149.71 с | −18 dB |
| MUSIC_SURVIVAL | `res://assets/music/metal_road_apocalyptic_combat_loop_heavier.ogg` | 166.40 с | −16 dB |
| MUSIC_ARBITER | `res://assets/music/metal_road_arbiter_arena_de_combote_loop.ogg` | 76.11 с | −17 dB |

Использованы уже предоставленные OGG. Аудиоданные не редактировались и не перекодировались, копии композиций не создавались. Старые theme/foundry ресурсы сохранены. В трёх `.ogg.import` установлены `loop=true`, `loop_offset=0`; то же гарантируется перед воспроизведением. Для новых композиций pitch всегда 1.0. `finished` не используется.

## Архитектура после изменений

Минимальный постоянный autoload `/root/Music` (`scripts/music_service.gd`) отвечает за все основные композиции. Существующий сценовый AudioManager сохранён для эффектов, двигателя и передачи прежних параметров Race. Это не второй конкурирующий музыкальный контроллер: старое воспроизведение композиций и stems из AudioManager удалено, неиспользуемые Music-ноды удалены из обеих боевых сцен. Сервис нужен, поскольку прежний менеджер имел срок жизни боевой сцены и не мог обеспечить непрерывность между сценами.

У сервиса ровно два постоянных AudioStreamPlayer на шине Music. Повторный запрос той же композиции не вызывает `play` и не изменяет позицию. Fade интерполирует квадрат амплитуды с последующим квадратным корнем (equal-power). Переходы: Menu→Survival 1.2 с; Survival→Arbiter 1.0 с; Arbiter→Survival и бой→Menu 1.5 с. В конце неактивный проигрыватель останавливается. При обратном переходе ещё играющая уходящая композиция используется с текущей позицией и громкостью; при третьем отличном запросе заменяется более тихий из двух слотов. Пулы/третий проигрыватель/накапливающиеся Tween не создаются. Мгновенный переход также останавливает неактивный слот.

Новые треки имеют консервативные отдельные уровни с запасом для наложения. Сервис не меняет уровни игровых эффектов. Master/Music из сохранённых settings применяются до первого звука; дальнейшие пользовательские настройки продолжают работать через существующие шины.

## Игровые события и жизненный цикл

- Запуск autoload начинает MENU. MainMenu, Garage, PreRace, Career, CareerDialogue и Controls явно запрашивают ту же тему; загрузочные переходы не уничтожают её.
- Survival начинает обычную тему при `start_round(1)`. Обычные последующие волны музыку не трогают.
- Только `_spawn_referee()` после фактического `_spawn_bot(..., true)` запрашивает ARBITER. Номер волны и ожидание отложенного появления ничего не переключают.
- Удалён покадровый запрос по `boss.alive`. Поэтому после гибели босса оставшиеся байкеры сохраняют тему. Используется существующая цепочка `_complete_combat_phase()` → `_end_round(true)`; именно успешное завершение всей фазы возвращает SURVIVAL. Новое определение победы не добавлялось.
- Поражение/результаты сохраняют текущую тему. Вход в экран меню/Garage включает MENU.
- Restart обновляет идентификатор музыкальной сессии и запрашивает SURVIVAL. Сервис принимает boss-запросы только от текущего token и живого владельца внутри SceneTree. Существующие generation-проверки отложенного появления босса сохранены. Старые token после Restart, перехода в меню и удаления сцены отклоняются.
- Музыка наследует прежнюю паузу SceneTree. PauseOverlay не запрашивает MENU; после Resume возобновляются трек и незавершённый fade.
- Race сохраняет `config.music`, прежние pitch/intensity/volume, Rust Frontier pulse и существующие эффекты. Career arena использует те же правила ArenaBattle, что и до изменения; Career race продолжает использовать Race. Основная музыка Race проходит через те же два слота, исключая конфликт с уходящей темой меню.

## Изменённые файлы музыкальной интеграции

- `project.godot`: autoload Music.
- `scripts/music_service.gd` и UID: постоянный сервис.
- `scripts/audio_manager.gd`: делегирование композиций; эффекты сохранены.
- `scenes/Main.tscn`, `scenes/ArenaBattle.tscn`: удалены неиспользуемые Music-ноды.
- `scripts/survival.gd`: только музыкальные вызовы в начале нового матча, фактическом spawn и завершении фазы; удалён прежний покадровый музыкальный запрос. Соседние tactical-изменения существовали до задачи.
- `scripts/main_menu.gd`, `garage.gd`, `pre_race.gd`, `career.gd`, `career_dialogue.gd`, `controls_screen.gd`: запрос общей темы меню.
- Три `assets/music/metal_road_*.ogg.import`: native loop.
- `tests/arena_music_smoke.gd`: regression трёх состояний вместо теста старых stems.
- `tests/music_states_visual.gd`: графические кадры и Music Bus capture.
- `tests/music_full_loop_capture.gd`: отдельная запись полного естественного цикла меню.
- `tests/analyze_music_boundaries.py`: анализ записанных PCM16 границ.
- Этот отчёт, `METAL_ROAD_QA_REPORT.md`, `music-states-evidence/`: результаты.

## Автоматические проверки

15/15 headless scripts PASS: `arena_music_smoke`, `survival_smoke`, `survival_boss_schedule_smoke`, `survival_restart_smoke`, `menu_smoke`, `garage_smoke`, `game_smoke`, `race_finish_smoke`, `career_smoke`, `career_gameplay_smoke`, `settings_persistence_smoke`, `audio_smoke`, `survival_session_end_smoke`, `survival_round_guard_smoke`, `release_candidate_smoke`.

Restart100: baseline 199 → final 197 узлов, orphan 0. Boss schedule проверяет волны 1–15, включая 5/10/15 и Career contracts. Музыкальный smoke проверяет startup, MainMenu→Garage→MainMenu→PreRace с сохранением позиции, волны 2/3/4/5 с сохранением позиции, отложенный spawn, настоящего босса, оставшихся байкеров, полный финал, boss Restart, устаревший token, Pause/Resume, поражение/результаты, выход в меню, уничтоженного владельца, 12 повторных входов/быстрых переходов, сохранение Music Bus volume, ровно два слота и один играющий после fade, прежнюю музыку Race и фактическое прохождение границы каждого OGG после seek к концу.

`git diff --check` проходит. Editor import после настройки loop завершён. В финальных тестах нет SCRIPT ERROR и тестовых FAIL. В отдельных логах есть shutdown ObjectDB/resources warnings; такие предупреждения присутствовали и в предыдущих QA этого проекта. Они сохраняются как ограничение и не объявляются исправленными музыкальной задачей.

## Графические и звуковые проверки

Полный музыкальный smoke дополнительно PASS с настоящими графическим и аудиодрайверами. `music_states_visual.gd` выполнен в графическом Godot; сохранены семь кадров: меню, Garage, Survival, пятая волна до босса, Арбитр, Pause, Restart. Просмотрены кадры меню, Garage, Арбитра и Pause. Это программно управляемый графический прогон, не ручное прохождение.

На шине Music через AudioEffectRecord записаны реальные PCM16 WAV по ~2.5 с, охватывающие конец и начало каждого трека. Нет перезапуска проигрывателя или fade на границе, после перехода позиция ~1.4–1.5 с и `playing=true`. Во внутренних 10-мс окнах записей нет цифровой тишины; clipped samples = 0. Пики: Menu −22.98 dBFS, Survival −18.76 dBFS, Arbiter −21.49 dBFS. Это измерения коротких записей с текущей шиной, не интегральная громкость полных композиций. Точные значения сохранены в `boundary-analysis.json`.

Дополнительно записан **полный естественный цикл Menu**, без перемотки к концу: длина OGG 149.71 с, запись 151.16 с, после повторения `playing=true`, позиция 1.95 с. Peak −19.74 dBFS, нулевых внутренних 10-мс окон и clipped samples нет. Большая запись (26 МиБ) сохранена в `/tmp/metal-road-music-full-loop.wav`; численные результаты и `full-loop.log` находятся в evidence. Временный WAV не добавляется в репозиторий.

## Ограничения

Записи получены внутри аудиографа Godot на Music Bus, а не внешним захватом физического выхода устройства. Короткие записи границ подтверждают фактический loop сверх проверки флага, но не заменяют субъективное прослушивание и LUFS-оценку баланса во всём бою. Субъективное отсутствие слышимого щелчка и окончательный комфорт баланса не объявляются подтверждёнными. Для проверки доступны сами WAV. При очень быстром запросе третьей отличной композиции более тихий слот заменяется немедленно; число голосов ограничено двумя, но субъективная гладкость такого редкого прерывания не измерялась отдельно. Полная финальная приёмка звука остаётся слуховой проверкой пользователя.

## Воспроизведение

Из каталога проекта:

```sh
flatpak run org.godotengine.Godot --headless --max-fps 60 --path "$PWD" --script res://tests/arena_music_smoke.gd
flatpak run org.godotengine.Godot --max-fps 60 --path "$PWD" --script res://tests/arena_music_smoke.gd
flatpak run org.godotengine.Godot --max-fps 60 --path "$PWD" --script res://tests/music_states_visual.gd
flatpak run --filesystem=/tmp org.godotengine.Godot --max-fps 60 --path "$PWD" --script res://tests/music_full_loop_capture.gd
python3 tests/analyze_music_boundaries.py
```

Логи, кадры, короткие записи и численный анализ: [music-states-evidence](music-states-evidence/).
