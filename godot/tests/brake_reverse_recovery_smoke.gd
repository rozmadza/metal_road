extends SceneTree

class BlockedDriver extends ArenaBot:
	func _update_intent(_delta: float) -> void:
		pass
	func _update_path(_delta: float) -> void:
		pass

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("BRAKE/RECOVERY FAIL: ", message)

func run() -> void:
	var car := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	root.add_child(car)
	car.linear_velocity = Vector2(car.config.max_speed, 0)
	var stop_time := -1.0
	var reverse_time := -1.0
	var early_speed := 0.0
	for frame in 180:
		car.apply_player_control(0.0, 1.0, 0.0, false, 1.0 / 60.0)
		await physics_frame
		var elapsed := float(frame + 1) / 60.0
		if frame == 17: early_speed = car.get_forward_speed()
		if stop_time < 0.0 and car.get_speed() <= 2.0: stop_time = elapsed
		if reverse_time < 0.0 and car.get_forward_speed() < -2.0: reverse_time = elapsed
	check(early_speed > 80.0, "full-speed braking retains momentum after 0.3 seconds")
	check(stop_time > 0.7, "braking has a progressive stopping interval")
	check(reverse_time > stop_time + 0.3, "reverse begins only after a stationary gear-change pause")
	check(reverse_time > 0.0, "holding brake eventually engages reverse")
	print("BRAKE timing: stop=", stop_time, " reverse=", reverse_time, " speed at 0.3s=", early_speed)
	car.apply_player_control(0.0, 0.0, 0.0, false, 1.0 / 60.0)
	check(not car._player_reverse, "releasing brake clears reverse selection")
	car.free()

	var bot_car := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	root.add_child(bot_car)
	bot_car.freeze = true
	var driver := BlockedDriver.new()
	bot_car.add_child(driver)
	driver.set_physics_process(false)
	driver._intent_goal = Vector2(30, 0)
	driver._path = PackedVector2Array([driver._intent_goal])
	var recovered := false
	for frame in 100:
		var commands := driver.get_commands(1.0 / 60.0)
		if commands.throttle < 0.0: recovered = true
	check(recovered, "stalled bot initiates recovery even within 70 pixels of its goal")
	bot_car.free()
	var sleeper := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	root.add_child(sleeper)
	sleeper.sleeping = true
	sleeper.apply_control(0.7, 0.0, 0.0)
	for frame in 20:
		await physics_frame
	check(sleeper.get_speed() > 5.0, "throttle wakes a sleeping car and produces motion")
	sleeper.free()
	print("BRAKE/RECOVERY: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
