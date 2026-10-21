extends SceneTree
## Headless smoke test for the AI bots: they drive along the track, stay on it
## and open fire when a target is in front of them.

var _game: Node
var _track: Track
var _player: Vehicle
var _bots: Array = []
var _start_positions: Array[Vector2] = []
var _max_off_center: Array[float] = []
var _fired_by: Dictionary = {}
var _time := 0.0
var _phase1_start := 0.0
var _discovered := false
var _movement_checked := false
var _failures := 0


func _initialize() -> void:
	_game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(_game)
	_track = _game.get_node("Track")
	_player = _game.get_node("Vehicle")


func _process(delta: float) -> bool:
	if not _discovered:
		_discovered = true
		_discover()
		if _bots.size() != 5:
			_report()
			return true
		return false

	_time += delta
	_track_fired()

	if _time < 4.0:
		_sample_off_center()
		return false

	if not _movement_checked:
		_movement_checked = true
		_check_movement()
		_phase1_start = _time

	if _time < _phase1_start + 0.8:
		# Park the player right in front of bot 0 so it actually shoots.
		var bot: BotController = _bots[0]
		var forward := Vector2.RIGHT.rotated(bot.vehicle.rotation)
		_player.global_position = bot.vehicle.global_position + forward * 150.0
		return false

	_check_fire_aim()
	_report()
	return true


func _discover() -> void:
	_bots = get_nodes_in_group("bots")
	_check(_bots.size() == 5, "five bots spawned (found %d)" % _bots.size())
	for bot in _bots:
		_start_positions.append((bot as BotController).vehicle.global_position)
		_max_off_center.append(0.0)


func _check_movement() -> void:
	for i in _bots.size():
		var bot: BotController = _bots[i]
		var moved := bot.vehicle.global_position.distance_to(_start_positions[i])
		_check(moved > 120.0, "bot %d drove along the track (%.0f px)" % [i, moved])
		_check(
			_max_off_center[i] <= _track.half_width + 8.0,
			"bot %d stayed on the track (off-centre %.1f)" % [i, _max_off_center[i]]
		)


func _check_fire_aim() -> void:
	for i in _bots.size():
		var bot: BotController = _bots[i]
		bot.strategy = BotController.Strategy.RACER
		bot.target = _player
		var bot_vehicle := bot.vehicle
		# The driving phase is allowed to include combat. Reset any wrecks so this
		# section isolates the aiming contract instead of depending on race damage.
		if not bot_vehicle.alive:
			bot_vehicle.reset_to(bot_vehicle.global_position, bot_vehicle.rotation)
		if not _player.alive:
			_player.reset_to(_player.global_position, _player.rotation)
		var forward := Vector2.RIGHT.rotated(bot_vehicle.rotation)
		bot_vehicle.activate_temporary_weapon(bot_vehicle.gun.config, 5.0)

		_player.global_position = bot_vehicle.global_position + forward * 150.0
		_check(bot.get_commands(0.0)["fire"], "bot %d fires at a target ahead" % i)

		_player.global_position = bot_vehicle.global_position - forward * 150.0
		_check(not bot._is_in_fire_solution(_player), "bot %d rejects a target behind" % i)

		_player.global_position = bot_vehicle.global_position + forward * (bot.fire_range + 200.0)
		_check(not bot._is_in_fire_solution(_player), "bot %d rejects a target out of range" % i)
		bot_vehicle.gun.set_enabled(false)
		_check(not bot.get_commands(0.0)["fire"], "bot %d only fires with a weapon bonus" % i)


func _track_fired() -> void:
	for bullet in _game.get_node("Bullets").get_children():
		if bullet is Bullet and bullet.shooter != null and bullet.shooter != _player:
			_fired_by[bullet.shooter] = true


func _sample_off_center() -> void:
	for i in _bots.size():
		var bot: BotController = _bots[i]
		var info := _track.get_closest_segment(bot.vehicle.global_position)
		_max_off_center[i] = maxf(_max_off_center[i], float(info["distance"]))


func _report() -> void:
	print("BOT: %d failures" % _failures)
	print("BOT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("BOT ok: ", label)
	else:
		_failures += 1
		print("BOT FAIL: ", label)
