extends Node
class_name ArenaBot
## Battle-royale AI driver.
##
## Hunts the nearest living car, steers around obstacles and the arena walls,
## and fires when the target is in front. Like [BotController] it only emits
## the shared command contract, so it reuses [Vehicle] physics and weapons.

## Arena used for obstacle and wall avoidance. Injected by the survival mode.
@export var arena: Arena

enum Strategy { BRAWLER, HUNTER, SCAVENGER, SURVIVOR }
enum TeamRole { NONE, VANGUARD, FLANKER, SUPPORT }
@export var strategy: Strategy = Strategy.HUNTER
@export var team_role: TeamRole = TeamRole.NONE
@export var focus_player := false
## Used by special units whose weapon cadence is controlled by a boss module.
@export var external_weapon_control := false

@export_group("Driving")
@export_range(0.0, 1.0, 0.05) var cruise_throttle: float = 0.9
@export_range(0.1, 10.0, 0.1) var steer_gain: float = 2.5
@export_range(0.0, 3.0, 0.05) var ease_angle: float = 0.5
@export_range(0.0, 3.0, 0.05) var brake_angle: float = 1.3
## Distance at which the bot eases off the throttle to keep its nose on target.
@export_range(0.0, 1000.0, 10.0) var preferred_range: float = 240.0

@export_group("Avoidance")
@export_range(10.0, 400.0, 5.0) var avoid_radius: float = 90.0
@export_range(0.0, 5.0, 0.1) var avoid_weight: float = 1.6
@export_range(0.0, 400.0, 5.0) var wall_avoid_margin: float = 70.0
@export_range(20.0, 400.0, 5.0) var hazard_avoid_radius: float = 120.0

@export_group("Combat")
@export_range(0.0, 2000.0, 10.0) var fire_range: float = 420.0
@export_range(0.0, 3.14, 0.01) var fire_angle: float = 0.22
@export_range(0.0, 1.0, 0.05) var retreat_health_ratio: float = 0.28
@export_range(0.0, 3.0, 0.1) var retreat_weight: float = 1.4

@export_group("Recovery")
@export_range(0.0, 200.0, 5.0) var stuck_speed: float = 20.0
@export_range(0.0, 10.0, 0.1) var stuck_timeout: float = 1.2
@export_range(0.0, 10.0, 0.1) var reverse_duration: float = 0.8

var vehicle: Vehicle
var _stuck_timer := 0.0
var _reversing := 0.0
var _recovery_steer := 1.0
var _last_steer := 0.0
var _last_throttle := 0.0
var _locked_pickup: BonusPickup
var _victim: Vehicle
var _intent: StringName = &"pursue"
var _intent_age := 0.0
var _intent_goal := Vector2.ZERO
var _reaction_clock := 0.0
var _reaction_interval := 0.32
var _passing_side := 1.0
var _turn_side := 0.0
var _nav: RefCounted
var _clearance := 24.0
var _path := PackedVector2Array()
var _path_index := 0
var _path_origin := Vector2.ZERO
var _path_goal := Vector2.ZERO
var _path_clock := 0.0
var _progress_anchor := Vector2.ZERO
var _drive_time := 0.0
var _pickup_ignore_until: Dictionary = {}
var _pickup_progress := INF
var _pickup_stall := 0.0
var _route_status: StringName = &"NONE"
var _resolved_goal := Vector2.ZERO
var _traffic_stall := 0.0
var _yield_until := 0.0
var _yield_cooldown := 0.0
var _yield_goal := Vector2.ZERO
var _traffic_peer: Vehicle
var yield_manoeuvres := 0
var _recovery_shape: ConvexPolygonShape2D
var _no_route_recoveries := 0
var _traffic_nav: RefCounted
var _detour_until := 0.0
var _detour_retry := 0.0
var _spawn_position := Vector2.ZERO
var _failed_yields: Array[Dictionary] = []
var _reverse_observed := false
var _recovery_retry := 0.0
var _blocked_reverse_position := Vector2(INF, INF)
var _blocked_reverse_angle := 0.0
var _blocked_peer_position := Vector2(INF, INF)
var _blocked_reverse_room := 0.0
var _blocked_reverse_arc := false
var _forward_escape_until := 0.0
var recovery_requested := 0
var recovery_started := 0
var recovery_completed := 0
var recovery_cancelled := 0
var recovery_rejected := 0
var traffic_detours := 0
var traffic_reason: StringName = &"clear"
var _waiting_for_peer := false
var _detour_signature: Array = []


func _ready() -> void:
	vehicle = get_parent() as Vehicle
	_spawn_position = vehicle.global_position
	# Geometry/spawn order is stable across unrelated ObjectDB allocations.
	var slot := absi(roundi(_spawn_position.x / 24.0) + roundi(_spawn_position.y / 24.0))
	_passing_side = -1.0 if slot % 2 == 0 else 1.0
	_recovery_steer = _passing_side
	_reaction_interval = 0.28 + float(slot % 4) * 0.04
	_progress_anchor = vehicle.global_position
	_apply_strategy()
	_apply_class_tactics()
	_recovery_shape = ConvexPolygonShape2D.new()
	var footprint := vehicle.config.get_body_vertices()
	for index in footprint.size(): footprint[index] *= Vehicle.COLLISION_SCALE
	_recovery_shape.points = footprint
	if arena != null:
		_nav = arena.navigation()
		_clearance = _nav.clearance(vehicle)


func _physics_process(delta: float) -> void:
	if vehicle == null or not vehicle.alive:
		return
	var commands := get_commands(delta)
	vehicle.apply_control(commands["throttle"], commands["brake"], commands["steer"],
		false if external_weapon_control else commands["fire"])


## Tactical choices have a human reaction interval; steering continuously
## follows the chosen route using the car's current speed and yaw rate.
func get_commands(delta: float = 0.0) -> Dictionary:
	_drive_time += delta
	_watch_pickup_progress(delta)
	_update_intent(delta)
	_update_traffic_yield(delta)
	_update_path(delta)
	var position := vehicle.global_position
	var forward := Vector2.RIGHT.rotated(vehicle.rotation)
	var speed := vehicle.get_speed()
	var forward_speed := vehicle.linear_velocity.dot(forward)
	var lookahead := clampf(avoid_radius * 0.45 + speed * 0.55, 55.0, 145.0)
	var aim := _path_aim(lookahead)
	var to_aim := aim - position
	var error := forward.angle_to(to_aim)
	# A target directly behind the car must not alternate left/right at +/-PI.
	if absf(error) > 1.65:
		if _turn_side == 0.0: _turn_side = signf(error) if absf(error) < 3.05 else _passing_side
		error = absf(error) * _turn_side
	elif absf(error) < 1.1:
		_turn_side = 0.0
	var curvature := 2.0 * sin(clampf(error, -PI * 0.5, PI * 0.5)) / maxf(to_aim.length(), 40.0)
	var max_speed := vehicle.get_current_max_speed() * vehicle.damage.engine_factor()
	var lateral_acceleration := 110.0 if _is_biker() else (62.0 if _is_boss() else 88.0)
	lateral_acceleration *= vehicle.damage.traction_factor() * vehicle.get_surface_traction_factor()
	var desired_speed := max_speed * clampf(cruise_throttle, 0.45, 0.95)
	if _nav != null and _path.is_empty():
		desired_speed = 0.0
	var waiting_for_goal := false
	if _nav != null and _route_status == &"NEAREST":
		var remaining := position.distance_to(_resolved_goal)
		desired_speed = minf(desired_speed, sqrt(2.0 * vehicle.config.brake_deceleration_limit * maxf(0.0, remaining - 18.0)))
		waiting_for_goal = remaining < 26.0
	elif _nav != null and _route_status == &"NONE":
		waiting_for_goal = _nav.point_clear(position, _clearance) or _no_route_recoveries >= 2
	waiting_for_goal = waiting_for_goal or _waiting_for_peer
	if _intent == &"supply":
		desired_speed = minf(desired_speed, maxf(28.0, position.distance_to(_intent_goal) * 1.15))
	desired_speed = minf(desired_speed, sqrt(maxf(25.0, lateral_acceleration) / maxf(absf(curvature), 0.001)))
	if absf(error) > 1.45: desired_speed = minf(desired_speed, 42.0 if not _is_boss() else 32.0)
	var service_deceleration := minf(vehicle.config.brake_deceleration_limit, maxf(80.0, vehicle.config.brake_force * 0.19))
	if _path_index + 1 < _path.size():
		var next_leg := _path[_path_index + 1] - _path[_path_index]
		var bend := absf(to_aim.angle_to(next_leg))
		var corner_speed := lerpf(max_speed, 42.0, smoothstep(0.2, 1.6, bend))
		var corner_distance := position.distance_to(_path[_path_index])
		desired_speed = minf(desired_speed, sqrt(corner_speed * corner_speed + 2.0 * service_deceleration * maxf(0.0, corner_distance - lookahead)))
	if _nav != null:
		var travel := vehicle.linear_velocity.normalized() if speed > 1.0 else forward
		var room: float = _nav.free_distance(position, travel, 260.0, vehicle.config.length * Vehicle.COLLISION_SCALE.x * 0.5 + 5.0)
		desired_speed = minf(desired_speed, sqrt(2.0 * service_deceleration * maxf(0.0, room - 12.0)) * 0.82)
	desired_speed = _traffic_speed(desired_speed, forward)
	if _drive_time < _forward_escape_until:
		# Footprint-limited forward creep when backing toward a wall cannot work.
		var room := _motion_room(forward, 65.0)
		desired_speed = minf(28.0, maxf(0.0, room - 5.0) * 1.4)
	if _waiting_for_peer: desired_speed = 0.0
	var target_yaw := maxf(absf(forward_speed), 24.0) * curvature
	var yaw_limit := 1.55 if _is_boss() else (2.2 if _is_biker() else 1.9)
	target_yaw = clampf(target_yaw, -yaw_limit, yaw_limit)
	var speed_factor := vehicle.get_steering_speed_factor(forward_speed)
	# Match Vehicle's steering response, including damping. Counter-yaw removes
	# overshoot before the nose crosses the intended heading.
	var nominal_yaw := vehicle.config.steer_rate * maxf(speed_factor, 0.35) * vehicle.damage.steering_factor() * 0.76
	var steer := clampf((target_yaw + (target_yaw - vehicle.angular_velocity) * 0.18) / maxf(nominal_yaw, 0.3), -1.0, 1.0)
	var acceleration := vehicle.config.acceleration * vehicle.damage.engine_factor() * maxf(0.12, 1.0 - maxf(forward_speed, 0.0) / maxf(max_speed, 1.0))
	var rolling_drag := maxf(forward_speed, 0.0) * (1.0 - vehicle.config.drag) * Engine.physics_ticks_per_second
	var throttle := clampf((rolling_drag + (desired_speed - forward_speed) * 2.7) / maxf(acceleration, 1.0), 0.0, cruise_throttle)
	var brake := 0.0
	# No minimum crawl into a blocked corridor: let the recovery manoeuvre
	# take over once the vehicle has actually stopped.
	if desired_speed < 5.0:
		throttle = 0.0
	if speed > desired_speed + 4.0:
		throttle = 0.0
		# Stay below handbrake activation: normal AI cornering uses service brake.
		brake = clampf((speed - desired_speed) * 3.2 / vehicle.config.brake_force, 0.0, 0.21)
	if position.distance_to(_progress_anchor) > 12.0:
		_progress_anchor = position
		_stuck_timer = 0.0
	elif speed < 12.0 and not vehicle.is_emp_disabled() and not waiting_for_goal:
		_stuck_timer += delta
	else:
		_stuck_timer = maxf(0.0, _stuck_timer - delta)
	if not waiting_for_goal and _reversing <= 0.0 and _stuck_timer >= maxf(stuck_timeout, 1.05) and _drive_time >= _recovery_retry:
		if _route_status == &"NONE": _no_route_recoveries += 1
		_stuck_timer = 0.0
		if not _request_reverse(-signf(error) if absf(error) > 0.15 else _passing_side, maxf(reverse_duration, 0.8)):
			_forward_escape_until = _drive_time + 1.5
	if _reversing > 0.0:
		if not _reverse_observed and forward_speed < -3.0:
			_reverse_observed = true
			recovery_started += 1
		_reversing = maxf(0.0, _reversing - delta)
		var finished_reverse := _reversing == 0.0
		throttle = -0.55 if forward_speed > -42.0 else 0.0
		brake = 0.0
		steer = _recovery_steer * 0.75
		if _nav != null:
			var rear_room := _reverse_room(forward)
			var reverse_limit := minf(42.0, sqrt(2.0 * service_deceleration * maxf(0.0, rear_room - 16.0)) * 0.7)
			if forward_speed < -reverse_limit:
				throttle = 0.0
				brake = 0.21
			if rear_room < 16.0:
				finished_reverse = false
				_cancel_reverse()
				_reversing = 0.0
				throttle = 0.0
				brake = 0.21
		if finished_reverse: recovery_completed += 1
		_last_throttle = throttle
		_last_steer = steer
	else:
		if delta > 0.0:
			steer = move_toward(_last_steer, steer, delta * clampf(steer_gain, 1.6, 3.2))
			throttle = 0.0 if brake > 0.0 or desired_speed < 5.0 else move_toward(_last_throttle, throttle, delta * 2.0)
		_last_steer = steer
		_last_throttle = throttle
	return {"throttle": throttle, "brake": brake, "steer": steer,
		"fire": is_instance_valid(_victim) and _can_fire(_victim)}


func _is_biker() -> bool:
	return bool(vehicle.get_meta("biker", false))


func _reverse_room(forward: Vector2) -> float:
	return _motion_room(-forward, 90.0)


func _motion_room(direction: Vector2, length: float) -> float:
	# A circular planner margin can trap a long car even when its oriented
	# body has room to back out. Sweep the REAL footprint, including traffic.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _recovery_shape
	query.transform = vehicle.global_transform
	query.motion = direction * length
	query.margin = 2.0
	query.exclude = [vehicle.get_rid()]
	query.collision_mask = vehicle.collision_mask
	var fractions := vehicle.get_world_2d().direct_space_state.cast_motion(query)
	var distance: float = fractions[0] * length
	if arena == null: return distance
	var half := Vector2(vehicle.config.length,vehicle.config.width) * Vehicle.COLLISION_SCALE * 0.5
	var c := absf(cos(vehicle.rotation))
	var s := absf(sin(vehicle.rotation))
	var extent := Vector2(half.x*c+half.y*s,half.x*s+half.y*c)
	var bounds: Rect2 = arena.get_bounds()
	var backward := direction
	for axis in 2:
		if backward[axis] > 0.001:
			distance = minf(distance,maxf(0.0,(bounds.end[axis]-extent[axis]-2.0-vehicle.global_position[axis])/backward[axis]))
		elif backward[axis] < -0.001:
			distance = minf(distance,maxf(0.0,(bounds.position[axis]+extent[axis]+2.0-vehicle.global_position[axis])/backward[axis]))
	return distance


func _is_boss() -> bool:
	return bool(vehicle.get_meta("boss", false))


func _safe_goal(point: Vector2) -> Vector2:
	if arena == null: return point
	var bounds := arena.get_bounds().grow(-maxf(_clearance + 22.0, wall_avoid_margin * 0.65))
	return point.clamp(bounds.position, bounds.end)


func _set_intent(value: StringName, goal: Vector2) -> void:
	if value != _intent:
		_intent = value
		_intent_age = 0.0
		_pickup_progress = INF
		_pickup_stall = 0.0
	_intent_goal = _safe_goal(goal)


func _watch_pickup_progress(delta: float) -> void:
	if _intent != &"supply" or not is_instance_valid(_locked_pickup): return
	var distance := vehicle.global_position.distance_to(_locked_pickup.global_position)
	if distance < _pickup_progress - 15.0:
		_pickup_progress = distance
		_pickup_stall = 0.0
	else:
		_pickup_stall += delta
	if _pickup_stall > 3.0:
		_pickup_ignore_until[_locked_pickup.get_instance_id()] = _drive_time + 7.0
		_locked_pickup = null
		_intent = &"pursue"
		_reaction_clock = 0.0
		_path.clear()
		_pickup_progress = INF
		_pickup_stall = 0.0


func _update_intent(delta: float) -> void:
	_intent_age += delta
	_reaction_clock -= delta
	var urgent_retreat := _health_ratio() <= retreat_health_ratio and _intent != &"retreat"
	if delta > 0.0 and _reaction_clock > 0.0 and is_instance_valid(_victim) and _victim.alive and not urgent_retreat: return
	_reaction_clock = _reaction_interval
	_victim = _choose_target()
	var position := vehicle.global_position
	var forward := Vector2.RIGHT.rotated(vehicle.rotation)
	if _victim == null:
		_set_intent(&"patrol", position + forward * 260.0)
		return
	var offset := _victim.global_position - position
	var distance := offset.length()
	if _health_ratio() <= retreat_health_ratio and not _is_boss():
		var repair := _best_pickup()
		if repair != null and repair.kind == BonusPickup.Kind.REPAIR:
			_set_intent(&"supply", repair.global_position)
			return
		if _intent != &"retreat" or _intent_age > 2.5 or position.distance_to(_intent_goal) < 65.0:
			_set_intent(&"retreat", position - offset.normalized() * 300.0 + forward.orthogonal() * _passing_side * 55.0)
			_intent_age = 0.0
		return
	if _intent == &"reposition" and _intent_age < 2.1 and position.distance_to(_intent_goal) > 60.0: return
	if not external_weapon_control and not _is_biker() and (not vehicle.has_temporary_weapon() or strategy == Strategy.SCAVENGER):
		var pickup := _best_pickup()
		if pickup != null:
			_set_intent(&"supply", pickup.global_position)
			return
	var armed := vehicle.has_temporary_weapon()
	if not _is_boss() and distance < 180.0 and (forward.dot(offset.normalized()) < 0.1 or distance < (125.0 if _is_biker() else 85.0 if armed else 40.0)):
		_set_intent(&"reposition", position + forward * 245.0 + forward.orthogonal() * _passing_side * 85.0)
		_intent_age = 0.0
		return
	var lead := clampf(distance / maxf(vehicle.get_current_max_speed(), 1.0) * 0.16, 0.16, 0.65)
	var goal := _victim.global_position + _victim.linear_velocity * lead
	if _is_biker() or team_role == TeamRole.FLANKER or (team_role == TeamRole.SUPPORT and armed):
		# Flanking is relative to the opponent's heading, never to our own
		# moving position; the old rotating target caused endless orbiting.
		var target_heading := _victim.linear_velocity.normalized() if _victim.get_speed() > 25.0 else Vector2.RIGHT.rotated(_victim.rotation)
		var width := 95.0 if _is_biker() else 135.0 * smoothstep(140.0, 430.0, distance)
		goal += target_heading.orthogonal() * _passing_side * width
	_set_intent(&"attack" if distance < 320.0 else &"pursue", goal)


func _update_path(delta: float) -> void:
	_path_clock -= delta
	if _traffic_nav != null:
		if _drive_time < _detour_until and _path_goal.distance_to(_intent_goal) < 75.0 and not _path.is_empty(): return
		_traffic_nav = null
		_path.clear()
	if _nav == null:
		_path = PackedVector2Array([_intent_goal])
		_path_index = 0
		return
	var moved_goal := _path_goal.distance_to(_intent_goal) > 75.0
	var finished := _path.is_empty() or _path_index >= _path.size()
	var blocked: bool = not finished and _path_clock <= 0.0 and not _nav.segment_clear(vehicle.global_position, _path[_path_index], _clearance * 0.8)
	if _path_clock <= 0.0 and (finished or moved_goal or blocked or _route_status != &"EXACT"):
		var result: Dictionary = _nav.route_result(vehicle.global_position, _intent_goal, _clearance)
		_path = result.path
		_route_status = result.status
		if _route_status == &"EXACT": _no_route_recoveries = 0
		_resolved_goal = result.resolved
		if _route_status != &"EXACT" and _intent == &"supply" and is_instance_valid(_locked_pickup):
			_pickup_ignore_until[_locked_pickup.get_instance_id()] = _drive_time + 7.0
			_locked_pickup = null
		_path_goal = _intent_goal
		_path_origin = vehicle.global_position
		_path_index = 0
		_path_clock = 0.65
	elif _path_clock <= 0.0:
		_path_clock = 0.65
		var anchor := _path[_path.size() - 2] if _path.size() > 1 else vehicle.global_position
		if _route_status == &"EXACT" and _nav.segment_clear(anchor, _intent_goal, _clearance):
			_path[_path.size() - 1] = _intent_goal
			_resolved_goal = _intent_goal
	# An unavailable route stays empty and is retried. A synthetic waypoint
	# straight ahead used to mask invalid routes and drive into the obstacle.


func _update_traffic_yield(delta: float) -> void:
	_waiting_for_peer = false
	if _nav == null: return
	if _yield_until > 0.0 and _drive_time >= _yield_until:
		if vehicle.global_position.distance_to(_yield_goal) > 40.0: _remember_yield_goal()
		_yield_until = 0.0
	if _drive_time < _yield_until:
		_set_intent(&"yield", _yield_goal)
		return
	var forward := Vector2.RIGHT.rotated(vehicle.rotation)
	var traffic := _traffic_limit(200.0, forward)
	var peer := traffic.peer as Vehicle
	if peer != _traffic_peer:
		_traffic_stall = 0.0
		_traffic_peer = peer
	if peer == null or vehicle.get_speed() > 18.0 or float(traffic.speed) > 25.0:
		_traffic_stall = 0.0
		traffic_reason = &"clear" if peer == null else &"moving"
		return
	_traffic_stall += delta
	var active := _active_driver(peer)
	traffic_reason = &"temporary_stop" if active != null else &"inactive_blocker"
	if _traffic_stall < 0.9 or _drive_time < _detour_retry: return
	# An inactive/EMP driver cannot be asked to yield. Active opponents elect
	# one manoeuvring driver by stable initial location, not incidental IDs.
	if active != null and active._traffic_peer == vehicle and _has_priority_over(active) and active._drive_time >= active._recovery_retry and (_traffic_stall < 2.5 or active._reversing > 0.0):
		traffic_reason = &"waiting_peer"
		_waiting_for_peer = true
		return
	if _traffic_nav == null and _try_traffic_detour():
		traffic_reason = &"bypass"
		return
	if _traffic_nav != null:
		traffic_reason = &"bypass"
		return
	if _drive_time < _yield_cooldown: return
	var rear := _reverse_room(forward)
	if rear < 24.0:
		_request_reverse(_passing_side, 1.25)
		_forward_escape_until = _drive_time + 1.5
		traffic_reason = &"rear_blocked"
		return
	for side in [_passing_side, -_passing_side]:
		for retreat in [65.0, 120.0]:
			var candidate: Vector2 = _safe_goal(vehicle.global_position - forward * retreat + forward.orthogonal() * side * (_clearance + 30.0))
			if _failed_yield(candidate) or not _nav.point_clear(candidate, _clearance) or not _body_clear(candidate, vehicle.rotation): continue
			var result: Dictionary = _nav.route_result(vehicle.global_position, candidate, _clearance)
			if result.status != &"EXACT": continue
			if not _request_reverse(side, maxf(reverse_duration, 1.25)): continue
			_yield_goal = candidate
			_yield_until = _drive_time + 6.0
			_yield_cooldown = _drive_time + 12.0
			_traffic_stall = 0.0
			_path.clear()
			_path_clock = 0.0
			_stuck_timer = 0.0
			yield_manoeuvres += 1
			_set_intent(&"yield", candidate)
			return
	_yield_cooldown = _drive_time + 2.0


func _active_driver(peer: Vehicle) -> ArenaBot:
	var driver := peer.get_node_or_null("ArenaBot") as ArenaBot
	if driver == null or not driver.is_physics_processing() or not driver.can_process() or peer.freeze or peer.is_emp_disabled(): return null
	return driver


func _has_priority_over(other: ArenaBot) -> bool:
	if not is_equal_approx(_spawn_position.x, other._spawn_position.x): return _spawn_position.x < other._spawn_position.x
	if not is_equal_approx(_spawn_position.y, other._spawn_position.y): return _spawn_position.y < other._spawn_position.y
	return vehicle.get_index() < other.vehicle.get_index()


func _body_clear(point: Vector2, angle: float) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _recovery_shape
	query.transform = Transform2D(angle, point)
	query.margin = 2.0
	query.collision_mask = vehicle.collision_mask
	query.exclude = [vehicle.get_rid()]
	return vehicle.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _failed_yield(point: Vector2) -> bool:
	for entry in _failed_yields:
		if _drive_time < entry.until and point.distance_to(entry.point) < 45.0: return true
	return false


func _remember_yield_goal() -> void:
	_failed_yields.append({"point":_yield_goal, "until":_drive_time + 12.0})
	if _failed_yields.size() > 6: _failed_yields.pop_front()


func _remember_failed_reverse(blocked_arc: bool = false) -> void:
	_blocked_reverse_arc = blocked_arc
	_blocked_reverse_position = vehicle.global_position
	_blocked_reverse_angle = vehicle.rotation
	_blocked_reverse_room = _reverse_room(Vector2.RIGHT.rotated(vehicle.rotation))
	_blocked_peer_position = _traffic_peer.global_position if is_instance_valid(_traffic_peer) else Vector2(INF, INF)
	_recovery_retry = _drive_time + 1.5
	if _yield_until > _drive_time:
		_remember_yield_goal()
		_yield_until = 0.0
		_yield_cooldown = _drive_time + 1.5
		_reaction_clock = 0.0


func _request_reverse(side: float, duration: float) -> bool:
	if _reversing > 0.0 or _drive_time < _recovery_retry: return false
	var peer_position := _traffic_peer.global_position if is_instance_valid(_traffic_peer) else Vector2(INF, INF)
	var same_peer := peer_position == _blocked_peer_position or (peer_position.is_finite() and _blocked_peer_position.is_finite() and peer_position.distance_to(_blocked_peer_position) < 12.0)
	var forward := Vector2.RIGHT.rotated(vehicle.rotation)
	var rear := _reverse_room(forward) if _nav != null else 90.0
	if vehicle.global_position.distance_to(_blocked_reverse_position) < 12.0 and absf(angle_difference(vehicle.rotation, _blocked_reverse_angle)) < 0.25 and same_peer and rear < maxf(24.0, _blocked_reverse_room + 8.0):
		# A side blocker may leave without changing straight rear_room.
		if not _blocked_reverse_arc or not (_reverse_arc_clear(side) or _reverse_arc_clear(-side)): return false
	recovery_requested += 1
	if rear < 24.0:
		recovery_rejected += 1
		_remember_failed_reverse()
		return false
	if not _reverse_arc_clear(side):
		side = -side
		if not _reverse_arc_clear(side):
			recovery_rejected += 1
			_remember_failed_reverse(true)
			return false
	_reversing = duration
	_reverse_observed = false
	_recovery_steer = side
	_reaction_clock = 0.0
	return true


func _reverse_arc_clear(side: float) -> bool:
	var forward := Vector2.RIGHT.rotated(vehicle.rotation)
	for distance in [8.0, 16.0]:
		if not _body_clear(vehicle.global_position - forward * distance, vehicle.rotation - side * distance * 0.006): return false
	return true


func _cancel_reverse() -> void:
	recovery_cancelled += 1
	_remember_failed_reverse()
	_forward_escape_until = _drive_time + 1.5


func _try_traffic_detour() -> bool:
	_detour_retry = _drive_time + 2.0
	var rectangles: Array[Rect2] = []
	for node in get_tree().get_nodes_in_group("combatants"):
		var other := node as Vehicle
		if other == null or other == vehicle or other == _victim or not other.alive: continue
		if other.global_position.distance_to(vehicle.global_position) > 320.0 or other.get_speed() > 28.0: continue
		var vertices := other.config.get_body_vertices()
		var rect := Rect2(other.global_transform * (vertices[0] * Vehicle.COLLISION_SCALE), Vector2.ZERO)
		for vertex in vertices: rect = rect.expand(other.global_transform * (vertex * Vehicle.COLLISION_SCALE))
		rectangles.append(rect.grow(6.0))
	if rectangles.is_empty(): return false
	var signature: Array = [vehicle.global_position.snapped(Vector2.ONE * 16.0), _intent_goal.snapped(Vector2.ONE * 24.0)]
	for rect in rectangles: signature.append(Rect2(rect.position.snapped(Vector2.ONE * 12.0), rect.size.snapped(Vector2.ONE * 8.0)))
	if signature == _detour_signature: return false
	_detour_signature = signature
	var planner: RefCounted = _nav.with_traffic(rectangles)
	# Traffic corridors need lateral clearance, not a full turning circle at
	# every point. Verify the oriented hull along each leg below.
	var lateral := vehicle.config.width * Vehicle.COLLISION_SCALE.y * 0.5 + 12.0
	var result: Dictionary = planner.route_result(vehicle.global_position, _intent_goal, lateral)
	if result.status != &"EXACT" or result.path.is_empty(): return false
	var anchor := vehicle.global_position
	for point in result.path:
		var angle: float = (point - anchor).angle()
		var steps := maxi(1, ceili(anchor.distance_to(point) / 16.0))
		for step in range(1, steps + 1):
			if not _body_clear(anchor.lerp(point, float(step) / steps), angle): return false
		anchor = point
	_traffic_nav = planner
	_path = result.path
	_path_goal = _intent_goal
	_resolved_goal = result.resolved
	_route_status = result.status
	_path_origin = vehicle.global_position
	_path_index = 0
	_detour_until = _drive_time + 10.0
	traffic_detours += 1
	_forward_escape_until = _drive_time + 2.0
	return true


func _path_aim(lookahead: float) -> Vector2:
	if _path.is_empty(): return _intent_goal
	var planner: RefCounted = _traffic_nav if _traffic_nav != null else _nav
	var position := vehicle.global_position
	while _path_index + 1 < _path.size():
		var waypoint := _path[_path_index]
		var passed := (position - waypoint).dot(waypoint - _path_origin) > 0.0
		var close := position.distance_to(waypoint) < maxf(30.0, vehicle.get_speed() * 0.32)
		if not (passed or close): break
		if planner != null and not planner.segment_clear(position, _path[_path_index + 1], _clearance * 0.72): break
		_path_origin = _path[_path_index]
		_path_index += 1
	var projected := Geometry2D.get_closest_point_to_segment(position, _path_origin, _path[_path_index])
	var remaining := lookahead
	var point := projected
	for index in range(_path_index, _path.size()):
		var leg := point.distance_to(_path[index])
		if leg >= remaining:
			point = point.move_toward(_path[index], remaining)
			break
		remaining -= leg
		point = _path[index]
	if planner != null and not planner.segment_clear(position, point, _clearance * 0.72):
		return _path[_path_index]
	return point


func _traffic_speed(desired: float, forward: Vector2) -> float:
	return float(_traffic_limit(desired, forward).speed)


func _projected_half(other: Vehicle, axis: Vector2) -> float:
	var extent := 0.0
	for vertex in other.config.get_body_vertices():
		extent = maxf(extent, absf((vertex * Vehicle.COLLISION_SCALE).rotated(other.rotation).dot(axis)))
	return extent


func _traffic_limit(desired: float, forward: Vector2) -> Dictionary:
	var peer: Vehicle
	# Yield behind allies instead of adding another left/right steering force.
	for node in get_tree().get_nodes_in_group("combatants"):
		var other := node as Vehicle
		if other == null or other == vehicle or not other.alive: continue
		if other == _victim and not _is_biker(): continue
		var offset := other.global_position - vehicle.global_position
		if offset.length_squared() > 90000.0: continue
		var ahead := offset.dot(forward)
		var lane := _projected_half(vehicle, forward.orthogonal()) + _projected_half(other, forward.orthogonal()) + 10.0
		if ahead <= 0.0 or absf(offset.cross(forward)) > lane: continue
		var gap := ahead - _projected_half(vehicle, forward) - _projected_half(other, forward)
		if gap < 95.0:
			var limit := maxf(0.0, other.linear_velocity.dot(forward)) + maxf(0.0, gap - 20.0) * 1.15
			if limit < desired:
				desired = limit
				peer = other
	return {"speed":desired, "peer":peer}


## The closest living combatant — in derby mode every other car is a target,
## so bots fight each other as well as the player.
func _choose_target() -> Vehicle:
	if focus_player:
		for node in get_tree().get_nodes_in_group("combatants"):
			var player_target := node as Vehicle
			if player_target != null and player_target.alive and player_target.get_meta("player_vehicle", false): return player_target
	if vehicle != null and is_instance_valid(vehicle.last_attacker):
		var attacker := vehicle.last_attacker as Vehicle
		if attacker != null and attacker != vehicle and attacker.alive and attacker.is_in_group("combatants") and not _same_squad(attacker):
			return attacker
	var best: Vehicle = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("combatants"):
		var other := node as Vehicle
		if other == null or other == vehicle or not other.alive or _same_squad(other):
			continue
		var distance := vehicle.global_position.distance_squared_to(other.global_position)
		if strategy == Strategy.SURVIVOR:
			distance /= maxf(other.damage.ratio(&"body"), 0.15)
		if distance < best_distance:
			best_distance = distance
			best = other
	return best


func _same_squad(other: Vehicle) -> bool:
	var squad: StringName = vehicle.get_meta("squad_id", &"") if vehicle != null else &""
	return squad != &"" and StringName(other.get_meta("squad_id", &"")) == squad

func _apply_strategy() -> void:
	match strategy:
		Strategy.BRAWLER:
			preferred_range = 105.0
			retreat_health_ratio = 0.08
			fire_angle = 0.34
			avoid_weight = 1.1
		Strategy.HUNTER:
			preferred_range = 220.0
		Strategy.SCAVENGER:
			preferred_range = 280.0
			avoid_weight = 1.9
		Strategy.SURVIVOR:
			retreat_health_ratio = 0.48
			retreat_weight = 1.7
			preferred_range = 330.0


func _apply_class_tactics() -> void:
	if vehicle == null or vehicle.config == null:
		return
	match vehicle.config.vehicle_class:
		VehicleConfig.VehicleClass.RAIDER:
			avoid_weight *= 1.08
		VehicleConfig.VehicleClass.INTERCEPTOR:
			cruise_throttle = 1.0
			steer_gain *= 1.08
		VehicleConfig.VehicleClass.ASSAULT:
			fire_range *= 1.15
			fire_angle += 0.05
		VehicleConfig.VehicleClass.JUGGERNAUT:
			preferred_range = minf(preferred_range, 115.0)
			retreat_health_ratio *= 0.55
			avoid_weight *= 0.78

func _best_pickup() -> BonusPickup:
	for id in _pickup_ignore_until.keys():
		if float(_pickup_ignore_until[id]) <= _drive_time:
			_pickup_ignore_until.erase(id)
	if is_instance_valid(_locked_pickup):
		if _locked_pickup.armed and not _locked_pickup.collected_once and vehicle.global_position.distance_to(_locked_pickup.global_position) < 720.0 and _pickup_utility(_locked_pickup) > 0.18:
			return _locked_pickup
	_locked_pickup = null
	var best: BonusPickup = null
	var best_score := 0.28
	for node in get_tree().get_nodes_in_group("bonus_pickups"):
		var pickup := node as BonusPickup
		if pickup == null or not pickup.armed or pickup.collected_once:
			continue
		if float(_pickup_ignore_until.get(pickup.get_instance_id(), 0.0)) > _drive_time: continue
		var distance := vehicle.global_position.distance_to(pickup.global_position)
		if distance > 680.0:
			continue
		var utility := _pickup_utility(pickup)
		if vehicle.config != null:
			match vehicle.config.vehicle_class:
				VehicleConfig.VehicleClass.RAIDER:
					utility *= 1.22
				VehicleConfig.VehicleClass.ASSAULT:
					utility *= 1.35 if pickup.kind == BonusPickup.Kind.WEAPON else 0.78
				VehicleConfig.VehicleClass.JUGGERNAUT:
					utility *= 1.3 if pickup.kind == BonusPickup.Kind.RAM_BOOST else 0.9
		var score := utility * lerpf(1.0, 0.32, distance / 680.0)
		if strategy == Strategy.SCAVENGER:
			score *= 1.3
		if score > best_score:
			best_score = score
			best = pickup
	_locked_pickup = best
	return best


func _pickup_utility(pickup: BonusPickup) -> float:
	match pickup.kind:
		BonusPickup.Kind.WEAPON:
			return 0.08 if vehicle.has_temporary_weapon() else 1.0
		BonusPickup.Kind.REPAIR:
			return clampf((1.0 - _health_ratio()) * 1.65, 0.08, 1.0)
		BonusPickup.Kind.SPEED_BOOST:
			return 0.25 if vehicle.is_boost_active() else 0.68
		BonusPickup.Kind.RAM_BOOST:
			if vehicle.is_ram_boost_active():
				return 0.25
			return 1.0 if strategy == Strategy.BRAWLER else 0.62
	return 0.0

func _health_ratio() -> float:
	if vehicle == null or vehicle.config == null or vehicle.config.max_health <= 0.0:
		return 1.0
	return clampf(vehicle.health / vehicle.config.max_health, 0.0, 1.0)


func _can_fire(target: Vehicle) -> bool:
	var to_target := target.global_position - vehicle.global_position
	var distance := to_target.length()
	if not vehicle.has_temporary_weapon():
		return false
	if vehicle.gun.config.weapon_type == WeaponConfig.WeaponType.MINE:
		return distance <= 145.0
	var weapon_range := minf(fire_range, vehicle.gun.config.effective_range)
	if distance > weapon_range or distance < 0.001:
		return false
	var forward := Vector2.RIGHT.rotated(vehicle.rotation)
	return absf(forward.angle_to(to_target)) <= fire_angle and (_nav == null or _nav.segment_clear(vehicle.global_position, target.global_position, 1.0))
