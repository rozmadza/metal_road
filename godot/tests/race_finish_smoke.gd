extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("RACE FINISH FAIL: ", label)
func run() -> void:
	var original_loadout := LoadoutProfile.read_ids()
	LoadoutProfile.save_ids(&"raider", &"machine_gun")
	change_scene_to_file("res://scenes/Main.tscn")
	await scene_changed
	var game: Game = current_scene
	await create_timer(0.1).timeout
	game.set_physics_process(false)
	for bot in game._bots: bot.set_physics_process(false)
	for car in game.participants: car.freeze = true
	var p := game.vehicle
	var bot: Vehicle = game.participants[1]
	var initial_position := game.get_race_position(p)
	check(initial_position == 6, "initial progress ranking")
	p.position = point_at(game.track, 20.0)
	game.progress.advance(p, 1.0 / 60)
	p.position = point_at(game.track, 90.0)
	game.progress.advance(p, 1.0 / 60)
	p.position = point_at(game.track, 175.0)
	game.progress.advance(p, 1.0 / 60)
	check(game.get_race_position(p) <= 3, "ranking updates after overtaking three racers")
	# Complete actual sampled laps through the same physics coordinator API.
	game._reset_race()
	game.set_physics_process(false)
	for driver in game._bots: driver.set_physics_process(false)
	for car in game.participants:
		car.freeze = true
		car._pending_reset = false
	var length := game.track.get_total_length()
	p.take_damage(45.0)
	p.take_damage(20.0, &"engine")
	for lap in range(3):
		for i in range(1, 201):
			p.position = point_at(game.track, length * i / 200.0 + 0.1)
			game._physics_process(1.0 / 60)
		check(p.damage.ratio(&"body") == 1.0 and p.damage.ratio(&"engine") == 1.0 and p.damage.ratio(&"wheels") == 1.0, "lap crossing fully repairs all modules")
	check(game.race_over and game.race_status[p] == &"FINISHED", "finish lifecycle")
	check(game.results.visible and game.result.laps == 3, "results shown with 3 laps")
	check(game.result.time > 0 and game.result.position == 1, "result time and rank")
	var final_time := game.elapsed
	game._physics_process(1)
	check(game.elapsed == final_time, "timer stops")
	game.results.get_node("%RetryButton").pressed.emit()
	await process_frame
	check(not game.race_over and not game.results.visible and p.alive and not p.freeze, "Retry fully restores")
	check(game.elapsed == 0 and game.progress.laps(p) == 0, "Retry clears race")
	# Real lethal projectile exercises result creation during Bullet._check_hit.
	for car in game.participants: car.freeze = true
	for index in range(2, game.participants.size()):
		game.participants[index].position = Vector2(600, 400 + index * 20)
	p.position = Vector2(440, 150)
	bot.position = Vector2(300, 150)
	bot.rotation = 0
	bot.gun.config = bot.gun.config.duplicate()
	bot.gun.config.bullet_damage = 100
	bot.gun._shoot()
	await create_timer(0.4).timeout
	check(game.race_over and game.result.status == &"DNF" and game.results.visible, "projectile DNF results")
	game.results.get_node("%GarageButton").pressed.emit()
	await scene_changed
	check(current_scene.scene_file_path == "res://scenes/Garage.tscn", "result Garage action")
	change_scene_to_file("res://scenes/Main.tscn")
	await scene_changed
	game = current_scene
	game.vehicle.take_damage(1000)
	check(game.result.status == &"DNF", "immediate death result")
	game.results.get_node("%MenuButton").pressed.emit()
	await scene_changed
	check(current_scene.scene_file_path == "res://scenes/MainMenu.tscn", "result Menu action")
	current_scene.free()
	LoadoutProfile.save_ids(original_loadout.vehicle, original_loadout.weapon)
	print("RACE FINISH: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func point_at(track: Track, distance: float) -> Vector2:
	var remaining := fposmod(distance, track.get_total_length())
	for i in track.segment_lengths.size():
		if remaining <= track.segment_lengths[i]:
			return track.segments[i] + track.segment_tangents[i] * remaining
		remaining -= track.segment_lengths[i]
	return track.finish_point
