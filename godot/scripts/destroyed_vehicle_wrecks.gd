extends Node2D
## Arena-owned session container: waves retain it, full Restart frees it.
const Wreck = preload("res://scripts/destroyed_vehicle_wreck.gd")
const MAX_ACTIVE := 5
const LIFETIME := 25.0
var active := true
var generation := 0
var _pending := 0

func queue_vehicle(vehicle: Vehicle) -> void:
	if not active or vehicle.has_meta("wreck_queued"): return
	vehicle.set_meta("wreck_queued",true)
	if _pending >= MAX_ACTIVE:
		vehicle.hide()
		vehicle.queue_free()
		return
	var data := Wreck.snapshot(vehicle)
	vehicle.hide()
	vehicle.process_mode = Node.PROCESS_MODE_DISABLED
	# Vehicle._die queued its collision disable before this method. The source
	# is retained until this deferred handoff, never two overlapping solid hulls.
	_pending += 1
	_spawn_deferred.call_deferred(data,weakref(vehicle),generation)

func _spawn_deferred(data: Dictionary, source: WeakRef, expected: int) -> void:
	_pending -= 1
	var old := source.get_ref() as Vehicle
	if is_instance_valid(old): old.queue_free()
	if not active or expected != generation: return
	var wrecks := get_children().filter(func(node):return not node.is_queued_for_deletion())
	if wrecks.size() >= MAX_ACTIVE:
		# Stable oldest-first eviction, preferring a body not in player contact.
		var victim: Node
		for wreck in wrecks:
			if not wreck.touching_vehicle(): victim= wreck; break
		# Five simultaneous occupied covers keep priority over a new wreck.
		# No pending queue can grow while they remain occupied.
		if victim == null: return
		victim.free()
	var wreck := Wreck.new()
	wreck.lifetime = LIFETIME
	wreck.setup(data)
	# Container is identity-relative to Arena; preserve world-space death pose.
	add_child(wreck)
	wreck.global_position = data.position
	wreck.global_rotation = data.angle
	if is_instance_valid(old): wreck.adopt_effects(old)

func stop() -> void:
	active = false
	generation += 1
	for wreck in get_children(): wreck.freeze = true

func clear_spawn_area(point: Vector2, config: VehicleConfig) -> void:
	# Retain authored spawn anchors and enemy counts. An expired vehicle may
	# not turn the next wave's mandatory anchor into overlapping solid bodies.
	var radius := (Vector2(config.length,config.width)*Vehicle.COLLISION_SCALE).length()*0.5+4.0
	for wreck in get_children():
		if wreck.navigation_rect().grow(radius).has_point(point): wreck.free()
