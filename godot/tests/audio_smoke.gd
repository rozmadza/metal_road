extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("AUDIO FAIL: ", label)

func run() -> void:
	var game: Game = load("res://scenes/Main.tscn").instantiate()
	game.spawn_bots = false
	root.add_child(game)
	for bus in ["Music", "Engine", "Weapons", "Impacts", "Environment", "UI"]:
		check(AudioServer.get_bus_index(bus) >= 0, "bus " + bus)
	check(game.vehicle.impacted.is_connected(game.audio.play_collision), "collision routed")
	game.audio.play_collision(0.25)
	var quiet := game.audio._impact.volume_db
	check(game.audio._impact.stream == game.audio.config.collision, "impact stream")
	game.audio._impact_cooldown = 0
	game.audio.play_collision(1)
	check(game.audio._impact.volume_db > quiet, "intensity controls volume")
	game.audio.play_fire()
	check(game.audio._impact != game.audio._sfx, "gun cannot cut off impact")
	game.audio.config = null
	game.audio.play_collision()
	game.camera.shake(10.0, 0.2)
	check(game.camera._shake_time > 0.0, "camera shake trigger")
	await process_frame
	game.free()
	print("AUDIO: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
