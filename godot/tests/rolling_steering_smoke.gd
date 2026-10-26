extends SceneTree

var failures := 0
var lane := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("ROLLING STEERING FAIL: ", label)

func car() -> Vehicle:
	var value := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	root.add_child(value)
	lane += 1
	value.position = Vector2(0, lane * 1000)
	return value

func yaw_at(speed: float, steering: float) -> float:
	var value := car()
	value.apply_control(0.0, 0.0, steering)
	for frame in 45:
		value.linear_velocity = Vector2.RIGHT.rotated(value.rotation) * speed
		await physics_frame
	var yaw := value.angular_velocity
	value.free()
	return yaw

func run() -> void:
	for direction in [-1.0, 1.0]:
		check(absf(await yaw_at(0.0, direction)) < 0.001, "stationary car cannot steer its body")
		check(absf(await yaw_at(1.0, direction)) < 0.001, "near-zero rolling speed cannot steer its body")
	var slow := await yaw_at(6.0, 1.0)
	var medium := await yaw_at(60.0, 1.0)
	var fast := await yaw_at(160.0, 1.0)
	check(slow > 0.0 and slow < medium * 0.1, "slow rolling produces only a small turn")
	check(medium > 0.5 and fast < medium * 0.7, "high-speed steering is gentler than medium-speed steering")
	check(await yaw_at(-60.0, 1.0) < -0.5, "reverse changes the sign of steering")
	var value := car()
	value.linear_velocity = Vector2(140, 0)
	value.apply_control(0.0, 0.0, 0.5)
	for frame in 15: await physics_frame
	check(value.get_speed() > 60.0 and value.angular_velocity > 0.1, "coasting retains momentum and steering without throttle")
	var peak_jump := 0.0
	var previous_yaw := value.angular_velocity
	for frame in 60:
		value.apply_control(0.0, 0.0, -1.0 if frame % 12 < 6 else 1.0)
		await physics_frame
		peak_jump = maxf(peak_jump, absf(value.angular_velocity - previous_yaw))
		previous_yaw = value.angular_velocity
	check(peak_jump < 0.5, "rapid steering changes do not cause angular velocity jumps")
	value.apply_control(0.0, 0.0, 0.0)
	for frame in 300: await physics_frame
	check(absf(value.angular_velocity) < 0.01, "releasing steering smoothly ends active turning")
	value.apply_control(0.0, 0.0, 1.0)
	for frame in 120: await physics_frame
	check(value.get_speed() < 1.5 and absf(value.angular_velocity) < 0.01, "steering stops after coasting to rest")
	value.free()
	var impact_car := car()
	var wall := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 400)
	collision.shape = shape
	wall.add_child(collision)
	root.add_child(wall)
	wall.position = impact_car.position + Vector2(120, 0)
	var contacts := [0]
	impact_car.body_entered.connect(func(body):
		if body == wall: contacts[0] += 1)
	impact_car.linear_velocity = Vector2(150, 0)
	impact_car.apply_control(0.7, 0.0, 0.0)
	for frame in 90: await physics_frame
	check(contacts[0] > 0 and is_finite(impact_car.angular_velocity), "actual wall contact remains physically stable")
	var impact_position := impact_car.position
	impact_car.apply_control(-0.6, 0.0, 0.3)
	for frame in 90: await physics_frame
	check(impact_car.position.distance_to(impact_position) > 15.0, "car can steer and reverse away after wall contact")
	impact_car.free()
	wall.free()
	print("ROLLING STEERING: ", "PASS" if failures == 0 else "FAIL", " yaw slow/medium/fast=", slow, "/", medium, "/", fast)
	quit(0 if failures == 0 else 1)
