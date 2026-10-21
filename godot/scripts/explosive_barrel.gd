extends Node2D
class_name ExplosiveBarrel

const BARREL_TEXTURE := preload("res://assets/environment/arena/explosive_barrel.png")

signal exploded(position: Vector2, radius: float)
@export var max_health := 30.0
@export var explosion_radius := 105.0
@export var explosion_damage := 55.0
@export var ram_explosion_speed := 55.0
var health := 30.0
var hit_count := 0
var destroyed := false
var exploding := false
var _flash := 0.0
var _explosion_elapsed := 0.0
var _burn_elapsed := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	health = max_health
	hit_count = 0
	add_to_group("destructibles")
	queue_redraw()

func take_damage(amount: float, _module: StringName = &"body", _source: Node = null) -> void:
	if destroyed or exploding or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	hit_count += 1
	_flash = 0.12
	if health <= 0.0:
		explode()
	else:
		queue_redraw()


func receive_ram(closing_speed: float, source: Vehicle) -> void:
	if destroyed or exploding or closing_speed <= 10.0:
		return
	if closing_speed >= ram_explosion_speed:
		explode()
		return
	var severity := clampf((closing_speed - 10.0) / maxf(1.0, ram_explosion_speed - 10.0), 0.0, 1.0)
	take_damage(lerpf(2.0, max_health * 0.55, severity), &"body", source)

func explode() -> void:
	if destroyed or exploding:
		return
	exploding = true
	destroyed = true
	var collision := get_node_or_null("Collision") as StaticBody2D
	if collision != null:
		collision.set_deferred("collision_layer", 0)
		collision.set_deferred("collision_mask", 0)
	_explosion_elapsed = 0.0
	_burn_elapsed = 0.0
	var origin := global_position
	for node in get_tree().get_nodes_in_group("combatants"):
		var vehicle := node as Vehicle
		if vehicle == null or not vehicle.alive:
			continue
		var distance := origin.distance_to(vehicle.global_position)
		if distance <= explosion_radius:
			var falloff := 1.0 - smoothstep(0.0, explosion_radius, distance)
			vehicle.take_damage(explosion_damage * falloff, &"body", self)
	for barrel in get_tree().get_nodes_in_group("destructibles"):
		if barrel == self or not is_instance_valid(barrel):
			continue
		if barrel.global_position.distance_to(origin) <= explosion_radius * 0.9:
			barrel.take_damage(explosion_damage * 0.8, &"body", self)
	exploded.emit(origin, explosion_radius)
	queue_redraw()
	await get_tree().create_timer(0.9).timeout
	queue_free()

func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if exploding:
		_explosion_elapsed += delta
		_burn_elapsed += delta
		queue_redraw()
	elif _flash > 0.0:
		queue_redraw()

func _draw() -> void:
	if exploding:
		var progress := clampf(_explosion_elapsed / 0.28, 0.0, 1.0)
		draw_circle(Vector2.ZERO, explosion_radius * progress, Color(1.0, 0.2, 0.03, 0.18 * (1.0 - progress)))
		draw_circle(Vector2.ZERO, 24.0 + 18.0 * sin(progress * PI), Color(1.0, 0.72, 0.14, 0.9 * (1.0 - progress * 0.4)))
		draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.95, 0.55, 1.0))
		if _burn_elapsed > 0.28:
			draw_circle(Vector2(-5, -6), 10.0 + sin(_burn_elapsed * 12.0) * 3.0, Color(1.0, 0.3, 0.04, 0.75))
			draw_circle(Vector2(4, -10), 6.0 + sin(_burn_elapsed * 9.0) * 2.0, Color(1.0, 0.78, 0.15, 0.8))
			draw_circle(Vector2.ZERO, 13.0, Color(0.12, 0.1, 0.08, 0.95))
		return
	var barrel_tint := Color.WHITE if _flash <= 0.0 else Color(1.0, 0.82, 0.42, 1.0)
	draw_texture_rect(BARREL_TEXTURE, Rect2(Vector2(-16, -16) + WorldArtGuide.SHADOW_OFFSET, Vector2(32, 32)), false, WorldArtGuide.SHADOW_COLOR)
	draw_texture_rect(BARREL_TEXTURE, Rect2(-16, -16, 32, 32), false, barrel_tint)
