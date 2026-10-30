extends RigidBody2D
## A non-combatant, indestructible physical cover. No Vehicle control/damage.
const COVER_LAYER := 4
const BODY_TINT := Color(0.32, 0.28, 0.24, 1)
const CONTACT_GRACE := 2.0
const FADE_TIME := 0.35
var lifetime := 25.0
var age := 0.0
var _fade := 0.0
var config: VehicleConfig
var hull: ConvexPolygonShape2D

static func snapshot(vehicle: Vehicle) -> Dictionary:
	var overlay: Material
	if vehicle.effects != null and vehicle.effects.damage_overlay != null:
		overlay = vehicle.effects.damage_overlay.material.duplicate() as Material
		if overlay is ShaderMaterial:
			overlay.set_shader_parameter("body_damage", 1.0)
			overlay.set_shader_parameter("engine_damage", 1.0 - vehicle.damage.ratio(&"engine"))
			overlay.set_shader_parameter("wheel_damage", 1.0 - vehicle.damage.ratio(&"wheels"))
			overlay.set_shader_parameter("damage_tint", vehicle.config.damage_color)
	return {"position":vehicle.global_position,"angle":vehicle.global_rotation,"config":vehicle.config,
		"shape":vehicle._collision_shape.shape.duplicate(),"overlay":overlay,"tint":vehicle.self_modulate}

func setup(data: Dictionary) -> void:
	position = data.position
	rotation = data.angle
	config = data.config
	hull = data.shape
	mass = maxf(1400.0, config.mass * 1.6)
	gravity_scale = 0.0
	linear_damp = 4.0
	angular_damp = 7.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	collision_layer = 1 | COVER_LAYER
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 12
	z_index = -1
	var material := PhysicsMaterial.new()
	material.friction = 0.65
	material.bounce = 0.0
	physics_material_override = material
	var collision := CollisionShape2D.new()
	collision.shape = hull
	add_child(collision)
	# Same chassis, shadow, damage shader and burnt tint as the dead Vehicle.
	# Textures/material shader are shared, never rendered into a new bitmap.
	var visual := Node2D.new()
	visual.name = "Chassis"
	add_child(visual)
	var size := Vector2(config.length, config.width) * Vehicle.VISUAL_SCALE
	if config.texture != null:
		var angle := deg_to_rad(config.texture_rotation_degrees)
		var texture_size := Vector2(size.y,size.x) if not is_zero_approx(angle) else size
		var shadow := Sprite2D.new()
		shadow.texture = config.texture
		shadow.rotation = angle
		shadow.scale = texture_size / config.texture.get_size()
		shadow.position = Vector2(3.5,4.5).rotated(angle)
		shadow.modulate = Color(0.015,0.012,0.01,0.42) * data.tint
		visual.add_child(shadow)
		var sprite := Sprite2D.new()
		sprite.texture = config.texture
		sprite.rotation = angle
		sprite.scale = texture_size / config.texture.get_size()
		sprite.modulate = data.tint
		visual.add_child(sprite)
		var overlay := Sprite2D.new()
		overlay.texture = config.texture
		overlay.scale = size / config.texture.get_size()
		overlay.material = data.overlay
		if overlay.material != null: visual.add_child(overlay)
		else: overlay.free()
	visual.modulate = BODY_TINT

func _ready() -> void:
	add_to_group("vehicle_wrecks")

func adopt_effects(source: Vehicle) -> void:
	if source.effects == null: return
	for particles in [source.effects.smoke,source.effects.flame,source.effects.explosion,source.effects.sparks]:
		particles.reparent(self,true)
		particles.process_mode = Node.PROCESS_MODE_INHERIT
	if config.effects_enabled:
		source.effects.smoke.emitting = true
		source.effects.flame.emitting = true

func navigation_rect() -> Rect2:
	var bounds := Rect2(to_global(hull.points[0]),Vector2.ZERO)
	for point in hull.points: bounds = bounds.expand(to_global(point))
	return bounds

func touching_vehicle() -> bool:
	return get_colliding_bodies().any(func(body): return body is Vehicle and body.alive)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Bound solver depenetration when the former Vehicle died during a ram.
	# Its identical hull is replaced only after its old body was disabled.
	state.linear_velocity = state.linear_velocity.limit_length(120.0)
	state.angular_velocity = clampf(state.angular_velocity,-2.0,2.0)

func _physics_process(delta: float) -> void:
	age += delta
	if age < lifetime: return
	if touching_vehicle() and age < lifetime + CONTACT_GRACE: return
	_fade += delta
	modulate.a = maxf(0.0,1.0-_fade/FADE_TIME)
	if _fade >= FADE_TIME: queue_free()
