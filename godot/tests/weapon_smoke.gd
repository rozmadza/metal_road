extends SceneTree
## Verifies the machine gun: bullets spawn on fire, move visibly, respect the
## active-bullet limit and disappear after their lifetime.
## Time-based (not frame-based) because headless runs the idle loop uncapped.

var _game: Node
var _bullets: Node2D
var _gun: MachineGun
var _time := 0.0
var _failures := 0
var _peak := 0
var _sample_bullet: Bullet
var _sample_pos := Vector2.ZERO
var _spawn_checked := false
var _moved_checked := false


func _initialize() -> void:
	_game = Node2D.new()
	root.add_child(_game)
	_bullets = Node2D.new()
	_bullets.name = "Bullets"
	_bullets.add_to_group("bullets")
	_game.add_child(_bullets)
	var vehicle := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	_game.add_child(vehicle)
	_gun = vehicle.get_node("MachineGun") as MachineGun
	_gun.set_enabled(true)
	_gun.set_physics_process(true)
	_gun._bullets_parent = _bullets
	var local_muzzle := vehicle.to_local(_gun.get_muzzle_position())
	_check(local_muzzle.x <= vehicle.config.length * 0.5, "muzzle stays inside vehicle body")


func _process(delta: float) -> bool:
	_time += delta
	if not _gun.is_physics_processing():
		_gun.set_physics_process(true)
	var count := _bullets.get_child_count()
	_peak = maxi(_peak, count)

	if _time <= 0.5:
		_gun.set_firing(true)
	else:
		_gun.set_firing(false)

	if not _spawn_checked and _time > 0.5:
		_spawn_checked = true
		_check(count >= 2, "bullets spawn while firing (count=%d)" % count)
		_check(count <= _gun.config.max_active_bullets, "respects max active bullets (count=%d)" % count)
		if count > 0:
			_sample_bullet = _bullets.get_child(0)
			_sample_pos = _sample_bullet.global_position

	if not _moved_checked and _spawn_checked and _time > 0.62:
		_moved_checked = true
		if is_instance_valid(_sample_bullet):
			var moved := _sample_pos.distance_to(_sample_bullet.global_position)
			_check(moved > 50.0, "bullet moves visibly (%.0f px)" % moved)
		else:
			_check(false, "sample bullet alive for movement check")

	if _time > 1.8:
		_check(count == 0, "bullets expire after lifetime (count=%d)" % count)
		_check(_peak >= 2, "multiple bullets were fired (peak=%d)" % _peak)
		print("WEAPON: %d failures" % _failures)
		print("WEAPON: %s" % ("PASS" if _failures == 0 else "FAIL"))
		_game.free()
		quit(0 if _failures == 0 else 1)
		return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("WEAPON ok: ", label)
	else:
		_failures += 1
		print("WEAPON FAIL: ", label)
