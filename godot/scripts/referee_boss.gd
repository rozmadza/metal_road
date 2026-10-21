extends Node2D
class_name RefereeBoss
## Exclusive survival boss equipment. Driving remains with ArenaBot, while
## this component owns the visible saw and the deliberately rare flame burst.

signal flame_warning
signal saw_contact

const SAW_TEXTURE := preload("res://assets/vehicles/referee/referee_saw.png")

enum FlameState { READY, WARNING, FIRING, COOLDOWN }

var vehicle: Vehicle
var phase := 1
var saw_damage := 11.0
var saw_speed := 7.5
var saw_radius := 19.0
var flame_state := FlameState.COOLDOWN
var flame_timer := 2.2
var _saw_sprite: Sprite2D
var _hit_cooldowns: Dictionary = {}
var _spark_clock := 0.0


func _ready() -> void:
	vehicle = get_parent() as Vehicle
	process_physics_priority = 100
	_saw_sprite = Sprite2D.new()
	_saw_sprite.name = "RotatingSaw"
	_saw_sprite.texture = SAW_TEXTURE
	_saw_sprite.position = _saw_position()
	var source_size := Vector2(SAW_TEXTURE.get_size())
	var target_diameter := saw_radius * 2.0
	_saw_sprite.scale = Vector2.ONE * target_diameter / maxf(source_size.x, source_size.y)
	_saw_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_saw_sprite)
	queue_redraw()


func set_phase(value: int) -> void:
	phase = clampi(value, 1, 3)
	saw_damage = [0.0, 11.0, 14.0, 18.0][phase]
	saw_speed = [0.0, 7.5, 9.5, 12.5][phase]
	# A new phase shortens the next opening, but never turns the flamethrower
	# into continuous fire.
	if flame_state == FlameState.COOLDOWN:
		flame_timer = minf(flame_timer, 3.8)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if vehicle == null or not vehicle.alive:
		_set_flame(false)
		return
	_saw_sprite.rotation += saw_speed * delta
	_spark_clock = maxf(0.0, _spark_clock - delta)
	_tick_hit_cooldowns(delta)
	_damage_saw_contacts()
	_update_flamethrower(delta)
	queue_redraw()


func _saw_position() -> Vector2:
	if vehicle == null or vehicle.config == null:
		return Vector2(60.0, 0.0)
	return Vector2(vehicle.config.length * Vehicle.VISUAL_SCALE * 0.53, 0.0)


func _damage_saw_contacts() -> void:
	var center := vehicle.to_global(_saw_position())
	for node in get_tree().get_nodes_in_group("combatants"):
		var target := node as Vehicle
		if target == null or target == vehicle or not target.alive or _same_squad(target):
			continue
		var target_radius := maxf(target.config.length, target.config.width) * 0.27
		if center.distance_to(target.global_position) > saw_radius + target_radius:
			continue
		var key := target.get_instance_id()
		if float(_hit_cooldowns.get(key, 0.0)) > 0.0:
			continue
		_hit_cooldowns[key] = maxf(0.12, 0.22 - float(phase) * 0.025)
		target.take_weapon_damage(saw_damage, &"body", vehicle, &"arbiter_saw")
		var push := center.direction_to(target.global_position)
		if push.length_squared() < 0.01:
			push = Vector2.RIGHT.rotated(vehicle.rotation)
		target.apply_central_impulse(push * minf(vehicle.mass * 0.2, 760.0))
		_spawn_sparks(center.lerp(target.global_position, 0.42))
		saw_contact.emit()


func _same_squad(target: Vehicle) -> bool:
	var squad: StringName = vehicle.get_meta("squad_id", &"") if vehicle != null else &""
	return squad != &"" and StringName(target.get_meta("squad_id", &"")) == squad


func _tick_hit_cooldowns(delta: float) -> void:
	for key in _hit_cooldowns.keys():
		var remaining := float(_hit_cooldowns[key]) - delta
		if remaining <= 0.0:
			_hit_cooldowns.erase(key)
		else:
			_hit_cooldowns[key] = remaining


func _spawn_sparks(world_position: Vector2) -> void:
	if _spark_clock > 0.0:
		return
	_spark_clock = 0.1
	var vfx := get_tree().get_first_node_in_group("combat_vfx") as CombatVFX
	if vfx != null:
		vfx.spawn_impact(world_position, Color(1.0, 0.66, 0.12))


func _update_flamethrower(delta: float) -> void:
	flame_timer = maxf(0.0, flame_timer - delta)
	match flame_state:
		FlameState.COOLDOWN:
			_set_flame(false)
			if flame_timer <= 0.0 and _player_in_flame_window():
				flame_state = FlameState.WARNING
				flame_timer = 0.75
				flame_warning.emit()
		FlameState.WARNING:
			_set_flame(false)
			if flame_timer <= 0.0:
				flame_state = FlameState.FIRING
				flame_timer = 1.45 + float(phase) * 0.15
		FlameState.FIRING:
			_set_flame(true)
			if flame_timer <= 0.0:
				_set_flame(false)
				flame_state = FlameState.COOLDOWN
				flame_timer = randf_range(6.5, 8.5) - float(phase - 1) * 0.55
		_:
			flame_state = FlameState.COOLDOWN
			flame_timer = 6.0


func _player_in_flame_window() -> bool:
	var player: Vehicle
	for node in get_tree().get_nodes_in_group("combatants"):
		var candidate := node as Vehicle
		if candidate != null and candidate.alive and bool(candidate.get_meta("player_vehicle", false)):
			player = candidate
			break
	if player == null:
		return false
	var offset := player.global_position - vehicle.global_position
	if offset.length() > 410.0 or offset.length_squared() < 0.01:
		return false
	# A slow tracked boss needs a generous acquisition cone. The warning gives
	# the player time to escape before the actual medium-range flames arrive.
	return Vector2.RIGHT.rotated(vehicle.rotation).dot(offset.normalized()) >= 0.0


func _set_flame(active: bool) -> void:
	if vehicle != null and vehicle.gun != null:
		vehicle.gun.set_firing(active)


func _draw() -> void:
	if vehicle == null or flame_state not in [FlameState.WARNING, FlameState.FIRING]:
		return
	var length := 292.0
	var half_angle := 0.27
	var origin := _saw_position() + Vector2(3.0, 0.0)
	var points := PackedVector2Array([
		origin,
		Vector2.RIGHT.rotated(-half_angle) * length,
		Vector2.RIGHT.rotated(half_angle) * length,
	])
	if flame_state == FlameState.WARNING:
		draw_colored_polygon(points, Color(1.0, 0.18, 0.02, 0.1))
		draw_polyline(points + PackedVector2Array([points[0]]), Color(1.0, 0.48, 0.08, 0.58), 2.4, true)
		return
	# Large animated tongues make the flame burst unmistakable even when its
	# damage projectiles disappear immediately on contact.
	var pulse := Time.get_ticks_msec() * 0.024
	for tongue in 5:
		var ratio := 0.66 + float(tongue) * 0.075 + sin(pulse + float(tongue) * 1.73) * 0.055
		var side := remap(float(tongue), 0.0, 4.0, -1.0, 1.0)
		var tip := Vector2(length * ratio, side * length * 0.19 + sin(pulse * 1.3 + tongue) * 8.0)
		var width := 14.0 + (1.0 - absf(side)) * 10.0
		draw_colored_polygon(PackedVector2Array([
			origin + Vector2(0.0, -width), tip, origin + Vector2(0.0, width),
		]), Color(1.0, 0.16 + float(tongue) * 0.045, 0.015, 0.34))
	var core_tip := Vector2(length * (0.55 + sin(pulse) * 0.04), 0.0)
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(0.0, -8.0), core_tip, origin + Vector2(0.0, 8.0),
	]), Color(1.0, 0.86, 0.16, 0.72))
