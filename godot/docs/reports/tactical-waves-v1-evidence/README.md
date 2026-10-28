# Tactical Wave Identity v1 — данные и воспроизведение

База: origin/main/1f04e96, ветка codex/tactical-wave-identity-v1. Окружение: Godot4.7.2 stable Flathub, Linux6.8.0-138, X11, RX580/radeonsi/OpenGL Compatibility,1280×720. Измерительные обёртки добавлялись только в копии /tmp/metal-road-tactics-before и /tmp/metal-road-tactics-after-profile. Немодифицированная по профилировщику копия /tmp/metal-road-tactics-after использовалась для регрессий.

## Окончательные источники таблиц

- behavior-final/before-final-{4217,104729,8675309}.json — исходное поведение native waves2/3/4 и контролируемой supply. Для старого flank_open в этих файлах сторона была выбрана к краю: использовать для истории, не как доказательство свободного бокового проезда.
- acceptance-behavior/after-accepted-SEED.json — окончательные параметры180/160, все физические случаи и native waves2/3/4.
- acceptance-behavior/before-flank-accepted-SEED.json — исправленный исходный controlled flank_open с тем же положением/стороной и anchor, что в окончательном кандидате.
- graphics-valid-loadout/*.json — окончательное графическое сравнение5 и8 AI на двух seed обеих версий. Файлы loadout/profile создаются до измерений. Это основной источник кадровых таблиц и AI timings.
- release-regressions/ — итоговый полный последовательный runner19/19,215 с; отдельный tactical_wave_identity_smoke PASS.
- release-navigation/ — окончательная seeded group8 acceptance на трёх seed с JSON и traces, полный arena_navigation_routes_smoke, traffic_yield_policy_smoke и traffic_recovery_smoke.
- scope-proof.json —82 исходника/Resource-файла физики, навигации, оружия, геометрии, wave data и кэшей совпадают с main.
- *-summary.json — автоматически вычисленные сводки. behavior-summary.json — baseline/промежуточный after; acceptance-behavior-summary.json — окончательный after и корректный before-flank. Не смешивать версии.

## Предварительные данные и неудачи

baseline/, candidate/, behavior-final/after-final-*, behavior-v2/, flank-final/, flank-v2/, regressions/, regressions-final/, navigation/, navigation-final/ — промежуточные этапы. Сохранены для истории. Параметры начального нового Flanker135/0→210/0 не давали выраженного подхода на краю;210/220 делал слишком длинный проезд. flank-parameter-probe/ фиксирует тестовые варианты offsets80/120/160, widths180/210 и контроль offset0; это не разные production версии всех игровых параметров.

Первый pilot-typed-source-error имел ошибку стенда: попытку искать StaticBody2D в TypedArray[Vehicle]. Исправлена проверкой source is Vehicle. Первый tactical-wave-smoke-initial-setup-fail не дождался физического reset, получил nil lock и остановился; после ожидания трёх physics frames и корректной исходной intent проверка прошла. Граничная unit-цель и сторона flank-стенда также исправлялись; не каждый промежуточный stdout сохранён отдельным файлом, сведения о них приведены в отчёте и логах candidate/.

Промежуточный after-final-4217/native_wave4 дал stop9.83 с у Crusher возле неподвижного high-HP тестового игрока: этот случай сохранён и отдельно обсуждён, не скрыт общим PASS. Никакой правки recovery/physics по нему не делалось.

graphics/ и graphics-accepted/ — графические прогоны до исправления подготовки loadout; слово accepted в историческом имени папки не означает окончательную приёмку. Измерялся пик~611 мс внутри TutorialCoach._complete (~602 мс). spike-triage/ с дополнительными таймерами подтвердил read/save профиля примерно по300 мс; отсутствующий тестовый loadout вызывал четыре штатных retry OS.delay_msec(75) внутри LoadoutProfile.read_ids. Probe создавал path_override, но не файл. Он исправлен созданием валидных loadout/profile до измерений. Это не основание обвинять новую тактику или менять HUD/профиль. Все ранние пики и исходные raw сохранены; окончательные графические запуски проведены заново для обеих версий.

## Команды

В test copy:

    python3 tests/instrument_tactical_probe.py "$project"
    flatpak run --filesystem="$project" org.godotengine.Godot --headless --fixed-fps 60 --path "$project" --script res://tests/tactical_wave_probe.gd -- id=after-accepted-4217 seed=4217
    flatpak run --filesystem="$project" org.godotengine.Godot --disable-vsync --delta-smoothing disable --max-fps 0 --path "$project" --script res://tests/tactical_wave_probe.gd -- id=after-valid-gui-4217 seed=4217 mode=performance
    bash tests/run_vehicle_catalog_regressions.sh "$project" "$logs"
    flatpak run --filesystem="$project" org.godotengine.Godot --headless --fixed-fps 60 --path "$project" --script res://tests/ai_navigation_recovery_probe.gd -- mode=group seed=4217 id=group8-4217

Анализ:

    python3 tests/analyze_tactical_waves.py docs/reports/tactical-waves-v1-evidence/graphics-valid-loadout --output docs/reports/tactical-waves-v1-evidence/graphics-valid-summary.json
    python3 tests/analyze_tactical_waves.py docs/reports/tactical-waves-v1-evidence/acceptance-behavior --output docs/reports/tactical-waves-v1-evidence/acceptance-behavior-summary.json

Behavior sim использует fixed-fps60 только для физических секунд, его frame wall time не публикуется как FPS/GPU. Native cases по30 с, controlled20/25 с, graphical5/8 cases по20 физических секунд. Все машины probe получают приватные HP/engine/wheels50000, чтобы не прерывать нагрузку; это исключает выводы о TTK/честной сложности. Игрок программно водит и не стреляет; физические бонусы собираются обычным контактом. В controlled flank всем AI выданы штатные пулемёты999 с исключительно в стенде. Seed не фиксирует частную случайность Arena/все столкновения: точного A/B replay нет.

Кадры: process timestamps, mean/nearest-rank p95/p99/max, пороги16.67/33.33/100 мс. Пропущен только первый неполный process interval каждого окна; остальные пики сохраняются. CPU AI — main-thread elapsed time вокруг get_commands, включая вложенные navigation queries, но без внешней физики/рендера. Detour timing вложен в AI timing, их нельзя складывать. Счётчики successful detour и количество попыток различаются. В последней версии timing enabled только внутри окна; край последнего physics tick даёт5995/9592 команд вместо6000/9600. Частота AI не снижалась.

Новые тесты/скрипты профиля являются инструментами разработки. Ни ручного игрового прохождения, ни физического геймпада эти прогоны не заменяют.

## Совместный рабочий каталог

Во время задания появились независимые изменения музыкальной системы в том же дереве. Они не включены в A/B и не отменялись. integration-current-tree/ — импорт и9 smoke снимка совместного дерева, все exit0 без GDScript/parse/тестовых FAIL. integration-snapshot.json фиксирует SHA256 ключевых project/scenes/Survival/AI/music файлов; на момент завершения они совпадают с рабочей папкой.

tactical-only.diff содержит только три production файла этой задачи, извлечённые из проверенной немодифицированной по таймерам копии относительно main/1f04e96. git-status-final.txt и git-diff-stat-final.txt отражают весь общий каталог, включая независимую музыку; их нельзя считать списком только Tactical Wave Identity. Новые сценарии/отчёты указаны в основном документе. Push, merge и общий commit не выполнялись.
