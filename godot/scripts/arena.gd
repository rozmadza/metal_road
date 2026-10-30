extends Node2D
class_name Arena
## Battle-royale arena: a rectangular floor with static walls and obstacle
## blocks that double as cover.
##
## Geometry comes from an [ArenaConfig] resource, so the layout can be
## reshaped in the Inspector without touching this script.

@export var config: ArenaConfig
const Navigation = preload("res://scripts/arena_navigation.gd")
var _navigation: RefCounted

const OBSTACLE_VISUAL_SCALE := 1.03
const COLLISION_SILHOUETTE_SCALE := 0.9
const COLLISION_ALPHA_THRESHOLD := 0.35
const FRONTIER_TEXTURES: Array[Texture2D] = [
	preload("res://assets/environment/frontier/pumpjack_topdown.png"),
	preload("res://assets/environment/frontier/water_tower_topdown.png"),
	preload("res://assets/environment/frontier/broken_pipe_topdown.png"),
	preload("res://assets/environment/frontier/drilling_truck_topdown.png"),
	preload("res://assets/environment/frontier/checkpoint_topdown.png"),
	preload("res://assets/environment/frontier/drum_scrap_topdown.png"),
]

static var _last_variation_by_biome: Dictionary = {}

var _obstacles: Array[Rect2] = []
var _obstacle_polygons: Array[PackedVector2Array] = []
var _bounds: Rect2 = Rect2()
var tire_tracks: TireTracks
var weather: FrontierWeather
var _ground: Sprite2D
var _run_rng := RandomNumberGenerator.new()
var _obstacle_texture_slots: Array[int] = []
var _run_variation_id := 0


func _ready() -> void:
	if config == null:
		config = ArenaConfig.new()
	_prepare_run_variation()
	_obstacles.clear()
	for rect in config.obstacles:
		_obstacles.append(rect)
	_prepare_obstacle_polygons()
	_bounds = Rect2(Vector2.ZERO, config.size)
	_create_ground()
	if config.structured_scrapyard:
		var dressing := preload("res://scripts/arena_dressing.gd").new()
		dressing.name = "ArenaDressing"
		dressing.config = config
		add_child(dressing)
	_create_collision()
	_create_tire_tracks()
	_create_interactives()
	_create_obstacle_visuals()
	_create_weather()
	queue_redraw()


func _create_ground() -> void:
	if config.floor_texture == null:
		return
	_ground = Sprite2D.new()
	_ground.name = "ArenaGround"
	_ground.texture = config.floor_texture
	_ground.centered = false
	_ground.region_enabled = true
	_ground.region_rect = _bounds
	_ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ground.material = WorldArtGuide.surface_material(WorldArtGuide.arena_surface_tint(config.biome_id, config.floor_color), 0.16 if config.structured_scrapyard else 0.32)
	_ground.z_index = -20
	add_child(_ground)


func _create_tire_tracks() -> void:
	tire_tracks = TireTracks.new()
	tire_tracks.name = "TireTracks"
	add_child(tire_tracks)


func _create_obstacle_visuals() -> void:
	var visual_count := _obstacles.size() if config.biome_id == &"rust_frontier" else mini(_obstacles.size(), 5)
	for index in visual_count:
		var texture := _obstacle_texture(index)
		if texture == null:
			continue
		var rect := _obstacles[index]
		var texture_size := Vector2(texture.get_size())
		var vertical := (rect.size.y > rect.size.x) != (texture_size.y > texture_size.x)
		var target_size := rect.size * OBSTACLE_VISUAL_SCALE
		var center := rect.position + rect.size * 0.5
		# The central ground-level wreck must not overpaint car bodies at z=0.
		var ground_wreck := config.structured_scrapyard and config.biome_id == &"scrapyard" and index == 0
		_add_obstacle_footprint(_obstacle_polygons[index], -4 if ground_wreck else -1)
		_add_obstacle_sprite(texture, center + WorldArtGuide.SHADOW_OFFSET, target_size, vertical, true, -3 if ground_wreck else 0)
		_add_obstacle_sprite(texture, center, target_size, vertical, false, -2 if ground_wreck else 0)


func _create_weather() -> void:
	if config.weather_type != &"dust_storm": return
	weather = FrontierWeather.new()
	weather.name = "DustStorm"
	weather.setup(config.storm_strength, 24.0, 11.0, config.storm_traction)
	add_child(weather)


func apply_surface_to(vehicle: Vehicle) -> void:
	if vehicle == null: return
	var grip := weather.grip_multiplier() if weather != null else 1.0
	vehicle.set_surface_modifier(grip, grip, self)


func _add_obstacle_sprite(texture: Texture2D, position: Vector2, target_size: Vector2, vertical: bool, shadow: bool, layer: int = 0) -> void:
	var sprite := Sprite2D.new()
	sprite.z_index = layer
	sprite.texture = texture
	sprite.position = position
	sprite.rotation = PI * 0.5 if vertical else 0.0
	# Atlas cells and source props have different silhouettes. A uniform scale
	# keeps tanks, pipes and trucks mechanically believable instead of forcing
	# every image into the collision rectangle's aspect ratio.
	var texture_size := Vector2(texture.get_size())
	var effective_size := Vector2(texture_size.y, texture_size.x) if vertical else texture_size
	# Fit the complete artwork inside its authored layout slot. Physics is then
	# derived from this exact rendered silhouette instead of the old rectangle.
	var uniform_scale := minf(target_size.x / effective_size.x, target_size.y / effective_size.y)
	sprite.scale = Vector2.ONE * uniform_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if shadow:
		sprite.name = "ObstacleShadow"
		sprite.modulate = WorldArtGuide.SHADOW_COLOR
	else:
		sprite.name = "ObstacleArt"
	add_child(sprite, true)


func _add_obstacle_footprint(polygon: PackedVector2Array, layer: int = -1) -> void:
	# Both the marker and physics use the same alpha-derived convex silhouette.
	# Round heaps therefore read as round, while long vehicles remain elongated.
	var fill := Polygon2D.new()
	fill.name = "ObstacleFootprint"
	fill.polygon = polygon
	fill.color = WorldArtGuide.CONTACT_COLOR
	fill.z_index = layer
	add_child(fill, true)

func _create_interactives() -> void:
	var oil_scene := preload("res://scenes/OilSpot.tscn")
	for point in config.oil_spots:
		var oil: OilSpot = oil_scene.instantiate()
		oil.position = _varied_prop_position(point, 34.0)
		add_child(oil)
	var barrel_scene := preload("res://scenes/ExplosiveBarrel.tscn")
	for point in config.explosive_barrels:
		var barrel: ExplosiveBarrel = barrel_scene.instantiate()
		barrel.position = _varied_prop_position(point, 28.0)
		add_child(barrel)
	var prop_scene := preload("res://scenes/MapProp.tscn")
	_create_props(prop_scene, config.crates, &"crate", Vector2(38, 38))
	_create_props(prop_scene, config.tire_walls, &"tire_wall", Vector2(52, 52))
	_create_props(prop_scene, config.wrecks, &"wreck", Vector2(86, 38))
	_create_props(prop_scene, config.concrete_blocks, &"concrete", Vector2(70, 14))
	_create_props(prop_scene, config.metal_fences, &"fence", Vector2(100, 12))

func _create_props(scene: PackedScene, points: Array[Vector2], kind: StringName, prop_size: Vector2) -> void:
	for point in points:
		var prop: MapProp = scene.instantiate()
		prop.kind = kind
		prop.size = prop_size
		prop.position = _varied_prop_position(point, 38.0)
		# Small authored rotations keep the silhouette believable while making
		# each run read as a newly assembled arena rather than a copied layout.
		prop.rotation = _run_rng.randf_range(-0.24, 0.24)
		prop.set_meta("run_variation", _run_variation_id)
		add_child(prop)


func _prepare_run_variation() -> void:
	_run_rng.seed = int(Time.get_ticks_usec()) ^ int(Time.get_unix_time_from_system() * 1000.0) ^ get_instance_id()
	var art_count := FRONTIER_TEXTURES.size() if config.biome_id == &"rust_frontier" else 5
	var shift := _run_rng.randi_range(0, maxi(art_count - 1, 0))
	var reverse_order := _run_rng.randf() > 0.5
	var signature := shift * 2 + int(reverse_order)
	var previous := int(_last_variation_by_biome.get(config.biome_id, -1))
	if art_count > 1 and signature == previous:
		shift = (shift + 1) % art_count
		signature = shift * 2 + int(reverse_order)
	_last_variation_by_biome[config.biome_id] = signature
	_run_variation_id = signature
	_obstacle_texture_slots.clear()
	if config.structured_scrapyard:
		_obstacle_texture_slots.assign([3, 4, 4, 0, 1])
		_run_variation_id = 0
		set_meta("run_variation", 0)
		return
	for index in art_count:
		var source := (index + shift) % art_count
		if reverse_order:
			source = (art_count - 1 - index + shift) % art_count
		_obstacle_texture_slots.append(source)
	set_meta("run_variation", _run_variation_id)


func _varied_prop_position(origin: Vector2, radius: float) -> Vector2:
	if config.structured_scrapyard:
		return origin
	var safe_bounds := Rect2(Vector2(42.0, 42.0), config.size - Vector2(84.0, 84.0))
	for attempt in 7:
		var angle := _run_rng.randf_range(0.0, TAU)
		var distance := _run_rng.randf_range(radius * 0.28, radius)
		var candidate := origin + Vector2.RIGHT.rotated(angle) * distance
		candidate.x = clampf(candidate.x, safe_bounds.position.x, safe_bounds.end.x)
		candidate.y = clampf(candidate.y, safe_bounds.position.y, safe_bounds.end.y)
		var clear := true
		for obstacle in _obstacles:
			if obstacle.grow(30.0).has_point(candidate):
				clear = false
				break
		if clear:
			return candidate
	return origin


func _create_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.set_meta("impact_factor", 1.1)
	var material := PhysicsMaterial.new()
	material.friction = 0.5
	material.bounce = 0.1
	body.physics_material_override = material
	add_child(body)

	var t := config.wall_thickness
	_add_box(body, Rect2(-t, -t, config.size.x + t * 2.0, t))              # top
	_add_box(body, Rect2(-t, config.size.y, config.size.x + t * 2.0, t))   # bottom
	_add_box(body, Rect2(-t, 0.0, t, config.size.y))                       # left
	_add_box(body, Rect2(config.size.x, 0.0, t, config.size.y))            # right

	var obstacle_collisions := Node2D.new()
	obstacle_collisions.name = "ObstacleCollisions"
	add_child(obstacle_collisions)
	var impact_factors := [0.3, 1.0, 1.0, 0.85, 1.0]
	for index in _obstacles.size():
		var obstacle_body := StaticBody2D.new()
		obstacle_body.name = "Obstacle%d" % index
		obstacle_body.physics_material_override = material
		obstacle_body.set_meta("impact_factor", impact_factors[index] if index < impact_factors.size() else 1.0)
		obstacle_collisions.add_child(obstacle_body)
		var texture := _obstacle_texture(index)
		if texture == null:
			_add_box(obstacle_body, _obstacles[index])
		else:
			var shape := CollisionPolygon2D.new()
			shape.name = "Silhouette"
			shape.polygon = _obstacle_polygons[index]
			obstacle_body.add_child(shape)


func _prepare_obstacle_polygons() -> void:
	_obstacle_polygons.clear()
	for index in _obstacles.size():
		var texture := _obstacle_texture(index)
		var rect := _obstacles[index]
		if texture == null:
			_obstacle_polygons.append(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))
		else:
			_obstacle_polygons.append(_build_obstacle_polygon(texture, rect))


func _obstacle_texture(index: int) -> Texture2D:
	var texture_index := _obstacle_texture_slots[index] if index >= 0 and index < _obstacle_texture_slots.size() else index
	if config.biome_id == &"rust_frontier":
		return FRONTIER_TEXTURES[texture_index % FRONTIER_TEXTURES.size()]
	var textures: Array[Texture2D] = [
		config.tire_heap_texture,
		config.school_bus_texture,
		config.semi_truck_texture,
		config.crushed_cars_texture,
		config.crushed_container_texture,
	]
	return textures[texture_index] if texture_index >= 0 and texture_index < textures.size() else null


func _build_obstacle_polygon(texture: Texture2D, rect: Rect2) -> PackedVector2Array:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var texture_size := Vector2(image.get_size())
	var rotated := (rect.size.y > rect.size.x) != (texture_size.y > texture_size.x)
	var effective_size := Vector2(texture_size.y, texture_size.x) if rotated else texture_size
	var sprite_scale := minf(rect.size.x / effective_size.x, rect.size.y / effective_size.y) * OBSTACLE_VISUAL_SCALE
	var center := rect.get_center()
	var sample_step := maxi(1, ceili(maxf(texture_size.x, texture_size.y) / 72.0))
	var opaque_points := PackedVector2Array()
	for y in range(0, image.get_height(), sample_step):
		for x in range(0, image.get_width(), sample_step):
			if image.get_pixel(x, y).a < COLLISION_ALPHA_THRESHOLD:
				continue
			var point := Vector2(x + 0.5, y + 0.5) - texture_size * 0.5
			if rotated:
				point = Vector2(-point.y, point.x)
			opaque_points.append(center + point * sprite_scale * COLLISION_SILHOUETTE_SCALE)
	if opaque_points.size() < 3:
		return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	return Geometry2D.convex_hull(opaque_points)


func _add_box(parent: Node, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.position + rect.size * 0.5
	parent.add_child(shape)


# ---------------------------------------------------------------------------
# Queries (used by the survival mode and the combat AI)
# ---------------------------------------------------------------------------

func get_bounds() -> Rect2:
	return _bounds


func get_obstacles() -> Array[Rect2]:
	return _obstacles


## Navigation envelopes of collision hulls, not the larger artwork slots.
func get_navigation_obstacles() -> Array[Rect2]:
	var rects: Array[Rect2] = _obstacles.duplicate()
	if _obstacle_polygons.size() == rects.size():
		for index in rects.size():
			var polygon := _obstacle_polygons[index]
			if polygon.is_empty(): continue
			var box := Rect2(polygon[0], Vector2.ZERO)
			for point in polygon: box = box.expand(point)
			rects[index] = box
	return rects


func navigation() -> RefCounted:
	if _navigation == null:
		_navigation = Navigation.new()
		_navigation.setup(self)
	return _navigation


func get_run_variation_id() -> int:
	return _run_variation_id


## Returns spawn anchors spread around the arena perimeter. Survival can field
## eight opponents plus the player, so the list must not stop at eight.
func get_spawn_points(count: int) -> Array[Vector2]:
	var m := config.spawn_margin
	var w := config.size.x
	var h := config.size.y
	var anchors: Array[Vector2] = [
		Vector2(m, m),
		Vector2(w - m, m),
		Vector2(w - m, h - m),
		Vector2(m, h - m),
		Vector2(w * 0.5, m),
		Vector2(w - m, h * 0.5),
		Vector2(w * 0.5, h - m),
		Vector2(m, h * 0.5),
		Vector2(w * 0.27, m),
		Vector2(w - m, h * 0.27),
		Vector2(w * 0.73, h - m),
		Vector2(m, h * 0.73),
	]
	var result: Array[Vector2] = []
	for i in mini(maxi(count, 0), anchors.size()):
		result.append(anchors[i])
	return result


func is_inside(point: Vector2, margin: float = 0.0) -> bool:
	return (
		point.x > margin
		and point.y > margin
		and point.x < config.size.x - margin
		and point.y < config.size.y - margin
	)


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _draw() -> void:
	if _ground == null:
		draw_rect(_bounds, config.floor_color)
		_draw_grid()

	var t := config.wall_thickness
	var wall_dark := WorldArtGuide.WALL_DARK
	var wall_metal := WorldArtGuide.WALL_METAL
	draw_rect(Rect2(-t, -t, config.size.x + t * 2.0, t), wall_dark)
	draw_rect(Rect2(-t, config.size.y, config.size.x + t * 2.0, t), wall_dark)
	draw_rect(Rect2(-t, 0.0, t, config.size.y), wall_dark)
	draw_rect(Rect2(config.size.x, 0.0, t, config.size.y), wall_dark)
	draw_rect(Rect2(0, -t * 0.72, config.size.x, t * 0.44), wall_metal)
	draw_rect(Rect2(0, config.size.y + t * 0.28, config.size.x, t * 0.44), wall_metal)
	draw_rect(Rect2(-t * 0.72, 0, t * 0.44, config.size.y), wall_metal)
	draw_rect(Rect2(config.size.x + t * 0.28, 0, t * 0.44, config.size.y), wall_metal)
	for x in range(20, int(config.size.x), 80):
		draw_circle(Vector2(x, -t * 0.5), 2.2, Color("#c08838"))
		draw_circle(Vector2(x, config.size.y + t * 0.5), 2.2, Color("#c08838"))
	for y in range(20, int(config.size.y), 80):
		draw_circle(Vector2(-t * 0.5, y), 2.2, Color("#c08838"))
		draw_circle(Vector2(config.size.x + t * 0.5, y), 2.2, Color("#c08838"))

	# Obstacle geometry is rendered by texture-backed Sprite2D children. The
	# rectangles remain the single source of truth for physics and bot routing.


func _draw_grid() -> void:
	var step := 100.0
	var x := 0.0
	while x <= config.size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, config.size.y), config.grid_color, 1.0)
		x += step
	var y := 0.0
	while y <= config.size.y:
		draw_line(Vector2(0.0, y), Vector2(config.size.x, y), config.grid_color, 1.0)
		y += step
