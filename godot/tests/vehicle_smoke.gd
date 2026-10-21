extends SceneTree
## Headless smoke test: verifies the tank-lite physics accelerate the vehicle.

var _vehicle: Vehicle
var _frames := 0


func _initialize() -> void:
	var config: VehicleConfig = load("res://resources/default_vehicle.tres")
	_vehicle = Vehicle.new()
	_vehicle.config = config
	root.add_child(_vehicle)


func _process(_delta: float) -> bool:
	_frames += 1
	_vehicle.apply_control(1.0, 0.0, 0.0)
	if _frames == 120:
		var speed := _vehicle.get_speed()
		var forward := _vehicle.get_forward_speed()
		print("SMOKE: speed=%.1f forward=%.1f" % [speed, forward])
		var ok := speed > 50.0 and forward > 0.0
		print("SMOKE: %s" % ("PASS" if ok else "FAIL"))
		_vehicle.free()
		quit(0 if ok else 1)
		return true
	return false
