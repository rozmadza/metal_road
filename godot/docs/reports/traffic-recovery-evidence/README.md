# Traffic / recovery evidence — 2026-10-26

Изолированная копия проекта: `/tmp/metal-road-traffic-hZypN1`, отдельный user-data profile. Старый AI запускался в сохранённой QA-копии `/tmp/metal-road-arena-LPmVHS`; её arena_bot/arena_navigation совпадали с `before/`. Сохранения пользователя не использовались.

## Как читать данные

- `before/`: прежние production scripts и recovery probe. Это рабочее состояние перед задачей, включая ранее незакоммиченные исправления.
- `baseline-replay.log`, `ai-diagnostic-baseline-replay.json`: прежний AI, четыре физических replay. Старые сценарии stationary/oblique медленно проходят, inactive_priority/rear_blocked_yield не проходят за90s.
- `baseline-policy.log`: прежний yield выбирает занятую машиной площадку, FAIL. `final-policy.log`: исправленный контракт; дополнительно проверены исключение боевой цели из traffic braking, память одинакового отказа, освобождение бокового пространства и память просроченной yield-цели. Последние проверки — отдельные unit checks с подменённым результатом проверки дуги, не физическая симуляция.
- `ai-diagnostic-traffic-baseline-{seed}.json`, `baseline-old-{seed}.log`: прежний AI, group-only stable side на старой карте. Seed4217/8675309 воспроизводит60 запросов/57 мгновенных отмен.
- `final-replay.log`, `ai-diagnostic-final-replay.json`: те же физические сцены после исправления.
- `acceptance-1..20.log` и одноимённые `ai-diagnostic-*.json`: приёмочные полные прогоны;16 одиночных маршрутов, повреждённые колёса, EXACT/NEAREST/NONE, две встречные пары и завершающая группа8 с припаркованными машинами.
- `parked-1..20`, `transit-1..20`: отдельные20 group-only parked и20 transit с seed4217/104729/8675309 по кругу. У transit прибывшие машины удаляются **только стендом**. Это дополнительное сравнение, не замена parked-теста и не игровое поведение.
- `parked-pad1`: дополнительная ObjectDB allocation перед машинами, seed4217; сравнивается с parked-1.
- `old-{seed}`, `old-full`, `destroy-{new,old}-{seed}`: старая карта, полный набор старых маршрутов и разрушение ящика на обеих картах. Проверяется реальное движение после обновления навигации.
- `reg-*`: регрессии. Первый uncapped results_navigation не дождался Garage за600 process frames. `reg-results_navigation-paced.log` использует `--max-fps 60`, прежние600 кадров, без изменения теста/сцены. Оба результата сохранены.
- `visual-final.log`, `traffic-visual.json`, `traffic-*.png`: реальный GUI,8 движущихся AI и15s боя со штатной физикой/AI. В маршрутах — обычный диагностический увеличенный запас HP; в бою — штатный Survival, программные Input actions и выданные стендом пулемёты для наблюдения стрельбы. Это не ручное прохождение.
- `exploratory/`: все промежуточные прогоны, включая FAIL и ошибку типизации раннего прототипа. Они не входят в приёмочную частоту. В первых5 full-прогонах поле immediate_cancellations ещё содержало все safety cancellations; не сравнивать его с исправленной схемой acceptance.

## Единицы и счётчики

`frames/60` — моделируемые секунды. `wall_seconds` — время процесса, не производительность игры/GPU. Reached — первое попадание в радиус55; после этого в parked машина остаётся живым физическим препятствием с отключённым AI и тормозом. Никаких изменений5400-кадрового/90s лимита нет.

В acceptance: `reverse_requests` — решения о запуске после cooldown/проверки неизменных условий; `recovery_rejected` — отказ до включения reverse; `recovery_started` — реально наблюдавшаяся продольная скорость<−3; `recovery_completed` — истёк срок манёвра; `recovery_cancelled` — сработала прежняя safety rear_room<16; `immediate_cancellations` — отмена в кадре нового запуска. Эти счётчики описывают разные события и не обязаны складываться в requested: начавшийся манёвр может позже отмениться. Прежний probe считал запросы при первом вызове rear-room safety, поскольку production counters тогда отсутствовали.

JSON содержит arrival_frame, max_stop_frames, состояние recovery/yield, цели, путь, координаты, фактические контакты, соседние машины/их скорость/активность, traffic_reason. Stop — непрерывное speed<12 до прибытия. NEAREST-ожидание, физический контакт и yield выделяются отдельными счётчиками; признаки могут пересекаться.

## Воспроизведение

Использовать отдельную QA-копию проекта и отдельный user-data profile. Команды для этой сессии:

```sh
flatpak run --filesystem=/tmp/metal-road-traffic-hZypN1 org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-traffic-hZypN1 --script res://tests/traffic_recovery_smoke.gd -- id=replay
flatpak run --filesystem=/tmp/metal-road-traffic-hZypN1 org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-traffic-hZypN1 --script res://tests/traffic_yield_policy_smoke.gd
flatpak run --filesystem=/tmp/metal-road-traffic-hZypN1 org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-traffic-hZypN1 --script res://tests/ai_navigation_recovery_probe.gd -- mode=full id=acceptance
flatpak run --filesystem=/tmp/metal-road-traffic-hZypN1 org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-traffic-hZypN1 --script res://tests/ai_navigation_recovery_probe.gd -- mode=group seed=4217 id=parked
flatpak run --filesystem=/tmp/metal-road-traffic-hZypN1 org.godotengine.Godot --headless --fixed-fps 60 --path /tmp/metal-road-traffic-hZypN1 --script res://tests/ai_navigation_recovery_probe.gd -- mode=group seed=4217 arrival=remove id=transit
flatpak run --filesystem=/tmp/metal-road-traffic-hZypN1 org.godotengine.Godot --path /tmp/metal-road-traffic-hZypN1 --script res://tests/traffic_recovery_visual.gd
```

Для старой карты добавить `--old`; для повторения исторических fixed-side контрольных запусков — `policy=stable`. Обычные acceptance/parked/transit используют production side/priority. Для старой production версии нужен старый probe из before/, поскольку у неё ещё нет новых счётчиков.

Shutdown ObjectDB/resources предупреждения сохранены без объявления runtime-утечкой. FPS/GPU profiler/CPU p95 не измерялись. Даже20 успешных прогонов не доказывают отсутствие всех возможных заторов.
