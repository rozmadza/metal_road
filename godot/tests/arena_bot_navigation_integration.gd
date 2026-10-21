extends SceneTree
## Measures visible steering reversals during a real arena pursuit.

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game := (load("res://scenes/ArenaBattle.tscn") as PackedScene).instantiate() as Survival
	root.add_child(game)
	await process_frame
	game._clear_enemies()
	await process_frame
	var durable := game.player.config.duplicate() as VehicleConfig
	durable.max_health = 50000.0
	durable.engine_health = 50000.0
	durable.wheels_health = 50000.0
	game.player.reconfigure(durable)
	game.player.freeze = true
	var bot := game._spawn_bot(game.arena.get_spawn_points(2)[1], 0)
	var start := bot.global_position
	var max_travel := 0.0
	var steer_flips := 0
	var last_sign := 0.0
	for frame in 720:
		await physics_frame
		if not is_instance_valid(bot) or not bot.alive:
			break
		max_travel = maxf(max_travel, start.distance_to(bot.global_position))
		if bot.get_speed() > 35.0 and absf(bot.steer) > 0.55:
			var current_sign := signf(bot.steer)
			if last_sign != 0.0 and current_sign != last_sign:
				steer_flips += 1
			last_sign = current_sign
	print("ARENA NAV distance=", max_travel, " steer_flips=", steer_flips)
	check(is_instance_valid(bot) and bot.alive, "car survives its route around arena cover")
	check(max_travel > 100.0, "car continues the pursuit")
	check(steer_flips <= 8, "car does not zigzag through repeated hard steering reversals")
	game.free()
	await process_frame
	print("ARENA BOT NAVIGATION: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	if ok:
		print("ARENA BOT NAVIGATION ok: ", label)
	else:
		failures += 1
		printerr("ARENA BOT NAVIGATION FAIL: ", label)
