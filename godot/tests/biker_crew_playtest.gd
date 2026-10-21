extends SceneTree
## Playable QA entry point for the Referee biker squad and fleeing crew.
## It deliberately skips the regular wave so both mechanics can be inspected
## immediately without changing production progression.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	CareerSession.clear_selection()
	change_scene_to_file("res://scenes/ArenaBattle.tscn")
	await scene_changed
	await process_frame
	var game := current_scene as Survival
	game.start_round(5)
	game._clear_enemies()
	await process_frame

	var center := game.arena.get_bounds().get_center()
	# QA-only durability keeps the staged encounter alive long enough to inspect;
	# production vehicle balance is untouched.
	var qa_player_config := game.player.config.duplicate() as VehicleConfig
	qa_player_config.max_health = maxf(qa_player_config.max_health, 1800.0)
	qa_player_config.engine_health = maxf(qa_player_config.engine_health, 700.0)
	qa_player_config.wheels_health = maxf(qa_player_config.wheels_health, 700.0)
	qa_player_config.damage_resistance = 0.65
	game.player.reconfigure(qa_player_config)
	game.player.reset_to(center + Vector2(-210.0, 0.0), 0.0)
	var escape_car := game._spawn_bot(center + Vector2(205.0, 0.0), 4)
	escape_car.reconfigure(escape_car.config.duplicate() as VehicleConfig)
	escape_car.damage.body = minf(escape_car.damage.body, 52.0)
	game._round_enemy_total = 1
	game._spawn_referee()
	game._spawn_biker_squad()
	game._biker_deploy_timer = 17.0
	game.camera.snap_to_target()
	game.hud.show_message(
		"QA · АРБИТР И МОТОСТАЯ\nУНИЧТОЖЬТЕ ОБЫЧНУЮ МАШИНУ · ДОГОНИТЕ ЭКИПАЖ",
		4.5
	)
	# Keep the hand-off deterministic: combat starts only when the tester is
	# ready, instead of the AI destroying the staged targets in the background.
	game.hud.pause_overlay.toggle()
	print("BIKER CREW PLAYTEST ready: paused=", paused, " overlay=", game.hud.pause_overlay.visible)
	if OS.has_environment("METAL_QA_AUTOSTART"):
		await process_frame
		game.hud.pause_overlay.resume()
		escape_car.take_damage(9999.0, &"body", game.player)
		if OS.has_environment("METAL_QA_SCALE_SNAPSHOT"):
			await process_frame
			var runners := get_nodes_in_group("escaping_crew")
			for index in runners.size():
				var runner := runners[index] as EscapingCrew
				runner.global_position = game.player.global_position + Vector2(8.0, -34.0 + float(index) * 68.0)
				runner.escape_direction = Vector2.RIGHT
			await create_timer(0.55).timeout
			game.hud.pause_overlay.visible = false
			paused = true
			print("BIKER CREW PLAYTEST scale snapshot ready")
