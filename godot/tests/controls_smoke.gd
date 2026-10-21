extends SceneTree
## End-to-end WASD test.
##
## Verifies that W/A/S/D are bound to the right actions in the Input Map and
## that pressing them (routed through InputMap, exactly like the engine does)
## drives the vehicle: accelerate, brake, steer and cancel-out.

var _game: Node
var _track: Track
var _vehicle: Vehicle
var _frames := 0
var _phase := 0
var _failures := 0
var _speed_after_accel := 0.0


func _initialize() -> void:
	_game = load("res://scenes/Main.tscn").instantiate()
	_game.spawn_bots = false
	root.add_child(_game)
	_track = _game.get_node("Track")
	_vehicle = _game.get_node("Vehicle")
	_check_bindings()


func _check_bindings() -> void:
	_check(_key_is_bound(KEY_W, "accelerate"), "W bound to accelerate")
	_check(_key_is_bound(KEY_S, "brake"), "S bound to brake")
	_check(_key_is_bound(KEY_A, "steer_left"), "A bound to steer_left")
	_check(_key_is_bound(KEY_D, "steer_right"), "D bound to steer_right")


func _key_is_bound(key: Key, action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false


## Routes a physical key through the InputMap binding into its action.
## (Input.action_press is used instead of synthetic key events because Godot
## only applies one synthetic action event per frame.)
func _key(key: Key, pressed: bool) -> void:
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == key:
				if pressed:
					Input.action_press(action)
				else:
					Input.action_release(action)


func _reset_car() -> void:
	_vehicle.reset_to(_track.get_start_position(), _track.get_start_angle())


func _process(_delta: float) -> bool:
	_frames += 1

	match _phase:
		0:  # hold W
			_key(KEY_W, true)
			_phase = 1
		1:
			if _frames >= 90:
				_speed_after_accel = _vehicle.get_forward_speed()
				_check(_speed_after_accel > 50.0, "W accelerates car (fwd=%.1f)" % _speed_after_accel)
				_key(KEY_W, false)
				_key(KEY_S, true)
				_phase = 2
				_frames = 0
		2:  # hold S: brakes first, then reverses (arcade style)
			if _frames == 25:
				var speed := _vehicle.get_forward_speed()
				_check(speed < _speed_after_accel - 50.0, "S brakes car (fwd=%.1f -> %.1f)" % [_speed_after_accel, speed])
			if _frames >= 120:
				var speed := _vehicle.get_forward_speed()
				_check(speed < -20.0, "S reverses at standstill (fwd=%.1f)" % speed)
				_key(KEY_S, false)
				_reset_car()
				_key(KEY_W, true)
				_phase = 3
				_frames = 0
		3:  # build up speed, then steer right with D
			if _frames >= 60:
				_key(KEY_D, true)
				_phase = 4
				_frames = 0
		4:  # W + D
			if _frames >= 30:
				_check(_vehicle.steer > 0.9, "D steers right (steer=%.1f)" % _vehicle.steer)
				_check(_vehicle.angular_velocity > 0.05, "D rotates car clockwise (ang_vel=%.2f)" % _vehicle.angular_velocity)
				_key(KEY_D, false)
				_reset_car()
				_phase = 5
				_frames = 0
		5:  # build up speed, then steer left with A
			if _frames >= 60:
				_key(KEY_A, true)
				_phase = 6
				_frames = 0
		6:  # W + A
			if _frames >= 30:
				_check(_vehicle.steer < -0.9, "A steers left (steer=%.1f)" % _vehicle.steer)
				_check(_vehicle.angular_velocity < -0.05, "A rotates car counter-clockwise (ang_vel=%.2f)" % _vehicle.angular_velocity)
				_key(KEY_A, false)
				_key(KEY_W, false)
				_key(KEY_S, false)
				_reset_car()
				_phase = 7
				_frames = 0
		7:  # settle with no keys held
			if _frames >= 5:
				_key(KEY_W, true)
				_key(KEY_S, true)
				_phase = 8
				_frames = 0
		8:  # W + S cancel
			if _frames >= 20:
				_check(_vehicle.throttle == 0.0 and _vehicle.brake == 0.0,
					"W+S cancel (throttle=%.1f brake=%.1f)" % [_vehicle.throttle, _vehicle.brake])
				_key(KEY_W, false)
				_key(KEY_S, false)
				_phase = 9
				_frames = 0
		9:
			print("CONTROLS: %d failures" % _failures)
			print("CONTROLS: %s" % ("PASS" if _failures == 0 else "FAIL"))
			_game.free()
			quit(0 if _failures == 0 else 1)
			return true

	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("CONTROLS ok: ", label)
	else:
		_failures += 1
		print("CONTROLS FAIL: ", label)
