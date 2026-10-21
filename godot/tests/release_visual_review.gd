extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var mode := OS.get_environment("RELEASE_REVIEW")
	if mode == "boss":
		CareerSession.select_event(&"grit_boss")
		change_scene_to_file("res://scenes/Main.tscn")
		await scene_changed
		await process_frame
		var game := current_scene as Game
		game.vehicle.freeze = true
		game.boss_vehicle.freeze = true
		game.boss_vehicle.health = game.boss_vehicle.config.max_health * 0.55
		game._update_boss_phase()
		game.camera.zoom = Vector2(1.42, 1.42)
		game.hud.show_banner("БОСС · GRIT · ФАЗА 2", 999.0)
	elif mode == "career":
		change_scene_to_file("res://scenes/Career.tscn")
		await scene_changed
	else:
		change_scene_to_file("res://scenes/MainMenu.tscn")
		await scene_changed
		await process_frame
		(current_scene as MainMenu)._on_settings_pressed()
