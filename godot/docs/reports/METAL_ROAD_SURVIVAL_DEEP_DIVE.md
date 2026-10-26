# Metal Road: углублённый аудит Survival

Дата: 2026-10-23. Godot 4.7.2 stable Flatpak. Ветка main, HEAD 13f16a727183498c2dbf0ee539a035fbf7349e6a. **Объект анализа — рабочая копия с незакоммиченными изменениями**, а не только HEAD. Исследованы scripts/, scenes/, resources/, tests/ и пять прежних docs/reports/METAL_ROAD_*.md. Ссылки ниже относительны корню проекта; указанные методы — точки проверки. Новая игровая логика не внедрялась. Headless-диагностика не является ручным прохождением или GPU-профилированием.

## 1. Поправки к предыдущему аудиту

- «Рост до 6 врагов» неверен для полного цикла: wave_plan даёт до 8 основных врагов. starting_enemies/max_enemies — fallback, практически перекрытый планом.
- В исходном аудите Арбитр появлялся после каждой волны вопреки полю boss. Обновление 2026-10-23: дефект расписания исправлен; теперь план определяет boss-wave только на 5,10,15,…, а обычные волны завершаются без Арбитра. Подробности текущих проверок и сравнительных метрик — QA, раздел «Арбитр каждые пять волн».
- ObjectDB на завершении пока нельзя классифицировать как runtime-утечку. Идентифицированы аудиоресурсы и playback; подробности ниже.
- Прежний статус READY относится к узким smoke-сценариям. Он не подтверждает весь баланс, проходимость каждого маршрута каждой машиной или полноценную воспроизводимость daily.
- Противники в обычном Survival сразу focus_player=true; старый комментарий «все против всех» не описывает выбор цели. Friendly fire/столкновения отдельных машин при этом возможны.

## 2. Геометрия scrapyard

Эксперимент2026-10-26: основной ресурс теперь1400×1000, объекты прежнего размера/количества перераспределены. Таблица ниже сохраняет **историческую**1000×800 геометрию аудита. Текущие координаты, физические hull, spawn/pads/hazards, камера и повторные old/new проверки: [scrapyard expansion](METAL_ROAD_SCRAPYARD_EXPANSION.md). Старый ресурс/декор сохранены в tests/fixtures, маршруты с --old. Наблюдаемый group8 FAIL3/20→1/20 не означает исправление AI;25 функциональных regressions и geometry smoke PASS.

Источник: resources/default_arena.tres; scripts/arena_config.gd; Arena._ready, _create_collision, _build_obstacle_polygon (scripts/arena.gd:38,223,284). Единицы — координаты Godot 2D, не физические метры.

Внутренний прямоугольник [0,1000] × [0,800]. Стены толщиной 20 снаружи: top=(-20,-20,1040,20), bottom=(-20,800,1040,20), left=(-20,0,20,800), right=(1000,0,20,800). StaticBody2D, friction=.5, bounce=.1; impact_factor стены=1.1.

| Объект/индекс | Layout Rect2(x,y,w,h), используемый AI | Фактический AABB CollisionPolygon2D, измерено headless | Вершин hull | impact_factor |
|---|---|---|---|---|
| 0, центральные разбитые машины | 430,300,140,120 | 436.964,331.334; 126.452×57.807 | 23 | .3 |
| 1, верхний контейнер | 185,205,145,44 | 201.057,208.326; 112.887×37.067 | 5 | 1 |
| 2, нижний контейнер | 185,390,145,44 | 201.057,393.326; 112.887×37.067 | 5 | 1 |
| 3, правая куча шин | 730,240,85,70 | 740.682,243.527; 63.950×63.009 | 31 | .85 |
| 4, правый автобус | 705,440,160,44 | 712.946,444.892; 144.847×35.177 | 12 | 1 |

Это выпуклые контуры, а не заполненные AABB. Алгоритм: выбрать texture slot [3,4,4,0,1]; fit пропорций в layout×1.03; семплировать alpha>=.35 с шагом ceil(max_dimension/72); масштабировать точки ещё на .9; Geometry2D.convex_hull. Поэтому точный центральный физический объект существенно ниже своего планировочного слота. Он статичен и не разрушается как Vehicle. Устаревший комментарий в Arena._draw о прямоугольниках как едином источнике physics/routing уже не соответствует реализации.

Дополнительные физические объекты (Arena._create_interactives/_create_props; MapProp._ready):

| Объект | Центры | Коллизия |
|---|---|---|
| Два ящика, HP=25 | (210,280), (260,290) | Rectangle 34.2×31.16, StaticBody; после разрушения collision_layer=0 и удаление через .35 s |
| Малая куча шин | (620,355) | Circle radius=22.88; неразрушаемая |
| Бетон | (235,505), (755,535) | Rectangle 63×11.48; неразрушаемый |
| Бочки, HP=30 | (820,210), (845,260), (820,310) | Circle radius=14, StaticBody |

MapProp rotation всё ещё случайна в [-.24,.24] rad даже при structured_scrapyard=true: фиксируются позиции и texture slots, но не угол. Для бетона высота world AABB до 26.12, для ящика до ~38.4. Planner использует более крупные half extents=size×(.48,.46), повёрнутые до world AABB. Wrecks и fences в этой конфигурации пусты.

### 2.1 Ширина маршрутов

Это геометрические сечения; они не равны гарантированному радиусу разворота.

- Левый обход центра: x=330..430, **100** layout units. Между реальными hull AABB контейнера и центра минимум по x≈123; прямой проход вдоль всего участка всё равно зависит от ящиков и поворота.
- Между контейнерными слотами по y=249..390 — **141**, но ящики (210,280)/(260,290) разбивают эту полосу. Нельзя считать всю её свободной.
- Справа от центра до большой кучи шин: 730−570=**160**, однако малая куча (620,355) закрывает часть. Между layout края центра570 и левым краем малого круга597.12 всего **27.12**; между фактическим hull AABB центра563.416 и кругом≈33.70. Это не автомобильный маршрут для обычного Raider шириной37.92.
- Правый внешний обход автобуса: 1000−865=**135** layout units (физический hull заканчивается≈857.79). Для boss planner с radius72 свободной осевой полосы здесь нет.
- Нижний манёвр: после самого нижнего бетона с учётом max rotation, y≈548.06..800 — **251.94** до стены. Разметка y=590 чисто декоративна. Исключение — шипы около (150,650), не твёрдое препятствие, но наносят урон.
- Верхний обход контейнеров: y=0..205, **205**; бочки справа сужают локальные варианты.

Вывод: крупным машинам нужны внешние обходы и пространство для разворота. Нельзя «заполнять пустоту» в нижнем коридоре без повторной проверки.

### 2.2 Spawn и supply

Arena.get_spawn_points (arena.gd:342) выдаёт по порядку:
(80,80), (920,80), (920,720), (80,720), (500,80), (920,400), (500,720), (80,400), (270,80), (920,216), (730,720), (80,584).
Игрок получает первый, остальные — первые N следующих. Поворот игрока 0 rad; боты ориентируются на игрока. Начальная пятёрка создаётся синхронно, stagger-интервала нет. Boss выбирает наиболее далёкий от игрока anchor из первых max(N+1,6); специального полного collision-query для boss spawn нет.

Hotspots: север (500,130), запад (90,320), восток (910,350), юг (500,660). Ground rings radius28/32 и отметки ±38 рисует arena_dressing.gd; коллизий/гарантированного бонуса они не создают.

### 2.3 Проходимость по габаритам

Vehicle.COLLISION_SCALE=(1.63,1.58); контур корпуса — скошенный восьмиугольник, visual scale1.72. ArenaNavigation.clearance=ceil((width×1.58/2+length×1.63×.23+6)/8)×8. Grid препятствия дополнительно grow(radius+4); CELL=24.

| Машина | Физический bbox length×width | Radius planner |
|---|---|---|
| Raider/Viper/Wasteland GT/Crusher | 65.2×37.92 | 40 |
| Phantom | 70.09×33.18 | 40 |
| Nomad/Dust Fox | 68.46/66.83×39.5 | 48 |
| Needle | 73.35×34.76 | 48 |
| Marauder/Warhound | 70.09×39.5 / 71.72×41.08 | 48 |
| Behemoth/Bastion | 78.24×47.4 / 79.87×48.98 | 48 / 56 |
| Arbiter | 120.62×71.1 | 72 |

Измерение: для каждого из 12 catalog chassis все 36 пар «первые 9 anchors → 4 hotspots» дают непустой путь и точную конечную точку. Arbiter: 36 непустых путей, но только 27 точных окончаний. _nearest_open может подменять заблокированную цель ближайшей клеткой — **непустой путь сам по себе не доказывает достижение цели**. Boss бонусы целенаправленно не собирает, но эта особенность важна при преследовании игрока у границ.

Чистая осевая ширина 100-unit коридора после grow(radius+4): Raider12, chassis radius48 — отрицательная4, Bastion−20, boss−52; grid24 может убрать даже 12-unit полосу. Поэтому у классов различаются маршруты, а не только скорость прохождения.

## 3. Hazards и декор

- Масло (815,380): Area2D, Circle radius1 с scale(66,34), визуальный эллипс132×68. OilSpot: traction×.38, steering×.72, снять modifier при выходе; без прямого damage. Не тестировалась точность неравномерно масштабированного Circle в physics backend.
- Бочки: взрыв при HP≤0 либо наезде closing_speed≥55; <=10 игнорируется, промежуточный удар lerp(2,16.5). Радиус105, урон55×(1−smoothstep(0,105,distance)), без LOS за укрытием. Соседние destructibles в94.5 получают44. Бочки расставлены через≈55.9 — возможна цепная детонация. Источник урона сама бочка, поэтому убийство не обязательно засчитывается игроку. Удаление .9s.
- Шипы **не перечислены в ArenaConfig**: Survival._setup_spike_strips:169 всегда добавляет (150,650), Rectangle76×20; 28 damage в wheels на body_entered. Повторный въезд повторяет урон; это делает нижнюю левую область не полностью безопасной.
- Декор: ArenaDressing z−12, opacity.65, центральные кольца112/122, skid arcs145/154/240/249, 32 пятна; нет gameplay effects. Лампы toggled каждые.4s, перерисовывается только их узел. Не следует принимать нарисованное «масло» за OilSpot.

Другие доступные арены — ресурсы, а не только future ideas:

| Resource | Размер | Механика |
|---|---|---|
| oil_cauldron_arena | 1280×900, wall24, margin95 | biome_id=rust_frontier; буря после8s, активна11s/пауза24s, strength.64, traction.82; итог grip при полном intensity .8848 |
| steel_foundry_arena | 1180×820 | press: случайная полоса140 вертикально/130 горизонтально; 28 body damage в момент удара |
| flooded_depot_arena | 1220×860 | flood по всей арене: grip.84 warning/.68 active, без damage |
| red_quarry_arena | 1320×920 | rockfall radius125, 34 body damage |

ArenaHazardDirector: первый warning max(5,interval×.55), затем предупреждение2.2s, active1.4s. Интервалы press13/flood15/rockfall12; между ударами interval+2.2. На scrapyard mechanic_id пуст — директор ничего не запускает. Dynamic hazards не входят в стоимость AStar; бот не планирует уход из красной зоны.

## 4. AI: фактические решения

Диагностика нестабильности 2026-10-23: исходный group8 smoke дал3 FAIL из20, инструментированный4 из20. Подтверждены влияние парковки доехавших машин, различие traffic/yield условий и повторные отмены recovery у границы. Новая геометрия или изменение физики не обоснованы. Подробные trace, контроль seed/instance_id и только предлагаемые исправления: [AI navigation diagnostics](METAL_ROAD_AI_NAVIGATION_DIAGNOSTICS.md). В этой диагностике игровой код не менялся.

Обновление 2026-10-23: после аудита уточнены геометрия навигации, контракт route_result(EXACT/NEAREST/NONE), локальное уступание и проверка заднего габарита. Ниже сохранён исходный снимок; актуальные алгоритмы/проверки описаны в QA, раздел «Навигация и встречное движение». Ресурсы основной арены не переставлялись.

Источники: scripts/arena_bot.gd:74–488; scripts/arena_navigation.gd; Survival._spawn_bot/_spawn_biker.

1. Каждый physics step выдаются команды. Tactical intent обновляется через .28/.32/.36/.40s (instance_id modulo4); смерть цели и низкое HP ускоряют выбор. Радиуса обнаружения игрока нет: поиск по combatants, focus_player=true даёт глобальное знание позиции.
2. Intent: patrol, pursue, attack (<320), supply, retreat, reposition. Упреждение .16..65s; flanker/support вооружённый смещает цель относительно направления жертвы до135, biker95.
3. AStarGrid2D24, octile, без диагонального срезания solid corners. Static layout + MapProps + barrel AABB36; refresh раз45 physics frames (~.75s при60Hz). Масло/шипы/другие машины не solid. Path replanning каждые.65s при смещении goal>75, blocked или конце пути; line-of-sight smoothing.
4. Lookahead clamp(avoid_radius×.45+speed×.55,55,145). Curvature=2sin(error)/max(distance,40); speed ограничивается sqrt(lateral_acceleration/abs(curvature)), lateral acceleration88 ordinary/62 boss/110 biker с поправкой damage/surface. Учитываются тормозной путь, повороты и free_distance260.
5. _traffic_speed снижает скорость за другими машинами при gap<95, оставляя20; целевой игрок исключён у обычной машины, чтобы таран был возможен. Совместного резервирования маршрутов и диспетчера разъезда нет. Встречные заторы и синхронный reverse — риск, не доказанный глобальный deadlock.
6. Recovery: перемещение>12 сбрасывает таймер; speed<12 вне EMP накапливает его; threshold=max(stuck_timeout,1.05). Реверс минимум.8s, throttle−.55 до speed−42, steer×.75; проверяется rear_room90 и стоп при<16. У boss duration1.45; biker.9. Настроенные boss timeout.72/biker.62 фактически оба ограничены1.05.

### 4.1 Роли, атака, ограничения настройки

Strategy BRAWLER: retreat.08, cone.34; HUNTER: базовый retreat.28/cone.22; SCAVENGER: поиск supply даже с оружием, utility×1.3; SURVIVOR: retreat.48. Class Juggernaut retreat×.55, Assault fire_range×1.15 и cone+.05; Interceptor cruise1 и steer_gain×1.08. Это независимые оси strategy/team_role/class.

Fire: только временное оружие; distance≤min(fire_range420,effective_range), cone≤.22rad по умолчанию и navigation.segment_clear radius1. Assault range483. Mine — distance≤145 без обычной проверки направления. Biker fire_range390/cone.31; boss external_weapon_control передаёт fire в RefereeBoss.

Supply видимость680, удержание цели720, score=utility×lerp(1,.32,d/680), начальный порог.28. Weapon utility1 невооружённому/.08 вооружённому; repair clamp((1−HP)×1.65,.08,1); speed .68/.25; ram .62 или1 brawler/.25 active. Застревание на бонусе3s → ignore7s.

**Подтверждённые неработающие настройки:** preferred_range, avoid_weight, hazard_avoid_radius, retreat_weight, stuck_speed, ease_angle, brake_angle объявлены/меняются, но не читаются в решении движения. В частности, «Оракул держит дистанцию» не обеспечивается preferred_range. Вносить баланс правкой этих чисел бессмысленно до определения нового контракта.

Геометрия совместима с основными путями каталога в проверенном layout; она не гарантирует tight turns, свободные встречные проезды и попадание boss в точную цель. Static clearance консервативен, но не является полноценным swept envelope длинной вращающейся машины.

## 5. Волны и баланс

Обновление2026-10-26: таблица ниже — исторический снимок аудита. Для начальной играбельности первый цикл изменён на3/4/4/5/3 врагов, elites0/0/1/1/1; wave1 стартует2+1 после5s с pending/generation guards. Арбитр остаётся на каждой5-й. Новые правила подтверждения замены оружия E/X/□ и полного body repair ограничены игроком Survival; Race/AI auto pickups прежние. Актуальные формулы, mapping и24 повторных regression PASS — QA, раздел «Начальная играбельность Survival —2026-10-26». Известный навигационный риск не исправлялся.

SurvivalRunData.wave_plan: cycle=(wave−1)%5+1; tier=floor((wave−1)/5).

| cycle | Название | основных врагов | элит из них | supply_rate |
|---|---|---|---|---|
| 1 | Схватка | min(5+tier,7) | min(tier,2) | 1 |
| 2 | Битва за поставки | min(6+tier,7) | 0 | 1.8 |
| 3 | Элитный отряд | min(4+tier,6) | min(2+tier,4) | 1.15 |
| 4 | Натиск | min(6+tier,8) | min(1+tier,3) | 1.35 |
| 5 | Суд Арбитра | 4 | 4 | 1.25 |

Обычный chassis = catalog[(index+wave×2)%catalog.size()]. На первых пяти волнах состав по ids: [dustfox,viper,phantom,needle,wasteland_gt]; [phantom,needle,wasteland_gt,marauder,warhound,crusher]; [Vanguard,Flanker,warhound,crusher]; [Vanguard,crusher,behemoth,bastion,raider,nomad]; [Vanguard,Flanker,Support,Vanguard]. Порядок каталога подтверждён LoadoutProfile.vehicle_ids и runtime probe. Career может заменить обычных ботов RivalRoster-конфигурациями.

Survival._scaled_bot_config: r=max(0,wave−1); HP×(1+min(.075r,.7)); engine/wheels×(1+min(.05r,.45)); accel×(1+min(.025r,.22)); speed=min(220,base+min(2r,18)). Elite дополнительно HP×1.45, resistance+.08 cap.55, weapon multiplier+.14, ram+.15.

| Elite база | L×W / масса | HP / engine / wheels | speed / accel / grip / steer | resist / ram | Вооружение |
|---|---|---|---|---|---|
| Vanguard | 54×31 /2250 | 245/135/125 | 126/590/23/3.5 | .29/1.9 | ram boost999s |
| Flanker | 47×22.5 /880 | 138/92/84 | 198/980/18.5/7.4 | .13/.92 | EMP999s; weapon damage1.18/rate1.12 до scaling |
| Support | 52×29 /1620 | 205/126/112 | 146/640/21/4.4 | .23/1.18 | heavy MG999s; damage1.38/rate1.2 до scaling |

Elite indices mod3 задают роль/оборудование, общий squad cerberus. Например первая elite_wave3: HP Vanguard408.5375, Flanker230.115. Это расчёт, не показатель «сложности в процентах».

### 5.1 Финал обычной и boss-wave

Текущий контракт: Survival._complete_combat_phase — общая точка завершения для death signal и recovery polling. Если живых врагов нет и wave_plan.boss=false, вызывается прежний _end_round(true), без boss timers/spawn. Если boss=true и Арбитр ещё не создавался — deferred _spawn_referee с прежним generation guard; после его появления ожидается также уничтожение активных riders. Самостоятельные вызовы request/spawn тоже проверяют boss. План вычисляет cycle=(wave−1)%5+1 и boss=(cycle==5); проверки modulo в UI/спавне не дублируются.

Внутренний export referee_every_wave=false позволяет диагностическое A/B со старым расписанием, без нового меню. Career может явно задать requires_arbiter=true в event; это нормализует тот же wave_plan.boss, а не создаёт второе состояние. Нынешние arena-контракты scrapyard_contract/oil_cauldron завершаются по target_rounds=2/3 и такого требования не имеют. Race boss_duel не затронут.

Base Arbiter:74×45, mass4600, HP400, engine310,wheels270,accel360,grip29,steer2.7,resist.34,ram2.45. Boss scaling не изменён: HP×2.65 сверх wave scale, engine/wheels×1.8, resist+.14 cap.62, ram+.35; speed=48/59/70/81/92 на wave1..5 (первые четыре значения теперь доступны только с явным override), затем92. Первая обычная встреча теперь wave5: HP1378/speed92, а не прежние wave1 HP1060/speed48. Это следствие расписания, не новая настройка босса.

Фазы HP>66%, 33..66%, ≤33%. Saw radius19, damage11/14/18 с cooldown .195/.17/.145 на цель; impulse≤760. Flame: initial cooldown2.2; обнаружение player≤410 в передней полуплоскости, warning.75s, fire1.6/1.75/1.9s, cooldown random6.5..8.5−.55×(phase−1). Geometry flame warning length292; это отдельный визуальный конус, не точное равенство range обнаружения.

Через10s boss deploy до6 bikers, повтор через36s, но таймер идёт только при отсутствии живых байкеров. Фактически может появиться меньше6: _find_clear_biker_spawn проверяет clearance34, расстояния50 между принятыми и62 от combatants, forward85 с room>60. Biker HP54,mass285,length25,width9.5,speed min(184,178+.35r), twin pistol9999s, squad referee. Убийство boss при живых riders не завершает волну.

Нулевая активность9s включает hunt и throttle+.08;18s пытается вызвать weapon supply. На72s fire_range+120, cruise1, hazard clock≤2, сообщение sudden death. Это не shrinking arena и не обязательное убийство таймером.

### 5.2 Переходы, перки и рестарт

Обновление 2026-10-23: описанные ниже проблемы start_round(1), deferred crew и продолжающихся после results подсистем исправлены. Restart пересоздаёт арену, завершение останавливает игровой мир с сохранением работы UI. Исторические наблюдения аудита сохранены; актуальные проверки — в QA-отчёте, раздел «Жизненный цикл и Restart Survival».

После всех enemies (включая riders): guard _round_over, награда, задержка1.2s, выбор1 из3 перков, следующая волна. Headless автоматически выбирает не second_wind — существенное отличие от GUI. Repair между волнами30% или45% с field_mechanic. Обычный Survival бесконечен до defeat; Career contract имеет target_rounds (fallback2) и VICTORY.

Перки уже реализованы: HP+28/resist+.04; speed+10/accel+150; grip+2/steer+.8; weapon damage+.22; rate+.18; ram+.25 и repair(12,8,8) за kill; supply_magnet; second_wind (body32%,engine45%,wheels55% раз/волну); volatile_wrecks (damage24/radius135); wave_repair; elite_score; weapon_duration. Не предлагать их как новые механики.

start_round(1) очищает score/kills/perks/crew, сбрасывает машину, bullets/enemies/bonuses/tire tracks. **Не пересоздаёт арену, разрушенные barrels/crates и hazard director**, VFX не очищает синхронно. _queue_crew_from_vehicle deferred не проверяет generation, в отличие от boss spawn — возможен crew после same-frame restart (проверить отдельным regression).

## 6. Поставки, вероятности, награды

Обновление 2026-10-23: описанный ниже исторический fallback ZERO исправлен. Текущий поиск возвращает явный отказ, учитывает дополнительные физические препятствия/шипы и достижимость штатным Raider; см. раздел исправления размещения в METAL_ROAD_QA_REPORT.md. Интервалы/партии/мешок типов и эффекты бонусов не перенастраивались.

Survival.start_round: interval5/rate; first_delay2.8/rate; warning1s; lifetime26s; batch3 с минимум2 weapons; supply_rush или supply_magnet batch4 с минимум3 weapons; max_active6/8; separation210.

Первый активный batch возникает через max(0,first_delay−1)+1; следующие при наличии мест — через interval+1 после предыдущего вооружения. Для cycles1..5: первые2.8/1.556/2.435/2.074/2.24s; интервалы6/3.778/5.348/4.704/5s. При лимите попытка откладывается на interval.

Оставшийся слот берётся из перемешиваемого мешка WEAPON,REPAIR,SPEED,RAM, каждый раз в четырёх draws. Это не независимые Bernoulli25%. При полном batch3 средняя доля weapon75%, остальные по8.333%; batch4 weapon81.25%, остальные по6.25%. При неполных партиях гарантированные weapons заполняют доступные слоты первыми, поддержка может не попасть. Оружие uniform1/7 из списка MG,heavy MG,shotgun,rocket,mine,flame,EMP.

_next_position (bonus_spawner.gd:177) пробует48 кандидатов, первые12 циклически hotspots. Проверяет layout.grow86 и separation от reserved/active; **не проверяет MapProps/barrels/spikes, машины и физическую достижимость**. После исчерпания возвращает ZERO, а _create_pickup всё равно создаёт объект — конкретный риск бонуса в углу карты.

Pickup физический radius50 (сцена), нарисованное поле radius45; _process пульсирует scale±6%, влияя также на Area2D. Подобрать может любая живая Vehicle, один раз (collected_once). Weapon25s, speed8s, ram9s; repair() добавляет body28/engine22/wheels24, ограничено максимумами, а не полный ремонт. Speed и ram boost взаимно выключают друг друга. get_bonus_duration_multiplier учитывает конфиг только при passive_id=salvager. supply_magnet добавляет .45 к конфигу и ещё умножает remaining×1.45 в _on_bonus_collected; weapon_duration дополнительно×1.35. Для Raider с базовым1.35 после магнита получается (1.35+.45)×1.45=2.61 от базовой длительности, вместо простого роста прежней длительности на45%; у chassis без salvager остаётся только внешний×1.45. Описание «поставки чаще» не меняет interval: увеличивается batch.

Очки (survival.gd:709,734,865,1008):

- Damage игрока врагу: round(amount×(8+combo×1.5)); каждые100 accumulated damage дают40 credits.
- Kill при last_attacker==player: combo++ и окно7s; обычный round((450+110combo)×(1+.2combo)×elite_bonus), biker (210+65combo)×(1+.2combo). Boss дополнительно4000.
- elite_bonus1.35 только если meta elite и perk elite_score. Boss имеет elite=false: описание «за элит и боссов» не соответствует проверке для boss.
- Crew:350+(combo−1)×55 за crush/weapon, продлить окно хотя бы до5s. От обычного/elite wreck выходят pilot+mechanic; boss/biker исключены.
- Pickup игроком:180+25combo. Урон игроку сбрасывает combo.
- Credits100 за credited kill и250 за выигранную волну; множитель difficulty .85/1/1.25. В EconomyConfig survival_victory_reward500 объявлен, но _end_round не начисляет его отдельно.

Запись профиля происходит при начислении, а не только в конце матча. Поэтому тесты необходимо изолировать. Последний атакующий barrel может лишить player kill-credit; это текущая атрибуция, не новая PvP-механика.

## 7. HUD и согласованность состояний

ArenaHUD.update_status (arena_hud.gd:48), VehicleReadout.update_vehicle, Survival._process:194.

| Событие | Что обновляется | Ограничение |
|---|---|---|
| start_round | wave/enemies/destroyed и объявление wave.name | прямой update без run_info временно показывает score0, пустой scenario; следующий _process исправляет |
| damage | module bars/speed через get_hud_state; flash/message через signals | damage-stage сообщение может вытеснить более важное |
| bonus | оружие/timer в readout; сообщение collect | единственный Message без очереди и приоритетов |
| последний обычный враг | deferred boss spawn, total+1 | панель boss может отставать до следующего process |
| elite | scenario содержит «Элитный отряд» для cycle3 | отдельный точный счёт элит в HUD отсутствует |
| конец волны | «ВОЛНА N ПРОЙДЕНА» каждую process итерацию до draft | первая строка с credits быстро заменяется countdown |
| defeat | Results и Message999s | BonusSpawner и hazards/AI не остановлены самой _end_round; могут продолжать события |

Подтверждён источник старого визуального кадра: tests/survival_art_review.gd вручную update_status(...round=3), выключает game._process, но оставляет сообщение wave1 от _ready. Это тестовый артефакт. В runtime start_round меняет _round и объявление вместе; устойчивое несовпадение разных номеров пока не доказано.

Другой риск подтверждается кодом: show_message — last writer wins. Hazard/supply/crew могут скрыть defeat/finale; update_status без run_info в _on_vehicle_died временно сбрасывает отображаемые score/combo/boss. Нужна проверка на каждом кадре, а не только финального текста. Headless auto-choice вызывает _on_perk_selected напрямую и не проходит _choose, где прячется overlay: тестовый UI может остаться видимым.

## 8. VFX и lifetime

Обновление 2026-10-23 после аудита: budget восстановлен с приоритетами important/large impact/impact, MAX_EVENTS48. Release и отдельный budget smoke проходят. Исторические результаты ниже описывают состояние до исправления; актуальный QA — METAL_ROAD_QA_REPORT.md.

CombatVFX spawn_* просто append; TTL impact.24/explosion.48/pickup.55s; _process уменьшает time и filter удаляет истёкшие, set_process(false) при пустоте. Git diff относительно HEAD показывает удаление _trim_events и трёх вызовов; прежний контракт pop_front при size>=48 перед append. Поэтому 70 синхронных impacts дают70, assertion≤48 закономерно FAIL.

Это **отсутствие peak budget**, не автоматически неограниченный рост во времени. При потоке λ events/s примерно λ×TTL живых событий; burst всё равно не ограничен. Impact рисует7 линий, explosion — круги/arc/11 sparks. CPU allocation/filter и draw calls требуют GPU-профиля; FPS headless не показатель.

Варианты: (A) восстановить48 FIFO — простая совместимость, но может вытеснить важные explosions/pickup feedback; (B) единый бюджет48 с приоритетами/объединением близких impacts — предпочтительный план после замеров; (C) оставить без cap только если измеренный worst-case укладывается в frame budget и новый контракт утверждён. Простая смена порога теста не устраняет риск.

TireTracks имеет cap1800/lifetime3s. Wreck Vehicles сохраняются в _enemies до следующей волны; повторные biker squads оставляют мёртвые Vehicle до очистки — реальный потенциальный рост объектов в долгой boss-фазе. CrewRemains сохраняются до _clear_crew. Это явное владение объектами, а не потерянные orphan nodes.

## 9. ObjectDB: доказательства и границы вывода

Изолированно повторены verbose release_candidate и survival_smoke. Release: AudioStreamWAV(menu_hover.wav) и AudioStreamPlaybackWAV, 2 leaked/1 resource. Survival: WAV/OggVorbis/OggPacketSequence и playback, 22/8; игровые Node не перечислены среди этих leaked instances. Smoke делает _game.free(); quit() в одном callback — audio backend может не успеть завершить освобождение. UISounds.play_hover вызывается focus_entered, play_click создаёт root UIClick и timer cleanup.

Гипотеза — порядок shutdown/аудио. Для различения нужен A/B drain после освобождения, проверка роста после нескольких циклов и воспроизведение в GUI. Общая подсказка Godot про remove_child без free не доказывает, что именно это произошло.

## 10. Проверки и воспроизводимость

Диагностическая копия /tmp/metal-road-deep-cRUfIj имеет отдельный application name/custom user directory, profile/loadout overrides. Исходный проект и постоянные сохранения этой проверкой не затрагиваются. Script audit_probe.gd: seeds4217,104729,8675309, по10800 physics frames (180 simulated seconds при60Hz); между scripted clear работают реальные physics, AI, bullets и pickups. Игрок искусственно усилен и заморожен, enemies принудительно добиваются на25/26-й секунде каждого30s интервала, чтобы испытать lifecycle. Это не оценка естественной скорости победы.

Глобальный RNG/bonus/hazard seeded; arena test subclass фиксирует prop rotation RNG4217. Но perk_choices в non-daily использует randomize, AI passing side/reaction зависит от instance_id. Поэтому seed фиксирует часть входов, **не гарантирует битовое повторение всего матча**. Production daily также не seed-ит Arena/BonusSpawner полностью. Результаты запуска и итоговые счётчики добавлены ниже.

## 11. Вывод для проектирования

Уже существуют supply contest, retreat/recovery, элитные роли, boss phases, riders, перки, hazards и пять арен. Следующий этап должен сначала закрепить воспроизводимость, restart/HUD/bonus contracts, затем расширять тактику и композицию. Нижний коридор и пути большой машины — ограничения для дальнейшего декора. Подробный порядок, критерии и риски: METAL_ROAD_SURVIVAL_IMPROVEMENT_PLAN.md.

## 12. Итоговые результаты новых запусков

Сырые логи и диагностические scripts сохранены в [survival-deep-evidence/](survival-deep-evidence/). Ниже только результаты текущего аудита; предыдущие PASS не выдаются за повторный запуск.

| Сценарий | Длительность/объём | Результат и отклонения |
|---|---|---|
| audit_probe, seed4217 | 10800 physics frames =180s симуляции | достигнута wave7;66 pickups всеми машинами,229 player-damage events; peak nodes308/objects2546; VFX peak6 |
| seed104729 | 180s симуляции | wave7;66 pickups,275 damage events; peak314/2568; VFX peak10 |
| seed8675309 | 180s симуляции | wave7;58 pickups,235 damage events; peak307/2561; VFX peak8 |
| Restart после каждого seed | 2 кадра наблюдения | wave1,5 enemies,score0,crew0; VFX remaining4/0/0 — старые эффекты кратковременно сохраняются |
| Teardown каждой сцены | deferred flush +2s simulation | nodes10 во всех трёх; objects1797/1797/1785; orphan0/0/0; устойчивого роста остатка нет |
| VFX burst/expiry | 70 impacts +.7s | сразу70, после ожидания0; подтверждены отсутствие cap и работа TTL |
| release_candidate original | короткий smoke, wall time отдельно не измерялся | FAIL только budget;2 audio instances/1 resource |
| release_candidate drain | тот же smoke +.5s перед quit | FAIL только budget; предупреждения ObjectDB/resources исчезли |
| survival_smoke original | ~3s scripted waits + кадры | PASS0;22 audio instances/8 resources при выходе |
| survival_smoke drain | тот же сценарий +.5s перед quit | PASS0; предупреждений ObjectDB/resources нет |
| survival_round_guard_smoke | короткий lifecycle smoke +.2s | PASS; остаются18 instances/7 resources при shutdown |
| arena_driver_regression, seed4217 | 7 маршрутов, лимит20s на car/bike и30s на boss, остановка при достижении; плюс wall braking | PASS0; все7 reached, contacts0, steering reversals0–1 |

HUD wave-mismatch sampling раз60 physics frames дал0 во всех трёх прогонах. Это не покадровая гарантия; вспышки на один кадр и перекрытие сообщений не исключены. Подбор происходил в живой физике, но счётчик объединяет player/AI. Player заморожен, поэтому тест не проверяет ощущения управления. Damage-events не равны количеству collision: источники смешаны; повторные физические контакты не подсчитаны отдельно. Driver regression проверяет отдельные машины, не всю очередь встречного трафика.

Суммарно540s симуляции и18 принудительно завершённых волн; естественное время зачистки не измерялось. Числа peak VFX снимались раз в секунду и могут пропустить короткий burst. Object count включает ресурсы, это не размер памяти. Wall-clock время каждого seed не записывалось; не заменять его simulated seconds. Все smoke/soak были headless. Нового GUI/manual playtest в этом аудите нет.

Уточнение стенда: freeze игрока выставляется при первом создании; переходы reset могут его снимать, ввод управления не подаётся. Driver regression использует свою тестовую арену1500×900 с одним прямоугольным препятствием, поэтому его PASS не доказывает все маршруты реальной scrapyard. Surface modifiers объединяются минимумом по источникам, не произведением (Vehicle._recalculate_surface_modifier).

**Вывод по ObjectDB:** A/B подтверждает зависимость предупреждений от немедленного shutdown аудио в этих двух тестах. Вместе с нулём orphan и стабильным cleanup это не даёт оснований объявлять runtime-утечку игры. Для других сценариев, например бесконечных biker squads, остаётся отдельный риск удержания принадлежащих сцене объектов.

### Воспроизведение

Создать независимую копию project/scenes/scripts/resources/assets/tests/import cache. В её project.godot задать уникальный application/config/name и custom_user_dir_name; не использовать основное user://. Скопировать audit_*.gd из evidence в корень этой копии. Команда:

```bash
flatpak run --filesystem=/ABS/AUDIT_COPY org.godotengine.Godot --headless --path /ABS/AUDIT_COPY --fixed-fps 60 --script res://audit_probe.gd
```

Для verbose smoke заменить script на tests/survival_smoke.gd или audit_survival_drain.gd и убрать fixed-fps, добавить --verbose. Копия audit_survival_drain переводит phase=5 перед асинхронным teardown и возвращает false из SceneTree._process, чтобы await действительно завершился. Production файлы не исправлены. Non-daily perks остаются случайными — это ограничение сохранённого probe.
