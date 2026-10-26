# Scrapyard expansion evidence — 2026-10-26

Godot4.7.2, изолированная копия проекта `/tmp/metal-road-arena-LPmVHS`, отдельный user-data profile. Основные сохранения не использовались. Полный анализ: [отчёт](../METAL_ROAD_SCRAPYARD_EXPANSION.md).

## Содержимое

- `before/`: точное состояние перед этим заданием, включая прежние незакоммиченные исправления. Расширение `.gd.before` намеренно исключает повторную регистрацию global classes.
- `geometry-change.patch`: изменения только6 production files этого эксперимента; обратное применение проверено, но не выполнено. Инструкции отката в отчёте.
- `routes-old-1..20.log`, `routes-new-1..20.log`: полные native route suites. Старые17/20 PASS, новые19/20 PASS; FAIL сохранены, не отфильтрованы. Одиночные16 маршрутов, heavy head-on и critical-wheels проходят во всех40; group8 всё ещё нестабилен. Таймаут90s и парковка доехавших не изменены.
- `controlled-*.log`, `ai-diagnostic-arena-*.json`: дополнительные group-only seeds4217/104729/8675309 со stable side в тестовом fixture, не изменение production AI. Старые FAIL/PASS/FAIL, новые PASS/PASS/PASS.
- `reg-*.log`:25 функциональных regression scripts, все PASS. После HUD-адаптации повторены playability/restart/roguelite/release candidate. Это не делает весь navigation stress suite успешным.
- `expansion-geometry.log/json`: размеры и физические AABB,192 spawn queries, поставки,2+1/Арбитр/байкеры, hazards/Restart и tutorial overlap smoke.
- `import-final.log`: финальный editor import. `visual.log`, `camera-checks.json`: реальный GUI,12 camera bounds/tutorial-clear checks и реальное физическое движение с программно удержанным газом.
-15PNG: старый/новый общий план, прежний центр1280, новые виды центра/нижнего проезда/стартов/поставок/движения1280×720 и800×600. Статические overview используют одинаковый диагностический zoom0.65 без машин; игровой zoom не менялся. AI и supplies в постановочных кадрах заморожены ради сравнения. Это не ручное прохождение.

## Воспроизведение

Работать в отдельной копии проекта с отдельным user-data profile: тесты могут писать profiles/diagnostic JSON. В командах заменить `/tmp/metal-road-arena-LPmVHS` путём такой копии. Не копировать поверх неё исходный project.godot после настройки отдельного профиля.

```sh
flatpak run --filesystem=/tmp/metal-road-arena-LPmVHS org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-arena-LPmVHS --script res://tests/arena_expansion_smoke.gd
flatpak run --filesystem=/tmp/metal-road-arena-LPmVHS org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-arena-LPmVHS --script res://tests/arena_navigation_routes_smoke.gd
flatpak run --filesystem=/tmp/metal-road-arena-LPmVHS org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-arena-LPmVHS --script res://tests/arena_navigation_routes_smoke.gd -- --old
flatpak run --filesystem=/tmp/metal-road-arena-LPmVHS org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-arena-LPmVHS --script res://tests/ai_navigation_diagnostic.gd -- mode=group seed=4217 policy=stable id=arena-new-4217
flatpak run --filesystem=/tmp/metal-road-arena-LPmVHS org.godotengine.Godot --path /tmp/metal-road-arena-LPmVHS --script res://tests/arena_expansion_visual.gd
```

Для старой контрольной группы добавить `--old`, использовать другой `id`. Seed фиксирует RNG геометрии; native passing-side по instance_id этим не стабилизируется. Поэтому20 native повторов отдельно от controlled fixture. `results_navigation_smoke` запускается без `--fixed-fps` из-за threaded scene loading.

Известные shutdown ObjectDB/resources предупреждения сохранены в логах; они не доказывают runtime утечку. Ни GPU-производительность, ни FPS, ни субъективный комфорт по этим данным не измерялись. Частота заторов3/20→1/20 описывает только эти прогоны, не статистическую гарантию исправления.
