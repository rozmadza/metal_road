extends Camera2D
class_name FollowCamera
## Smoothed follow camera with optional track bounds.
##
## Smoothing uses time-based interpolation (`1 - exp(-speed * dt)`), matching
## the recommendation in the TDD so the camera never becomes sluggish.

@export var target: Node2D
@export_range(0.1, 50.0, 0.1) var follow_speed: float = 6.0
@export var use_track_limits: bool = true
@export var margin: float = 40.0
@export var resting_zoom := 1.23
@export var maximum_speed_zoom := 1.0
@export var look_ahead_distance := 72.0
@export var velocity_look_ahead := 42.0
@export var acceleration_lag_distance := 16.0
var _shake_time := 0.0
var _shake_strength := 0.0
var _trauma := 0.0
var _shake_phase := 0.0
var _kick_offset := Vector2.ZERO
var _zoom_pulse := 0.0
var _look_offset := Vector2.ZERO
var _last_speed_ratio := 0.0
var _acceleration_bias := 0.0


func _ready() -> void:
	make_current()
	zoom = Vector2.ONE * resting_zoom
	if target != null:
		global_position = target.global_position


func _process(delta: float) -> void:
	if target == null:
		return
	var weight := 1.0 - exp(-follow_speed * delta)
	var desired_position := target.global_position
	var speed_ratio := 0.0
	var vehicle := target as Vehicle
	if vehicle != null and vehicle.config != null:
		speed_ratio = clampf(vehicle.get_speed() / maxf(vehicle.get_current_max_speed(), 1.0), 0.0, 1.0)
		var forward := Vector2.RIGHT.rotated(vehicle.global_rotation)
		var velocity_direction := vehicle.linear_velocity.normalized() if vehicle.get_speed() > 2.0 else forward
		var desired_look := (
			forward * look_ahead_distance * speed_ratio
			+ velocity_direction * velocity_look_ahead * speed_ratio
		)
		_look_offset = _look_offset.lerp(desired_look, 1.0 - exp(-5.2 * delta))
		var acceleration := clampf((speed_ratio - _last_speed_ratio) / maxf(delta, 0.001), -2.0, 2.0)
		_acceleration_bias = lerpf(_acceleration_bias, acceleration, 1.0 - exp(-4.5 * delta))
		# During acceleration the camera hangs slightly behind the chassis, moving
		# the car toward open road. Braking briefly gives the opposite weight.
		desired_position += _look_offset - forward * _acceleration_bias * acceleration_lag_distance
		_last_speed_ratio = speed_ratio
	var desired_zoom := lerpf(resting_zoom, maximum_speed_zoom, speed_ratio) + _zoom_pulse
	zoom = zoom.lerp(Vector2.ONE * desired_zoom, 1.0 - exp(-3.5 * delta))
	global_position = global_position.lerp(desired_position, weight)
	_kick_offset = _kick_offset.lerp(Vector2.ZERO, 1.0 - exp(-11.0 * delta))
	_zoom_pulse = lerpf(_zoom_pulse, 0.0, 1.0 - exp(-6.5 * delta))
	_shake_phase += delta * 24.0
	if _shake_time > 0.0 or _trauma > 0.01:
		_shake_time = maxf(0.0, _shake_time - delta)
		_trauma = maxf(0.0, _trauma - delta * 8.0)
		var fade := maxf(_trauma * _trauma, clampf(_shake_time / 0.1, 0.0, 1.0))
		var noise := Vector2(sin(_shake_phase * 1.31), sin(_shake_phase * 1.83 + 1.7))
		offset = noise * _shake_strength * fade + _kick_offset
	else:
		offset = _kick_offset

func shake(strength: float = 8.0, duration: float = 0.24) -> void:
	# No continuous road vibration. Even explosions are capped to a short,
	# low-amplitude impulse to avoid motion sickness and headaches.
	strength = minf(strength * 0.15, 1.6) * AccessibilitySettings.screen_shake
	if strength <= 0.01: return
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, minf(duration, 0.1))
	_trauma = maxf(_trauma, clampf(strength / 4.0, 0.08, 0.4))

func kick(world_direction: Vector2, strength: float = 7.0) -> void:
	var safe_strength := minf(strength * 0.28, 3.0) * AccessibilitySettings.screen_shake
	_kick_offset += world_direction.normalized() * safe_strength
	_zoom_pulse = minf(_zoom_pulse + safe_strength * 0.002, 0.012)

func focus_pulse(amount: float = -0.055) -> void:
	_zoom_pulse = clampf(_zoom_pulse + amount, -0.09, 0.07)


## Restricts the camera to a world-space rectangle (usually the track bounds).
func set_bounds(rect: Rect2) -> void:
	if not use_track_limits or rect.size == Vector2.ZERO:
		return
	limit_left = int(rect.position.x - margin)
	limit_top = int(rect.position.y - margin)
	limit_right = int(rect.end.x + margin)
	limit_bottom = int(rect.end.y + margin)


## Snaps the camera immediately to the target (used on restart).
func snap_to_target() -> void:
	if target != null:
		global_position = target.global_position
	zoom = Vector2.ONE * resting_zoom
	offset = Vector2.ZERO
	_shake_time = 0.0
	_shake_strength = 0.0
	_trauma = 0.0
	_kick_offset = Vector2.ZERO
	_zoom_pulse = 0.0
	_look_offset = Vector2.ZERO
	_last_speed_ratio = 0.0
	_acceleration_bias = 0.0
