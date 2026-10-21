# Паспорт проекта «Metal Road» (Godot 4)

> **Обновление 2026-09-22:** актуальное состояние Sprint B–D описано в
> [итоговом отчёте](docs/sprints/bcd/report.md). Уже реализованы общий компактный
> HUD, combat в Race, DNF, три круга, позиции, таймер и экран результатов.
> Текущий набор — 21 smoke-тест. Разделы ниже сохранены как паспорт исходного MVP;
> утверждения об отсутствии боя/финиша и перечень 11 тестов относятся к нему.
> История восстановления незакоммиченного проекта: [recovery.md](docs/sprints/bcd/recovery.md).

> Документ описывает текущее состояние проекта и предназначен для передачи
> другой команде разработки. Содержит архитектуру, API классов, игровые правила,
> точные значения всех конфигов, инструкции по запуску/тестированию и точки
> расширения.

---

## 1. Общие сведения

| Параметр | Значение |
| --- | --- |
| Название | Metal Road |
| Жанр | 2D top-down аркадные боевые гонки / дерби на выживание |
| Движок | Godot **4.7.2** stable (`GL Compatibility` renderer) |
| Язык | GDScript |
| Платформа | Linux x86_64 (перенос с Python/Pymunk прототипа) |
| Корень Godot-проекта | `godot/` |
| Главная сцена | `res://scenes/MainMenu.tscn` |
| Разрешение | 800×600, stretch `canvas_items` |
| Игровые режимы | **Гонка** (Race), **Выживание/Дерби** (Survival) |

**Запуск:**
```bash
/home/andrey/applications/Godot/Godot_v4.7.2-stable_linux.x86_64 \
  --path /home/andrey/PycharmProjects/metal_road/godot
```

**Запуск тестов** (headless, все 11 должны проходить):
```bash
GODOT=/home/andrey/applications/Godot/Godot_v4.7.2-stable_linux.x86_64
PROJ=/home/andrey/PycharmProjects/metal_road/godot
for t in vehicle_smoke track_smoke assets_smoke game_smoke controls_smoke \
         weapon_smoke menu_smoke bot_smoke arena_smoke survival_smoke derby_smoke; do
  $GODOT --headless --path $PROJ --script res://tests/$t.gd
done
```

---

## 2. Структура проекта

```
godot/
├── project.godot                 # настройки движка, главная сцена, Input Map
├── icon.svg
├── scenes/
│   ├── MainMenu.tscn             # титульный экран (Гонка/Выживание/Настройки/Выход)
│   ├── Main.tscn                 # режим Гонка (Track + Player + 2 байка)
│   ├── ArenaBattle.tscn          # режим Выживание/Дерби (Arena + Player + спавн-боты)
│   ├── Track.tscn                # трек (ссылается на TrackConfig)
│   ├── Arena.tscn                # арена (ссылается на ArenaConfig)
│   ├── Vehicle.tscn              # машина: RigidBody2D + CollisionShape2D + AnimationPlayer + MachineGun
│   ├── Bullet.tscn               # снаряд
│   ├── HUD.tscn                  # отладочный HUD гонки
│   └── ArenaHUD.tscn             # HUD выживания (HP/враги/раунд/баннеры)
├── scripts/                      # только логика, значения — в resources/
│   ├── main_menu.gd              # MainMenu
│   ├── game.gd                   # Game            (координатор гонки)
│   ├── survival.gd               # Survival        (координатор дерби)
│   ├── bot_controller.gd         # BotController   (ИИ гонки, едет по траектории)
│   ├── arena_bot.gd              # ArenaBot        (боевой ИИ дерби)
│   ├── vehicle.gd                # Vehicle         (физика, здоровье, таран)
│   ├── track.gd                  # Track           (геометрия/стены трека)
│   ├── arena.gd                  # Arena           (стены/препятствия/спавны арены)
│   ├── bullet.gd                 # Bullet          (снаряд, урон, столкновения)
│   ├── machine_gun.gd            # MachineGun      (темп стрельбы, разброс, лимит пуль)
│   ├── input_handler.gd          # InputHandler    (InputMap -> contract)
│   ├── camera.gd                 # FollowCamera    (плавная камера)
│   ├── debug_hud.gd              # DebugHUD        (HUD гонки)
│   ├── arena_hud.gd              # ArenaHUD        (HUD выживания)
│   ├── audio_manager.gd          # AudioManager    (музыка/двигатель/SFX)
│   ├── *_config.gd               # схемы ресурсов (Vehicle/Weapon/Track/Arena/Audio)
├── resources/
│   ├── default_vehicle.tres      # VehicleConfig
│   ├── default_machine_gun.tres  # WeaponConfig
│   ├── iron_circuit.tres         # TrackConfig
│   ├── default_arena.tres        # ArenaConfig
│   └── default_audio.tres        # AudioConfig
├── assets/
│   ├── images/                   # vehicle.svg, track_surface.svg, background.svg
│   ├── sounds/                   # engine.wav, fire.wav, collision.wav, finish.wav
│   └── music/                    # theme.wav
└── tests/                        # 11 headless smoke-тестов (SceneTree-скрипты)
```

---

## 3. Архитектурные принципы

1. **Данные отделены от кода.** Все настраиваемые значения лежат в `Resource`
   (`*Config`/`*.tres`), а не в скриптах. Художник/геймдизайнер меняет `.tres`
   без правки логики.
2. **Единый контракт управления.** Любой «водитель» (игрок, ИИ) возвращает
   словарь `{throttle, brake, steer, fire}` и подаёт его в
   `Vehicle.apply_control(...)`. Физика не знает, кто за рулём.
3. **Композиция через сцены.** Машина — самостоятельная сцена `Vehicle.tscn`,
   переиспользуется в обоих режимах и динамически инстанцируется для врагов.
4. **Группы как контракт боя.**
   - `"bullets"` → контейнер `Bullets`;
   - `"bots"` → узлы `BotController` в гонке;
   - `"combatants"` → **динамическая** группа, добавляется только в режиме
     выживания (игрок + враги). Урон и таран применяются **только** к этой
     группе, поэтому в гонке боя нет.
5. **Отрисовка процедурная.** Машина/трек/арена рисуются в `_draw()`
   (при наличии текстур — используются текстуры).

### Поток данных (режим Выживание)
```
Survival._physics_process -> InputHandler.get_commands -> Player.apply_control
ArenaBot._physics_process  -> get_commands            -> Vehicle.apply_control
Vehicle.apply_control      -> MachineGun.set_firing
MachineGun._physics_process-> Bullet.setup (spawn в "bullets")
Bullet._physics_process    -> столкновение со стеной (freed) ИЛИ take_damage(combatant)
Vehicle.take_damage        -> health-- / hit_flash / _die -> signal died
Survival._on_vehicle_died  -> конец раунда / следующий раунд
```

---

## 4. Режимы игры

### 4.1 Гонка (`scenes/Main.tscn`, `scripts/game.gd` — класс `Game`)
- Кольцевая трасса `iron_circuit.tres`, игрок + 2 бота, едущих по центральной линии.
- Игрок управляется с клавиатуры; ИИ — `BotController`.
- **Боевой урон отключён**: машины не входят в группу `combatants`.
- Рестарт — `R`; возврат в меню — `Esc`; тоггл отладки — `F1`.
- Гонка пока **не имеет условия финиша** (см. «Технический долг»), есть только
  геометрия финишной линии и помощники прогресса в `Track`.
- Экспорт `Game.spawn_bots: bool = true`; тесты выставляют `false` для
  детерминизма (удаляет `Bot1`/`Bot2`).

### 4.2 Выживание / Дерби (`scenes/ArenaBattle.tscn`, `scripts/survival.gd` — класс `Survival`)
- Прямоугольная арена со стенами и 7 блоками-укрытиями.
- Игрок с здоровьем против волн врагов. **Все против всех**: каждый бот
  атакует ближайшую живую машину, поэтому боты дерутся и друг с другом.
- **Раунды**: раунд 1 — 2 врага, каждый следующий +1 до `max_enemies = 6`.
  Зачистка раунда → через `round_end_delay` стартует следующий.
- Победа в раунде = остаться последним живым. Поражение (гибель игрока) —
  баннер «ПОРАЖЕНИЕ», рестарт с 1-го раунда по `R`.
- Урон: пули + таран машин.
- `Esc` — в меню.

---

## 5. Боевая система

### 5.1 Здоровье и смерть (`Vehicle`)
- `health: float`, `alive: bool`; инициализируется из `VehicleConfig.max_health`.
- `take_damage(amount)`: игнорирует мёртвых; вызывает `hit_flash` анимацию;
  при `health <= 0` → `_die()`.
- `_die()`: `alive=false`, удаление из `combatants`, остановка оружия,
  обнуление скоростей, отключение коллизий и `freeze` (через `set_deferred`),
  проигрывание анимации `destroyed`, эмит `died(self)`.
- `reset_to(position, angle)`: воскрешает, восстанавливает HP/модуляцию/слои/
  `freeze`, телепорт применяется в `_integrate_forces`.

### 5.2 Урон от пуль (`Bullet`)
- Пуля — не физическое тело, а `Node2D`, летит по прямой.
- `_check_hit()` перебирает `combatants`, сравнивает расстояние
  `<= max(length, width) * 0.5 + bullet.radius`; на попадании —
  `take_damage(damage)` и `queue_free()`. Свой shooter игнорируется.
- **Препятствия**: `_hits_obstacle()` делает точечный физзапрос
  (`PhysicsPointQueryParameters2D` + `direct_space_state.intersect_point`) и при
  попадании в `StaticBody2D` (стены арены, блоки, отбойники трека) пуля
  уничтожается. Пули сквозь укрытия не проходят.

### 5.3 Таран машин (`Vehicle._on_body_entered`)
- `contact_monitor = true`, `max_contacts_reported = 4`.
- При контакте двух живых `combatants` считается скорость сближения
  `(_last_velocity - other.get_last_velocity()).length()`.
- Если она > `collision_min_speed`, обе машины получают
  `(closing - collision_min_speed) * collision_damage` (урон симметричный,
  каждая машина обрабатывает свой контакт). Кулдаун `0.2 с`.
- `_last_velocity` сохраняется в начале шага в `_integrate_forces` (скорость
  до удара).

### 5.4 Группы
| Группа | Где | Назначение |
| --- | --- | --- |
| `bullets` | `Bullets` (Main, ArenaBattle) | контейнер снарядов |
| `bots` | `BotController` (Main) | поиск ИИ гонки |
| `combatants` | runtime в `Survival` | цель урона/тарана; удаляется при смерти |

---

## 6. API классов (краткий справочник)

### `VehicleConfig` (Resource, `scripts/vehicle_config.gd`)
Группы и значения (совпадают с `default_vehicle.tres`):
| Группа | Параметр | Значение |
| --- | --- | --- |
| Dimensions | length / width / corner_bevel_ratio | 40 / 24 / 0.15 |
| Body | mass / moment | 1000 / 180000 |
| Movement | max_speed / acceleration / brake_force / drag / traction | 300 / 800 / 1200 / 0.98 / 15 |
| Steering | steer_rate / steer_speed_factor / angular_damping | 5 / 0.3 / 0.95 |
| Combat | max_health | 100 |
| Ramming | collision_min_speed / collision_damage | 120 / 0.18 |
| Assets | texture | `assets/images/vehicle.svg` |

Метод: `get_body_vertices() -> PackedVector2Array` — октагон со скосами.

### `Vehicle` (RigidBody2D)
- Данные: `config`, `throttle/brake/steer/fire`, `health`, `alive`,
  `gun: MachineGun`.
- Сигнал: `died(vehicle: Vehicle)`.
- Методы: `apply_control(throttle, brake, steer, fire=false)`,
  `take_damage(amount)`, `get_speed()`, `get_forward_speed()`,
  `get_lateral_speed()`, `get_last_velocity()`, `reset_to(position, angle)`.
- Физика в `_apply_physics`: тяга (с падением к max_speed), реверс, торможение,
  боковое трение, сопротивление качению, руль через момент, угловое демпфирование,
  жёсткий клэмп скорости. `continuous_cd = CCD_MODE_CAST_SHAPE`.
- Материал: friction 0.7, bounce 0.1.

### `WeaponConfig` (Resource, `scripts/weapon_config.gd`)
| Параметр | Значение в `default_machine_gun.tres` |
| --- | --- |
| fire_rate (выстр./с) | **3.0** |
| spread (рад) | 0.03 |
| max_active_bullets | 60 |
| muzzle_offset | 22 |
| bullet_speed | 700 |
| bullet_damage | 5 |
| bullet_lifetime | 0.9 |
| bullet_radius | 3 |
| trail_length | 14 |

### `MachineGun` (Node2D)
- Сигнал `fired`. Экспорты `config`, `bullet_scene`.
- `set_firing(value)`; `_shoot()` спавнит `Bullet` в контейнер `bullets`
  (лимит общий для всех орудий); `_active_bullet_count()`.

### `Bullet` (Node2D)
- `setup(position, direction, config, owner_node)`.
- Движение, lifetime, столкновение со стенами, урон по `combatants`.

### `InputHandler` (RefCounted)
- `get_commands() -> {throttle, brake, steer, fire, restart}`;
  W+S взаимно гасятся; `is_debug_toggle_pressed()`.

### `FollowCamera` (Camera2D)
- `target`, `follow_speed=6`, `use_track_limits`, `margin=40`.
- `set_bounds(rect)`, `snap_to_target()`; плавность `1 - exp(-speed*dt)`.

### `AudioManager` (Node) / `AudioConfig` (Resource)
- Дети `Music`/`Engine`/`SFX`; `_enable_loop` зацикливает WAV.
- `play_fire()`, `play_collision()`, `play_finish()`,
  `set_engine_intensity(0..1)` (питч/громкость двигателя).
- Ресурс: `music/engine/fire/collision/finish`, громкости (music −14 dB,
  sfx −8 dB, engine −16 dB).

### `Track` (Node2D) / `TrackConfig` (Resource)
- Строит границы смещением центральной линии на `track_width/2`
  (выпуклые углы — дуги, вогнутые — митры), создаёт `StaticBody2D` с
  `CollisionPolygon2D` (BUILD_SEGMENTS), фон и ленту `Line2D`.
- Запросы: `get_start_position/angle`, `get_bounds`, `get_total_length`,
  `get_closest_segment(point) -> {segment_index, closest_point, t, distance}`,
  `get_progress_along_track(point)`, `is_point_on_track(point, margin)`.
- `TrackConfig`: `track_width=80`, `centerline` (8 точек, замкнутый контур),
  текстуры поверхности/фона.

### `Arena` (Node2D) / `ArenaConfig` (Resource)
- Прямоугольная арена: пол (цвет или текстура) + сетка, 4 стены и препятствия
  как `StaticBody2D` + `RectangleShape2D`.
- `get_bounds()`, `get_obstacles() -> Array[Rect2]`,
  `get_spawn_points(count) -> Array[Vector2]` (до 8 якорей: 4 угла + 4 середины
  сторон с отступом `spawn_margin`), `is_inside(point, margin)`.
- `default_arena.tres`: `size=(1000,800)`, `wall_thickness=20`,
  `spawn_margin=80`, препятствия:
  `(440,340,120,120)`, `(400,180,200,40)`, `(400,580,200,40)`,
  `(180,340,40,120)`, `(780,340,40,120)`, `(300,480,120,40)`,
  `(580,280,120,40)`.

### `Game` (Node2D) — координатор гонки
- Экспорт `spawn_bots`. Настраивает `BotController` (track + target=игрок),
  рестарт `R`, `Esc` → меню. `spawn_bots=false` удаляет ботов.

### `Survival` (Node2D) — координатор дерби
- Экспорты: `bot_scene: PackedScene`, `starting_enemies=2`, `max_enemies=6`,
  `round_end_delay=2.0`.
- `start_round(n)`: чистит пули/врагов, ставит игрока на `spawns[0]`, добавляет
  в `combatants`, спавнит `_enemy_count()` ботов (`min(starting+n-1, max)`),
  сообщение «РАУНД n». Враг = `Vehicle` + дочерний `ArenaBot` (arena), цвет из
  `BOT_COLORS` (6 цветов), поворот на игрока.
- `_on_vehicle_died`: смерть игрока → поражение; иначе удаление из списка, и
  если живых врагов нет → победа.
- `R` — рестарт с 1-го раунда, `Esc` — меню.

### `BotController` (Node) — ИИ гонки
- Едет по центральной линии: `_lookahead_point(from, distance)` идёт вперёд по
  сегментам, `steer = clamp(heading_error * steer_gain)`.
- Экспорты: `track`, `target`, `cruise_throttle=0.9`, `lookahead=110`,
  `ease_angle=0.5`, `brake_angle=1.2`, `steer_gain=2.5`;
  восстановление: `stuck_speed=20`, `stuck_timeout=1.5`, `reverse_duration=0.9`;
  бой: `fire_range=450`, `fire_angle=0.2`.
- `setup(track, target)`, `get_commands(delta)`, `reset()`.

### `ArenaBot` (Node) — боевой ИИ дерби
- `_choose_target()` — ближайший живой `combatant` (не только игрок).
- Стремится к цели, слегка тормозит ближе `preferred_range=240`, рулит с
  объездом препятствий/стен (репульсия): `avoid_radius=90`, `avoid_weight=1.6`,
  `wall_avoid_margin=70`.
- Экспорты: `arena`, `cruise_throttle=0.9`, `steer_gain=2.5`, `ease_angle=0.5`,
  `brake_angle=1.3`, `preferred_range=240`, `fire_range=420`, `fire_angle=0.22`,
  `stuck_speed=20`, `stuck_timeout=1.2`, `reverse_duration=0.8`.

### `MainMenu` (Control)
- Кнопки: `RaceButton`, `SurvivalButton`, `SettingsButton`, `QuitButton`;
  панель `SettingsPanel` со слайдером громкости Master (`AudioServer`, инд. 0)
  и чекбоксом полноэкранного режима (`DisplayServer`), `BackButton`.
- Переходы: Гонка → `Main.tscn`, Выживание → `ArenaBattle.tscn`.

### `ArenaHUD` (CanvasLayer)
- `update_status(player, enemies, round)`, `show_message(text, duration)`.
- Показывает «ВЫЖИВАНИЕ — РАУНД n», `HP: cur / max`, «Врагов», FPS, баннеры.

---

## 7. Управление (Input Map, `project.godot`)

| Действие | Клавиши |
| --- | --- |
| `accelerate` | W / ↑ |
| `brake` | S / ↓ |
| `steer_left` | A / ← |
| `steer_right` | D / → |
| `fire` | Ctrl / Space |
| `restart` | R |
| `toggle_debug` | F1 |
| `ui_cancel` (встроенное) | Esc — выход в меню |

---

## 8. Тесты

`tests/*.gd` — самостоятельные `SceneTree`-скрипты (запуск через `--script`).

| Тест | Что проверяет |
| --- | --- |
| `vehicle_smoke` | физика машины |
| `track_smoke` | геометрия/стены трека |
| `assets_smoke` | наличие текстур/звуков/анимаций |
| `game_smoke` | гонка: движение, камера, границы |
| `controls_smoke` | привязки WASD, разгон/торможение/руль/W+S |
| `weapon_smoke` | пули: спавн, движение, лимит, время жизни |
| `menu_smoke` | меню: кнопки, настройки, переход «Гонка» |
| `bot_smoke` | ИИ гонки: движение по трассе, огонь по цели |
| `arena_smoke` | арена: bounds, препятствия, спавны, коллизии |
| `survival_smoke` | спавн врагов, урон, смерть, раунды, поражение |
| `derby_smoke` | таранный урон между машинами |

**Особенности тестов:**
- Группы (`get_nodes_in_group`) доступны только на первом кадре `_process`
  (Godot откладывает `_ready` при `add_child`), поэтому многие тесты ищут узлы
  в `_process`, а не в `_initialize`.
- Тесты, грузящие `Main.tscn`, ставят `_game.spawn_bots = false` для
  детерминизма; `survival_smoke`/`derby_smoke` отключают ИИ и орудия врагов.
- Предупреждения `ObjectDB instances leaked` / `resources still in use` в конце
  — известное поведение headless, не провал теста.

---

## 9. Известные подводные камни (важно для новой команды)

1. **`pkill -f Godot_v4.7.2`** матчит и убивает собственную командную оболочку
   (строка запуска содержит путь бинарника). Используйте трюк со скобками
   (`pkill -f "[G]odot_v4.7.2"`) в отдельной команде или `kill <pid>`.
2. **Новые `class_name`** регистрируются в
   `.godot/global_script_class_cache.cfg` только после
   `--headless --path <proj> --import`. Без этого GDScript-парсер не видит тип.
3. **Порядок групп**: в `_initialize`/`_ready` при `add_child` карта групп ещё
   пуста — запрашивайте группы в `_process`.
4. **`Vehicle.moment`** задан фиксированным (180000), хотя в комментарии
   сказано, что 0 = авторасчёт.
5. **README** в корне репозитория упоминает «Godot 4.3», фактически проект 4.7.2.

---

## 10. Технический долг / что не реализовано

- **Финиш гонки**: нет подсчёта кругов и завершения заезда (есть только
  `Track.get_progress_along_track` и разметка финиша).
- **Счёт/рекорды**, таблица лидеров, пауза, сохранение прогресса.
- **Настройки меню не сохраняются** между запусками (нужен `ConfigFile`).
- **Звук**: `AudioManager.play_collision()` и `play_finish()` не вызываются;
  выстрелы ботов не озвучены (подключено только орудие игрока).
- **Попадания** пуль определяются по кругу (расстояние), а не по форме; нет
  эффектов/искр; нет урона от удара о стены.
- **ИИ**: объезд препятствий — репульсия без рейкастов, возможны застревания
  (есть авто-реверс); боты не выбирают укрытия и не перезаряжаются.
- **Лимит пуль** общий для всех орудий (`max_active_bullets`).
- **Локализация**: меню/боевой HUD на русском, отладочный HUD — на английском.
- Только одна арена и один трек по умолчанию; нет выбора уровня.

---

## 11. Точки расширения (рекомендации следующей команде)

1. **Треки/арены как данные**: продублировать `iron_circuit.tres` /
   `default_arena.tres`, добавить выбор уровня в меню.
2. **Новые враги**: дублировать `VehicleConfig` (скорость, HP, урон) и/или
   добавить вторую сцену с другим оружием (`WeaponConfig`).
3. **Волны/сложность**: расширить `Survival` (интервалы, боссы, призы).
4. **Прогресс гонки**: реализовать подсчёт кругов через
   `get_progress_along_track` + индикатор в `DebugHUD`, завершение заезда.
5. **Пауза/меню паузы**: отдельная сцена `CanvasLayer` c `get_tree().paused`.
6. **Сохранение настроек**: `ConfigFile` в `user://` (громкость, fullscreen).
7. **Боевые эффекты**: вспышка попадания (анимация уже есть), звук
   `play_collision`, «взрыв» при `died`.
8. **Сетевой мультиплеер**: контракт `apply_control` уже отделяет ввод от
   физики — удобно для синхронизации команд.
9. **Рефакторинг урона**: вынести боевую логику из `Vehicle` в `Health`
   компонент/`damage`-модуль (в духе TDD-прототипа).

---

## 12. Соответствие Python-прототипу

Проект — порт Python/Pymunk-прототипа (каталоги `src/`, `AI/` в корне
репозитория). Сохранены:
- модель «танк-lite» физики (`Vehicle`);
- сегментные стены трека (`Track`);
- контракт команд и разделение данные/логика.

Отличия Godot-версии: добавлены полноценные сцены/ресурсы, режим дерби,
здоровье/урон/таран, боевой ИИ, меню и настройки.

---

_Дата создания паспорта: 2026 (актуально для состояния проекта на момент
последнего коммита). Документ дополнять по мере развития._
