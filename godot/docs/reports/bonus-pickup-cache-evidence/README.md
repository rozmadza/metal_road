# BonusPickup cache — исходные данные и воспроизведение

Дата 2026-10-28. Версии: Godot 4.7.2 Flathub, OpenGL Compatibility, RX580/radeonsi, 1280×720. Изолированные копии исходного состояния и исправленной версии находились в /tmp/metal-road-bonus-profile-old и /tmp/metal-road-bonus-profile-new. Все графические runs — отдельные процессы. Во всех штатных прогонах VSync отключён, max-fps=0, delta-smoothing отключён, кроме quick/preload. Профили не являются ручной игрой.

- preload/: восемь независимых A/B запусков no-prep/sync/threaded (два на режим, плюс два без subthreads); raw JSON и stdout. quick/raw/entry-new-*.json — встроенный переход с кэшем, тот же тестовый пробник.
- quick/: два исходных и два новых неинструментированных окна поставок с VSync, включая кадровые JSON, logs и status.
- race/: графический Race через меню, две партии, Restart. Race-new сначала завершился timeout exit124 из-за Parse Error: Identifier BonusWeaponCache not declared в SceneTransition._commit_scene в чистой копии без зарегистрированных class_name. Исправлено явным preload; второй запуск exit0. Исходный лог был перезаписан; точный результат первого вызова сохранён в status.txt, ошибка и путь приведены здесь. Не смешивать неудачный запуск с профилем.
- full/: один исходный и один исправленный полный инструментированный Survival: волны 1/2/5, 60 с волны 4, два Restart, повторный вход. Файлы *-manifest.json и файлы окон, анализ windows.csv/summary.json. В full-new окно wave5_bikers завершилось поражением через3.132 с; исходный полный 12-секундный профиль этого окна нельзя считать парой.
- endurance/: отдельный одинаковый активный 60-секундный бой волны 4, Restart и повторный вход. Игроку выдана приватная конфигурация высокого HP только в test process; это заменяет недействительную пару длинных окон из full/.
- wave5/: одинаковый синтетический fixture с приватным player max_health=10000 только в тестовом процессе, оба прогона 11+12 секунд wave5 с Арбитром и семью AI. Не является естественным прохождением.
- memory/: новый graphical lifecycle без накопления кадров, 10 Restart и5 menu reentry. Для исходной версии в отчёте использован уже опубликованный docs/reports/bonus-pickup-evidence/raw/bonus-memory-soak.json с таким же сценарием.
- regressions-final/: предварительный полный runner 19/19 PASS до последней правки явного preload. regressions-final-after-preload/: итоговый повтор на последнем production-коде. extra-tests/ и extra-tests-final/: отдельные smoke. candidate-instrumentation.diff: диагностические обёртки только в одноразовых копиях.

Основные команды (project — путь к копии, id — отдельный идентификатор):

    flatpak run --filesystem="$project" org.godotengine.Godot --disable-vsync --delta-smoothing disable --max-fps 0 --path "$project" --script res://tests/survival_catalog_comparison.gd -- "id=$id" seed=4217 instrumented=1
    flatpak run --filesystem="$project" org.godotengine.Godot --disable-vsync --delta-smoothing disable --max-fps 0 --path "$project" --script res://tests/bonus_wave5_cache_profile.gd -- "id=$id" seed=4217
    flatpak run --filesystem="$project" org.godotengine.Godot --disable-vsync --delta-smoothing disable --max-fps 0 --path "$project" --script res://tests/bonus_wave4_endurance_profile.gd -- "id=$id" seed=4217
    python3 tests/analyze_survival_performance.py docs/reports/bonus-pickup-cache-evidence/full --output docs/reports/bonus-pickup-cache-evidence/full/analysis
    bash tests/run_vehicle_catalog_regressions.sh "$project" "$log_dir"

Программа инструментирования tests/instrument_bonus_cache_comparison.py измеряет только стадии BonusSpawner/Cache в копиях; production код не содержит таймеров. Пробник синхронной и фоновой подготовки — tests/bonus_preload_comparison.gd. Для точного воспроизведения A/B нужно использовать два самостоятельных процесса с одинаковым размером окна, без иных одновременных GPU-прогонов. Seed не фиксирует повороты props, instance IDs и весь AI; цифры не следует трактовать как строгий детерминированный replay.

Метрики: frame wall time по SceneTree._process, ближайший ранг p95/p99, пороги 16.67/33.33/100 мс. RSS из /proc/PID/status, MEMORY_STATIC и RENDER_VIDEO_MEM_USED из Godot Performance. Они измеряют разные величины; суммы из разных процессов не имеют физического смысла. В полном профиле накопление кадров в памяти искажает рост MEMORY_STATIC, поэтому стабильность оценивается по отдельному memory probe. Shutdown ObjectDB/resources warnings не равны доказанной утечке во время матча.
