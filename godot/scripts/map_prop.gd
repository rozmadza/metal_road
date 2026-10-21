extends Node2D
class_name MapProp

const TIRE_TEXTURE := preload("res://assets/environment/arena/tire_scrap_heap_topdown.png")
const WRECK_TEXTURE := preload("res://assets/environment/arena/crushed_cars_topdown.png")
const CRATE_TEXTURE := preload("res://assets/environment/arena/reinforced_crate.png")
const CONCRETE_TEXTURE := preload("res://assets/environment/arena/concrete_barrier_topdown.png")
const FENCE_TEXTURE := preload("res://assets/environment/arena/metal_fence_topdown.png")

@export var kind: StringName = &"crate"
@export var size := Vector2(34.0, 34.0)
@export var max_health := 25.0
var health := 25.0
var destroyed := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_to_group("arena_obstacles")
	set_meta("avoid_radius", maxf(size.x, size.y) * 0.54)
	health = max_health
	if kind == &"crate":
		add_to_group("destructibles")
	var body := StaticBody2D.new()
	body.name = "Collision"
	var impact_factors := {
		&"crate": 0.4,
		&"tire_wall": 0.3,
		&"wreck": 0.9,
		&"concrete": 1.2,
		&"fence": 0.65,
	}
	body.set_meta("impact_factor", float(impact_factors.get(kind, 1.0)))
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	if kind == &"tire_wall":
		var circle := CircleShape2D.new()
		circle.radius = minf(size.x, size.y) * 0.44
		shape.shape = circle
	elif kind == &"wreck":
		var capsule := CapsuleShape2D.new()
		capsule.radius = size.y * 0.42
		capsule.height = size.x * 0.88
		shape.rotation = PI * 0.5
		shape.shape = capsule
	else:
		var box := RectangleShape2D.new()
		box.size = size * Vector2(0.9, 0.82)
		shape.shape = box
	body.add_child(shape)
	add_child(body)
	queue_redraw()

func take_damage(amount: float, _module: StringName = &"body", _source: Node = null) -> void:
	if destroyed or kind != &"crate": return
	health -= amount
	if health <= 0.0:
		destroyed = true
		var collision := get_node_or_null("Collision") as StaticBody2D
		if collision != null: collision.collision_layer = 0
		queue_redraw()
		await get_tree().create_timer(0.35).timeout
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	if destroyed:
		_draw_texture_prop(CRATE_TEXTURE, Color(0.2, 0.14, 0.09, 0.72))
		return
	if kind == &"tire_wall":
		_draw_texture_prop(TIRE_TEXTURE)
	elif kind == &"wreck":
		_draw_texture_prop(WRECK_TEXTURE)
	elif kind == &"concrete":
		_draw_texture_prop(CONCRETE_TEXTURE)
	elif kind == &"fence":
		_draw_texture_prop(FENCE_TEXTURE)
	else:
		_draw_texture_prop(CRATE_TEXTURE)


func _draw_texture_prop(texture: Texture2D, modulate := Color.WHITE) -> void:
	# Never force a wide fence or a square tire pile into the collision box's
	# aspect ratio. Uniform fitting prevents the stretched, asymmetric look.
	var texture_size := Vector2(texture.get_size())
	# Fit inside the authored footprint. The visible object and its collision
	# now share the same maximum extent on every biome.
	var uniform_scale := minf(size.x / texture_size.x, size.y / texture_size.y) * 0.98
	var draw_size := texture_size * uniform_scale
	var rect := Rect2(-draw_size * 0.5, draw_size)
	draw_texture_rect(texture, Rect2(rect.position + WorldArtGuide.SHADOW_OFFSET, rect.size), false, WorldArtGuide.SHADOW_COLOR)
	draw_texture_rect(texture, rect, false, modulate)
