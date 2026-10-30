extends Node2D
class_name Bullet
const VisualProfile = preload("res://scripts/weapon_visual_profile.gd")
## A simple projectile (not a physics body). Moves in a straight line, is
## drawn as a bright dot with a tracer tail, and frees itself after its
## lifetime. `shooter` is stored so it can be ignored for damage later.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var lifetime: float = 1.0
var radius: float = 3.0
var trail_length: float = 14.0
var color: Color = Color(1.0, 0.85, 0.2)
var shooter: Node = null
var weapon_type: WeaponConfig.WeaponType = WeaponConfig.WeaponType.BALLISTIC
var weapon_id: StringName = &"machine_gun"
var splash_radius := 0.0
var homing_strength := 0.0
var homing_max_turn := 0.0
var homing_turn_used := 0.0
var effect_duration := 0.0
var age := 0.0
var detonated := false
var visual_profile: VisualProfile
var _explosion_owned_by_vfx := false


func setup(position: Vector2, direction: Vector2, config: WeaponConfig, owner_node: Node) -> void:
	global_position = position
	velocity = direction.normalized() * config.bullet_speed
	damage = config.bullet_damage
	lifetime = config.bullet_lifetime
	radius = config.bullet_radius
	trail_length = config.trail_length
	color = config.bullet_color
	shooter = owner_node
	weapon_type = config.weapon_type
	weapon_id = config.weapon_id
	visual_profile = config.visual_profile
	splash_radius = config.splash_radius
	homing_strength = config.homing_strength
	homing_max_turn = config.homing_max_turn
	homing_turn_used = 0.0
	effect_duration = config.effect_duration
	# Flame already has the muzzle velocity of the burning mixture.  In world
	# space it must also inherit the carrier velocity; otherwise a fast vehicle
	# catches up with its own projectiles and the visible reach collapses while
	# driving forward.  Relative to the nozzle the configured range now stays
	# bullet_speed * bullet_lifetime in every direction of travel.
	if weapon_type == WeaponConfig.WeaponType.FLAME and owner_node is Vehicle:
		velocity += (owner_node as Vehicle).linear_velocity
	if weapon_type == WeaponConfig.WeaponType.MINE:
		# Bullets and cars share the world parent. Equal z=0 made the later
		# spawned mine draw over the car; the installed hazard belongs on ground.
		z_index = -1
		add_to_group("weapon_hazards")
		velocity = (owner_node as Vehicle).linear_velocity * 0.12 if owner_node is Vehicle else Vector2.ZERO
	rotation = direction.angle()
	set_process(visual_profile != null and visual_profile.has_projectile())
	queue_redraw()


func _process(_delta: float) -> void:
	# Animation only; never consumes gameplay RNG or changes physics timing.
	if not detonated:
		queue_redraw()


func _physics_process(delta: float) -> void:
	age += delta
	if weapon_type == WeaponConfig.WeaponType.ROCKET:
		_guide_rocket(delta)
	if weapon_type == WeaponConfig.WeaponType.MINE:
		velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
		rotation += delta * 0.8
		global_position += velocity * delta
		lifetime -= delta
		if age >= effect_duration and _mine_has_target():
			_detonate()
		elif lifetime <= 0.0:
			queue_free()
		return
	var previous_position := global_position
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	# Destructibles own StaticBody2D children. Resolve them before generic
	# cover, otherwise the physics point query consumes the bullet first.
	if _check_destructible_hit():
		return
	if _hits_wreck(previous_position):
		_impact()
		return
	if _hits_obstacle():
		_impact()
		return
	if _check_crew_hit(previous_position):
		return
	_check_vehicle_hit()


## True when the bullet has flown into a wall or arena obstacle. Bullets stop
## at cover instead of passing through it.
func _hits_wreck(previous_position: Vector2) -> bool:
	# A separate cover bit selects only wrecks, never live RigidBody vehicles.
	# Sweep the existing centre line; a fast bullet cannot skip a narrow bike.
	var query := PhysicsRayQueryParameters2D.create(previous_position,global_position,4)
	query.hit_from_inside = true
	var contact := get_world_2d().direct_space_state.intersect_ray(query)
	if contact.is_empty(): return false
	global_position = contact.position
	return true


func _hits_obstacle() -> bool:
	var world := get_world_2d()
	if world == null:
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for result in world.direct_space_state.intersect_point(query, 4):
		if result["collider"] is StaticBody2D:
			return true
	return false


## Damages the first combatant the bullet overlaps. Only vehicles in the
## "combatants" group are affected, so race mode is left untouched.
func _check_destructible_hit() -> bool:
	if damage <= 0.0:
		return false
	for node in get_tree().get_nodes_in_group("destructibles"):
		if is_instance_valid(node) and node.has_method("take_damage") and global_position.distance_to(node.global_position) <= radius + 16.0:
			if splash_radius > 0.0:
				_detonate()
			else:
				node.take_damage(damage, &"body", shooter if is_instance_valid(shooter) else null)
				_emit_impact(global_position)
				queue_free()
			return true
	return false


func _check_vehicle_hit() -> bool:
	if damage <= 0.0:
		return false
	for node in get_tree().get_nodes_in_group("combatants"):
		var vehicle := node as Vehicle
		if vehicle == null or vehicle == shooter or not vehicle.alive or vehicle.config == null or _same_squad(vehicle):
			continue
		var local_hit := vehicle.to_local(global_position)
		var half_length := vehicle.config.length * Vehicle.COLLISION_SCALE.x * 0.5
		var half_width := vehicle.config.width * Vehicle.COLLISION_SCALE.y * 0.5
		var nearest := Vector2(clampf(local_hit.x, -half_length, half_length), clampf(local_hit.y, -half_width, half_width))
		if local_hit.distance_to(nearest) <= radius:
			if splash_radius > 0.0:
				_detonate()
			else:
				_apply_hit(vehicle, damage)
				queue_free()
			return true
	return false


func _check_crew_hit(previous_position: Vector2) -> bool:
	if damage <= 0.0:
		return false
	for node in get_tree().get_nodes_in_group("escaping_crew"):
		var crew := node as EscapingCrew
		if crew == null or not crew._active:
			continue
		var contact := Geometry2D.get_closest_point_to_segment(crew.global_position, previous_position, global_position)
		if contact.distance_to(crew.global_position) > radius + 7.0:
			continue
		if splash_radius > 0.0:
			global_position = contact
			_detonate()
		else:
			crew.take_weapon_damage(damage, shooter if is_instance_valid(shooter) else null)
			var vfx := get_tree().get_first_node_in_group("combat_vfx") as CombatVFX
			if vfx != null:
				vfx.spawn_impact(contact, color, false, visual_profile)
			queue_free()
		return true
	return false


func _apply_hit(vehicle: Vehicle, amount: float) -> void:
	var vfx := get_tree().get_first_node_in_group("combat_vfx") as CombatVFX
	if vfx != null:
		vfx.spawn_impact(global_position, color, false, visual_profile)
	# EMP remains primarily a control weapon, but its electrical discharge also
	# burns a small, visible amount of body HP. Body damage already shares a
	# portion with the engine module, preserving the intended system disruption.
	vehicle.take_weapon_damage(amount, &"body", shooter if is_instance_valid(shooter) else null, weapon_id)
	if weapon_type == WeaponConfig.WeaponType.EMP:
		vehicle.apply_emp(effect_duration)


func _impact() -> void:
	if splash_radius > 0.0:
		_detonate()
	else:
		var vfx := get_tree().get_first_node_in_group("combat_vfx") as CombatVFX
		if vfx != null:
			vfx.spawn_impact(global_position, color, false, visual_profile)
		queue_free()


func _emit_impact(point: Vector2) -> void:
	# Destructible contacts previously had no projectile feedback. Restrict the
	# addition to the two new profiles; keep other weapons' presentation intact.
	if visual_profile == null or not visual_profile.ballistic: return
	var vfx := get_tree().get_first_node_in_group("combat_vfx") as CombatVFX
	if vfx != null: vfx.spawn_impact(point, color, false, visual_profile)


func _detonate() -> void:
	if detonated:
		return
	detonated = true
	var combat_audio := get_tree().get_first_node_in_group("combat_audio") as AudioManager
	if combat_audio != null:
		combat_audio.play_weapon_impact(weapon_type)
	var vfx := get_tree().get_first_node_in_group("combat_vfx") as CombatVFX
	if vfx != null:
		_explosion_owned_by_vfx = visual_profile != null and visual_profile.has_explosion()
		vfx.spawn_explosion(global_position, color, maxf(splash_radius, 42.0), visual_profile)
	for node in get_tree().get_nodes_in_group("combatants"):
		var vehicle := node as Vehicle
		if vehicle == null or vehicle == shooter or not vehicle.alive or _same_squad(vehicle):
			continue
		var distance := global_position.distance_to(vehicle.global_position)
		if distance <= splash_radius:
			var falloff := lerpf(1.0, 0.25, clampf(distance / maxf(splash_radius, 1.0), 0.0, 1.0))
			_apply_hit(vehicle, damage * falloff)
	for node in get_tree().get_nodes_in_group("destructibles"):
		if is_instance_valid(node) and node.has_method("take_damage"):
			var distance := global_position.distance_to(node.global_position)
			if distance <= splash_radius:
				node.take_damage(damage * lerpf(1.0, 0.3, distance / maxf(splash_radius, 1.0)), &"body", shooter if is_instance_valid(shooter) else null)
	for node in get_tree().get_nodes_in_group("escaping_crew"):
		var crew := node as EscapingCrew
		if crew == null or not crew._active:
			continue
		var distance := global_position.distance_to(crew.global_position)
		if distance <= splash_radius:
			crew.take_weapon_damage(damage * lerpf(1.0, 0.25, distance / maxf(splash_radius, 1.0)), shooter if is_instance_valid(shooter) else null)
	queue_redraw()
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 2.4, 0.14)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)


func _mine_has_target() -> bool:
	for node in get_tree().get_nodes_in_group("combatants"):
		var vehicle := node as Vehicle
		if vehicle == null or vehicle == shooter or not vehicle.alive or vehicle.config == null or _same_squad(vehicle):
			continue
		# Arming is triggered by contact with the chassis. The blast radius is
		# used only after detonation to damage nearby targets.
		var local_hit := vehicle.to_local(global_position)
		var half_length := vehicle.config.length * Vehicle.COLLISION_SCALE.x * 0.5
		var half_width := vehicle.config.width * Vehicle.COLLISION_SCALE.y * 0.5
		var nearest := Vector2(clampf(local_hit.x, -half_length, half_length), clampf(local_hit.y, -half_width, half_width))
		if local_hit.distance_to(nearest) <= radius:
			return true
	return false


func _guide_rocket(delta: float) -> void:
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("combatants"):
		var vehicle := node as Vehicle
		if vehicle == null or vehicle == shooter or not vehicle.alive or _same_squad(vehicle):
			continue
		var distance := global_position.distance_squared_to(vehicle.global_position)
		if distance < best_distance:
			best_distance = distance
			best = vehicle
	for node in get_tree().get_nodes_in_group("escaping_crew"):
		var crew := node as EscapingCrew
		if crew == null or not crew._active:
			continue
		var distance := global_position.distance_squared_to(crew.global_position)
		if distance < best_distance:
			best_distance = distance
			best = crew
	if best == null:
		return
	var aim_point := best.global_position
	if best is EscapingCrew:
		var target_crew := best as EscapingCrew
		var travel_time := minf(sqrt(best_distance) / maxf(velocity.length(), 1.0), 0.3)
		aim_point += target_crew.escape_direction * target_crew.run_speed * travel_time
	var desired := global_position.direction_to(aim_point).angle()
	var current := velocity.angle()
	var step := homing_strength * delta
	if homing_max_turn > 0.0:
		step = minf(step, maxf(0.0, homing_max_turn - homing_turn_used))
	var next := rotate_toward(current, desired, step)
	homing_turn_used += absf(angle_difference(current, next))
	velocity = Vector2.RIGHT.rotated(next) * velocity.length()
	rotation = next


func _same_squad(vehicle: Vehicle) -> bool:
	if not is_instance_valid(shooter) or not shooter is Vehicle: return false
	var squad: StringName = shooter.get_meta("squad_id", &"")
	return squad != &"" and StringName(vehicle.get_meta("squad_id", &"")) == squad


func _draw() -> void:
	if detonated:
		# Preserve the Bullet lifetime/cap accounting; only CombatVFX renders
		# an asset explosion. Without CombatVFX retain the legacy flash.
		if _explosion_owned_by_vfx:
			return
		draw_circle(Vector2.ZERO, maxf(16.0, splash_radius * 0.38), Color(color, 0.42))
		draw_circle(Vector2.ZERO, maxf(6.0, splash_radius * 0.12), Color(1.0, 0.9, 0.55, 0.95))
		return
	if weapon_type == WeaponConfig.WeaponType.MINE:
		var armed_color := color if age >= effect_duration else Color(0.42, 0.44, 0.43)
		draw_circle(Vector2.ZERO, radius + 4.0, Color(0.08, 0.08, 0.075, 0.96))
		for spoke in 6:
			var direction := Vector2.RIGHT.rotated(TAU * float(spoke) / 6.0)
			draw_line(direction * 5.0, direction * (radius + 6.0), armed_color, 2.2, true)
		draw_circle(Vector2.ZERO, 3.5, armed_color)
		return
	if weapon_type == WeaponConfig.WeaponType.ROCKET:
		if visual_profile != null and visual_profile.draw_projectile(self, age):
			return
		draw_line(Vector2(-trail_length, 0), Vector2(-5, 0), Color(1.0, 0.34, 0.05, 0.8), radius * 1.5, true)
		draw_rect(Rect2(-6, -radius, 13, radius * 2.0), color, true)
		draw_circle(Vector2(7, 0), radius, Color(0.9, 0.92, 0.86))
		return
	if weapon_type == WeaponConfig.WeaponType.FLAME:
		draw_circle(Vector2.ZERO, radius * 1.6, Color(color, 0.42))
		draw_circle(Vector2.ZERO, radius * 0.7, Color(1.0, 0.92, 0.38, 0.9))
		return
	if weapon_type == WeaponConfig.WeaponType.BALLISTIC and visual_profile != null and visual_profile.ballistic and visual_profile.draw_projectile(self, age):
		return
	if weapon_type == WeaponConfig.WeaponType.EMP:
		draw_arc(Vector2.ZERO, radius * 2.0, 0.0, TAU, 12, Color(color, 0.72), 2.0, true)
	# Local +X is the direction of travel, so the tail goes towards -X.
	if trail_length > 0.0:
		draw_line(Vector2(-trail_length, 0.0), Vector2.ZERO, color, radius * 0.9, true)
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.9))
