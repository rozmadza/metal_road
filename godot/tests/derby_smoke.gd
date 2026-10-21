extends SceneTree
## Verifies derby ramming: two combatant cars that collide at speed damage each
## other.

var _game: Survival
var _player: Vehicle
var _enemy: Vehicle
var _time := 0.0
var _phase_time := 0.0
var _phase := 0
var _failures := 0


func _initialize() -> void:
	_game = load("res://scenes/ArenaBattle.tscn").instantiate()
	root.add_child(_game)
	_player = _game.get_node("Player")


func _process(delta: float) -> bool:
	_time += delta

	match _phase:
		0:
			_phase = 1
			_phase_time = _time
			_disable_ai()
			_enemy = _first_enemy()
			if _enemy == null:
				_check(false, "an enemy exists to ram")
				_report()
				return true
			# Lower, realistic top speeds need a shorter run-up than the old
			# 300+ km/h tuning used by this regression test.
			_player.reset_to(Vector2(330, 700), 0.0)
			_enemy.reset_to(Vector2(470, 700), PI)
			return false
		1:
			_disable_ai()
			if _time >= _phase_time + 0.2:
				_player.linear_velocity = Vector2(350, 0)
				_enemy.linear_velocity = Vector2(-350, 0)
				_phase = 2
				_phase_time = _time
			return false
		2:
			if _time >= _phase_time + 1.0:
				_check(
					_player.health < _player.config.max_health
					or _enemy.health < _enemy.config.max_health,
					"ramming damages the cars (p=%.0f e=%.0f)" % [_player.health, _enemy.health]
				)
				_report()
				return true
	return false


func _disable_ai() -> void:
	for node in get_nodes_in_group("combatants"):
		var vehicle := node as Vehicle
		if vehicle == null:
			continue
		if vehicle.gun != null:
			vehicle.gun.set_physics_process(false)
		var ai := vehicle.get_node_or_null("ArenaBot")
		if ai != null:
			ai.set_physics_process(false)


func _first_enemy() -> Vehicle:
	for node in get_nodes_in_group("combatants"):
		var vehicle := node as Vehicle
		if vehicle != null and vehicle != _player:
			return vehicle
	return null


func _report() -> void:
	print("DERBY: %d failures" % _failures)
	print("DERBY: %s" % ("PASS" if _failures == 0 else "FAIL"))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("DERBY ok: ", label)
	else:
		_failures += 1
		print("DERBY FAIL: ", label)
