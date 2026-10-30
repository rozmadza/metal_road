extends RigidBody2D
class_name Vehicle
## Player vehicle with the arcade "tank-lite" physics model.
##
## This is a direct port of the Python `Vehicle` (Pymunk) class. The rigid body
## is the single source of truth for position/velocity/rotation; this script
## only applies forces. All tuning lives in a [VehicleConfig] resource.

const VISUAL_SCALE := 1.72
## Slightly inside the artwork: clean sprites have a narrow transparent rim.
## Physics, steering and visible chassis must share the same footprint.
const COLLISION_SCALE := Vector2(1.63, 1.58)
## Scenery should punish a crash without competing with weapon or car-ram damage.
const STATIC_IMPACT_DAMAGE_SCALE := 0.25
## Player gear selection only; AI's direct signed throttle is unaffected.
const PLAYER_REVERSE_DELAY := 0.15
const PLAYER_REVERSE_STOP_SPEED := 2.0

@export var config: VehicleConfig

## Emitted when the vehicle's health reaches zero.
signal died(vehicle: Vehicle)
signal impacted(intensity: float)
signal damaged(vehicle: Vehicle, amount: float, source: Node)
signal damage_stage_changed(vehicle: Vehicle, stage: int)
var last_attacker: Node
var last_weapon_id: StringName = &""
var _pending_weapon_id: StringName = &""

## Current control state (same command contract the AI will use later).
var throttle: float = 0.0
var brake: float = 0.0
var steer: float = 0.0
var fire: bool = false

## Combat state (only meaningful when the vehicle is in the "combatants" group).
var damage := VehicleDamage.new()
var health: float:
	get: return damage.body
	set(value): damage.body = value
var effects: VehicleEffects
var alive: bool = true
var _surface_traction_factor := 1.0
var _surface_steering_factor := 1.0
var _surface_traction_target := 1.0
var _surface_steering_target := 1.0
var _surface_modifiers: Dictionary = {}

var _collision_shape: CollisionShape2D
var _velocity_debug_scale: float = 0.1

@onready var gun: MachineGun = get_node_or_null("MachineGun")
@onready var _animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
var _pending_reset: bool = false
var _reset_position: Vector2 = Vector2.ZERO
var _reset_angle: float = 0.0
var _base_modulate: Color = Color.WHITE
var _default_layer: int = 1
var _default_mask: int = 1
var _last_velocity: Vector2 = Vector2.ZERO
var _previous_velocity: Vector2 = Vector2.ZERO
var _collision_cooldowns: Dictionary = {}
var weapon_time_remaining: float = 0.0
var boost_time_remaining: float = 0.0
var ram_boost_time_remaining: float = 0.0
var emp_time_remaining: float = 0.0
var apex_boost_time_remaining: float = 0.0
var passive_feedback_time_remaining: float = 0.0
var _apex_cooldown_remaining: float = 0.0
var _time_since_impact: float = 99.0
var _wheels_repair_cooldown: float = 0.0
var _wheel_pull_direction: float = 0.0
var _handbrake_strength: float = 0.0
var _delivered_throttle: float = 0.0
var _reverse_hold := 0.0
var _player_reverse := false
var _steering_input := 0.0


func _ready() -> void:
	if config == null:
		config = VehicleConfig.new()

	damage.reset(config)
	_base_modulate = modulate
	_default_layer = collision_layer
	_default_mask = collision_mask

	# Needed for car-to-car ramming damage (see _on_body_entered).
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	mass = config.mass
	inertia = config.moment
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	# Prevent tunnelling through thin segment walls at high speed.
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

	var material := PhysicsMaterial.new()
	material.friction = 0.22
	material.bounce = 0.28
	physics_material_override = material

	_build_collision_shape()
	effects = VehicleEffects.new()
	effects.name = "Effects"
	add_child(effects)
	queue_redraw()


func _build_collision_shape() -> void:
	if _collision_shape == null:
		_collision_shape = get_node_or_null("CollisionShape2D")
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
	var shape := ConvexPolygonShape2D.new()
	# set_point_cloud builds the convex hull, so vertex winding does not matter.
	var vertices := config.get_body_vertices()
	for index in vertices.size():
		vertices[index] *= COLLISION_SCALE
	shape.set_point_cloud(vertices)
	_collision_shape.shape = shape


func reconfigure(value: VehicleConfig) -> void:
	config = value
	mass = config.mass
	inertia = config.moment
	damage.reset(config)
	_build_collision_shape()
	queue_redraw()


## Sets the vehicle control commands. Values are clamped to their valid range.
func apply_control(new_throttle: float, new_brake: float, new_steer: float, new_fire: bool = false) -> void:
	if not alive:
		return
	throttle = clampf(new_throttle, -1.0, 1.0)
	# Thrust is applied inside _integrate_forces, which sleeping bodies skip.
	if absf(throttle) > 0.001 and sleeping:
		sleeping = false
	brake = clampf(new_brake, 0.0, 1.0)
	steer = clampf(new_steer, -1.0, 1.0)
	fire = new_fire
	if gun != null:
		gun.set_firing(fire)

func apply_player_control(gas: float, brake_input: float, steering: float, firing: bool, delta: float) -> void:
	if brake_input <= 0.0 or gas > 0.0:
		_reverse_hold = 0.0
		_player_reverse = false
	elif not _player_reverse:
		_reverse_hold = _reverse_hold + delta if absf(get_forward_speed()) <= PLAYER_REVERSE_STOP_SPEED else 0.0
		_player_reverse = _reverse_hold >= PLAYER_REVERSE_DELAY
	if _player_reverse:
		apply_control(-0.6 * brake_input, 0.0, steering, firing)
	else:
		apply_control(gas, brake_input, steering, firing)


func set_surface_modifier(traction_multiplier: float, steering_multiplier: float, source: Node = null) -> void:
	var key: Variant = source if source != null else &"default"
	_surface_modifiers[key] = Vector2(
		clampf(traction_multiplier, 0.1, 1.0),
		clampf(steering_multiplier, 0.1, 1.0)
	)
	_recalculate_surface_modifier()

func clear_surface_modifier(source: Node = null) -> void:
	var key: Variant = source if source != null else &"default"
	_surface_modifiers.erase(key)
	_recalculate_surface_modifier()

func _recalculate_surface_modifier() -> void:
	_surface_traction_target = 1.0
	_surface_steering_target = 1.0
	for modifier in _surface_modifiers.values():
		_surface_traction_target = minf(_surface_traction_target, modifier.x)
		_surface_steering_target = minf(_surface_steering_target, modifier.y)

func get_surface_traction_factor() -> float:
	return _surface_traction_factor

func get_surface_steering_factor() -> float:
	return _surface_steering_factor


## Shared damage entry point for both modes. Ignored once destroyed.
func take_damage(amount: float, module: StringName = &"body", source: Node = null) -> void:
	if not alive or amount <= 0.0 or not is_finite(amount):
		return
	last_weapon_id = _pending_weapon_id
	_pending_weapon_id = &""
	if has_meta("player_vehicle"):
		amount *= AccessibilitySettings.player_damage_multiplier()
	amount *= 1.0 - clampf(config.damage_resistance, 0.0, 0.75)
	var before := health
	var stage_before := damage.visual_stage()
	var wheels_before := damage.wheels
	damage.apply(amount, module)
	if damage.wheels < wheels_before:
		_wheels_repair_cooldown = config.wheels_repair_delay
		var source_2d := source as Node2D
		if source_2d != null:
			# A damaged left/right wheel assembly gives the car a restrained pull
			# only while rolling. It communicates the fault without stealing
			# steering control from the player.
			var local_source := to_local(source_2d.global_position)
			if absf(local_source.y) > 1.0:
				_wheel_pull_direction = signf(local_source.y)
	if health < before:
		last_attacker = source
		damaged.emit(self, before - health, source)
	if effects != null:
		var local_hit := Vector2.ZERO
		var source_2d := source as Node2D
		if source_2d != null:
			var source_direction := to_local(source_2d.global_position).normalized()
			local_hit = Vector2(source_direction.x * get_visual_size().x, source_direction.y * get_visual_size().y) * 0.38
		effects.impact(clampf(amount / config.max_health, 0.1, 1.0), local_hit)
	var stage_after := damage.visual_stage()
	if stage_after != stage_before:
		damage_stage_changed.emit(self, stage_after)
	if health <= 0.0:
		_die()
	elif _animation_player != null and _animation_player.has_animation("hit_flash"):
		_animation_player.play("hit_flash")


func take_weapon_damage(amount: float, module: StringName, source: Node, weapon_id: StringName) -> void:
	_pending_weapon_id = weapon_id
	take_damage(amount, module, source)


func _die() -> void:
	if not alive: return
	alive = false
	remove_from_group("combatants")
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	fire = false
	_handbrake_strength = 0.0
	_delivered_throttle = 0.0
	if gun != null:
		gun.set_firing(false)
		gun.set_enabled(false)
		gun.set_physics_process(false)
	weapon_time_remaining = 0.0
	boost_time_remaining = 0.0
	ram_boost_time_remaining = 0.0
	apex_boost_time_remaining = 0.0
	passive_feedback_time_remaining = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	# Changing physics state mid-step must be deferred.
	call_deferred("_disable_destroyed_physics")
	if effects != null:
		effects.explode()
	if _animation_player != null and _animation_player.has_animation("destroyed"):
		_animation_player.play("destroyed")
	died.emit(self)


## Derby ramming: when two combatant cars collide above the minimum closing
## speed, both take damage proportional to the impact. Each car handles its own
## contact, so the hit is applied symmetrically without double counting.
func _on_body_entered(body: Node) -> void:
	if not alive or body == null:
		return
	var collider_id := body.get_instance_id()
	if float(_collision_cooldowns.get(collider_id, 0.0)) > 0.0:
		return
	var other := body as Vehicle
	var barrel := body.get_parent() as ExplosiveBarrel
	if barrel != null and not barrel.destroyed:
		var barrel_direction := barrel.global_position - global_position
		var barrel_speed := _closing_speed_against_static(barrel_direction)
		_collision_cooldowns[collider_id] = maxf(config.impact_cooldown, 0.35)
		barrel.receive_ram(barrel_speed, self)
		_emit_impact_feedback(barrel_speed)
		return

	var closing_speed := 0.0
	var impact_direction := _last_velocity.normalized()
	var incoming_mass := config.mass
	var incoming_power := 1.0
	var material_factor := float(body.get_meta("impact_factor", 1.0))
	if other != null:
		var between := other.global_position - global_position
		var normal := between.normalized()
		var relative_velocity := _last_velocity - other.get_last_velocity()
		var previous_relative := _previous_velocity - other._previous_velocity
		if not normal.is_zero_approx():
			closing_speed = maxf(absf(relative_velocity.dot(normal)), absf(previous_relative.dot(normal)))
		else:
			closing_speed = maxf(relative_velocity.length(), previous_relative.length())
		impact_direction = normal if not normal.is_zero_approx() else relative_velocity.normalized()
		incoming_mass = other.config.mass
		var other_contact := (-normal).rotated(-other.global_rotation)
		var other_hit_front: bool = other_contact.x > 0.55
		incoming_power = other.config.ram_power if other_hit_front else 1.0
		if other_hit_front and other.config.passive_id == &"reinforced_ram":
			other._trigger_passive_feedback(1.1)
		if other.is_ram_boost_active():
			incoming_power *= other.config.boost_ram_multiplier
		# Give the heavier chassis the smaller velocity change. Godot resolves
		# penetration; this extra normal impulse makes a fast impact separate
		# cleanly instead of letting tire friction glue the cars together.
		if not normal.is_zero_approx():
			var approach_speed := maxf(relative_velocity.dot(normal), previous_relative.dot(normal))
			if approach_speed > 18.0:
				var reduced_mass := mass * other.mass / maxf(mass + other.mass, 1.0)
				apply_central_impulse(-normal * reduced_mass * approach_speed * 0.42)
	else:
		closing_speed = maxf(_last_velocity.length(), _previous_velocity.length())

	_collision_cooldowns[collider_id] = maxf(config.impact_cooldown, 0.35)
	_emit_impact_feedback(closing_speed)
	if not is_in_group("combatants"):
		return
	if other != null and (not other.alive or not other.is_in_group("combatants")):
		return
	# Coordinated elite squads still collide physically, but should not erase
	# themselves through formation contact. Vehicles without a squad remain
	# hostile to everybody, so the Referee can keep bulldozing ordinary bots.
	if other != null and _same_combat_squad(other):
		return
	if other == null and not body is StaticBody2D:
		return
	# A rider survives bullets by evasion, not by absorbing a second crash.
	# Formation contacts with other Referee units are handled above.
	if bool(get_meta("biker", false)) and closing_speed > 8.0:
		take_damage(maxf(health, 1.0), &"body", other if other != null else body)
		return

	var impact := _calculate_collision_damage(
		closing_speed, incoming_mass, incoming_power, material_factor, impact_direction
	)
	if impact.damage > 0.0:
		var damage_amount: float = impact.damage
		if other == null:
			damage_amount *= STATIC_IMPACT_DAMAGE_SCALE
		_take_collision_damage(damage_amount, impact.module, other if other != null else body)


func _same_combat_squad(other: Vehicle) -> bool:
	if other == null:
		return false
	var squad: StringName = get_meta("squad_id", &"")
	return squad != &"" and StringName(other.get_meta("squad_id", &"")) == squad


func _closing_speed_against_static(direction: Vector2) -> float:
	if direction.is_zero_approx():
		return maxf(_last_velocity.length(), _previous_velocity.length())
	var normal := direction.normalized()
	return maxf(absf(_last_velocity.dot(normal)), absf(_previous_velocity.dot(normal)))


func _calculate_collision_damage(
	closing_speed: float,
	incoming_mass: float,
	incoming_power: float,
	material_factor: float,
	impact_direction: Vector2
) -> Dictionary:
	var module := &"engine" if absf(impact_direction.rotated(-global_rotation).x) >= absf(impact_direction.rotated(-global_rotation).y) else &"wheels"
	if closing_speed <= config.impact_safe_speed:
		return {"damage": 0.0, "module": module}
	var range := maxf(1.0, config.impact_damage_full_speed - config.impact_safe_speed)
	var severity := clampf((closing_speed - config.impact_safe_speed) / range, 0.0, 1.0)
	var base_damage := lerpf(config.impact_min_damage, config.impact_max_damage, pow(severity, 1.35))
	var mass_factor := clampf(sqrt(maxf(incoming_mass, 1.0) / maxf(config.mass, 1.0)), 0.75, 1.35)
	var local_direction := impact_direction.rotated(-global_rotation)
	var zone_factor := config.side_impact_factor
	if absf(local_direction.x) >= absf(local_direction.y):
		zone_factor = config.front_impact_factor if local_direction.x >= 0.0 else config.rear_impact_factor
		if local_direction.x >= 0.0 and is_ram_boost_active():
			zone_factor *= 0.75
	var result := base_damage * mass_factor * maxf(incoming_power, 0.0) * maxf(material_factor, 0.0) * zone_factor
	return {"damage": minf(result, config.impact_damage_cap), "module": module}


func _take_collision_damage(amount: float, module: StringName, source: Node) -> void:
	if amount <= 0.0:
		return
	take_damage(amount, &"body", source)
	if alive and module != &"body":
		var resisted_module_damage := amount * (1.0 - clampf(config.damage_resistance, 0.0, 0.75)) * 0.2
		damage.apply(resisted_module_damage, module)


func _emit_impact_feedback(speed: float) -> void:
	_time_since_impact = 0.0
	if speed < config.impact_min_speed:
		return
	# The same speed feels heavier in a multi-ton chassis. Physics already uses
	# mass for momentum transfer; this mirrors it in camera/audio feedback.
	var momentum_factor := clampf(sqrt(maxf(config.mass, 1.0) / 1000.0), 0.85, 1.45)
	var intensity := clampf(speed / config.impact_full_speed * momentum_factor, 0.0, 1.0)
	impacted.emit(intensity)
	if effects != null:
		effects.impact(intensity)


## Velocity at the start of the current physics step (pre-impact).
func get_last_velocity() -> Vector2:
	return _last_velocity


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Teleporting a RigidBody2D must happen inside the physics step, otherwise
	# the velocity from the previous step is integrated again.
	if _pending_reset:
		_pending_reset = false
		_reverse_hold = 0.0
		_player_reverse = false
		_steering_input = 0.0
		state.transform = Transform2D(_reset_angle, _reset_position)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		return
	if not alive:
		return
	_previous_velocity = _last_velocity
	_last_velocity = state.linear_velocity
	_apply_physics(state, state.step)


func _apply_physics(state: PhysicsDirectBodyState2D, dt: float) -> void:
	if dt <= 0.0:
		return

	var effective_speed := get_current_max_speed() * damage.engine_factor()
	var emp_factor := 0.52 if is_emp_disabled() else 1.0
	effective_speed *= emp_factor
	var acceleration_multiplier := config.boost_acceleration_multiplier if is_boost_active() else 1.0
	if is_apex_boost_active():
		acceleration_multiplier = maxf(acceleration_multiplier, config.passive_apex_acceleration_multiplier)
	var effective_acceleration := config.acceleration * acceleration_multiplier * damage.engine_factor() * emp_factor
	var body_rotation := state.transform.get_rotation()
	var forward := Vector2.RIGHT.rotated(body_rotation)
	var right := forward.rotated(-PI * 0.5)

	var velocity := state.linear_velocity
	var forward_speed := velocity.dot(forward)
	var lateral_speed := velocity.dot(right)
	_delivered_throttle = move_toward(
		_delivered_throttle, throttle, dt / maxf(config.throttle_response, 0.05)
	)
	if brake > 0.0 and throttle == 0.0:
		_delivered_throttle = 0.0
	# A full brake press at road speed acts as an arcade handbrake. The speed
	# gate keeps ordinary low-speed braking and reverse unchanged, while the
	# progressive trigger input still allows gentle service braking.
	var handbrake_input := smoothstep(0.22, 0.88, brake)
	var handbrake_speed := smoothstep(
		config.handbrake_min_speed,
		config.handbrake_min_speed + 42.0,
		absf(forward_speed)
	)
	_handbrake_strength = handbrake_input * handbrake_speed

	# --- Forward thrust -----------------------------------------------------
	if _delivered_throttle > 0.0:
		var speed_ratio := forward_speed / effective_speed
		var thrust_multiplier := maxf(0.0, 1.0 - speed_ratio)
		var thrust := _delivered_throttle * effective_acceleration * thrust_multiplier * mass
		state.apply_central_force(forward * thrust)
	elif _delivered_throttle < 0.0:
		var reverse_force := _delivered_throttle * effective_acceleration * 0.3 * mass
		state.apply_central_force(forward * reverse_force)

	# --- Braking ------------------------------------------------------------
	# Oppose the actual direction of travel, otherwise "braking" while moving
	# backwards would accelerate the car further in reverse.
	if brake > 0.0 and absf(forward_speed) > 0.0:
		var braking_efficiency := lerpf(1.0, config.handbrake_brake_multiplier, _handbrake_strength)
		var deceleration := minf(brake * config.brake_force * braking_efficiency, config.brake_deceleration_limit)
		# Braking and rolling drag together must not push velocity through zero.
		var rolling_loss := absf(forward_speed) * (1.0 - config.drag) * lerpf(1.0, 0.25, brake) / dt
		deceleration = minf(deceleration, maxf(0.0, absf(forward_speed) / dt - rolling_loss))
		var brake_force := deceleration * mass * signf(forward_speed)
		state.apply_central_force(-forward * brake_force)

	# --- Lateral friction (traction) ----------------------------------------
	if absf(lateral_speed) > 0.1:
		var rear_grip := lerpf(1.0, config.handbrake_traction_multiplier, _handbrake_strength)
		var corner_load := smoothstep(72.0, maxf(110.0, effective_speed), absf(forward_speed)) * absf(steer)
		var speed_grip := lerpf(1.0, config.high_speed_grip, corner_load)
		var friction_force := -lateral_speed * config.traction * speed_grip * rear_grip * damage.traction_factor() * _surface_traction_factor * mass
		var max_friction := absf(lateral_speed) * mass / dt
		friction_force = clampf(friction_force, -max_friction, max_friction)
		state.apply_central_force(right * friction_force)

	# --- Rolling resistance (drag) ------------------------------------------
	if absf(forward_speed) > 0.1:
		var drag_force := forward_speed * (1.0 - config.drag) * lerpf(1.0, 0.25, brake) * mass / dt
		state.apply_central_force(-forward * drag_force)

	# --- Steering -----------------------------------------------------------
	_steering_input = move_toward(_steering_input, steer, config.steering_input_rate * dt)
	var speed_factor := get_steering_speed_factor(forward_speed)

	# Steering requires rolling speed: pressing A/D while stationary must turn
	# the wheels visually, not spin the whole car in place. A fixed wheel angle
	# turns the body in the opposite direction while reversing.
	var steering_direction := signf(forward_speed)
	var target_angular_velocity := _steering_input * steering_direction * config.steer_rate * damage.steering_factor() * _surface_steering_factor * speed_factor * emp_factor
	# With the rear axle loose, steering initiates the slide more readily. No
	# steering means no artificial spin: braking in a straight line stays stable.
	target_angular_velocity *= 1.0 + config.handbrake_steer_boost * _handbrake_strength * absf(steer)
	if absf(forward_speed) > 24.0 and damage.ratio(&"wheels") < 0.55:
		var pull_strength := (0.55 - damage.ratio(&"wheels")) / 0.55
		target_angular_velocity += _wheel_pull_direction * pull_strength * 0.16 * steering_direction
	var angular_error := target_angular_velocity - state.angular_velocity
	var torque := angular_error * inertia * config.steering_yaw_response
	var max_torque := inertia * config.steer_rate * 5.0
	torque = clampf(torque, -max_torque, max_torque)
	state.apply_torque(torque)

	# --- Angular damping ----------------------------------------------------
	var rotation_retention := lerpf(
		config.angular_damping,
		config.handbrake_angular_damping,
		_handbrake_strength
	)
	state.angular_velocity *= pow(rotation_retention, dt * 60.0)

	# --- Hard max-speed safety clamp ----------------------------------------
	var speed := state.linear_velocity.length()
	if speed > effective_speed:
		state.linear_velocity *= effective_speed / speed


func get_steering_speed_factor(longitudinal_speed: float) -> float:
	var speed := absf(longitudinal_speed)
	var rolling := smoothstep(config.steering_stop_speed, maxf(config.steering_stop_speed + 1.0, config.steering_full_speed), speed)
	var high_start := maxf(config.steering_full_speed, config.steering_high_speed_start)
	var high_end := maxf(high_start + 1.0, get_current_max_speed())
	return rolling * lerpf(1.0, config.steering_high_speed_factor, smoothstep(high_start, high_end, speed))


func _physics_process(delta: float) -> void:
	_time_since_impact += delta
	_surface_traction_factor = move_toward(_surface_traction_factor, _surface_traction_target, delta / 0.6)
	_surface_steering_factor = move_toward(_surface_steering_factor, _surface_steering_target, delta / 0.6)
	for collider_id in _collision_cooldowns.keys():
		var remaining: float = float(_collision_cooldowns[collider_id]) - delta
		if remaining <= 0.0:
			_collision_cooldowns.erase(collider_id)
		else:
			_collision_cooldowns[collider_id] = remaining
	_update_temporary_bonuses(delta)
	if _wheels_repair_cooldown > 0.0:
		_wheels_repair_cooldown = maxf(0.0, _wheels_repair_cooldown - delta)
	elif alive and damage.wheels < config.wheels_health:
		damage.repair_wheels(config.wheels_repair_rate * delta)


func _process(_delta: float) -> void:
	# Steering, animated bonuses and their final frame must all stay current.
	queue_redraw()


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

func get_speed() -> float:
	return linear_velocity.length()


func get_forward_speed() -> float:
	return linear_velocity.dot(Vector2.RIGHT.rotated(rotation))


func get_lateral_speed() -> float:
	var forward := Vector2.RIGHT.rotated(rotation)
	return linear_velocity.dot(forward.rotated(-PI * 0.5))


func get_handbrake_strength() -> float:
	return _handbrake_strength


func activate_temporary_weapon(weapon_config: WeaponConfig, duration: float = 30.0) -> void:
	if not alive or gun == null or weapon_config == null:
		return
	gun.equip(weapon_config)
	gun.set_physics_process(true)
	weapon_time_remaining = maxf(duration * get_bonus_duration_multiplier(), 0.0)
	if config.passive_id in [&"salvager", &"weapon_overdrive"]:
		_trigger_passive_feedback(1.2)
	queue_redraw()


func activate_boost(duration: float = 10.0) -> void:
	if not alive:
		return
	ram_boost_time_remaining = 0.0
	boost_time_remaining = maxf(boost_time_remaining, maxf(duration * get_bonus_duration_multiplier(), 0.0))
	if config.passive_id == &"salvager":
		_trigger_passive_feedback(1.2)
	queue_redraw()


func is_boost_active() -> bool:
	return alive and boost_time_remaining > 0.0


func activate_ram_boost(duration: float = 9.0) -> void:
	if not alive:
		return
	boost_time_remaining = 0.0
	ram_boost_time_remaining = maxf(ram_boost_time_remaining, maxf(duration * get_bonus_duration_multiplier(), 0.0))
	if config.passive_id == &"salvager":
		_trigger_passive_feedback(1.2)
	queue_redraw()


func is_ram_boost_active() -> bool:
	return alive and ram_boost_time_remaining > 0.0


func apply_emp(duration: float) -> void:
	if not alive:
		return
	var resistance := 0.65 if config != null and config.vehicle_class == VehicleConfig.VehicleClass.JUGGERNAUT else 1.0
	emp_time_remaining = maxf(emp_time_remaining, maxf(0.0, duration * resistance))
	if effects != null:
		effects.impact(0.7)
	queue_redraw()


func is_emp_disabled() -> bool:
	return alive and emp_time_remaining > 0.0


func repair(body_amount: float = 28.0, engine_amount: float = 22.0, wheels_amount: float = 24.0) -> void:
	if not alive or config == null:
		return
	var stage_before := damage.visual_stage()
	var health_before := damage.body
	damage.body = minf(config.max_health, damage.body + maxf(body_amount, 0.0))
	damage.engine = minf(config.engine_health, damage.engine + maxf(engine_amount, 0.0))
	damage.wheels = minf(config.wheels_health, damage.wheels + maxf(wheels_amount, 0.0))
	_wheels_repair_cooldown = 0.0
	_wheel_pull_direction = 0.0
	if effects != null and damage.body > health_before:
		effects.repair_feedback(false)
	if damage.visual_stage() != stage_before:
		damage_stage_changed.emit(self, damage.visual_stage())
	queue_redraw()


func repair_full() -> void:
	if not alive or config == null:
		return
	var stage_before := damage.visual_stage()
	damage.reset(config)
	_wheels_repair_cooldown = 0.0
	_wheel_pull_direction = 0.0
	if effects != null:
		effects.reset()
		effects.repair_feedback(true)
	if stage_before != 0:
		damage_stage_changed.emit(self, 0)
	queue_redraw()


func has_temporary_weapon() -> bool:
	return alive and weapon_time_remaining > 0.0 and gun != null and gun.enabled


func get_current_max_speed() -> float:
	if config == null:
		return 1.0
	var multiplier := config.boost_speed_multiplier if is_boost_active() else 1.0
	if is_apex_boost_active():
		multiplier = maxf(multiplier, config.passive_apex_speed_multiplier)
	return minf(config.max_speed * multiplier, 200.0)


func get_bonus_duration_multiplier() -> float:
	if config != null and config.passive_id == &"salvager":
		return maxf(config.passive_bonus_duration_multiplier, 1.0)
	return 1.0


func get_weapon_damage_multiplier() -> float:
	var multiplier := maxf(config.weapon_damage_multiplier, 1.0) if config != null else 1.0
	if config != null and config.passive_id == &"weapon_overdrive":
		multiplier *= maxf(config.passive_weapon_damage_multiplier, 1.0)
	return multiplier


func get_weapon_fire_rate_multiplier() -> float:
	return maxf(config.weapon_fire_rate_multiplier, 1.0) if config != null else 1.0


func notify_clean_corner() -> bool:
	if config == null or config.passive_id != &"apex_boost":
		return false
	if _apex_cooldown_remaining > 0.0 or _time_since_impact < 1.25:
		return false
	if get_speed() < config.max_speed * 0.55:
		return false
	if absf(get_lateral_speed()) > maxf(22.0, get_speed() * 0.34):
		return false
	apex_boost_time_remaining = maxf(apex_boost_time_remaining, config.passive_apex_duration)
	_apex_cooldown_remaining = config.passive_apex_cooldown
	_trigger_passive_feedback(config.passive_apex_duration)
	return true


func is_apex_boost_active() -> bool:
	return alive and apex_boost_time_remaining > 0.0


func _trigger_passive_feedback(duration: float) -> void:
	passive_feedback_time_remaining = maxf(passive_feedback_time_remaining, duration)
	queue_redraw()


func _update_temporary_bonuses(delta: float) -> void:
	var had_visual_effect := boost_time_remaining > 0.0 or ram_boost_time_remaining > 0.0 or emp_time_remaining > 0.0 or apex_boost_time_remaining > 0.0 or passive_feedback_time_remaining > 0.0
	if weapon_time_remaining > 0.0:
		weapon_time_remaining = maxf(0.0, weapon_time_remaining - delta)
		if weapon_time_remaining <= 0.0 and gun != null:
			gun.set_enabled(false)
			gun.set_firing(false)
	if boost_time_remaining > 0.0:
		boost_time_remaining = maxf(0.0, boost_time_remaining - delta)
	if ram_boost_time_remaining > 0.0:
		ram_boost_time_remaining = maxf(0.0, ram_boost_time_remaining - delta)
	if emp_time_remaining > 0.0:
		emp_time_remaining = maxf(0.0, emp_time_remaining - delta)
	if apex_boost_time_remaining > 0.0:
		apex_boost_time_remaining = maxf(0.0, apex_boost_time_remaining - delta)
	if _apex_cooldown_remaining > 0.0:
		_apex_cooldown_remaining = maxf(0.0, _apex_cooldown_remaining - delta)
	if passive_feedback_time_remaining > 0.0:
		passive_feedback_time_remaining = maxf(0.0, passive_feedback_time_remaining - delta)
	if had_visual_effect and boost_time_remaining <= 0.0 and ram_boost_time_remaining <= 0.0 and emp_time_remaining <= 0.0 and apex_boost_time_remaining <= 0.0 and passive_feedback_time_remaining <= 0.0:
		queue_redraw()


# ---------------------------------------------------------------------------
# Rendering (local space; the node transform handles rotation)
# ---------------------------------------------------------------------------

func get_visual_size() -> Vector2:
	if config == null:
		return Vector2.ZERO
	return Vector2(config.length, config.width) * VISUAL_SCALE

func _draw() -> void:
	if config == null:
		return

	_draw_boost_flame()
	_draw_emp_feedback()
	# Artwork and the collision polygon now use the same effective footprint;
	# the polygon only excludes transparent sprite margins.
	var visual_length := config.length * VISUAL_SCALE
	var visual_width := config.width * VISUAL_SCALE
	var half_l := visual_length * 0.5
	var body_rect := Rect2(
		Vector2(-half_l, -visual_width * 0.5),
		Vector2(visual_length, visual_width)
	)
	var is_referee_biker := bool(get_meta("biker", false)) or config.vehicle_id == &"referee_biker"

	if config.texture != null:
		# Image-driven look: swap the texture in VehicleConfig, no code changes.
		# A tight alpha-matched contact shadow seats the top-down chassis on the
		# road and adds mass without adding a visible selection frame.
		var texture_rect := body_rect
		var texture_rotation := deg_to_rad(config.texture_rotation_degrees)
		if not is_zero_approx(texture_rotation):
			# Portrait sprites are authored pointing to the top of the source image.
			# Swap the target axes before rotating so the world-space silhouette
			# still matches the configured length and width.
			texture_rect = Rect2(
				Vector2(-visual_width * 0.5, -visual_length * 0.5),
				Vector2(visual_width, visual_length)
			)
			draw_set_transform(Vector2.ZERO, texture_rotation)
		var shadow_rect := Rect2(texture_rect.position + Vector2(3.5, 4.5), texture_rect.size)
		draw_texture_rect(config.texture, shadow_rect, false, Color(0.015, 0.012, 0.01, 0.42))
		draw_texture_rect(config.texture, texture_rect, false)
		if not is_zero_approx(texture_rotation):
			draw_set_transform(Vector2.ZERO, 0.0)
	else:
		var vertices := _body_vertices(visual_length, visual_width)
		draw_colored_polygon(vertices, config.body_color)
		var closed := vertices + PackedVector2Array([vertices[0]])
		draw_polyline(closed, config.outline_color, 2.0, true)
	if is_referee_biker:
		# The transparent sprite carries the silhouette. Only physical lights are
		# added in code, so readability does not turn the bike into a UI capsule.
		draw_circle(Vector2(visual_length * 0.42, 0.0), 2.0, Color(1.0, 0.88, 0.46, 0.96))
		draw_circle(Vector2(-visual_length * 0.42, 0.0), 1.8, Color(1.0, 0.055, 0.025, 0.96))
	_draw_ram_boost(visual_length, visual_width)
	_draw_active_weapon(visual_length)
	if not config.debug_vectors:
		return
	draw_circle(Vector2(half_l, 0.0), 3.0, config.front_marker_color)
	draw_line(Vector2.ZERO, Vector2(half_l * 1.5, 0.0), Color.WHITE, 2.0, true)

	var local_velocity := linear_velocity.rotated(-rotation) * _velocity_debug_scale
	draw_line(Vector2.ZERO, local_velocity, config.velocity_vector_color, 1.0, true)


func _body_vertices(body_length: float, body_width: float) -> PackedVector2Array:
	var bevel := body_width * config.corner_bevel_ratio
	var half_length := body_length * 0.5
	var half_width := body_width * 0.5
	return PackedVector2Array([
		Vector2(half_length - bevel, half_width),
		Vector2(half_length, half_width - bevel),
		Vector2(half_length, -half_width + bevel),
		Vector2(half_length - bevel, -half_width),
		Vector2(-half_length + bevel, -half_width),
		Vector2(-half_length, -half_width + bevel),
		Vector2(-half_length, half_width - bevel),
		Vector2(-half_length + bevel, half_width),
	])


func _draw_boost_flame() -> void:
	if not is_boost_active() and not is_apex_boost_active():
		return
	var pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.025)
	var rear_x := -config.length * 0.72
	var flame_length := 28.0 * pulse
	for side in [-1.0, 1.0]:
		var y: float = float(side) * config.width * 0.27
		draw_colored_polygon(PackedVector2Array([
			Vector2(rear_x + 6.0, y - 4.0),
			Vector2(rear_x - flame_length, y),
			Vector2(rear_x + 6.0, y + 4.0),
		]), Color(1.0, 0.28, 0.03, 0.9))
		draw_colored_polygon(PackedVector2Array([
			Vector2(rear_x + 4.0, y - 2.0),
			Vector2(rear_x - flame_length * 0.58, y),
			Vector2(rear_x + 4.0, y + 2.0),
		]), Color(1.0, 0.88, 0.18, 0.95))


func _draw_ram_boost(vehicle_length: float, vehicle_width: float) -> void:
	if not is_ram_boost_active():
		return
	var pulse := 0.72 + 0.28 * sin(Time.get_ticks_msec() * 0.018)
	var front_x := vehicle_length * 0.5
	var half_width := vehicle_width * 0.42
	draw_line(Vector2(front_x, -half_width), Vector2(front_x, half_width), Color(1.0, 0.34, 0.04, 0.5 * pulse), 8.0, true)
	draw_line(Vector2(front_x, -half_width), Vector2(front_x, half_width), Color(1.0, 0.78, 0.18, 0.95), 2.5, true)


func _draw_emp_feedback() -> void:
	if not is_emp_disabled() or config == null:
		return
	var pulse := 0.65 + sin(Time.get_ticks_msec() * 0.022) * 0.25
	var radius := maxf(config.length, config.width) * VISUAL_SCALE * 0.58
	draw_arc(Vector2.ZERO, radius, -0.4, PI * 0.75, 14, Color(0.2, 0.9, 1.0, pulse), 2.0, true)
	draw_arc(Vector2.ZERO, radius * 0.72, PI * 0.8, PI * 1.85, 12, Color(0.45, 0.75, 1.0, pulse), 1.5, true)


func _draw_active_weapon(vehicle_length: float) -> void:
	if not has_temporary_weapon() or gun.config.texture == null:
		return
	var source_size := Vector2(gun.config.texture.get_size())
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var width := vehicle_length * clampf(gun.config.preview_scale, 0.18, 0.34)
	var weapon_size := Vector2(width, width * source_size.y / source_size.x)
	# Keep the temporary roof module within the car silhouette.
	var max_height := config.width * VISUAL_SCALE * 0.62
	if weapon_size.y > max_height:
		weapon_size *= max_height / weapon_size.y
	draw_texture_rect(gun.config.texture, Rect2(-weapon_size * 0.5, weapon_size), false)

# ---------------------------------------------------------------------------
# Restart helper
# ---------------------------------------------------------------------------

## Places the vehicle at a start position and clears all motion.
##
## The actual teleport is applied on the next physics step (see
## `_integrate_forces`), which is the only safe way to move a RigidBody2D.
func reset_to(position: Vector2, angle: float) -> void:
	alive = true
	last_attacker = null
	last_weapon_id = &""
	_pending_weapon_id = &""
	damage.reset(config)
	if effects != null:
		effects.reset()
	modulate = _base_modulate
	collision_layer = _default_layer
	collision_mask = _default_mask
	freeze = false
	if _animation_player != null:
		_animation_player.stop()
	if gun != null:
		gun.reset()
		gun.set_enabled(false)
		gun.set_physics_process(true)
	weapon_time_remaining = 0.0
	boost_time_remaining = 0.0
	ram_boost_time_remaining = 0.0
	emp_time_remaining = 0.0
	apex_boost_time_remaining = 0.0
	passive_feedback_time_remaining = 0.0
	_apex_cooldown_remaining = 0.0
	_time_since_impact = 99.0
	_wheels_repair_cooldown = 0.0
	_wheel_pull_direction = 0.0
	_handbrake_strength = 0.0
	_delivered_throttle = 0.0
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	fire = false
	sleeping = false
	_reset_position = position
	_reset_angle = angle
	_pending_reset = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_last_velocity = Vector2.ZERO
	_previous_velocity = Vector2.ZERO


## Starts another survival wave without erasing the consequences of the run.
func reset_for_next_wave(position: Vector2, angle: float, repair_fraction: float) -> void:
	var old_body := damage.body
	var old_engine := damage.engine
	var old_wheels := damage.wheels
	reset_to(position, angle)
	var fraction := clampf(repair_fraction, 0.0, 1.0)
	damage.body = minf(config.max_health, old_body + (config.max_health - old_body) * fraction)
	damage.engine = minf(config.engine_health, old_engine + (config.engine_health - old_engine) * fraction)
	damage.wheels = minf(config.wheels_health, old_wheels + (config.wheels_health - old_wheels) * fraction)
	queue_redraw()
	_collision_cooldowns.clear()
	_surface_modifiers.clear()
	_surface_traction_target = 1.0
	_surface_steering_target = 1.0


## Shared runtime HUD contract for both modes; health values are normalized.
func get_hud_state() -> Dictionary:
	var bonus_name := "НЕТ БОНУСА"
	var bonus_state := "ИЩИТЕ ЯЩИК"
	if has_temporary_weapon():
		bonus_name = gun.config.display_name
		bonus_state = "%.1f С · %s" % [weapon_time_remaining, gun.ammo_state()]
	if is_boost_active():
		if has_temporary_weapon():
			bonus_state += "  ·  BOOST %.1f С" % boost_time_remaining
		else:
			bonus_name = "УСКОРЕНИЕ"
			bonus_state = "%.1f С" % boost_time_remaining
	elif is_ram_boost_active():
		if has_temporary_weapon():
			bonus_state += "  ·  ТАРАН %.1f С" % ram_boost_time_remaining
		else:
			bonus_name = "УСИЛЕННЫЙ ТАРАН"
			bonus_state = "%.1f С" % ram_boost_time_remaining
	if is_emp_disabled():
		bonus_state += " · ЭМИ %.1f С" % emp_time_remaining
	return {
		"speed": get_speed(),
		"damage_stage": damage.visual_stage(),
		"body_health": damage.ratio(&"body"),
		"engine_health": damage.ratio(&"engine"),
		"wheels_health": damage.ratio(&"wheels"),
		"critical_module": damage.critical_module(),
		"weapon_name": bonus_name,
		"weapon_state": "ОТКЛЮЧЕНО" if not alive else bonus_state,
		"weapon_texture": gun.config.texture if has_temporary_weapon() else null,
		"weapon_role": gun.config.tactical_role if has_temporary_weapon() else "ДОСТАВКА НА КАРТЕ",
		"passive_state": _passive_hud_state(),
	}


func _passive_hud_state() -> String:
	if config == null or config.passive_name.is_empty():
		return "КЛАСС · СТАНДАРТ"
	match config.passive_id:
		&"salvager":
			return "%s · БОНУСЫ ×%.2f" % [config.passive_name, get_bonus_duration_multiplier()]
		&"apex_boost":
			if is_apex_boost_active():
				return "%s · %.1f С" % [config.passive_name, apex_boost_time_remaining]
			return "%s · %s" % [config.passive_name, "ГОТОВО" if _apex_cooldown_remaining <= 0.0 else "ПЕРЕЗАРЯДКА"]
		&"weapon_overdrive":
			return "%s · %s" % [config.passive_name, "+%d%% УРОН" % roundi((get_weapon_damage_multiplier() - 1.0) * 100.0) if has_temporary_weapon() else "ЖДЕТ ОРУЖИЕ"]
		&"reinforced_ram":
			return "%s · %s" % [config.passive_name, "УДАР!" if passive_feedback_time_remaining > 0.0 else "ФРОНТАЛЬНО"]
	return "%s · ГОТОВО" % config.passive_name


func _disable_destroyed_physics() -> void:
	if not alive:
		collision_layer = 0
		collision_mask = 0
		freeze = true
