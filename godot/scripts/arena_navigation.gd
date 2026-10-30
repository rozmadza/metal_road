extends RefCounted
## Shared, size-aware navigation. Cached grids only change with arena geometry.

const CELL := 24.0
var arena: Node2D
var _rects: Array[Rect2] = []
var _grids: Dictionary = {}
var _refresh_frame := -1000
var _dynamic_rects: Array[Rect2] = []
var _dynamic_frame := -1
var _dynamic_revision := 0
var _dynamic_cells: Dictionary = {}
var _dynamic_versions: Dictionary = {}
var _static_cells: Dictionary = {}
var _dynamic_source: RefCounted

func _refresh_dynamic() -> void:
	var frame := Engine.get_physics_frames()
	if _dynamic_frame == frame: return
	_dynamic_frame = frame
	var rectangles: Array[Rect2] = []
	if _dynamic_source != null:
		_dynamic_source._refresh_dynamic()
		rectangles.assign(_dynamic_source._dynamic_rects)
	else:
		for wreck in arena.get_tree().get_nodes_in_group("vehicle_wrecks"):
			if arena.is_ancestor_of(wreck) and not wreck.is_queued_for_deletion():
				rectangles.append(wreck.navigation_rect())
	if rectangles != _dynamic_rects:
		_dynamic_rects = rectangles
		_dynamic_revision += 1

func _apply_dynamic(grid: AStarGrid2D, key: int, radius: float) -> void:
	_refresh_dynamic()
	if int(_dynamic_versions.get(key,-1)) == _dynamic_revision: return
	var covered := {}
	for rect in _dynamic_rects:
		var expanded := rect.grow(radius + 4.0)
		var from := Vector2i((expanded.position-grid.offset)/CELL).clamp(Vector2i.ZERO,grid.region.end-Vector2i.ONE)
		var to := Vector2i((expanded.end-grid.offset)/CELL+Vector2.ONE).clamp(Vector2i.ZERO,grid.region.end-Vector2i.ONE)
		for y in range(from.y,to.y+1):
			for x in range(from.x,to.x+1):
				var cell := Vector2i(x,y)
				if expanded.has_point(grid.get_point_position(cell)): covered[cell]=true
	var old: Dictionary = _dynamic_cells.get(key,{})
	var static_solid: Dictionary = _static_cells[key]
	for cell in old:
		if not covered.has(cell): grid.set_point_solid(cell,static_solid.has(cell))
	for cell in covered:
		if not old.has(cell): grid.set_point_solid(cell,true)
	_dynamic_cells[key]=covered
	_dynamic_versions[key]=_dynamic_revision

func setup(value: Node2D) -> void:
	arena = value
	_refresh()

func clearance(vehicle: Vehicle) -> float:
	var footprint := Vector2(vehicle.config.length, vehicle.config.width) * Vehicle.COLLISION_SCALE
	var driving_margin := footprint.y * 0.5 + footprint.x * 0.23 + 6.0
	# A long body must fit through a heading change, not just a straight lane.
	return ceilf(maxf(driving_margin, footprint.length() * 0.5) / 8.0) * 8.0

func _refresh() -> void:
	var frame := Engine.get_physics_frames()
	if frame - _refresh_frame < 45: return
	_refresh_frame = frame
	var rects: Array[Rect2] = arena.get_navigation_obstacles() if arena is Arena else arena.get_obstacles().duplicate()
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
		_dynamic_cells.clear()
		_dynamic_versions.clear()
		_static_cells.clear()

func _grid(radius: float) -> AStarGrid2D:
	_refresh()
	var key := int(radius)
	if _grids.has(key):
		_apply_dynamic(_grids[key],key,radius)
		return _grids[key]
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
	var static_solid := {}
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
			if solid: static_solid[id]=true
	_grids[key] = grid
	_static_cells[key] = static_solid
	_apply_dynamic(grid,key,radius)
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
	return route_result(start, goal, radius).path


## A short-lived planning snapshot for one driver's confirmed traffic jam.
## Never mutate shared cached grids or add physical obstacles to the arena.
func with_traffic(rectangles: Array[Rect2]) -> RefCounted:
	_refresh()
	var snapshot: RefCounted = get_script().new()
	snapshot.arena = arena
	snapshot._rects = _rects.duplicate()
	snapshot._rects.append_array(rectangles)
	snapshot._refresh_frame = Engine.get_physics_frames() + 1000000
	snapshot._dynamic_source = self
	return snapshot


## Compatibility callers may keep route(); drivers need the explicit outcome.
## NEAREST is a reachable stopping point, never permission to drive at goal.
func route_result(start: Vector2, goal: Vector2, radius: float) -> Dictionary:
	var missing := {"status": &"NONE", "path": PackedVector2Array(), "requested": goal, "resolved": start}
	if not arena.get_bounds().has_point(start): return missing
	var grid := _grid(radius)
	var from := _nearest_open(grid, start)
	var to := _nearest_open(grid, goal)
	if from.x < 0 or to.x < 0: return missing
	if not segment_clear(start, grid.get_point_position(from), radius + 2.0):
		var distance := INF
		from = Vector2i(-1,-1)
		for y in grid.region.size.y:
			for x in grid.region.size.x:
				var cell := Vector2i(x,y)
				if grid.is_point_solid(cell): continue
				var point := grid.get_point_position(cell)
				var d := start.distance_squared_to(point)
				if d < distance and segment_clear(start, point, radius + 2.0):
					from = cell
					distance = d
		if from.x < 0: return missing
	var raw := grid.get_point_path(from, to)
	if raw.is_empty():
		# Find the closest point in the START component, not on an island
		# selected only by geometric distance to the requested goal.
		to = _reachable_nearest(grid, from, goal)
		raw = grid.get_point_path(from, to)
	if raw.is_empty(): return missing
	if not segment_clear(start, raw[0], radius + 2.0): return missing
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
		if not anchor.is_equal_approx(goal):
			result.append(goal)
	var resolved := result[result.size() - 1]
	return {"status": &"EXACT" if resolved.is_equal_approx(goal) else &"NEAREST", "path": result, "requested": goal, "resolved": resolved}


func _reachable_nearest(grid: AStarGrid2D, start: Vector2i, goal: Vector2) -> Vector2i:
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var best := start
	var distance := grid.get_point_position(start).distance_squared_to(goal)
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		var d := grid.get_point_position(current).distance_squared_to(goal)
		if d < distance:
			best = current
			distance = d
		# Cardinal flood fill is sufficient: diagonal grid moves cannot
		# connect components separated under ONLY_IF_NO_OBSTACLES.
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + step
			if grid.region.has_point(next) and not visited.has(next) and not grid.is_point_solid(next):
				visited[next] = true
				queue.append(next)
	return best

func segment_clear(start: Vector2, end: Vector2, radius: float) -> bool:
	_refresh_dynamic()
	var bounds: Rect2 = arena.get_bounds()
	if not bounds.grow(-radius).has_point(end): return false
	for rect in _rects + _dynamic_rects:
		var expanded := rect.grow(radius)
		# A collision or a wide corner can put the centre inside the planning
		# margin. Allow an outward escape, never a shortcut through the prop.
		if expanded.has_point(start) and not expanded.has_point(end) and (end - start).dot(start - expanded.get_center()) > 0.0:
			continue
		if _entry_fraction(start, end, expanded) < INF: return false
	return true

func point_clear(point: Vector2, radius: float) -> bool:
	_refresh()
	_refresh_dynamic()
	var bounds: Rect2 = arena.get_bounds()
	if not bounds.grow(-radius).has_point(point): return false
	for rect in _rects + _dynamic_rects:
		if rect.grow(radius).has_point(point): return false
	return true

func free_distance(start: Vector2, direction: Vector2, length: float, radius: float) -> float:
	_refresh()
	_refresh_dynamic()
	var end := start + direction * length
	var result := length
	var bounds: Rect2 = arena.get_bounds().grow(-radius)
	for axis in 2:
		if direction[axis] > 0.001:
			result = minf(result, maxf(0.0, (bounds.end[axis] - start[axis]) / direction[axis]))
		elif direction[axis] < -0.001:
			result = minf(result, maxf(0.0, (bounds.position[axis] - start[axis]) / direction[axis]))
	for rect in _rects + _dynamic_rects:
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
