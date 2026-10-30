# Safe AI Integration into Main — проверка фактического состояния

Дата: 2026-10-30.

## Результат Git-аудита

После успешного `git fetch origin --prune`:

| Ссылка | SHA |
|---|---|
| main | 95914638b21f87b44503066d271268216ff45572 |
| origin/main | 95914638b21f87b44503066d271268216ff45572 |
| codex/tactical-wave-identity-v1 (текущая) | 95914638b21f87b44503066d271268216ff45572 |

`git ls-remote origin refs/heads/main` независимо подтвердил тот же SHA на GitHub (`git@github.com:rozmadza/metal_road.git`). Обе проверки `git rev-list --left-right --count` дают 0/0: уникальных коммитов main или AI-ветки нет. Diff между ветками пуст. Локальных неопубликованных коммитов main нет.

Tactical Wave Identity уже опубликован: файл `scripts/survival_wave_tactics.gd` добавлен в общем предке `3b8a9bc747539470326e907b15b4ceb5d674018e`. В main присутствуют профиль, его UID, изменения ArenaBot, применение `WAVE_TACTICS.apply_to` в Survival, tactical_wave_identity_smoke, tactical_wave_probe, аналитические скрипты и отчёт METAL_ROAD_TACTICAL_WAVES_V1.md.

## Состав AI и зависимости

Профили supply_rush, elite_team, onslaught задают стратегии SCAVENGER/HUNTER/BRAWLER, радиусы интереса к поставкам, эксклюзивность целей и параметры бокового подхода. Остальные профили возвращают пустой словарь. В ArenaBot присутствуют соответствующие параметры и логика выбора поставок/Flanker. Survival применяет профиль обычным противникам с исключением Career. Всё это уже находится в одном дереве main и AI-ветки; переносимых отсутствующих файлов нет.

В общем main одновременно присутствуют вызовы boss-музыки, session generation guards и отложенное создание crew. Никаких версий survival.gd или других файлов не заменяли. Музыка, оружие, UI, физика, бонусы, Race и Career в рамках этой проверки не изменены. Конфликтов объединения нет, поскольку объединять разные коммиты не требуется.

## Незакоммиченный функционал

До начала проверки рабочее дерево содержало существенные независимые изменения:

- Rocket Launcher v3: scripts/bullet.gd, scripts/weapon_config.gd, scripts/weapon_visual_profile.gd, resources/weapons/rocket_launcher.tres, resources/weapon_visuals/rocket_launcher.tres.
- Изменённые QA и Survival improvement plan.
- Новые explosion_polished_sheet.png и .import, rocket_homing_v3_smoke.gd и .uid, отчёт v3 и каталог доказательств rocket-launcher-v3-evidence.
- Untracked assets/vfx/weapons: muzzle_sheet/projectile_core для machine_gun и heavy_machine_gun; shared tracer_strip, impact_metal_light_sheet и impact_metal_heavy_sheet.

Они не входят в опубликованный SHA. Эти изменения относятся к отдельным задачам оружия/графики, а не к необходимым зависимостям Tactical Wave Identity. Их включение в AI-интеграцию нарушило бы требование переносить только AI и зависимости. Все сохранены без изменений. Единственный созданный этой проверкой файл — настоящий отчёт.

## Проверки и ограничения

Выполнены status, branch -avv, remote -v, log --graph --all, fetch, сравнения SHA/диапазонов/деревьев, проверка содержимого main и ls-remote. `git diff --check` для исходного рабочего diff прошёл.

Новый regression runner, графический запуск и ручная приёмка волн 3–5 не выполнялись. Ранее записанные PASS в Tactical Waves и Rocket v3 относятся к своим проверенным состояниям и не выдаются за новые результаты этой задачи. Новый интеграционный код отсутствует. Поэтому этот отчёт подтверждает наличие AI в GitHub, но не повторную полную техническую приёмку опубликованного main.

## Решение и публикация

Интеграционная ветка/worktree не создавались: база и источник уже идентичны. Cherry-pick/merge породили бы ненужное повторение существующих изменений. Новый коммит, fast-forward и push не выполнялись. Исходная AI-ветка сохранена. Опубликованный итоговый SHA остаётся 95914638b21f87b44503066d271268216ff45572.

Требование наличия Tactical Wave Identity в GitHub main уже выполнено до этой задачи. Публикация оставшегося рабочего дерева остановлена согласно условию задания о существенном независимом незакоммиченном функционале: Rocket v3 и параллельные PNG нельзя автоматически включать в AI-перенос. Безопасное продолжение — отдельная приёмка и адресная публикация этих изменений с установлением состава параллельных assets/vfx. Для самостоятельной повторной приёмки main нужен чистый снимок опубликованного SHA; запуск текущего грязного дерева проверял бы другую версию.
