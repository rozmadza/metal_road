# Metal Road — матрица функциональности

Статусы: READY — подтверждено тестами; IMPLEMENTED — есть в коде, но покрытие неполное; PARTIAL — часть цикла; PROTOTYPE — визуальная/ограниченная версия; MISSING — не найдено.

| Система | Статус | Что работает | Что отсутствует/ограничено | Подтверждение |
|---|---|---|---|---|
| Главное меню и переходы | READY | меню, режимы, настройки, возврат | визуальный manual smoke не автоматизирован полностью | `scripts/main_menu.gd`, `tests/menu_smoke.gd` |
| Race | READY | старт, 3 круга, прогресс, позиции, бой, DNF, результаты, retry | ограниченный набор трасс в основном цикле | `scripts/game.gd`, `tests/race_finish_smoke.gd` |
| Survival | READY | волны, 5 стартовых врагов, рост до 6, смерть, Arbiter, HUD | длительный баланс и ручной playthrough не подтверждены | `scripts/survival.gd`, `tests/survival_smoke.gd` |
| Физика машины | READY | RigidBody2D, инерция, торможение/реверс, speed-scaled steering, grip, handbrake | не полноценная tire model | `scripts/vehicle.gd`, `tests/rolling_steering_smoke.gd` |
| Повреждения | READY | body/engine/wheels, сопротивление, ремонт колёс, визуальные стадии | persistence damage между матчами не нужна/не реализована | `scripts/vehicle_damage.gd`, `tests/damage_modules_smoke.gd` |
| Оружие | READY | 9 конфигураций, пули, ракеты, мины, огонь, EMP, shotgun | баланс и все комбинации friendly-fire требуют ручной проверки | `resources/weapons/`, `scripts/bullet.gd`, `tests/weapon_smoke.gd` |
| AI Race | IMPLEMENTED | движение по траектории и столкновения | сложные тактики/обгон ограничены | `scripts/bot_controller.gd` |
| AI Survival | READY | поиск цели, steering, obstacle navigation, стрельба, recovery | застревание в редких динамических конфликтах требует soak | `scripts/arena_bot.gd`, `tests/arena_bot_navigation_integration.gd` |
| Арены | READY | ArenaConfig, стены, препятствия, hazards, supply hotspots, биомы | разнообразие проверено в основном smoke, не полноценным матчем каждого биома | `scripts/arena.gd`, `resources/*arena.tres` |
| Гараж/автомобили | IMPLEMENTED | каталог, выбор, preview, классы, улучшения | прогрессия и баланс не являются полной экономической кампанией | `scripts/garage.gd`, `resources/vehicle_catalog.tres` |
| Career | IMPLEMENTED | события, первый сюжетный эпизод, диалоги, награды | сюжет полноценно раскрыт не для всех событий | `scripts/career*.gd`, `tests/career_story_smoke.gd` |
| Сохранения | IMPLEMENTED | profiles/loadout/settings, recovery smoke | повреждение реального user-файла вручную не проверено | `scripts/player_profile.gd`, `tests/profile_recovery_smoke.gd` |
| Аудио | IMPLEMENTED | музыка, двигатель, fire/collision/finish/explosion, UI SFX | полнота микса и длительное переключение сцен требуют ручной проверки | `scripts/audio_manager.gd`, `tests/audio_smoke.gd` |
| Камера/VFX | IMPLEMENTED | follow, zoom, shake, smoke/fire/sparks, tire tracks | release budget test сейчас падает на `VFX budget cap` | `scripts/camera.gd`, `scripts/combat_vfx.gd`, `tests/release_candidate_smoke.gd` |

