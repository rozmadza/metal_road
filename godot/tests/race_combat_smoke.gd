extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("RACE COMBAT FAIL: ", label)
func run() -> void:
	var game: Game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.1).timeout
	game.set_physics_process(false)
	for bot in game._bots: bot.set_physics_process(false)
	var p := game.vehicle
	var a: Vehicle = game.participants[1]
	var b: Vehicle = game.participants[2]
	check(game.participants.size() == 6, "six participants")
	for car in game.participants:
		check(car.is_in_group("combatants"), "combat membership")
		car.freeze = true
		car.gun.set_firing(false)
	for pair in [[p, a], [a, p], [a, b]]:
		game._clear_bullets()
		for car in game.participants: car.position = Vector2(600, 400)
		var shooter: Vehicle = pair[0]
		var target: Vehicle = pair[1]
		shooter.position = Vector2(300, 150)
		shooter.rotation = 0
		target.position = Vector2(440, 150)
		var before := target.health
		var self_before := shooter.health
		shooter.gun._shoot()
		await create_timer(0.25).timeout
		check(target.health < before, "real projectile %s -> %s" % [shooter.name, target.name])
		check(shooter.health == self_before, "shooter immunity")
	check(game.damage_dealt[p] > 0 and game.damage_dealt[a] > 0, "actual damage attribution")
	game._clear_bullets()
	b.position = Vector2(600, 400)
	p.reset_to(Vector2(320, 150), 0)
	a.reset_to(Vector2(460, 150), PI)
	await create_timer(0.1).timeout
	p.linear_velocity = Vector2(300, 0)
	a.linear_velocity = Vector2(-300, 0)
	await create_timer(0.6).timeout
	check(p.health < p.config.max_health or a.health < a.config.max_health, "physical ram damage")
	a.take_damage(1000, &"body", p)
	a.apply_control(1, 0, 1, true)
	await process_frame
	check(game.race_status[a] == &"DNF" and not a.alive, "death becomes DNF")
	check(a.freeze and a.collision_layer == 0 and not a.is_in_group("combatants"), "dead physics/group")
	check(a.throttle == 0 and not a.fire and not a.gun.is_physics_processing(), "dead input and weapon")
	check(game.kills[p] == 1, "kill attribution")
	await create_timer(0.2).timeout
	check(not a.alive, "no auto respawn")
	game._reset_race()
	check(a.alive and game.race_status[a] == &"RACING" and a.is_in_group("combatants"), "retry restores lifecycle")
	check(game.kills[p] == 0 and game.damage_dealt[p] == 0, "retry clears stats")
	game.track.config = game.track.config.duplicate()
	game.track.config.combat_enabled = false
	game._reset_race()
	for car in game.participants: check(not car.is_in_group("combatants"), "optional noncombat")
	game.free()
	print("RACE COMBAT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
