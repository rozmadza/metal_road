extends SceneTree
## Windowed composition helper for reviewing the exclusive squad and Arbiter.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	CareerSession.clear_selection()
	change_scene_to_file("res://scenes/ArenaBattle.tscn")
	await scene_changed
	await process_frame
	var game := current_scene as Survival
	game.start_round(5)
	game._spawn_referee()
	await process_frame
	await physics_frame
	# Wave spawn points are already validated against obstacle geometry, so use
	# the boss spawn as the center of this inspection composition.
	var center := game._boss.global_position
	game.player.freeze = true
	game.player.global_position = center + Vector2(-170.0, 0.0)
	game.player.rotation = 0.0
	var positions := [
		center + Vector2(35.0, 0.0),
		center + Vector2(15.0, -105.0),
		center + Vector2(15.0, 105.0),
		center + Vector2(150.0, -5.0),
		center + Vector2(150.0, 95.0),
	]
	for index in game._enemies.size():
		var enemy := game._enemies[index]
		enemy.freeze = true
		enemy.global_position = positions[index]
		enemy.rotation = PI if index == 0 else 0.0
		var ai := enemy.get_node_or_null("ArenaBot") as ArenaBot
		if ai != null: ai.set_physics_process(false)
		var referee := enemy.get_node_or_null("RefereeBoss") as RefereeBoss
		if referee != null: referee.set_physics_process(false)
	game.camera.target = game._boss
	game.camera.resting_zoom = 1.58
	game.camera.maximum_speed_zoom = 1.58
	game.camera.snap_to_target()
	game.hud.show_message("ЦЕРБЕР · ЭЛИТНЫЙ ЭСКОРТ     АРБИТР · БОСС-РЕФЕРИ", 8.0)
	game.hud.update_status(game.player, game._alive_enemies(), 5, 0, {
		"scenario": "СУД АРБИТРА", "score": 0, "combo": 0, "boss": game._boss,
	})
