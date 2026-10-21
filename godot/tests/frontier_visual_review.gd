extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var mode := OS.get_environment("FRONTIER_REVIEW")
	if mode == "arena" or mode == "default_arena":
		CareerSession.select_event(&"scrapyard_contract" if mode == "default_arena" else &"oil_cauldron")
		PreRaceSetup.request_mode(&"survival")
		change_scene_to_file("res://scenes/ArenaBattle.tscn")
		await scene_changed
		await process_frame
		var survival := current_scene as Survival
		if survival.arena.weather != null: survival.arena.weather.force_storm(true)
		survival.player.freeze = true
		for enemy in survival._enemies: enemy.freeze = true
	else:
		CareerSession.select_event(&"frontier_express")
		PreRaceSetup.request_mode(&"race")
		change_scene_to_file("res://scenes/Main.tscn")
		await scene_changed
		await process_frame
		var game := current_scene as Game
		game._countdown_remaining = 0.0
		if game.track.weather != null: game.track.weather.force_storm(true)
		game.vehicle.freeze = true
		for bot in game._bots: (bot.get_parent() as Vehicle).freeze = true
		game.camera.zoom = Vector2(0.86, 0.86)
