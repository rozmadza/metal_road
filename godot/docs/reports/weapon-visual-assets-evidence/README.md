# Weapon Visual Assets Audit — воспроизведение и доказательства

Дата2026-10-28. Текущий исходный снимок указан в workspace-before.json. Игровое дерево не менялось; редактор/import и графический процесс запускались только в /tmp/metal-road-weapon-visual-audit, скопированном через rsync без docs/.git/perf-output.

Каталог evidence помечен .gdignore: PNG и служебные файлы аудита не должны импортироваться Godot как runtime-ресурсы.

## Содержимое

- manifest.json:7 загруженных WeaponConfig с фактическими defaults,22 capture states, позиции, ages, muzzle timer, HP/damage events, активные VFX и параметры camera/viewport.
- capture.log и import.log: реальный Godot4.7.2 Flathub, X11, OpenGL Compatibility, AMD RX580/radeonsi. Capture завершился exit0; GDScript/parse ошибок нет.
- weapon-fire/flight/impact.png:7×3 полных1280×720 PNG. У mine flight —взведённое состояние после0.65 с; цвет действительно остался серым. Дополнительный flamethrower-continuous.png показывает удержание огня0.4 с.
- comparison-native.png:3 колонки,480×240 crops вокруг реального FX без изменения масштаба,1 world unit=1px.
- comparison-detail-2x.png:240×200 crops тех же кадров, увеличенные2× nearest-neighbor. Это увеличение текущего renderer, не создание или улучшение арт-ассетов.
- existing-art-reference.png: монтаж существующих семи roof PNG, текущего Raider и mud_ground. Уменьшенные исходники/подписи; это не projectile pack.
- existing-weapon-images.json: размеры, реальные alpha bounds и file bytes семи roof.
- proposed-asset-spec.json: только предложение27 будущих файлов с frame/atlas/world/pivot/alpha/format/anchor/hit contract. Игровые .tres/.tscn и PNG по этим путям не создавались.
- capture-harness.gd.txt и compose-sheets.py.txt: скрипты исключительно аудита. Суффикс .txt не даёт Godot импортировать их как игровые сценарии.
- workspace-before.json и workspace-verification.json: проверка сохранности исходников, сцен, ресурсов, существующих assets и project.godot.

## Метод

Собраны неизменённые Arena.tscn/Vehicle.tscn/Bullet.tscn и CombatVFX z4. Стандартные Raider40×24,100 HP, camera(700,650)/zoom1,1280×720, без HUD и координатора Survival. Выстрел — вызов настоящего MachineGun._shoot для одного burst; попадание/снижение HP — реальные Bullet проверки, а не вызов spawn_impact/detonate для иллюстрации. У всех7 финальных fire есть Bullet и muzzle timer; flight имеет Bullet; impact содержит реальный damage и живой CombatVFX event. Это проверено в capture-checks.json.

Мина после установки скрыта под стрелком по штатному z−1/offset. Для кадра deployed/armed стрелок переставлен вперёд; затем цель поставлена непосредственно на мину после её настоящего arming time. При этом _mine_has_target сам запустил взрыв. Это постановочный контакт, не ручное прохождение или доказательство естественного проезда.

Два автомобиля заморожены для одинаковых поз. Ресурсы оружия/параметры урона/радиусы/TTL не подменяются. Смена оружия/reset присутствуют только в harness. Графический процесс реальный; headless использован только для предварительного editor import, не вместо картинок.

Первая серия сохраняла каждый PNG синхронно прямо между фазами. Задержка кодирования нарушала равномерное наблюдение: часть коротких impact уже истекала к кадру. Поэтому сохранены initial-manifest.json, initial-capture.log и initial-capture-harness.gd.txt, а итоговая серия заново снята с Images в памяти и записью PNG только в конце. Предварительные PNG оставлены в /tmp/metal-road-weapon-visual-initial, в отчёт они не включены. Монтажный скрипт также приведён в совместимость с установленным Pillow (Image.NEAREST/LANCZOS). Эти исправления относятся к инструментам аудита, production не затрагивают.

Команды для изолированной копии:

    flatpak run --filesystem="$project" org.godotengine.Godot --headless --editor --import --path "$project" --quit
    flatpak run --filesystem="$project" org.godotengine.Godot --disable-vsync --delta-smoothing disable --max-fps 60 --path "$project" --script res://tests/weapon_visual_audit_capture.gd

Перед запуском копировать capture-harness.gd.txt в tests/weapon_visual_audit_capture.gd внутри копии. Capture сохраняет результат в res://visual-audit-output/. Пользовательские profile/loadout использованы только внутри этого каталога, Master bus заглушён только в отдельном процессе; настройки рабочего проекта не менялись.

## Ограничения

Это визуальный технический стенд, без AI/естественного движения игрока, проверки баланса и ручного playtest. Снимки фиксируют конкретные возраста FX, не всю временную последовательность. Урон по crew/destructibles исследован по коду, а семь impact-кадров —по машинам. GPU throughput, RSS/VRAM будущих PNG и качество ещё не созданных изображений не измерялись. Сравнительные листы содержат существующую процедурную графику именно как baseline, не предложенные итоговые ассеты.
