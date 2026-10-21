extends SceneTree
## Rendered endurance run through InputMap. No teleport, HP override or lap override.
## The driver is automated; real mouse/keyboard UI review is recorded separately.
var game: Game
var elapsed := 0.0
var driver: BotController
var previous_lap := 0
var ending := false

func _initialize() -> void: call_deferred("start")
func start() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	if "--solo" in OS.get_cmdline_user_args(): game.spawn_bots = false
	root.add_child(game)
	current_scene = game
	driver = BotController.new()
	driver.vehicle = game.vehicle
	driver.track = game.track
	driver.lookahead = 75
	driver.cruise_throttle = 0.8
	# Refuse to move the real vehicle directly: only InputMap below drives it.

func action(name: String, strength: float) -> void:
	if strength > 0: Input.action_press(name, strength)
	else: Input.action_release(name)

func _process(delta: float) -> bool:
	if game == null or ending: return false
	elapsed += delta
	if not game.race_over:
		var c := driver.get_commands(delta)
		# Keyboard is binary; duty-cycle the requested throttle instead of treating
		# every nonzero analog value as full acceleration.
		action("accelerate", 1.0 if c.throttle > 0 and fmod(elapsed, 0.25) < 0.25 * c.throttle else 0.0)
		action("brake", c.brake if c.throttle >= 0 else 1.0)
		action("steer_right", maxf(c.steer, 0))
		action("steer_left", maxf(-c.steer, 0))
		action("fire", 1)
		var lap := game.progress.laps(game.vehicle)
		if lap != previous_lap:
			previous_lap = lap
			print("PLAYTHROUGH lap ", lap, " time ", game.elapsed, " HP ", game.vehicle.health)
	if game.race_over or elapsed > 120:
		for name in ["accelerate", "brake", "steer_right", "steer_left", "fire"]: Input.action_release(name)
		print("PLAYTHROUGH result ", game.result, " real elapsed ", elapsed)
		ending = true
		finish.call_deferred()
	return false

func finish() -> void:
	if not ending: return
	# Disable this SceneTree's polling by dropping the game reference after snapshot.
	var completed := game
	game = null
	await create_timer(0.3).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/sprints/bcd/playthrough-%s.png" % ("solo" if "--solo" in OS.get_cmdline_user_args() else "combat"))
	var ok: bool = completed.race_over and completed.result.status == &"FINISHED"
	driver.free()
	if "--review" in OS.get_cmdline_user_args(): return
	completed.free()
	quit(0 if ok else 1)
