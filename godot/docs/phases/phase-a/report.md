# Report

Phase A — Main Menu Visual Rework, 2026-09-21.

## Что изменено

Пустое меню заменено industrial derby-композицией: крупная бронированная машина,
столкновение, взрыв и заводские прожекторы; отдельный металлический логотип.
Слева — пять читаемых кнопок. Gradient, dark overlay и vignette отделяют UI от арта.

Предварительный аудит: [audit.md](audit.md). Baseline 15/15 PASS.

## Какие файлы добавлены

- `scenes/MenuBackdrop.tscn`, `scenes/UISounds.tscn`, `scenes/Garage.tscn`.
- `scripts/ui_sounds.gd`, `scripts/garage.gd`.
- `resources/audio/menu_audio.tres`.
- `tools/generate_ui_audio.py` — воспроизводимый генератор оригинальных UI cues.
- Тесты и документация, перечисленные ниже.

## Какие файлы изменены

- `scenes/MainMenu.tscn`: artwork, logo, пять кнопок, modal settings overlay.
- `scripts/main_menu.gd`: Garage route, keyboard focus, Escape из настроек,
  короткая задержка закрытия для click sound.
- `resources/ui/main_theme.tres`: IndustrialButton variation с отдельными
  normal/hover/pressed/focus; прежние стили игрового HUD сохранены.
- `scripts/audio_config.gd`: опциональные menu_hover/menu_click/ui_volume_db.

## Что реализовано

- ГОНКА / ВЫЖИВАНИЕ / ГАРАЖ / НАСТРОЙКИ / ВЫХОД — все кнопки работают.
- Металлическая рамка, подсветка hover/focus, отдельный pressed.
- Hover и keyboard focus озвучены; click доигрывает при смене сцены и удаляется.
- UI bus и конфигурация звуков через существующий AudioConfig, без autoload manager.
- Настройки Master/fullscreen сохранены; фон модально затемняется; Escape/Назад
  восстанавливает фокус главного меню.
- Отдельный Garage показывает текущий Sport, Resource-based характеристики и
  пулемёт; можно вернуться или запустить любой из существующих режимов.
- Garage в Phase A — осмотр действующей комплектации. Выбор, покупки, Credits,
  уровни и сохранение не выдаются за реализованные функции; они относятся к F–H.

## Какие assets добавлены

- `assets/ui/menu/derby_background.png`.
- `assets/ui/menu/metal_road_logo.png` (alpha).
- `assets/ui/menu/menu_overlay.gdshader`.
- `assets/sounds/ui/menu_hover.wav`, `menu_click.wav`.
- README с происхождением и инструкциями замены ассетов в обоих каталогах.

Фон и логотип созданы через imagegen; WAV — оригинальный детерминированный
синтез stdlib Python, без внешних записей и новых зависимостей.

## Какие tests добавлены

- `menu_visual_smoke.gd`: artwork, shader, кнопки, style states, focus, modal,
  UI signal wiring, audio streams/UI bus, отключённый config, lifetime клика.
- `garage_smoke.gd`: переходы Menu → Garage → Menu и Garage → Survival,
  preview и характеристики из реальных ресурсов.
- `menu_phase_a_review.gd`: оконные review-кадры меню, настроек, гаража; отдельный
  viewport для точного 1280×720, независимо от ограничений desktop window manager.

## Результаты tests

**17/17 PASS**, exit 0. Старые тесты не изменялись.

| Smoke test | Результат |
|---|---|
| arena | PASS |
| assets | PASS |
| audio | PASS |
| bot | PASS |
| controls | PASS |
| damage_contract | PASS |
| damage_modules | PASS |
| derby | PASS |
| feedback | PASS |
| game | PASS |
| garage | PASS |
| menu | PASS |
| menu_visual | PASS |
| survival | PASS |
| track | PASS |
| vehicle | PASS |
| weapon | PASS |

Логи: [test-logs](test-logs/), исходные: [baseline-logs](baseline-logs/).
Оконная проверка на Godot 4.7.2 / GL Compatibility / Intel HD 4000.

Кадры: [меню 800×600](menu-800.png), [меню 1280×720](menu-1280.png),
[настройки](settings-800.png), [гараж](garage-800.png).

## Найденные проблемы

- Причина неизменных HP в Race — отсутствие combatants; текущий HUD уже читает
  runtime damage. Исправление боя и regression источника HUD — B/C.
- Существующие teardown-предупреждения WAV/PlaybackWAV в старом audio/game suite
  остаются baseline-проблемой. Новые menu_visual и garage smoke завершаются чисто.
- Настройки громкости/видео пока не сохраняются; save предусмотрен G/I.
- Текущий desktop ограничивает размер больших окон: wide layout проверен через
  точный viewport, а не по названию файла, созданного после resize окна.
- Субъективная громкость UI cues требует прослушивания пользователем; маршрутизация
  и воспроизведение проверены автоматически.

## Что осталось

HUD layout, combat race, четыре машины, дополнительные оружия, окружение,
интерактивные объекты, экономика, сохранение, апгрейды и soundtrack относятся
к последующим фазам. Phase A не меняет физику или игровые правила.

## Следующий этап

Проверка пользователем Phase A, затем Phase B: компактный HUD по краям экрана,
живые показатели Race/Survival и hud_race_smoke. После B — общий combat в C.
Автоматический переход к Phase B не выполнялся.
