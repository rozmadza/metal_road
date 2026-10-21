extends SceneTree
## Deterministic real-physics routes; no career saves or random map layout.

class TestArena extends Arena:
	func _ready() -> void:
		_bounds = Rect2(Vector2.ZERO, Vector2(1500, 900))
		config = ArenaConfig.new()
		config.size = _bounds.size
		for rect in _obstacles:
			var body := StaticBody2D.new()
			var collision := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = rect.size
			collision.shape = shape
			body.position = rect.get_center()
			body.add_child(collision)
			add_child(body)
		var walls := StaticBody2D.new()
		add_child(walls)
		_add_box(walls, Rect2(-20, -20, 1540, 20))
		_add_box(walls, Rect2(-20, 900, 1540, 20))
		_add_box(walls, Rect2(-20, 0, 20, 900))
		_add_box(walls, Rect2(1500, 0, 20, 900))

var failures := 0
var traces: Array = []
var contacts := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(4217)
	for kind in ["car", "bike", "boss"]:
		await scenario(kind, false, false)
		await scenario(kind, true, false)
	await scenario("car", false, true)
	await check_wall_braking()
	check(traces.size() == 7, "all physics scenarios completed")
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var output := "/tmp/metal-road-driving-before.json" if baseline else "/tmp/metal-road-driving-after.json"
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(traces))
	print("DRIVER REGRESSION: ", "PASS" if failures == 0 else "FAIL", " (", failures, ") ", output)
	quit(0 if baseline or failures == 0 else 1)

func scenario(kind: String, obstacle: bool, behind: bool) -> void:
	var world := Node2D.new()
	root.add_child(world)
	var arena := TestArena.new()
	if obstacle:
		arena._obstacles = [Rect2(570, 330, 150, 240)]
	world.add_child(arena)
	var scene := load("res://scenes/Vehicle.tscn") as PackedScene
	var target := scene.instantiate() as Vehicle
	target.config = target.config.duplicate()
	target.config.effects_enabled = false
	target.position = Vector2(180, 450) if behind else Vector2(1250, 450)
	target.freeze = true
	target.collision_layer = 0
	target.collision_mask = 0
	target.set_meta("player_vehicle", true)
	world.add_child(target)
	target.add_to_group("combatants")
	var car := scene.instantiate() as Vehicle
	if kind == "bike":
		car.config = load("res://resources/vehicles/elite/referee_biker.tres").duplicate()
		car.set_meta("biker", true)
	elif kind == "boss":
		car.config = load("res://resources/vehicles/elite/referee_arbiter.tres").duplicate()
		car.set_meta("boss", true)
	else:
		car.config = car.config.duplicate()
	car.config.effects_enabled = false
	car.position = Vector2(1100, 450) if behind else Vector2(120, 450)
	world.add_child(car)
	car.add_to_group("combatants")
	var driver := ArenaBot.new()
	driver.arena = arena
	driver.focus_player = true
	driver.external_weapon_control = true
	driver.team_role = ArenaBot.TeamRole.VANGUARD
	car.add_child(driver)
	if obstacle:
		# Simulate a previously valid route that is now blocked. Replanning
		# must happen immediately, not replace it with a straight-ahead goal.
		driver._intent_goal = target.position
		driver._path_goal = target.position
		driver._path = PackedVector2Array([target.position])
		driver._path_clock = 0.0
		driver._update_path(0.0)
		check(driver._path.size() > 1, kind + " replans a blocked route")
	contacts = 0
	car.body_entered.connect(func(body: Node) -> void:
		if body is StaticBody2D: contacts += 1)
	var path: Array = []
	var distance := INF
	var sideways := 0.0
	var yaw_reversals := 0
	var last_yaw := 0.0
	var reached := false
	var frames := 1800 if kind == "boss" else 1200
	for frame in frames:
		await physics_frame
		distance = car.global_position.distance_to(target.global_position)
		sideways = maxf(sideways, absf(car.position.y - 450.0))
		if absf(car.angular_velocity) > 0.22 and car.get_speed() > 35.0:
			var sign_now := signf(car.angular_velocity)
			if last_yaw != 0.0 and last_yaw != sign_now:
				yaw_reversals += 1
			last_yaw = sign_now
		if frame % 6 == 0:
			path.append([car.position.x, car.position.y, car.rotation, car.get_speed(), car.steer, car.throttle, car.brake])
		if distance < 180.0:
			reached = true
			break
		if not car.alive: break
	var label := kind + ("_detour" if obstacle else "_straight") + ("_uturn" if behind else "")
	print("ROUTE ", label, " reached=", reached, " contacts=", contacts, " reversals=", yaw_reversals, " lateral=", snappedf(sideways, 0.1), " distance=", snappedf(distance, 0.1))
	check(reached, label + " reaches the target")
	check(contacts == 0, label + " avoids scenery")
	if not obstacle and not behind:
		var corridor := 110.0 if kind == "bike" else 20.0
		check(sideways < corridor and yaw_reversals <= 1, label + " follows a steady approach lane")
	elif obstacle:
		check(yaw_reversals <= 4, label + " completes one smooth detour")
	traces.append({"name": label, "path": path, "obstacles": [[570, 330, 150, 240]] if obstacle else [], "target": [target.position.x, target.position.y]})
	world.free()
	await process_frame

func check_wall_braking() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var arena := TestArena.new()
	world.add_child(arena)
	var bike := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	bike.config = load("res://resources/vehicles/elite/referee_biker.tres").duplicate()
	bike.set_meta("biker", true)
	bike.position = Vector2(18, 450)
	bike.rotation = PI
	world.add_child(bike)
	var driver := ArenaBot.new()
	driver.arena = arena
	bike.add_child(driver)
	bike.linear_velocity = Vector2(-0.5, 0)
	var commands := driver.get_commands(1.0 / 30.0)
	check(is_zero_approx(float(commands.throttle)), "rider never accelerates into a wall at crawling speed")
	bike.rotation = 0.0
	bike.linear_velocity = Vector2(-20, 0)
	driver._reversing = 1.0
	commands = driver.get_commands(1.0 / 30.0)
	check(is_zero_approx(float(commands.throttle)) and float(commands.brake) > 0.0, "reverse recovery brakes before the wall")
	world.free()
	await process_frame

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("DRIVER FAIL: ", label)
