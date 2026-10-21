# Phase E — Settings Persistence + Widescreen

## Что изменено

Меню настроек теперь имеет отдельные Master, Music, SFX и Engine sliders.
Настройки сохраняются в `user://settings.cfg` через `ConfigFile` с полем
`settings_version = 1`. Значения применяются сразу и восстанавливаются при
повторном создании меню/перезапуске процесса.

При старте меню гарантируются аудиошины Master, Music, SFX, Engine, UI,
Weapons и Impacts. UI/Weapons/Impacts направлены в SFX; существующие
AudioManager bus bindings продолжают работать.

Базовый viewport проекта переведён с 800×600 на 1280×720, добавлены window
overrides 1280×720. Canvas-items layout сохраняется; компактные HUD-якоря
используют дополнительную ширину.

## Файлы

Изменены:

- `scripts/main_menu.gd`
- `scenes/MainMenu.tscn`
- `project.godot`

Добавлены:

- `tests/settings_persistence_smoke.gd`
- `docs/phases/phase-e/report.md`
- `docs/phases/phase-e/test-logs/`

## Проверка

`settings_persistence_smoke.gd` проверяет наличие bus-каналов, запись файла,
версию, все четыре значения, fullscreen и восстановление во втором MainMenu.

Полный набор: **23/23 PASS** — прежние 22 smoke-теста плюс новый тест Phase E.
GDScript errors не обнаружены. В отдельных headless-процессах сохраняются
известные предупреждения Godot об ObjectDB/resources при завершении.

Оконная визуальная проверка 1280×720 сохранена в
`docs/sprints/bcd/manual/phase-e-1280.png`: меню занимает широкую область,
арт не обрезан, кнопки и логотип читаемы.

## Ограничения

Fullscreen и дополнительные разрешения требуют проверки на целевом desktop,
так как window manager может добавлять рамки. Настройка сохраняет факт
fullscreen, но не вводит отдельный выбор разрешения.

Экономика, Garage expansion, окружение и полный audio/VFX overhaul относятся
к следующим фазам и не изменялись.

## Следующий этап

После пользовательской проверки Phase E — Phase F: расширение Garage до четырёх
машин и трёх видов оружия, выбор loadout и resource-based характеристики.
