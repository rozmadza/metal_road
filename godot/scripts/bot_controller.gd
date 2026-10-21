extends Node
class_name BotController
## Waypoint-following AI driver for a [Vehicle].
##
## Produces the same command contract as the player (`throttle, brake, steer,
## fire`) and feeds it straight into [method Vehicle.apply_control], so bots
## reuse the exact vehicle physics and weapon logic with no special cases.

## Track used as the racing line. Injected by [Game].
@export var track: Track
## Preferred rival. Combat selection still favours whichever racer is
## immediately ahead, because finishing the race is always the main goal.
@export var target: Vehicle

enum Strategy { RACER, BRAWLER, OPPORTUNIST, BLOCKER, SPRINTER }
@export var strategy: Strategy = Strategy.RACER

@export_group("Driving")
## Throttle held while the bot is aligned with the racing line.
@export_range(0.0, 1.0, 0.05) var cruise_throttle: float = 0.9
## Distance ahead along the centreline used as the steering target.
@export_range(10.0, 400.0, 5.0) var lookahead: float = 110.0
## Heading error (radians) above which the bot eases off the throttle.
@export_range(0.0, 3.0, 0.05) var ease_angle: float = 0.5
## Heading error (radians) above which the bot brakes into the corner.
@export_range(0.0, 3.0, 0.05) var brake_angle: float = 1.2
## Steering gain: steer = clamp(heading_error * gain, -1, 1).
@export_range(0.1, 10.0, 0.1) var steer_gain: float = 2.5

@export_group("Recovery")
## Speed below which, while trying to drive, the bot is considered stuck.
@export_range(0.0, 200.0, 5.0) var stuck_speed: float = 20.0
## Seconds of being stuck before the bot backs up.
@export_range(0.0, 10.0, 0.1) var stuck_timeout: float = 1.5
## Seconds spent reversing during a recovery.
@export_range(0.0, 10.0, 0.1) var reverse_duration: float = 0.9

@export_group("Combat")
## Maximum distance at which the bot opens fire.
@export_range(0.0, 3000.0, 10.0) var fire_range: float = 450.0
## Maximum angle (radians) between the nose and the target to open fire.
@export_range(0.0, 3.14, 0.01) var fire_angle: float = 0.2

var vehicle: Vehicle

var _start_position: Vector2 = Vector2.ZERO
var _start_angle: float = 0.0
var _stuck_timer: float = 0.0
var _reversing: float = 0.0
var _lane_bias := 0.0


func _ready() -> void:
	vehicle = get_parent() as Vehicle
	_apply_strategy()
	_apply_class_tactics()
	if vehicle != null:
		_start_position = vehicle.global_position
		_start_angle = vehicle.rotation


func _physics_process(delta: float) -> void:
	if vehicle == null or track == null:
		return
	var commands := get_commands(delta)
	vehicle.apply_control(
		commands["throttle"], commands["brake"], commands["steer"], commands["fire"]
	)


## Wires the bot to its world. Called by [Game] once the scene is ready.
func setup(track_ref: Track, target_ref: Vehicle) -> void:
	track = track_ref
	target = target_ref


## Returns the current command dict. `delta` only advances the recovery timer,
## so tests can inspect the decision without side effects by passing 0.
func get_commands(delta: float = 0.0) -> Dictionary:
	var throttle := 0.0
	var brake := 0.0
	var heading_error := _heading_error()
	var steer := clampf(heading_error * steer_gain, -1.0, 1.0)

	if _reversing > 0.0:
		_reversing = maxf(0.0, _reversing - delta)
		throttle = -0.7
	else:
		var magnitude := absf(heading_error)
		if magnitude >= brake_angle:
			# Keep a small drive force through a tight turn. Steering now correctly
			# requires rolling speed, so a brake-only bot would wait forever.
			throttle = cruise_throttle * 0.32
		elif magnitude >= ease_angle:
			throttle = cruise_throttle * 0.4
		else:
			throttle = cruise_throttle

		if vehicle.get_speed() < stuck_speed and throttle > 0.0:
			_stuck_timer += delta
		else:
			_stuck_timer = 0.0
		if _stuck_timer >= stuck_timeout:
			_stuck_timer = 0.0
			_reversing = reverse_duration
			throttle = -0.7
			brake = 0.0

	return {
		"throttle": throttle,
		"brake": brake,
		"steer": steer,
		"fire": _should_fire(),
	}


## Returns the bot to the position it had when the scene loaded.
func reset() -> void:
	_stuck_timer = 0.0
	_reversing = 0.0
	if vehicle != null:
		vehicle.reset_to(_start_position, _start_angle)


func _heading_error() -> float:
	if vehicle == null or track == null:
		return 0.0
	var vehicle_track_info := track.get_closest_segment(vehicle.global_position)
	var target_point := _lookahead_point(vehicle.global_position, lookahead)
	var line_info := track.get_closest_segment(target_point)
	var safe_half_width := maxf(0.0, track.half_width - 28.0)
	# Outside the comfortable racing corridor, recovery to the centreline takes
	# precedence over tactics, pickups and lane preference.
	if float(vehicle_track_info.distance) <= track.half_width * 0.72:
		target_point += track.segment_normals[int(line_info.segment_index)] * _lane_bias * safe_half_width
	if strategy == Strategy.OPPORTUNIST or _class_is(VehicleConfig.VehicleClass.RAIDER) or _class_is(VehicleConfig.VehicleClass.ASSAULT):
		var pickup := _pickup_on_route(lookahead * 1.6)
		if pickup != null:
			target_point = target_point.lerp(pickup.global_position, 0.28)
	for hazard in get_tree().get_nodes_in_group("weapon_hazards"):
		if hazard is Bullet and hazard.shooter != vehicle:
			var to_hazard: Vector2 = hazard.global_position - vehicle.global_position
			if to_hazard.length() < 145.0 and Vector2.RIGHT.rotated(vehicle.rotation).dot(to_hazard) > 0.0:
				var escape_sign := -1.0 if track.segment_normals[int(line_info.segment_index)].dot(to_hazard) > 0.0 else 1.0
				target_point += track.segment_normals[int(line_info.segment_index)] * escape_sign * minf(72.0, safe_half_width)
	# Ramming is an opportunistic pass, never a reason to abandon the course.
	var victim := _combat_target()
	if victim != null and _can_safely_ram(victim):
		var attack_weight := 0.42 if strategy == Strategy.BRAWLER or vehicle.is_ram_boost_active() or _class_is(VehicleConfig.VehicleClass.JUGGERNAUT) else 0.24
		var intercept := victim.global_position + victim.linear_velocity * 0.12
		var candidate := target_point.lerp(intercept, attack_weight)
		if float(track.get_closest_segment(candidate).distance) <= safe_half_width:
			target_point = candidate
	var to_target := target_point - vehicle.global_position
	if to_target.length_squared() < 0.0001:
		return 0.0
	var forward := Vector2.RIGHT.rotated(vehicle.rotation)
	return forward.angle_to(to_target)


## Walks the centreline forward from the closest point and returns a point
## `distance` px ahead, giving a smooth racing line even on sparse tracks.
func _lookahead_point(from: Vector2, distance: float) -> Vector2:
	var info := track.get_closest_segment(from)
	var idx: int = info["segment_index"]
	var count := track.segment_lengths.size()
	if count == 0:
		return from

	var t: float = float(info["t"])
	var remaining := distance
	var current_remaining := track.segment_lengths[idx] * (1.0 - t)
	if remaining <= current_remaining:
		var p1: Vector2 = track.segments[idx]
		var p2: Vector2 = track.path_points[(idx + 1) % count]
		var local_t := t + remaining / track.segment_lengths[idx]
		return p1.lerp(p2, clampf(local_t, 0.0, 1.0))

	remaining -= current_remaining
	var i := (idx + 1) % count
	var guard := 0
	while remaining > track.segment_lengths[i] and guard < count:
		remaining -= track.segment_lengths[i]
		i = (i + 1) % count
		guard += 1
	var p1_next: Vector2 = track.segments[i]
	var p2_next: Vector2 = track.path_points[(i + 1) % count]
	return p1_next.lerp(p2_next, clampf(remaining / track.segment_lengths[i], 0.0, 1.0))


func _should_fire() -> bool:
	if vehicle == null or not vehicle.has_temporary_weapon():
		return false
	if vehicle.gun.config.weapon_type == WeaponConfig.WeaponType.MINE:
		return _should_drop_mine()
	# The injected rival is reliable when it is physically in the firing cone;
	# this avoids ambiguous progress projections where two bends run nearby.
	if _is_in_fire_solution(target):
		return true
	var victim := _combat_target()
	return _is_in_fire_solution(victim)


func _is_in_fire_solution(victim: Vehicle) -> bool:
	if victim == null or not is_instance_valid(victim) or not victim.alive:
		return false
	var to_target := victim.global_position - vehicle.global_position
	var distance := to_target.length()
	var weapon_range := minf(fire_range, vehicle.gun.config.effective_range) if vehicle.has_temporary_weapon() else fire_range
	if distance > weapon_range or distance < 0.001:
		return false
	var forward := Vector2.RIGHT.rotated(vehicle.rotation)
	return absf(forward.angle_to(to_target)) <= fire_angle


func _should_drop_mine() -> bool:
	var forward := Vector2.RIGHT.rotated(vehicle.rotation)
	for node in get_tree().get_nodes_in_group("combatants"):
		var candidate := node as Vehicle
		if candidate == null or candidate == vehicle or not candidate.alive:
			continue
		var to_candidate := candidate.global_position - vehicle.global_position
		if to_candidate.length() <= 135.0 and forward.dot(to_candidate.normalized()) < -0.15:
			return true
	return false

func _apply_strategy() -> void:
	match strategy:
		Strategy.RACER:
			cruise_throttle = 0.96
			lookahead = 135.0
			ease_angle = 0.58
			_lane_bias = -0.48
		Strategy.BRAWLER:
			cruise_throttle = 1.0
			lookahead = 80.0
			fire_angle = 0.34
			fire_range = 360.0
			_lane_bias = -0.18
		Strategy.OPPORTUNIST:
			lookahead = 95.0
			fire_range = 560.0
			fire_angle = 0.26
			_lane_bias = 0.18
		Strategy.BLOCKER:
			cruise_throttle = 0.92
			lookahead = 105.0
			fire_range = 420.0
			fire_angle = 0.3
			_lane_bias = 0.48
		Strategy.SPRINTER:
			cruise_throttle = 1.0
			lookahead = 165.0
			ease_angle = 0.72
			brake_angle = 1.48
			steer_gain = 2.2
			_lane_bias = 0.0


func _apply_class_tactics() -> void:
	if vehicle == null or vehicle.config == null:
		return
	match vehicle.config.vehicle_class:
		VehicleConfig.VehicleClass.RAIDER:
			lookahead *= 0.92
		VehicleConfig.VehicleClass.INTERCEPTOR:
			lookahead *= 1.18
			ease_angle += 0.12
			brake_angle += 0.12
		VehicleConfig.VehicleClass.ASSAULT:
			fire_range *= 1.12
			fire_angle += 0.05
		VehicleConfig.VehicleClass.JUGGERNAUT:
			lookahead *= 0.82
			fire_range *= 0.86
			_lane_bias *= 0.55


func _class_is(value: VehicleConfig.VehicleClass) -> bool:
	return vehicle != null and vehicle.config != null and vehicle.config.vehicle_class == value

func _combat_target() -> Vehicle:
	if vehicle == null or track == null:
		return null
	var best: Vehicle = null
	var score := INF
	for node in get_tree().get_nodes_in_group("combatants"):
		var candidate := node as Vehicle
		if candidate == null or candidate == vehicle or not candidate.alive:
			continue
		var to_candidate := candidate.global_position - vehicle.global_position
		var distance := to_candidate.length()
		if distance < 0.001 or distance > fire_range:
			continue
		var forward := Vector2.RIGHT.rotated(vehicle.rotation)
		if forward.dot(to_candidate / distance) <= 0.1:
			continue
		var progress_ahead := fposmod(
			track.get_progress_along_track(candidate.global_position) - track.get_progress_along_track(vehicle.global_position),
			track.get_total_length()
		)
		if progress_ahead > minf(fire_range * 1.35, track.get_total_length() * 0.22):
			continue
		var candidate_score := distance
		if vehicle.has_temporary_weapon():
			match vehicle.gun.config.weapon_type:
				WeaponConfig.WeaponType.ROCKET:
					# Guided splash weapons are reserved for whoever is furthest ahead.
					candidate_score -= progress_ahead * 0.32
				WeaponConfig.WeaponType.EMP:
					candidate_score -= candidate.get_speed() * 0.22
				WeaponConfig.WeaponType.FLAME, WeaponConfig.WeaponType.SHOTGUN:
					candidate_score *= 0.72 if distance < 210.0 else 1.35
		if strategy == Strategy.OPPORTUNIST:
			candidate_score *= 0.35 + 0.65 * candidate.damage.ratio(&"body")
		if candidate == target:
			candidate_score *= 0.9
		if candidate_score < score:
			score = candidate_score
			best = candidate
	return best

func _pickup_on_route(radius: float) -> BonusPickup:
	var best: BonusPickup = null
	var best_distance := radius * radius
	var forward := Vector2.RIGHT.rotated(vehicle.rotation)
	for node in get_tree().get_nodes_in_group("bonus_pickups"):
		var pickup := node as BonusPickup
		if pickup == null or not pickup.armed:
			continue
		if _class_is(VehicleConfig.VehicleClass.ASSAULT) and pickup.kind != BonusPickup.Kind.WEAPON:
			continue
		var to_pickup := pickup.global_position - vehicle.global_position
		if forward.dot(to_pickup) <= 0.0:
			continue
		if float(track.get_closest_segment(pickup.global_position).distance) > track.half_width * 0.72:
			continue
		var distance := to_pickup.length_squared()
		if distance < best_distance:
			best_distance = distance
			best = pickup
	return best


func _can_safely_ram(victim: Vehicle) -> bool:
	var to_victim := victim.global_position - vehicle.global_position
	var distance := to_victim.length()
	var maximum := 105.0 if strategy == Strategy.BRAWLER or vehicle.is_ram_boost_active() or _class_is(VehicleConfig.VehicleClass.JUGGERNAUT) else 62.0
	if distance < 0.001 or distance > maximum:
		return false
	var forward := Vector2.RIGHT.rotated(vehicle.rotation)
	return forward.dot(to_victim / distance) > 0.72
