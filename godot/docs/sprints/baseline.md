# Sprint 1 baseline — 2026-09-21

Изучены pasport.md, все 9 сцен, 5 Config-классов и соответствующие .tres.
Godot 4.7.2 stable ed1daf0bf, GL Compatibility, Intel HD Graphics 4000.
До изменений: все 11 *_smoke.gd PASS (exit 0). Полные логи: baseline-logs/.
Main и ArenaBattle запущены headless и оконно на 180 кадров, exit 0.
В ряде тестов и при закрытии Race: 4 ObjectDB instances / 2 resources leaked.
Sandbox блокирует запись стандартного user://logs; далее --log-file /tmp/...
Git: весь godot/ уже untracked; исходные файлы не принадлежат отдельному коммиту.

Архитектура: Vehicle — физика, apply_control и боевой контракт; Resource — баланс;
координаторы Game/Survival — правила; combatants — только Survival.
Перед выделением состояния повреждений добавляется regression smoke для health,
смерти, сигнала и reset. Body сохраняет прежнюю семантику health/take_damage.
Engine/Wheels — runtime состояние экземпляра, без изменения общего Resource.

Art direction: graphite / pale steel / rust, yellow hazard marks, cyan lights/UI,
orange fire, green healthy modules. Sport raster направлен вправо. Три стадии
повреждений поверх базового арта + непрозрачный wreck. Геометрия машины прежняя.
Scope: Sprint 1. Гонки с кругами, оружие, гараж и новые карты — следующие спринты.
