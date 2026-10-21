extends Node2D
class_name VehicleEffects
## Bounded GPU emitters: no per-hit scene spawning, Compatibility renderer.

const DamageOverlay = preload("res://scripts/vehicle_damage_overlay.gd")

var vehicle: Vehicle
var smoke: GPUParticles2D
var flame: GPUParticles2D
var sparks: GPUParticles2D
var explosion: GPUParticles2D
var dust: GPUParticles2D
var damage_overlay: Node2D
var impact_flash_time := 0.0
var repair_flash_time := 0.0
var impact_point := Vector2.ZERO

func _ready() -> void:
	vehicle = get_parent() as Vehicle
	damage_overlay = DamageOverlay.new()
	damage_overlay.setup(vehicle)
	add_child(damage_overlay)
	smoke = emitter(vehicle.config.smoke_particles, 1.55, Color(0.18, 0.17, 0.16, 0.78), 5.0, 13.0)
	flame = emitter(vehicle.config.fire_particles, 0.55, Color(1.0, 0.3, 0.025, 0.95), 3.0, 7.0)
	sparks = emitter(vehicle.config.spark_particles, 0.3, Color(1.0, 0.72, 0.25), 0.7, 1.3)
	explosion = emitter(24, 0.6, Color(1.0, 0.5, 0.08), 6, 12)
	dust = emitter(14, 0.65, Color(0.34, 0.25, 0.16, 0.32), 2.5, 6.5)
	dust.position = Vector2(-vehicle.config.length * 0.42, 0)
	var dust_material := dust.process_material as ParticleProcessMaterial
	dust_material.direction = Vector3(-1, 0, 0)
	dust_material.spread = 42.0
	dust_material.initial_velocity_min = 10.0
	dust_material.initial_velocity_max = 28.0
	explosion.one_shot = true
	explosion.explosiveness = 1.0
	var burst := explosion.process_material as ParticleProcessMaterial
	burst.spread = 180
	burst.initial_velocity_min = 25
	burst.initial_velocity_max = 100
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	var spark_material := sparks.process_material as ParticleProcessMaterial
	spark_material.initial_velocity_min = 35.0
	spark_material.initial_velocity_max = 100.0
	spark_material.spread = 180.0
	var visual_size := vehicle.get_visual_size()
	smoke.position = Vector2(visual_size.x * 0.2, 0.0)
	flame.position = Vector2(visual_size.x * 0.16, 0.0)
	z_index = 4
	if bool(vehicle.get_meta("biker", false)) or vehicle.config.vehicle_id == &"referee_biker":
		# A full car-sized smoke plume used to erase the tiny rider silhouette.
		# Keep the damage cue, but trail it from the exhaust and render it below
		# the motorcycle so aim and heading remain legible.
		smoke.position = Vector2(-visual_size.x * 0.30, 0.0)
		smoke.amount = mini(smoke.amount, 8)
		smoke.lifetime = 1.0
		smoke.modulate = Color(0.82, 0.78, 0.72, 0.62)
		smoke.z_index = -5

func emitter(count: int, lifetime: float, color: Color, min_scale: float, max_scale: float) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.amount = count
	particles.lifetime = lifetime
	var soft_edge := Gradient.new()
	soft_edge.set_color(0, Color.WHITE)
	soft_edge.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.width = 16
	texture.height = 16
	texture.gradient = soft_edge
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	particles.texture = texture
	particles.local_coords = false
	particles.visibility_rect = Rect2(-150, -150, 300, 300)
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(-0.5, -1.0, 0)
	material.spread = 35.0
	material.gravity = Vector3(0, -12, 0)
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 25.0
	material.scale_min = min_scale / 4.0
	material.scale_max = max_scale / 4.0
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	material.color_ramp = ramp
	particles.process_material = material
	add_child(particles)
	particles.position = Vector2(vehicle.config.length * 0.2, 0)
	return particles

func _process(delta: float) -> void:
	var enabled := vehicle.config.effects_enabled
	var stage := vehicle.damage.visual_stage()
	var had_flash := impact_flash_time > 0.0 or repair_flash_time > 0.0
	impact_flash_time = maxf(0.0, impact_flash_time - delta)
	repair_flash_time = maxf(0.0, repair_flash_time - delta)
	if not enabled:
		sparks.emitting = false
	smoke.emitting = enabled and (stage >= 2 or vehicle.damage.ratio(&"engine") < 0.5)
	flame.emitting = enabled and stage >= 3
	var speed_ratio := clampf(vehicle.get_speed() / maxf(vehicle.get_current_max_speed(), 1.0), 0.0, 1.0)
	dust.emitting = enabled and vehicle.alive and speed_ratio > 0.22
	dust.amount_ratio = lerpf(0.22, 1.0, smoothstep(0.22, 0.9, speed_ratio))
	dust.speed_scale = lerpf(0.72, 1.35, speed_ratio)
	if had_flash:
		queue_redraw()

func impact(intensity: float, local_point: Vector2 = Vector2.ZERO) -> void:
	if vehicle.config.effects_enabled:
		var size := vehicle.get_visual_size()
		var damage_size := size * Vector2(0.76, 0.54)
		impact_point = local_point
		if impact_point.is_zero_approx():
			impact_point = Vector2(damage_size.x * 0.16, randf_range(-damage_size.y * 0.32, damage_size.y * 0.32))
		else:
			impact_point.x = clampf(impact_point.x, -damage_size.x * 0.44, damage_size.x * 0.44)
			impact_point.y = clampf(impact_point.y, -damage_size.y * 0.44, damage_size.y * 0.44)
		impact_flash_time = lerpf(0.12, 0.28, intensity)
		sparks.position = impact_point
		var material := sparks.process_material as ParticleProcessMaterial
		material.initial_velocity_max = lerpf(40.0, 100.0, intensity)
		sparks.restart()
		sparks.emitting = true
		queue_redraw()


func repair_feedback(full_repair: bool = false) -> void:
	if not vehicle.config.effects_enabled:
		return
	repair_flash_time = 0.95 if full_repair else 0.55
	queue_redraw()

func reset() -> void:
	for particles in [smoke, flame, sparks, explosion, dust]:
		particles.emitting = false
		particles.restart()
		particles.emitting = false
	impact_flash_time = 0.0
	repair_flash_time = 0.0
	impact_point = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var size := vehicle.get_visual_size() * Vector2(0.76, 0.54)
	if impact_flash_time > 0.0:
		var impact_alpha := impact_flash_time / 0.28
		draw_circle(impact_point, 4.5 + (1.0 - impact_alpha) * 7.0, Color(1.0, 0.78, 0.26, impact_alpha * 0.55), false, 2.0, true)
		draw_line(impact_point + Vector2(-7, 0), impact_point + Vector2(7, 0), Color(1, 0.92, 0.65, impact_alpha), 1.4, true)
		draw_line(impact_point + Vector2(0, -7), impact_point + Vector2(0, 7), Color(1, 0.92, 0.65, impact_alpha), 1.4, true)
	if repair_flash_time > 0.0:
		var repair_alpha := clampf(repair_flash_time / 0.95, 0.0, 1.0)
		var repair_color := Color(0.24, 1.0, 0.66, repair_alpha * 0.8)
		draw_arc(Vector2.ZERO, maxf(size.x, size.y) * (0.48 + (1.0 - repair_alpha) * 0.12), 0.0, TAU, 28, repair_color, 2.2, true)
		draw_line(Vector2(-4, 0), Vector2(4, 0), repair_color, 2.0, true)
		draw_line(Vector2(0, -4), Vector2(0, 4), repair_color, 2.0, true)


func explode() -> void:
	if vehicle.config.effects_enabled:
		explosion.restart()
		explosion.emitting = true
