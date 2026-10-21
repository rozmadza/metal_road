# Development audit — 2026-09-21

## 1. Current State
Sprint 1: два режима, один Sport, MachineGun, runtime Body/Engine/Wheels,
GPU damage FX, базовая Theme и audio buses. Меню — плоский фон и 4 кнопки.
Повторный baseline: 15/15 smoke tests, exit 0 (логи baseline-logs/).
Изучены сцены, связанные скрипты, Config/tres, существующие тесты и Sprint Report.
Race HUD получает Game.vehicle каждый кадр, ModuleStatus читает damage.ratio.
Причина неизменных HP при стрельбе в Race: отсутствие combatants, не статический HUD.
Впереди отдельный regression test источника HUD и единый combat в фазах B/C.
Git: проект уже untracked до начала этой работы; чужие файлы не удаляются.

## 2. Reusable Systems
Vehicle/apply_control/damage; MachineGun; Game/Survival; Theme; AudioConfig;
UI bus; ресурсы default_vehicle/default_machine_gun; стабильные unique node names.

## 3. Required Refactoring
Только композиция главного меню, локальный UI audio component и новые слоты
в AudioConfig. Нет изменения физики, игровых контрактов или HUD в Phase A.
IndustrialButton variation общей Theme изолирует крупные кнопки от игрового HUD.

## 4. New Scenes
MenuBackdrop — фон + gradient/vignette; UISounds — подключение UI сигналов;
Garage — действующий осмотр текущего автомобиля/оружия и запуск режимов.
Выбор, покупки и апгрейды остаются F–H; никакой фиктивной экономики в UI.

## 5. New Resources
menu_audio.tres на существующем AudioConfig; menu overlay shader/material;
IndustrialButton variation в существующей Theme. Никакого нового глобального manager.

## 6. New Assets
Кинематографический industrial derby background и отдельный alpha metal logo
через imagegen. Два оригинальных синтезированных UI WAV, воспроизводимый генератор.

## 7. New Tests
menu_visual_smoke: assets, states, focus, settings, звуковые сигналы/отключение;
garage_smoke: переход, runtime config stats/preview, возвращение в меню.
Оконный review 800×600 и 1280×720, settings и Garage; весь старый suite.

## 8. Risks
Alpha/типографика логотипа, контраст фона, crop при смене aspect ratio;
click звук при смене сцены; headless audio teardown (известно из baseline).
Гараж Phase A должен оставаться полезным осмотром, не обещать доступные покупки.
Новая музыка и full SFX относятся к I. Старые настройки ещё не сохраняются.

## 9. Roadmap
A: меню + доступный Garage → визуальная и тестовая проверка → отчёт.
B: компактный HUD + regression. C: общий combat и политика respawn.
D: машины/damage states. E: props/oil/barrels. F: loadout.
G: Credits/rewards/save. H: upgrades. I: music/audio. J: VFX/polish.
После Phase A остановиться для review, не расширять объём автоматически.
