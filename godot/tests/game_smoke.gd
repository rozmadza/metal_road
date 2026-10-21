extends SceneTree
## Headless smoke test for the full Main scene: scene wiring + physics + walls.

var _game: Node
var _frames := 0


func _initialize() -> void:
	_game = load("res://scenes/Main.tscn").instantiate()
	_game.spawn_bots = false
	root.add_child(_game)


func _process(_delta: float) -> bool:
	_frames += 1
	Input.action_press("accelerate")
	if _frames < 240:
		return false

	Input.action_release("accelerate")
	var vehicle: Vehicle = _game.get_node("Vehicle")
	var pos := vehicle.global_position
	var speed := vehicle.get_speed()
	print("GAME: pos=(%.0f, %.0f) speed=%.1f" % [pos.x, pos.y, speed])

	var failures := 0
	failures += _check(speed > 50.0, "vehicle is moving")
	failures += _check(pos.x > 90.0 and pos.x < 710.0, "x within track bounds")
	failures += _check(pos.y > 90.0 and pos.y < 510.0, "y within track bounds")
	failures += _check(_game.get_node("Camera").global_position.distance_to(pos) < 145.0, "camera follows with a bounded speed look-ahead")

	print("GAME: %d failures" % failures)
	print("GAME: %s" % ("PASS" if failures == 0 else "FAIL"))
	_game.free()
	quit(0 if failures == 0 else 1)
	return true


func _check(condition: bool, label: String) -> int:
	if not condition:
		print("GAME FAIL: ", label)
		return 1
	return 0
