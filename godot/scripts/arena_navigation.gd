extends RefCounted
## Shared, size-aware navigation. Cached grids only change with arena geometry.

const CELL := 24.0
var arena: Node2D
var _rects: Array[Rect2] = []
var _grids: Dictionary = {}
var _refresh_frame := -1000

func setup(value: Node2D) -> void:
	arena = value
	_refresh()

func clearance(vehicle: Vehicle) -> float:
	return ceilf((vehicle.config.width * Vehicle.COLLISION_SCALE.y * 0.5 + vehicle.config.length * Vehicle.COLLISION_SCALE.x * 0.23 + 6.0) / 8.0) * 8.0

func _refresh() -> void:
	var frame := Engine.get_physics_frames()
	if frame - _refresh_frame < 45: return
	_refresh_frame = frame
	var rects: Array[Rect2] = arena.get_obstacles().duplicate()
	for node in arena.get_tree().get_nodes_in_group("arena_obstacles"):
		if not is_instance_valid(node) or bool(node.get("destroyed")): continue
		var half: Vector2 = node.size * Vector2(0.48, 0.46)
		var c := absf(cos(node.global_rotation))
		var s := absf(sin(node.global_rotation))
		var extent := Vector2(half.x * c + half.y * s, half.x * s + half.y * c)
		rects.append(Rect2(node.global_position - extent, extent * 2.0))
	for node in arena.get_tree().get_nodes_in_group("destructibles"):
		if node is ExplosiveBarrel and not node.destroyed:
			rects.append(Rect2(node.global_position - Vector2(18, 18), Vector2(36, 36)))
	if rects != _rects:
		_rects = rects
		_grids.clear()

func _grid(radius: float) -> AStarGrid2D:
	_refresh()
	var key := int(radius)
	if _grids.has(key): return _grids[key]
	var bounds: Rect2 = arena.get_bounds()
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(ceilf(bounds.size.x / CELL), ceilf(bounds.size.y / CELL)))
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = bounds.position + Vector2.ONE * CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var interior := bounds.grow(-radius - 4.0)
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var id := Vector2i(x, y)
			var point := grid.get_point_position(id)
			var solid := not interior.has_point(point)
			if not solid:
				for rect in _rects:
					if rect.grow(radius + 4.0).has_point(point):
						solid = true
						break
			grid.set_point_solid(id, solid)
	_grids[key] = grid
	return grid

func _nearest_open(grid: AStarGrid2D, point: Vector2) -> Vector2i:
	var id := Vector2i((point - grid.offset) / CELL + Vector2.ONE * 0.5)
	id = id.clamp(grid.region.position, grid.region.end - Vector2i.ONE)
	if not grid.is_point_solid(id): return id
	var best := Vector2i(-1, -1)
	var distance := INF
	for ring in range(1, 13):
		for y in range(maxi(0, id.y - ring), mini(grid.region.end.y, id.y + ring + 1)):
			for x in range(maxi(0, id.x - ring), mini(grid.region.end.x, id.x + ring + 1)):
				var candidate := Vector2i(x, y)
				if maxi(absi(x - id.x), absi(y - id.y)) != ring or grid.is_point_solid(candidate): continue
				var d := grid.get_point_position(candidate).distance_squared_to(point)
				if d < distance:
					distance = d
					best = candidate
		if best.x >= 0: return best
	return best

func route(start: Vector2, goal: Vector2, radius: float) -> PackedVector2Array:
	var grid := _grid(radius)
	var from := _nearest_open(grid, start)
	var to := _nearest_open(grid, goal)
	if from.x < 0 or to.x < 0: return PackedVector2Array()
	var raw := grid.get_point_path(from, to)
	if raw.is_empty(): return raw
	var result := PackedVector2Array()
	var anchor := start
	var index := 0
	# Visibility smoothing eliminates the grid's staircase before steering.
	while index < raw.size():
		var furthest := index
		for next in range(index + 1, raw.size()):
			if not segment_clear(anchor, raw[next], radius + 2.0): break
			furthest = next
		result.append(raw[furthest])
		anchor = raw[furthest]
		index = furthest + 1
	if segment_clear(anchor, goal, radius + 2.0):
		if anchor.distance_to(goal) > 4.0:
			result.append(goal)
	return result

func segment_clear(start: Vector2, end: Vector2, radius: float) -> bool:
	var bounds: Rect2 = arena.get_bounds()
	if not bounds.grow(-radius).has_point(end): return false
	for rect in _rects:
		var expanded := rect.grow(radius)
		# A collision or a wide corner can put the centre inside the planning
		# margin. Allow an outward escape, never a shortcut through the prop.
		if expanded.has_point(start) and not expanded.has_point(end) and (end - start).dot(start - expanded.get_center()) > 0.0:
			continue
		if _entry_fraction(start, end, expanded) < INF: return false
	return true

func point_clear(point: Vector2, radius: float) -> bool:
	_refresh()
	var bounds: Rect2 = arena.get_bounds()
	if not bounds.grow(-radius).has_point(point): return false
	for rect in _rects:
		if rect.grow(radius).has_point(point): return false
	return true

func free_distance(start: Vector2, direction: Vector2, length: float, radius: float) -> float:
	_refresh()
	var end := start + direction * length
	var result := length
	var bounds: Rect2 = arena.get_bounds().grow(-radius)
	for axis in 2:
		if direction[axis] > 0.001:
			result = minf(result, maxf(0.0, (bounds.end[axis] - start[axis]) / direction[axis]))
		elif direction[axis] < -0.001:
			result = minf(result, maxf(0.0, (bounds.position[axis] - start[axis]) / direction[axis]))
	for rect in _rects:
		var expanded := rect.grow(radius)
		# Permit a car already touching conservative clearance to pull away.
		if expanded.has_point(start) and direction.dot(start - expanded.get_center()) > 0.0: continue
		result = minf(result, _entry_fraction(start, end, expanded) * length)
	return result

func _entry_fraction(start: Vector2, end: Vector2, rect: Rect2) -> float:
	var delta := end - start
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		if absf(delta[axis]) < 0.0001:
			if start[axis] < rect.position[axis] or start[axis] > rect.end[axis]: return INF
		else:
			var a := (rect.position[axis] - start[axis]) / delta[axis]
			var b := (rect.end[axis] - start[axis]) / delta[axis]
			enter = maxf(enter, minf(a, b))
			leave = minf(leave, maxf(a, b))
			if enter > leave: return INF
	return enter
