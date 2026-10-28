extends Node2D
class_name BonusSpawner

signal bonus_announced(kind: BonusPickup.Kind, world_position: Vector2, duration: float)
signal bonus_spawned(pickup: BonusPickup)
signal bonus_collected(vehicle: Vehicle, kind: BonusPickup.Kind)

@export var spawn_interval: float = 8.0
@export var first_spawn_delay: float = 5.0
@export var warning_duration: float = 3.0
@export var active_lifetime: float = 12.0
@export var max_active: int = 1
## A delivery may contain several crates that are announced and armed on the
## same physics tick. Race mode keeps the default single contested pickup;
## Survival configures larger action-oriented batches.
@export_range(1, 6, 1) var batch_size: int = 1
@export_range(0, 6, 1) var minimum_weapons_per_batch: int = 0
@export_range(80.0, 500.0, 10.0) var minimum_spawn_separation: float = 180.0
@export var pickup_scene: PackedScene = preload("res://scenes/BonusPickup.tscn")
## Ordinary collector used for placement reachability, never the Arbiter.
@export var placement_vehicle_config: VehicleConfig = preload("res://resources/vehicles/raider.tres")
const Navigation = preload("res://scripts/arena_navigation.gd")
const BonusCache = preload("res://scripts/bonus_weapon_cache.gd")
const POSITION_ATTEMPTS := 48
const PICKUP_CLEARANCE := 53.0 # Collection radius50 at maximum pulse1.06.

var track: Track
var arena: Arena
var _time_to_event := 2.0
var _active_time := 0.0
var _warning := false
var _current_pickup: BonusPickup
var _pending_pickups: Array[BonusPickup] = []
var _active_pickups: Array[BonusPickup] = []
var _active_lifetimes: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _spawn_index := 0
var _kind_bag: Array[int] = []
var weapon_paths := BonusCache.PATHS.duplicate()


func _ready() -> void:
	# Directly instantiated Race/Survival scenes bypass SceneTransition. Warm
	# once during scene setup, before the first active physics tick.
	if not BonusCache.prepare():
		set_physics_process(false)
		return
	_rng.randomize()
	_begin_first_cycle()


func setup_for_track(value: Track) -> void:
	track = value
	arena = null


func setup_for_arena(value: Arena) -> void:
	arena = value
	track = null


func _physics_process(delta: float) -> void:
	_update_active_pickups(delta)

	_time_to_event -= delta
	if _time_to_event > 0.0:
		return
	if _warning:
		_arm_announced_pickup()
	else:
		_announce_next_pickup()


func reset() -> void:
	for node in get_tree().get_nodes_in_group("bonus_pickups"):
		if is_instance_valid(node) and node.get_parent() == self:
			node.queue_free()
	_current_pickup = null
	_pending_pickups.clear()
	_active_pickups.clear()
	_active_lifetimes.clear()
	_kind_bag.clear()
	_spawn_index = 0
	_begin_first_cycle()


## Immediate active spawn retained for tests and scripted events.
func spawn_random_bonus(forced_kind: int = -1) -> BonusPickup:
	if not _pending_pickups.is_empty() or is_instance_valid(_current_pickup) or pickup_scene == null or _active_pickups.size() >= max_active:
		return null
	var pickup := _create_pickup(forced_kind, true)
	if pickup != null:
		_register_active(pickup)
		bonus_spawned.emit(pickup)
	else:
		_begin_cooldown()
	return pickup


func _announce_next_pickup() -> void:
	if not _pending_pickups.is_empty() or is_instance_valid(_current_pickup):
		return
	if _active_pickups.size() >= max_active:
		_begin_cooldown()
		return
	var available_slots := mini(batch_size, max_active - _active_pickups.size())
	var reserved_positions: Array[Vector2] = []
	for index in available_slots:
		var chosen_kind := BonusPickup.Kind.WEAPON if _pending_pickups.size() < mini(minimum_weapons_per_batch, available_slots) else -1
		var pickup := _create_pickup(chosen_kind, false, reserved_positions)
		if pickup == null:
			continue
		_pending_pickups.append(pickup)
		reserved_positions.append(pickup.global_position)
	if _pending_pickups.is_empty():
		_begin_cooldown()
		return
	_current_pickup = _pending_pickups[0]
	_warning = true
	_time_to_event = warning_duration
	bonus_announced.emit(_current_pickup.kind, _current_pickup.global_position, warning_duration)


func _arm_announced_pickup() -> void:
	_warning = false
	if _pending_pickups.is_empty() and is_instance_valid(_current_pickup):
		_pending_pickups.append(_current_pickup)
	if _pending_pickups.is_empty():
		_begin_cooldown()
		return
	for pickup in _pending_pickups.duplicate():
		if not is_instance_valid(pickup):
			continue
		pickup.set_armed(true)
		_register_active(pickup)
		bonus_spawned.emit(pickup)
	_pending_pickups.clear()
	_current_pickup = null
	_begin_cooldown()


func _create_pickup(chosen_kind: int, is_armed: bool, reserved_positions: Array[Vector2] = []) -> BonusPickup:
	var location := _next_position(reserved_positions)
	if not location.success or pickup_scene == null:
		return null
	var pickup := pickup_scene.instantiate() as BonusPickup
	if pickup == null:
		return null
	if chosen_kind < 0:
		chosen_kind = _draw_kind()
	var weapon: WeaponConfig = null
	if chosen_kind == BonusPickup.Kind.WEAPON:
		var path: String = weapon_paths[_rng.randi_range(0, weapon_paths.size() - 1)]
		weapon = BonusCache.get_config(path)
		if weapon == null and not path in BonusCache.PATHS:
			# Preserve the existing extension point for a custom path. Standard
			# pickup paths must already be prepared before gameplay begins.
			weapon = load(path) as WeaponConfig
		if weapon == null:
			pickup.free()
			return null
	pickup.setup(chosen_kind as BonusPickup.Kind, weapon, is_armed)
	add_child(pickup)
	pickup.global_position = location.position
	pickup.collected.connect(_on_collected)
	_spawn_index += 1
	return pickup


func _draw_kind() -> int:
	if _kind_bag.is_empty():
		_kind_bag.assign([
			BonusPickup.Kind.WEAPON,
			BonusPickup.Kind.REPAIR,
			BonusPickup.Kind.SPEED_BOOST,
			BonusPickup.Kind.RAM_BOOST,
		])
		_kind_bag.shuffle()
	return _kind_bag.pop_back()


func _begin_first_cycle() -> void:
	_warning = false
	_active_time = 0.0
	_time_to_event = maxf(0.0, first_spawn_delay - warning_duration)


func _begin_cooldown() -> void:
	_warning = false
	_active_time = 0.0
	_time_to_event = spawn_interval


func _next_position(reserved_positions: Array[Vector2] = []) -> Dictionary:
	if track != null:
		var distance := _rng.randf_range(0.0, track.get_total_length())
		if not track.config.bonus_hotspots.is_empty() and _spawn_index % 3 != 2:
			distance = track.get_total_length() * float(track.config.bonus_hotspots[_spawn_index % track.config.bonus_hotspots.size()])
		var center := track.get_point_at_distance(distance)
		var info := track.get_closest_segment(center)
		var normal: Vector2 = track.segment_normals[int(info.segment_index)]
		return {"success": true, "position": center + normal * _rng.randf_range(-track.half_width * 0.45, track.half_width * 0.45)}
	if arena != null:
		var bounds := arena.get_bounds()
		# Placement owns a fresh snapshot so destroyed props are not held by
		# the AI navigation cache's 45-frame refresh interval.
		var nav = Navigation.new()
		nav.setup(arena)
		var collector := Vehicle.new()
		collector.config = placement_vehicle_config
		var clearance: float = nav.clearance(collector)
		collector.free()
		var origins := arena.get_spawn_points(1)
		if origins.is_empty():
			return {"success": false}
		var origin: Vector2 = origins[0]
		if not nav.point_clear(origin, clearance):
			return {"success": false}
		for _attempt in POSITION_ATTEMPTS:
			var candidate := Vector2(
				_rng.randf_range(bounds.position.x + 75.0, bounds.end.x - 75.0),
				_rng.randf_range(bounds.position.y + 75.0, bounds.end.y - 75.0)
			)
			var blocked := false
			if _attempt < 12 and not arena.config.supply_hotspots.is_empty():
				candidate = arena.config.supply_hotspots[(_spawn_index + _attempt) % arena.config.supply_hotspots.size()]
			if not bounds.grow(-maxf(75.0, clearance)).has_point(candidate):
				continue
			for rect in arena.get_obstacles():
				# Leave room for a full car to enter the enlarged pickup field.
				if rect.grow(86.0).has_point(candidate):
					blocked = true
					break
			if not blocked:
				for reserved in reserved_positions:
					if candidate.distance_to(reserved) < minimum_spawn_separation:
						blocked = true
						break
			if not blocked:
				for active in _active_pickups:
					if is_instance_valid(active) and candidate.distance_to(active.global_position) < minimum_spawn_separation:
						blocked = true
						break
			if not blocked and _arena_position_clear(candidate, nav, clearance, origin):
				return {"success": true, "position": candidate}
	return {"success": false}


func _arena_position_clear(candidate: Vector2, nav: RefCounted, clearance: float, origin: Vector2) -> bool:
	if not nav.point_clear(candidate, maxf(PICKUP_CLEARANCE, clearance)):
		return false
	# Physical shapes include extra StaticBodies not authored in ArenaConfig.
	# Oil is traversable; spikes damage wheels and are forbidden pickup sites.
	var shape := CircleShape2D.new()
	shape.radius = maxf(PICKUP_CLEARANCE, clearance)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = 1
	query.collide_with_areas = true
	for hit in arena.get_world_2d().direct_space_state.intersect_shape(query, 128):
		if hit.collider is StaticBody2D or hit.collider is SpikeStrip:
			return false
	# SpikeStrip intentionally has collision_layer=0 (sensor only), so a
	# physics shape query cannot discover it. Test its transformed rectangle.
	for spike in get_tree().get_nodes_in_group("spike_strips"):
		if not arena.is_ancestor_of(spike):
			continue
		var collision := spike.get_node("CollisionShape2D") as CollisionShape2D
		var half: Vector2 = (collision.shape as RectangleShape2D).size * 0.5
		var polygon := PackedVector2Array()
		for corner in [Vector2(-half.x,-half.y), Vector2(half.x,-half.y), half, Vector2(-half.x,half.y)]:
			polygon.append(collision.to_global(corner))
		if Geometry2D.is_point_in_polygon(candidate, polygon):
			return false
		for index in polygon.size():
			if candidate.distance_to(Geometry2D.get_closest_point_to_segment(candidate, polygon[index], polygon[(index+1)%polygon.size()])) <= maxf(PICKUP_CLEARANCE, clearance):
				return false
	var path: PackedVector2Array = nav.route(origin, candidate, clearance)
	if path.is_empty() or path[-1].distance_to(candidate) > 4.0:
		return false
	var previous := origin
	for waypoint in path:
		if not nav.segment_clear(previous, waypoint, clearance):
			return false
		previous = waypoint
	return nav.segment_clear(previous, candidate, clearance)


func _on_collected(pickup: BonusPickup, vehicle: Vehicle) -> void:
	bonus_collected.emit(vehicle, pickup.kind)
	_active_pickups.erase(pickup)
	_active_lifetimes.erase(pickup)
	if pickup == _current_pickup:
		_pending_pickups.erase(pickup)
		_current_pickup = _pending_pickups[0] if not _pending_pickups.is_empty() else null
		_begin_cooldown()


func _register_active(pickup: BonusPickup) -> void:
	if not _active_pickups.has(pickup):
		_active_pickups.append(pickup)
	_active_lifetimes[pickup] = active_lifetime


func _update_active_pickups(delta: float) -> void:
	for pickup in _active_pickups.duplicate():
		if not is_instance_valid(pickup):
			_active_pickups.erase(pickup)
			_active_lifetimes.erase(pickup)
			continue
		var remaining := float(_active_lifetimes.get(pickup, active_lifetime)) - delta
		if remaining <= 0.0:
			_active_pickups.erase(pickup)
			_active_lifetimes.erase(pickup)
			pickup.queue_free()
		else:
			_active_lifetimes[pickup] = remaining
