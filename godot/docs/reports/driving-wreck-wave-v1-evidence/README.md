# Driving / Wreck / Wave Recovery v1 evidence

Все PNG сняты настоящим Godot/OpenGL, без дорисовки игровых объектов. comparison-1280/800 только компоновка кадров before/after при нативном масштабе. .gdignore исключает evidence из production-импорта. Временные fixtures здесь сохранены с .txt.

- regressions-final: окончательный последовательный runner19/19; regressions — предварительная серия.
- extra: дополнительные23теста, каждый завершён без GDScript/Parse/тестовых FAIL.
- reverse-before-final.log и reverse-after-accepted.log: принятые измерения12сценариев; JSON и reverse-table.md рядом. Другие reverse-логи показывают промежуточные ошибки тестового ввода/неподходящего порога. Они не подменяют окончательные результаты.
- wave-recovery-accepted.log, wreck-layer.log, wreck-accepted.log: новые независимые tests.
- navigation-routes.log: реальные маршруты/скорости/попытки reverse, в том числе8AI.
- gui.log и gui/: реальная проверка кнопок через события ввода, не вызовы pressed.emit.
- before/after-1280/800: collision/HUD PNG и raw performance manifests. Управляемые состояния, AI заморожены; это не естественное прохождение.
- prototype/: изолированный RigidBody sandbox, не production Survival.
- preserved-sha256.json: неизменность существующих weapon configs/graphics, AI, navigation, bonus, default arena и perks.

Запуск штатных headless-проверок в чистом снимке принятого рабочего дерева:

```bash
bash tests/run_vehicle_catalog_regressions.sh /absolute/project/path /absolute/log/path
flatpak run --filesystem=/absolute/project/path org.godotengine.Godot --headless --path /absolute/project/path --script res://tests/driving_reverse_response_smoke.gd
flatpak run --filesystem=/absolute/project/path org.godotengine.Godot --headless --path /absolute/project/path --script res://tests/survival_full_wave_recovery_smoke.gd
flatpak run --filesystem=/absolute/project/path org.godotengine.Godot --headless --path /absolute/project/path --script res://tests/wreck_layer_smoke.gd
flatpak run --filesystem=/absolute/project/path org.godotengine.Godot --headless --path /absolute/project/path --script res://tests/movable_wreck_prototype_smoke.gd
```

Для baseline reverse-response тот же тест запускается с `-- --baseline` в исходном снимке, включающем принятые Rocket v3 и MG/Heavy до текущей задачи. Это не исходный HEAD9591463, поскольку принятая оружейная база ещё незакоммичена. Нельзя использовать HEAD как якобы идентичный before.

Shutdown ObjectDB/resources warnings сохранены; они не скрываются проверкой PASS и не доказывают новую runtime-утечку. Производительность в manifests — короткий60FPS fixture с фоновыми regression-процессами, не изолированная GPU-оценка.
