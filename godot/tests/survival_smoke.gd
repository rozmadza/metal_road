extends SceneTree
## Verifies the survival mode: spawning, damage, death, round progression and
## defeat. Enemy AI and guns are disabled to keep the test deterministic.

var _game: Survival
var _player: Vehicle
var _weapon: WeaponConfig
var _bullet_target: Vehicle
var _bullet_target_health := 0.0
var _time := 0.0
var _phase_time := 0.0
var _phase := 0
var _failures := 0


func _initialize() -> void:
	_game = load("res://scenes/ArenaBattle.tscn").instantiate()
	root.add_child(_game)
	_player = _game.get_node("Player")
	_weapon = load("res://resources/default_machine_gun.tres")


func _process(delta: float) -> bool:
	_time += delta

	match _phase:
		0:
			_phase = 1
			_check_spawn()
			_check_direct_damage()
			_launch_test_bullet()
			_disable_enemies()
			_phase_time = _time
			return false
		1:
			_disable_enemies()
			if _time >= _phase_time + 5.2:
				_check_bullet_damage()
				for enemy in _enemies():
					enemy.take_damage(1000.0)
				_phase = 2
				_phase_time = _time
			return false
		2:
			_disable_enemies()
			if _time >= _phase_time + 0.2:
				_check(not is_instance_valid(_game._boss) and not _game._referee_spawn_pending, "ordinary wave has no Arbiter finale")
				_check(_game._round_over and _game._player_won, "ordinary wave completes after regular opponents")
				_phase = 3
				_phase_time = _time
			return false
		3:
			_disable_enemies()
			if _time >= _phase_time + 2.6:
				_check(_game._round == 2, "round advances after clearing enemies")
				_check(_enemies().size() == 4, "round 2 has four enemies (%d)" % _enemies().size())
				_player.take_damage(1000.0)
				_phase = 4
				_phase_time = _time
			return false
		4:
			if _time >= _phase_time + 0.1:
				_check(not _player.alive, "player death ends the run")
				_check(_game.get_node("HUD/Message").visible, "defeat message shown")
				_report()
				return true
	return false


func _check_spawn() -> void:
	_check(_player.alive, "player is alive at round start")
	_check(_enemies().size() == 2 and _game._pending_enemies.size() == 1, "round 1 starts with two enemies and one reinforcement")
	_check(get_nodes_in_group("combatants").size() == 3, "player + 2 initial enemies are combatants")
	_check(_enemies().all(func(enemy): return not enemy.gun.enabled), "bots start without bonus weapons")
	_check("УНИЧТОЖЕНО 0" in _game.get_node("HUD/Top/Panel/Status").text, "HUD shows destroyed count")
	_check("ОСТАЛОСЬ 3" in _game.get_node("HUD/Top/Panel/Status").text, "HUD includes the pending reinforcement")


func _check_direct_damage() -> void:
	var enemies := _enemies()
	if enemies.is_empty():
		return
	var enemy: Vehicle = enemies[0]
	var before := enemy.health
	enemy.take_damage(5.0)
	_check(is_equal_approx(enemy.health, before - 5.0), "take_damage reduces health")


func _launch_test_bullet() -> void:
	var enemies := _enemies()
	if enemies.size() < 2:
		return
	_bullet_target = enemies[1]
	_bullet_target_health = _bullet_target.health
	var bullet: Bullet = (load("res://scenes/Bullet.tscn") as PackedScene).instantiate()
	_game.get_node("Bullets").add_child(bullet)
	bullet.setup(_bullet_target.global_position, Vector2.RIGHT, _weapon, _player)


func _check_bullet_damage() -> void:
	if _bullet_target == null:
		return
	_check(_bullet_target.health < _bullet_target_health, "bullet damages the target it overlaps")


func _disable_enemies() -> void:
	for enemy in _enemies():
		if enemy.gun != null:
			enemy.gun.set_physics_process(false)
		var ai := enemy.get_node_or_null("ArenaBot")
		if ai != null:
			ai.set_physics_process(false)


func _enemies() -> Array[Vehicle]:
	var result: Array[Vehicle] = []
	for node in get_nodes_in_group("combatants"):
		var vehicle := node as Vehicle
		if vehicle != null and vehicle != _player:
			result.append(vehicle)
	return result


func _report() -> void:
	print("SURVIVAL: %d failures" % _failures)
	print("SURVIVAL: %s" % ("PASS" if _failures == 0 else "FAIL"))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("SURVIVAL ok: ", label)
	else:
		_failures += 1
		print("SURVIVAL FAIL: ", label)
