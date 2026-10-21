extends Area2D
class_name EscapingCrew
## Vulnerable survivors released from a destroyed non-boss car. They do not
## fight: each chooses a different route to the arena perimeter and runs.

signal crushed(crew: EscapingCrew, vehicle: Vehicle)
signal escaped(crew: EscapingCrew)

enum Role { PILOT, MECHANIC }

const PILOT_TEXTURE := preload("res://assets/characters/crew/pilot_run_sheet.png")
const MECHANIC_TEXTURE := preload("res://assets/characters/crew/mechanic_run_sheet.png")

@export var role: Role = Role.PILOT
@export_range(30.0, 120.0, 1.0) var run_speed := 55.0
@export_range(0.0, 2.0, 0.05) var crush_grace := 0.5

var arena: Arena
var escape_direction := Vector2.RIGHT
var _active := true
var _age := 0.0
var _run_frame_clock := 0.0
var _sprite: Sprite2D


func setup(value_role: Role, value_arena: Arena, direction: Vector2) -> void:
	role = value_role
	arena = value_arena
	escape_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	run_speed = 58.0 if role == Role.PILOT else 52.0


func _ready() -> void:
	add_to_group("escaping_crew")
	body_entered.connect(_on_body_entered)
	_sprite = Sprite2D.new()
	_sprite.name = "Runner"
	_sprite.texture = PILOT_TEXTURE if role == Role.PILOT else MECHANIC_TEXTURE
	_sprite.hframes = 2
	_sprite.vframes = 2
	# One 768 px sprite-sheet cell becomes a roughly 22 px human. With the
	# 70–80 px car silhouettes this matches an adult next to a 4–5 metre car.
	_sprite.scale = Vector2.ONE * (0.037 if role == Role.PILOT else 0.036)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)
	rotation = escape_direction.angle() + PI * 0.5
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	var desired := (escape_direction + _obstacle_avoidance() * 1.45).normalized()
	if desired.is_zero_approx():
		desired = escape_direction
	escape_direction = escape_direction.slerp(desired, clampf(delta * 4.5, 0.0, 1.0)).normalized()
	rotation = lerp_angle(rotation, escape_direction.angle() + PI * 0.5, clampf(delta * 9.0, 0.0, 1.0))
	global_position += escape_direction * run_speed * delta
	if _sprite != null:
		# The four authored frames carry alternating arms and legs. Cadence tracks
		# actual running speed so slowing a survivor also slows the animation.
		_run_frame_clock += delta * lerpf(7.0, 9.0, inverse_lerp(45.0, 65.0, run_speed))
		_sprite.frame = int(_run_frame_clock) % 4
		_sprite.position.y = sin(_age * 12.0) * 0.35
	if arena != null and not arena.get_bounds().grow(34.0).has_point(global_position):
		_active = false
		escaped.emit(self)
		queue_free()


func crush(vehicle: Vehicle) -> bool:
	if not _active or vehicle == null or not vehicle.alive or _age < crush_grace:
		return false
	if vehicle.get_speed() < 24.0:
		return false
	_active = false
	set_deferred("monitoring", false)
	crushed.emit(self, vehicle)
	queue_free()
	return true


func role_label() -> String:
	return "ПИЛОТ" if role == Role.PILOT else "ПОМОЩНИК"


func _on_body_entered(body: Node) -> void:
	# Contact callbacks run during the physics query flush. Defer the state
	# change and scoring callback so the Area2D can be removed safely.
	crush.call_deferred(body as Vehicle)


func _obstacle_avoidance() -> Vector2:
	if arena == null:
		return Vector2.ZERO
	var push := Vector2.ZERO
	for rect in arena.get_obstacles():
		var expanded := rect.grow(26.0)
		var probe := global_position + escape_direction * 34.0
		if not expanded.has_point(probe):
			continue
		var closest := Vector2(
			clampf(global_position.x, expanded.position.x, expanded.end.x),
			clampf(global_position.y, expanded.position.y, expanded.end.y)
		)
		var away := global_position - closest
		if away.is_zero_approx():
			away = escape_direction.rotated(PI * 0.5 if get_instance_id() % 2 == 0 else -PI * 0.5)
		push += away.normalized()
	return push


func _draw() -> void:
	# A small neutral contact shadow keeps the runner readable without turning
	# it into a glowing pickup or UI marker.
	draw_ellipse_shadow(Vector2(1.5, 4.0), Vector2(8.0, 4.0), Color(0.01, 0.008, 0.006, 0.38))


func draw_ellipse_shadow(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 18:
		var angle := TAU * float(index) / 18.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
