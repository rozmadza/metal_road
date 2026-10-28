# Evidence: VehicleCatalog final regression + BonusPickup profile

Дата 2026-10-28. Основной [отчёт](../METAL_ROAD_BONUS_PICKUP_PROFILE.md). Все JSON в [raw/](raw/) получены в графическом Godot 4.7.2, OpenGL Compatibility, RX580/radeonsi, 1280×720, VSync около 60. Headless использовался **только** для регрессии.

## Регрессия

- [Общий результат](regression-summary.log): 19/19 PASS.
- [Общая длительность](regression-timing.txt): 212 с, exit 0.
- [Отдельные логи](regressions/): 19 файлов, включая 11 с shutdown ObjectDB/resources warnings.
- [Git diff исходных файлов на момент запуска](git-diff-before.patch), [статус](git-status-before.txt), [статистика](git-diff-stat-before.txt). Это снимок **до** добавления диагностических скриптов/отчётов; итоговый diff фиксируется отдельно.
- [Итоговый tracked diff](git-diff-final.patch), [итоговый статус](git-status-final.txt), [перечень всех untracked файлов](git-untracked-files-final.txt), [HEAD](git-head.txt). Новые диагностические скрипты/JSON остаются untracked, поэтому в tracked patch их содержания нет; они доступны непосредственно в рабочем дереве.

Набор запускался командой:

    bash tests/run_vehicle_catalog_regressions.sh /tmp/metal-road-final-regression ABSOLUTE_EVIDENCE_DIR/regressions

Временный проект был точной копией рабочего дерева перед вызовом. Runner затем не правился.

## Графические процессы

Каждый ID — отдельный процесс Godot. Первые окна длятся 13 с, окно повторного входа/Restart — ещё 13 с. Все включают две штатные партии, а после окна при forced=1 — отдельную fixture из пяти принудительных типов. Скриптовый ремонт игрока каждые 0.25 с удерживал матч, AI перемещались.

| ID | Код | Режим | seed | pilot | Окна |
|---|---|---|---:|---:|---|
| bonus-i4217-a | instrumented | direct | 4217 | 0 | 13 с |
| bonus-b4217-a | baseline | direct | 4217 | 0 | 13 с |
| bonus-i4217-b | instrumented | direct | 4217 | 0 | 13 с |
| bonus-i104729-a | instrumented | direct | 104729 | 0 | 13 с |
| bonus-i4217-menu | instrumented | menu + reentry | 4217 | 0 | 13+13 с |
| bonus-i4217-restart | instrumented | direct + Restart | 4217 | 0 | 13+13 с |
| bonus-b4217-b | baseline | direct | 4217 | 0 | 13 с |
| bonus-i4217-combat | instrumented | direct | 4217 | 1 | 13 с |
| bonus-i4217-post | instrumented, доп. сигналы | direct | 4217 | 0 | 13 с |
| bonus-i4217-memory | instrumented, диагностический | direct + 10 Restart + 5 menu | 4217 | 0 | 13 с + 15×2.4 с |

Логи ID находятся рядом с этим README; JSON с кадрами, stage events и memory marks — в raw. [Статус шести последовательных batch runs](profile-run-status.txt), [агрегат](profile-summary.txt), [машинная сводка](raw/summary.json). Два первоначальных прогона и отдельные post/memory прогоны запущены отдельно и имеют собственные логи/JSON. Все завершились exit 0. В menu/memory графических логах возможны shutdown ObjectDB warnings.

Три независимых графических resource-only процесса: [cold](raw/bonus-resource-cold.json), [image_first](raw/bonus-resource-image_first.json), [all_weapons](raw/bonus-resource-all_weapons.json), [статус](resource-run-status.txt). Контрольный графический [memory soak](raw/bonus-memory-soak.json) без покадровых массивов: 10 Restart и 5 входов из меню. Его лог содержит shutdown ObjectDB/resources warnings.

## Воспроизведение

В рабочем проекте production-код не инструментирован. Создайте две отдельные временные копии проекта; в instrumented копии выполните:

    python3 tests/instrument_bonus_pickup_profile.py /tmp/metal-road-bonus-instrumented

Сохранённые [diff spawner](spawner-instrumentation.diff) и [diff pickup](pickup-instrumentation.diff) показывают внесённые только во временную копию таймеры. Пример команды графического прогона:

    flatpak run --filesystem=/tmp/metal-road-bonus-instrumented org.godotengine.Godot --path /tmp/metal-road-bonus-instrumented --script res://tests/bonus_pickup_profile.gd -- id=bonus-i4217-a mode=direct instrumented=1 pilot=0 forced=1 seed=4217

Для baseline используйте копию без инструментирования и instrumented=0. Имя ID должно быть уникальным: сценарий пишет res://perf-output/ID-manifest.json, ID-stages.json и ID-ИМЯ_ОКНА.json. Сводка:

    python3 tests/analyze_bonus_pickup_profile.py ABSOLUTE_EVIDENCE_DIR/raw

Сценарии resource probe и memory soak находятся в tests/bonus_resource_probe.gd и tests/bonus_memory_soak.gd. RSS читается из /proc/PID/status процесса Godot; MEMORY_STATIC и RENDER_VIDEO_MEM_USED — штатные Performance monitors. Сырые данные сохранены; COW-копии в /tmp не являются единственным хранилищем доказательств.
