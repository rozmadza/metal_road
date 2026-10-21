# Phase B report
Общий Vehicle.get_hud_state + VehicleReadout, нижние компактные speed/weapon/modules,
верхний status и отдельный F1. Прежние update_info/update_status сохранены.
18/18 smoke PASS (phase-b-logs/). hud_race_smoke проверяет live binding, speed,
Body/Engine/Wheels, bounds и отсутствие пересечений spawn/debug на 800×600,
1024×768 и 1366×768. Оконные кадры Main-*/ArenaBattle-*; реальные клавиши/мышь:
manual/B-race.png, B-debug.png, B-survival.png. Spawn игрока открыт.
Race position/lap/time появятся с реальным lifecycle в D, не фиктивные значения.
Следующий этап C: общий combat + DNF.
