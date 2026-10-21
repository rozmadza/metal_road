extends Node2D
class_name Track
## Iron Circuit track: geometry, static collision walls and rendering.
##
## The track is generated at runtime from a [TrackConfig] resource, so the
## whole layout can be reshaped in the Inspector without editing this script.
## Static walls are created as segment chains, exactly like the Pymunk
## `Segment` shapes in the Python prototype.

@export var config: TrackConfig
## Toggle to rebuild collision walls from the config.
@export var build_collision: bool = true
## Show waypoints (AI navigation targets) and the finish line marker.
@export var show_debug: bool = false

var segments: Array[Vector2] = []          # start points, parallel to segment_tangents
var segment_lengths: PackedFloat32Array = PackedFloat32Array()
var segment_tangents: PackedVector2Array = PackedVector2Array()
var segment_normals: PackedVector2Array = PackedVector2Array()
var segment_midpoints: PackedVector2Array = PackedVector2Array()
var path_points: PackedVector2Array = PackedVector2Array()

var inner_boundary: PackedVector2Array = PackedVector2Array()
var outer_boundary: PackedVector2Array = PackedVector2Array()
var waypoints: Array[Dictionary] = []

var total_length: float = 0.0
var half_width: float = 0.0

var finish_point: Vector2 = Vector2.ZERO
var finish_tangent: Vector2 = Vector2.RIGHT
var finish_normal: Vector2 = Vector2.DOWN
var finish_line_start: Vector2 = Vector2.ZERO
var finish_line_end: Vector2 = Vector2.ZERO

var _walls: StaticBody2D
var _surface_line: Line2D
var _background: Sprite2D
var _bounds: Rect2 = Rect2()
var weather: FrontierWeather

const START_GANTRY := preload("res://assets/environment/arena/start_gantry.png")
const FRONTIER_TEXTURES: Array[Texture2D] = [
	preload("res://assets/environment/frontier/pumpjack_topdown.png"),
	preload("res://assets/environment/frontier/water_tower_topdown.png"),
	preload("res://assets/environment/frontier/broken_pipe_topdown.png"),
	preload("res://assets/environment/frontier/drilling_truck_topdown.png"),
	preload("res://assets/environment/frontier/checkpoint_topdown.png"),
	preload("res://assets/environment/frontier/drum_scrap_topdown.png"),
]
const DECOR_TEXTURES: Array[Texture2D] = [
	preload("res://assets/environment/arena/school_bus_topdown.png"),
	preload("res://assets/environment/arena/semi_truck_topdown.png"),
	preload("res://assets/environment/arena/tire_scrap_heap_topdown.png"),
	preload("res://assets/environment/arena/crushed_cars_topdown.png"),
	preload("res://assets/environment/arena/crushed_container_topdown.png"),
	preload("res://assets/environment/arena/metal_fence_topdown.png"),
	preload("res://assets/environment/arena/concrete_barrier_topdown.png"),
]


func _ready() -> void:
	if config == null:
		config = TrackConfig.new()
	half_width = config.track_width * 0.5
	_compute_geometry()
	if build_collision:
		_create_static_boundaries()
	_setup_assets()
	queue_redraw()


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------

func _compute_geometry() -> void:
	path_points = _build_smooth_path(config.centerline)
	var points := path_points
	var n := points.size()
	if n < 3:
		push_error("TrackConfig.centerline must contain at least 3 points.")
		return

	segments.clear()
	segment_lengths = PackedFloat32Array()
	segment_tangents = PackedVector2Array()
	segment_normals = PackedVector2Array()
	segment_midpoints = PackedVector2Array()

	total_length = 0.0

	for i in n:
		var p1 := points[i]
		var p2 := points[(i + 1) % n]
		var d := p2 - p1
		var length := d.length()
		if length <= 0.0:
			push_error("Zero-length centerline segment at index %d." % i)
			continue

		var tangent := d / length
		var normal := Vector2(-tangent.y, tangent.x)  # left of travel direction

		segments.append(p1)
		segment_lengths.append(length)
		segment_tangents.append(tangent)
		segment_normals.append(normal)
		segment_midpoints.append((p1 + p2) * 0.5)
		total_length += length

	# Boundaries are generated with the same round joins used by the visual
	# surface (Line2D), so the collision walls sit exactly on the visible edge.
	inner_boundary = _build_boundary(1.0)
	outer_boundary = _build_boundary(-1.0)

	waypoints.clear()
	for p in config.centerline:
		waypoints.append({
			"position": p,
			"radius": maxf(30.0, half_width * 0.8),
		})

	finish_point = points[0]
	finish_tangent = segment_tangents[0]
	finish_normal = segment_normals[0]
	finish_line_start = finish_point + finish_normal * half_width
	finish_line_end = finish_point - finish_normal * half_width

	_bounds = _compute_bounds()


## Replaces polygonal corners with quadratic arcs while preserving long
## straights. Dense samples are shared by rendering, physics, AI and progress.
func _build_smooth_path(controls: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	if controls.size() < 3:
		return controls
	for index in controls.size():
		var previous := controls[(index - 1 + controls.size()) % controls.size()]
		var current := controls[index]
		var following := controls[(index + 1) % controls.size()]
		var incoming := current - previous
		var outgoing := following - current
		var radius := minf(160.0, minf(incoming.length() * 0.42, outgoing.length() * 0.42))
		var entry := current - incoming.normalized() * radius
		var exit := current + outgoing.normalized() * radius
		result.append(entry)
		for step in range(1, 13):
			var t := float(step) / 12.0
			var one_minus := 1.0 - t
			result.append(entry * one_minus * one_minus + current * 2.0 * one_minus * t + exit * t * t)
	return result


## Builds an offset boundary of the centerline on one side.
## `side_sign` = +1 uses the left normal, -1 the right normal. Convex corners
## get a sampled arc (matching a round-join ribbon), concave corners get the
## miter intersection of the two offset lines.
func _build_boundary(side_sign: float) -> PackedVector2Array:
	var points := path_points
	var result := PackedVector2Array()
	if points.size() < 2:
		return points
	for index in points.size():
		var previous := points[(index - 1 + points.size()) % points.size()]
		var current := points[index]
		var following := points[(index + 1) % points.size()]
		var previous_tangent := (current - previous).normalized()
		var next_tangent := (following - current).normalized()
		var previous_normal := Vector2(-previous_tangent.y, previous_tangent.x)
		var next_normal := Vector2(-next_tangent.y, next_tangent.x)
		var normal := (previous_normal + next_normal).normalized()
		var alignment := maxf(0.5, normal.dot(next_normal))
		result.append(current + normal * half_width * side_sign / alignment)
	return result


func _compute_bounds() -> Rect2:
	var all_points: PackedVector2Array = PackedVector2Array()
	all_points.append_array(outer_boundary)
	all_points.append_array(inner_boundary)
	if all_points.is_empty():
		return Rect2()
	var rect := Rect2(all_points[0], Vector2.ZERO)
	for p in all_points:
		rect = rect.expand(p)
	return rect


func _create_static_boundaries() -> void:
	if _walls != null:
		_walls.queue_free()
	_walls = StaticBody2D.new()
	_walls.name = "Walls"
	var material := PhysicsMaterial.new()
	material.friction = 0.5
	material.bounce = 0.1
	_walls.physics_material_override = material
	add_child(_walls)

	_add_boundary_chain(outer_boundary)
	_add_boundary_chain(inner_boundary)


func _add_boundary_chain(boundary: PackedVector2Array) -> void:
	var polygon := CollisionPolygon2D.new()
	polygon.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	polygon.polygon = boundary
	_walls.add_child(polygon)


# ---------------------------------------------------------------------------
# Assets (textures can be swapped in TrackConfig without touching logic)
# ---------------------------------------------------------------------------

func _setup_assets() -> void:
	_setup_background()
	_setup_surface_line()
	_setup_edge_lines()
	_setup_tire_tracks()
	_setup_trackside_decor()
	_setup_trackside_hazards()
	_setup_start_gantry()
	_setup_weather()


func _setup_background() -> void:
	if config.background_texture == null:
		return
	_background = Sprite2D.new()
	_background.name = "BackgroundTexture"
	_background.texture = config.background_texture
	# A cool, subdued surround separates colorful vehicles from the world.
	_background.modulate = config.background_modulate
	_background.centered = false
	_background.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var bounds := _bounds.grow(520.0)
	_background.position = bounds.position
	_background.region_enabled = true
	_background.region_rect = Rect2(Vector2.ZERO, bounds.size)
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_background.z_index = -10
	add_child(_background)


func _setup_surface_line() -> void:
	if config.surface_texture == null:
		return
	_surface_line = Line2D.new()
	_surface_line.name = "SurfaceTexture"
	_surface_line.points = path_points
	_surface_line.closed = true
	_surface_line.width = config.track_width
	_surface_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_surface_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_surface_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_surface_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	_surface_line.texture = config.surface_texture
	_surface_line.material = WorldArtGuide.surface_material(config.surface_tint, config.surface_detail)
	_surface_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_surface_line.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_surface_line.z_index = -5
	add_child(_surface_line)


func _setup_edge_lines() -> void:
	_add_edge_line(inner_boundary, 14.0, WorldArtGuide.ROAD_EDGE_DARK, -4)
	_add_edge_line(outer_boundary, 14.0, WorldArtGuide.ROAD_EDGE_DARK, -4)
	_add_edge_line(inner_boundary, 4.0, config.edge_color, -3)
	_add_edge_line(outer_boundary, 4.0, config.edge_color, -3)


func _add_edge_line(points: PackedVector2Array, width: float, color: Color, layer: int) -> void:
	var line := Line2D.new()
	line.points = points
	line.closed = true
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.z_index = layer
	add_child(line)


func _setup_tire_tracks() -> void:
	var tracks := TireTracks.new()
	tracks.name = "TireTracks"
	tracks.lifetime = 7.0
	tracks.max_segments = 2600
	tracks.z_index = -1
	add_child(tracks)


func _setup_trackside_decor() -> void:
	var placements := [
		[0.08, -1.0, 0, Vector2(190, 64)], [0.16, 1.0, 2, Vector2(92, 92)],
		[0.24, -1.0, 4, Vector2(150, 58)], [0.32, 1.0, 1, Vector2(210, 82)],
		[0.41, -1.0, 3, Vector2(160, 58)], [0.49, 1.0, 5, Vector2(155, 46)],
		[0.58, -1.0, 2, Vector2(105, 105)], [0.66, 1.0, 6, Vector2(120, 48)],
		[0.75, -1.0, 1, Vector2(200, 78)], [0.83, 1.0, 3, Vector2(165, 60)],
		[0.91, -1.0, 0, Vector2(185, 62)], [0.96, 1.0, 4, Vector2(145, 56)],
	]
	for placement in placements:
		var distance := total_length * float(placement[0])
		var center := get_point_at_distance(distance)
		var info := get_closest_segment(center)
		var index := int(info.segment_index)
		var side := float(placement[1])
		var texture: Texture2D = FRONTIER_TEXTURES[int(placement[2]) % FRONTIER_TEXTURES.size()] if config.decor_style == 3 else DECOR_TEXTURES[_decor_texture_index(int(placement[2]))]
		var target_size: Vector2 = placement[3]
		var position := center + segment_normals[index] * side * (half_width + 105.0)
		_add_decor_sprite(texture, position + WorldArtGuide.SHADOW_OFFSET, target_size, segment_tangents[index].angle(), true)
		_add_decor_sprite(texture, position, target_size, segment_tangents[index].angle(), false)


func _decor_texture_index(base_index: int) -> int:
	var sets := [
		[0, 1, 4, 5, 6, 3, 2],
		[2, 3, 6, 2, 3, 6, 2],
		[3, 4, 5, 6, 3, 4, 5],
	]
	return sets[clampi(config.decor_style, 0, sets.size() - 1)][base_index % 7]


func _setup_trackside_hazards() -> void:
	if config.hazard_count <= 0:
		return
	var barrel_scene := preload("res://scenes/ExplosiveBarrel.tscn")
	var prop_scene := preload("res://scenes/MapProp.tscn")
	for hazard_index in config.hazard_count:
		var fraction := fposmod(0.13 + float(hazard_index) * 0.173, 0.94)
		var center := get_point_at_distance(total_length * fraction)
		var info := get_closest_segment(center)
		var index := int(info.segment_index)
		var side := -1.0 if hazard_index % 2 == 0 else 1.0
		var position := center + segment_normals[index] * side * half_width * 0.72
		if config.hazard_profile == &"frontier" and hazard_index % 3 == 1:
			var drift := SandDrift.new()
			drift.position = position
			drift.rotation = segment_tangents[index].angle()
			add_child(drift)
		elif config.hazard_profile == &"frontier" and hazard_index % 3 == 2:
			var oil := preload("res://scenes/OilSpot.tscn").instantiate() as OilSpot
			oil.position = position
			add_child(oil)
		elif hazard_index % 3 == 0:
			var barrel := barrel_scene.instantiate() as ExplosiveBarrel
			barrel.position = position
			add_child(barrel)
		else:
			var prop := prop_scene.instantiate() as MapProp
			prop.kind = &"crate"
			prop.size = Vector2(34, 34)
			prop.position = position
			add_child(prop)


func apply_surface_to(vehicle: Vehicle) -> void:
	if vehicle == null:
		return
	var weather_grip := weather.grip_multiplier() if weather != null else 1.0
	if is_point_on_track(vehicle.global_position, -8.0):
		vehicle.set_surface_modifier(config.road_traction * weather_grip, config.road_steering * weather_grip, self)
	else:
		vehicle.set_surface_modifier(config.offroad_traction * weather_grip, config.offroad_steering * weather_grip, self)


func _setup_weather() -> void:
	if config.weather_type != &"dust_storm" or config.storm_strength <= 0.0:
		return
	weather = FrontierWeather.new()
	weather.name = "DustStorm"
	weather.setup(config.storm_strength, config.storm_interval, config.storm_duration, config.storm_traction)
	add_child(weather)


func _add_decor_sprite(texture: Texture2D, at: Vector2, target_size: Vector2, angle: float, shadow: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.rotation = angle
	var texture_size := Vector2(texture.get_size())
	var uniform_scale := minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	sprite.scale = Vector2.ONE * uniform_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index = -3 if shadow else -2
	if shadow:
		sprite.modulate = WorldArtGuide.SHADOW_COLOR
	add_child(sprite)


func _setup_start_gantry() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "StartGantry"
	sprite.texture = START_GANTRY
	sprite.position = finish_point
	sprite.rotation = finish_tangent.angle() + PI * 0.5
	var target_width := config.track_width + 90.0
	sprite.scale = Vector2.ONE * (target_width / float(START_GANTRY.get_width()))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index = 3
	add_child(sprite)


# ---------------------------------------------------------------------------
# Queries (used by race progress and AI in later phases)
# ---------------------------------------------------------------------------

func get_start_position() -> Vector2:
	return finish_point


func get_start_angle() -> float:
	return finish_tangent.angle()


## Uses compact staggered rows when the six visual lanes are narrower than the
## actual cars. Every slot retains a distinct race progress value and enough
## side/bumper clearance for the largest participant.
func get_start_grid(count: int, vehicle_length: float = 80.0, vehicle_width: float = 48.0) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= 0:
		return result
	var edge_margin := maxf(28.0, vehicle_width * 0.5 + 8.0)
	var usable_half_width := maxf(0.0, half_width - edge_margin)
	var column_step := vehicle_width + 12.0
	var columns := mini(count, maxi(1, 1 + floori(usable_half_width * 2.0 / column_step)))
	# Curves near the finish can shorten the straight-line separation between
	# adjacent rows, so leave extra room beyond the bumper-to-bumper length.
	var row_step := vehicle_length + 54.0
	for index in count:
		var column := index % columns
		var row := floori(float(index) / float(columns))
		var across := (float(column) - float(columns - 1) * 0.5) * column_step
		# A short within-row stagger gives every racer a distinct start rank.
		var centre := get_point_at_distance(row_step * float(row) + float(column) * 12.0)
		var centre_info := get_closest_segment(centre)
		var local_normal := segment_normals[int(centre_info.segment_index)]
		result.append(centre + local_normal * across)
	return result


func get_bounds() -> Rect2:
	return _bounds


func get_total_length() -> float:
	return total_length


## Projects a point onto the centerline.
## Returns { segment_index, closest_point, t, distance }.
func get_closest_segment(point: Vector2) -> Dictionary:
	var min_dist := INF
	var best_idx := 0
	var best_t := 0.0
	var best_point := path_points[0]

	for i in segment_tangents.size():
		var p1 := segments[i]
		var p2 := path_points[(i + 1) % path_points.size()]
		var d := p2 - p1
		var seg_len_sq := d.length_squared()
		var t := 0.0
		if seg_len_sq > 0.0:
			t = clampf((point - p1).dot(d) / seg_len_sq, 0.0, 1.0)
		var closest := p1 + d * t
		var dist := point.distance_to(closest)
		if dist < min_dist:
			min_dist = dist
			best_idx = i
			best_t = t
			best_point = closest

	return {
		"segment_index": best_idx,
		"closest_point": best_point,
		"t": best_t,
		"distance": min_dist,
	}


## Distance travelled along the centerline (0..total_length) for a point.
func get_progress_along_track(point: Vector2) -> float:
	var info := get_closest_segment(point)
	var idx: int = info["segment_index"]
	var progress := 0.0
	for i in idx:
		progress += segment_lengths[i]
	progress += segment_lengths[idx] * info["t"]
	return progress


## Samples the racing line by travelled distance. Used by world pickups so
## they always land on drivable asphalt.
func get_point_at_distance(distance: float) -> Vector2:
	if segment_lengths.is_empty() or total_length <= 0.0:
		return get_start_position()
	var remaining := fposmod(distance, total_length)
	for index in segment_lengths.size():
		if remaining <= segment_lengths[index]:
			var next := path_points[(index + 1) % path_points.size()]
			return segments[index].lerp(next, remaining / segment_lengths[index])
		remaining -= segment_lengths[index]
	return segments[0]


func is_point_on_track(point: Vector2, margin: float = 5.0) -> bool:
	return get_closest_segment(point)["distance"] <= (half_width - margin)


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _draw() -> void:
	if config == null or outer_boundary.size() < 3:
		return

	# Track surface. Without a texture it is drawn as a filled ring. With a
	# texture the Line2D ribbon created in _setup_assets() provides the
	# surface, so no polygon fill is needed.
	if config.surface_texture == null:
		draw_colored_polygon(outer_boundary, config.surface_color)
		if inner_boundary.size() >= 3:
			draw_colored_polygon(inner_boundary, config.background_color)

	var lanes := maxi(1, config.lane_count)
	var lane_width := config.track_width / float(lanes)
	for lane in range(1, lanes):
		var offset := -half_width + lane_width * float(lane)
		var divider := _build_offset_loop(offset)
		_draw_dashed_loop(divider, config.centerline_color, 1.0, 14.0, 12.0)

	var finish_cells := 12
	var finish_step := config.track_width / float(finish_cells)
	for cell in finish_cells:
		var from := finish_line_end + finish_normal * finish_step * float(cell)
		var color := Color("e5d8bd") if cell % 2 == 0 else Color("292521")
		draw_line(from, from + finish_normal * finish_step, color, 8.0, true)

	if show_debug:
		for wp in waypoints:
			draw_arc(wp["position"], wp["radius"], 0.0, TAU, 32, config.waypoint_color, 1.0, true)
			draw_circle(wp["position"], 3.0, config.waypoint_color)


func _draw_dashed_loop(points: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	var n := points.size()
	for i in n:
		var p1 := points[i]
		var p2 := points[(i + 1) % n]
		var seg := p2 - p1
		var seg_len := seg.length()
		if seg_len <= 0.0:
			continue
		var dir := seg / seg_len
		var dist := 0.0
		var drawing := true
		while dist < seg_len:
			var next_dist: float = minf(dist + (dash if drawing else gap), seg_len)
			if drawing:
				draw_line(p1 + dir * dist, p1 + dir * next_dist, color, width, true)
			dist = next_dist
			drawing = not drawing


func _build_offset_loop(offset: float) -> PackedVector2Array:
	var points := path_points
	var result := PackedVector2Array()
	for index in points.size():
		var previous := points[(index - 1 + points.size()) % points.size()]
		var current := points[index]
		var following := points[(index + 1) % points.size()]
		var previous_normal := Vector2(-(current - previous).normalized().y, (current - previous).normalized().x)
		var next_normal := Vector2(-(following - current).normalized().y, (following - current).normalized().x)
		var joined_normal := (previous_normal + next_normal).normalized()
		var alignment := maxf(0.5, joined_normal.dot(next_normal))
		result.append(current + joined_normal * offset / alignment)
	return result


func set_debug_enabled(enabled: bool) -> void:
	show_debug = enabled
	queue_redraw()
