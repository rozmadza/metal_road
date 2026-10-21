extends SceneTree

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
	durable.damage_resistance = 0.75
	game.player.reconfigure(durable)
	game.player.freeze = true
	game._referee_spawned = false
	game._spawn_referee()
	var boss_start := game._boss.global_position
	game._spawn_biker_squad()
	var boss_max_travel := 0.0
	var tracked_biker: Vehicle = null
	for enemy in game._enemies:
		if bool(enemy.get_meta("biker", false)):
			tracked_biker = enemy
			break
	var steer_flips := 0
	var last_steer_sign := 0.0
	for frame in 720:
		await physics_frame
		if is_instance_valid(game._boss):
			boss_max_travel = maxf(boss_max_travel, boss_start.distance_to(game._boss.global_position))
		if is_instance_valid(tracked_biker) and tracked_biker.alive and tracked_biker.get_speed() > 35.0:
			var steer_sign := signf(tracked_biker.steer) if absf(tracked_biker.steer) > 0.55 else 0.0
			if steer_sign != 0.0:
				if last_steer_sign != 0.0 and steer_sign != last_steer_sign:
					steer_flips += 1
				last_steer_sign = steer_sign

	print("NAV RESULT riders=", game._alive_biker_count(), " boss_distance=", boss_max_travel, " biker_steer_flips=", steer_flips)
	check(game._alive_biker_count() >= 5, "most riders survive twelve seconds without player contact")
	check(boss_max_travel >= 70.0, "Referee escapes cover and continues hunting")
	check(steer_flips <= 8, "riders avoid repeated hard steering reversals")

	game.free()
	await process_frame
	print("BIKER BOSS NAVIGATION: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	if ok:
		print("BIKER BOSS NAVIGATION ok: ", label)
	else:
		failures += 1
		printerr("BIKER BOSS NAVIGATION FAIL: ", label)
