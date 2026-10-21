extends Control
class_name GarageVehiclePreview

var texture: Texture2D
var weapon: WeaponConfig
var module_levels: Dictionary = {}
var _source_region := Rect2()
static var _card_texture_cache: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_vehicle(value: Texture2D) -> void:
	texture = value
	_source_region = visible_region(value)
	queue_redraw()

func set_weapon(value: WeaponConfig) -> void:
	weapon = value
	queue_redraw()

func set_modules(value: Dictionary) -> void:
	module_levels = value.duplicate()
	queue_redraw()

func _draw() -> void:
	if texture == null:
		return
	if _source_region.size.is_zero_approx():
		_source_region = visible_region(texture)
	var source_size := _source_region.size
	var fit := minf((size.x - 24.0) / source_size.x, (size.y - 18.0) / source_size.y)
	var vehicle_size := source_size * fit
	var vehicle_rect := Rect2((size - vehicle_size) * 0.5, vehicle_size)
	draw_texture_rect_region(texture, vehicle_rect, _source_region)
	_draw_module_badges()

	if weapon == null or weapon.texture == null:
		return
	var weapon_source := Vector2(weapon.texture.get_size())
	var weapon_width := vehicle_size.x * weapon.preview_scale
	var weapon_size := Vector2(weapon_width, weapon_width * weapon_source.y / weapon_source.x)
	var mount := get_weapon_mount()
	var weapon_rect := Rect2(mount - weapon_size * 0.5, weapon_size)
	# A small contact shadow seats the module into the roof instead of making it
	# look like an unrelated icon floating over the vehicle.
	draw_ellipse_shadow(mount, weapon_size)
	draw_texture_rect(weapon.texture, weapon_rect, false)

func _draw_module_badges() -> void:
	var categories := [&"engine", &"armor", &"wheels", &"weapon"]
	var colors := [Color("f2a53b"), Color("72c7d8"), Color("a8d46f"), Color("ef6b61")]
	var block_width := 44.0
	var start_x := (size.x - block_width * categories.size()) * 0.5
	var y := size.y - 15.0
	for category_index in categories.size():
		var level := int(module_levels.get(categories[category_index], 0))
		var x := start_x + category_index * block_width
		for pip in 3:
			var pip_color: Color = colors[category_index] if pip < level else Color(0.22, 0.25, 0.26, 0.72)
			draw_rect(Rect2(x + pip * 12.0, y, 8.0, 4.0), pip_color, true)

func get_weapon_mount() -> Vector2:
	return size * 0.5

func draw_ellipse_shadow(center: Vector2, weapon_size: Vector2) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * weapon_size.x * 0.43, sin(angle) * weapon_size.y * 0.38))
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.38))


static func visible_region(value: Texture2D) -> Rect2:
	if value == null:
		return Rect2()
	var image := value.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, value.get_size())
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i.ZERO
	var found := false
	# Ignore extremely faint glow pixels and sample in small blocks. This is
	# calculated only when a preview/card is built, never during gameplay.
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			if image.get_pixel(x, y).a < 0.12:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
			found = true
	if not found:
		return Rect2(Vector2.ZERO, value.get_size())
	var margin := 8
	minimum -= Vector2i(margin, margin)
	maximum += Vector2i(margin, margin)
	minimum.x = maxi(0, minimum.x)
	minimum.y = maxi(0, minimum.y)
	maximum.x = mini(image.get_width(), maximum.x)
	maximum.y = mini(image.get_height(), maximum.y)
	return Rect2(minimum, maximum - minimum)


static func cropped_texture(value: Texture2D) -> Texture2D:
	if value == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = value
	atlas.region = visible_region(value)
	return atlas


static func card_texture(value: Texture2D) -> Texture2D:
	## Produces a resolution-independent card icon. Using an AtlasTexture here
	## made 768 px vehicle art render much smaller than legacy 1774 px art in a
	## Button, despite both having the same icon width limit.
	if value == null:
		return null
	var cache_key := value.resource_path
	if not cache_key.is_empty() and _card_texture_cache.has(cache_key):
		return _card_texture_cache[cache_key] as Texture2D
	var source := value.get_image()
	if source == null or source.is_empty():
		return cropped_texture(value)
	var region := visible_region(value)
	var source_rect := Rect2i(
		Vector2i(region.position.round()),
		Vector2i(region.size.round())
	)
	source_rect.position.x = clampi(source_rect.position.x, 0, source.get_width() - 1)
	source_rect.position.y = clampi(source_rect.position.y, 0, source.get_height() - 1)
	source_rect.size.x = clampi(source_rect.size.x, 1, source.get_width() - source_rect.position.x)
	source_rect.size.y = clampi(source_rect.size.y, 1, source.get_height() - source_rect.position.y)
	var cropped := source.get_region(source_rect)
	# Equal on-card length keeps every vehicle readable while preserving the
	# actual body proportions (wide trucks remain wider than narrow racers).
	const CANVAS_SIZE := Vector2i(82, 50)
	const VEHICLE_LENGTH := 76
	const MAX_HEIGHT := 46
	var target_width := VEHICLE_LENGTH
	var target_height := maxi(1, roundi(float(cropped.get_height()) * target_width / cropped.get_width()))
	if target_height > MAX_HEIGHT:
		var ratio := float(MAX_HEIGHT) / target_height
		target_width = maxi(1, roundi(target_width * ratio))
		target_height = MAX_HEIGHT
	cropped.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8)
	var destination := (CANVAS_SIZE - Vector2i(target_width, target_height)) / 2
	canvas.blend_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()), destination)
	var result := ImageTexture.create_from_image(canvas)
	if not cache_key.is_empty():
		_card_texture_cache[cache_key] = result
	return result
