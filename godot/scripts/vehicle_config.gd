extends Resource
class_name VehicleConfig
## All tunable parameters for a vehicle.
##
## This resource is the Godot replacement for the Python `config.py` vehicle
## block. Edit the values in the Inspector (or create additional `.tres`
## resources) without touching any code.

enum VehicleClass { RAIDER, INTERCEPTOR, ASSAULT, JUGGERNAUT }

@export_group("Identity")
@export var vehicle_id: StringName = &"vehicle"
@export var display_name: String = "VEHICLE"
@export_multiline var description: String = ""
@export var vehicle_class: VehicleClass = VehicleClass.RAIDER
@export var passive_id: StringName = &""
@export var passive_name: String = ""
@export_multiline var passive_description: String = ""
## Optional career gate. Objective gate is used for a bonus reward vehicle.
@export var career_unlock_event: StringName = &""
@export var career_unlock_objective: bool = false

@export_group("Class passive tuning")
## Raider: multiplier applied to temporary weapon, speed and ram pickups.
@export_range(1.0, 2.0, 0.05) var passive_bonus_duration_multiplier: float = 1.0
## Assault: multiplier applied to every projectile fired by this vehicle.
@export_range(1.0, 2.0, 0.05) var passive_weapon_damage_multiplier: float = 1.0
## Permanent garage weapon module; affects every temporary weapon pickup.
@export_range(1.0, 3.0, 0.01) var weapon_damage_multiplier: float = 1.0
@export_range(1.0, 3.0, 0.01) var weapon_fire_rate_multiplier: float = 1.0
## Interceptor: short personal boost earned at a clean race checkpoint.
@export_range(0.0, 10.0, 0.1) var passive_apex_duration: float = 0.0
@export_range(1.0, 2.0, 0.05) var passive_apex_speed_multiplier: float = 1.0
@export_range(1.0, 3.0, 0.05) var passive_apex_acceleration_multiplier: float = 1.0
@export_range(0.0, 20.0, 0.1) var passive_apex_cooldown: float = 0.0


func class_label() -> String:
	match vehicle_class:
		VehicleClass.INTERCEPTOR: return "ПЕРЕХВАТЧИК"
		VehicleClass.ASSAULT: return "ШТУРМОВИК"
		VehicleClass.JUGGERNAUT: return "ДЖАГГЕРНАУТ"
	return "РЕЙДЕР"

@export_group("Dimensions")
@export_range(4.0, 400.0, 0.5) var length: float = 40.0
@export_range(4.0, 400.0, 0.5) var width: float = 24.0
## Bevel applied to the four corners of the collision octagon (0 = sharp box).
@export_range(0.0, 50.0, 0.5) var corner_bevel_ratio: float = 0.15

@export_group("Body")
@export_range(1.0, 100000.0, 1.0) var mass: float = 1000.0
## 0 lets Godot compute the moment of inertia from the collision shape.
@export_range(0.0, 100000000.0, 1.0) var moment: float = 180000.0

@export_group("Movement")
@export_range(1.0, 200.0, 1.0) var max_speed: float = 160.0
@export_range(1.0, 20000.0, 1.0) var acceleration: float = 800.0
@export_range(1.0, 20000.0, 1.0) var brake_force: float = 1200.0
## Fraction of forward speed kept per physics step (rolling resistance).
@export_range(0.5, 1.0, 0.001) var drag: float = 0.98
## Lateral (sideways) grip coefficient. Higher = less sliding.
@export_range(0.0, 200.0, 0.1) var traction: float = 15.0
## Time for the drivetrain to deliver the requested throttle.
@export_range(0.05, 0.8, 0.01) var throttle_response: float = 0.24
## Grip remaining at high speed in a hard corner.
@export_range(0.25, 1.0, 0.01) var high_speed_grip: float = 0.55

@export_group("Handbrake")
## Above this forward speed a strong brake press starts releasing rear grip.
@export_range(10.0, 200.0, 1.0) var handbrake_min_speed: float = 58.0
## Remaining lateral grip at full handbrake. Front-end steering is preserved
## separately in Vehicle so the slide can be caught with counter-steer.
@export_range(0.1, 1.0, 0.01) var handbrake_traction_multiplier: float = 0.25
## A locked rear axle still slows the car, but less efficiently than all-wheel
## service braking.
@export_range(0.1, 1.0, 0.01) var handbrake_brake_multiplier: float = 0.22
## Extra yaw response used to initiate the rear-axle slide.
@export_range(0.0, 1.5, 0.01) var handbrake_steer_boost: float = 0.42
## Higher retention lets the body keep rotating until the player catches it.
@export_range(0.5, 1.0, 0.001) var handbrake_angular_damping: float = 0.985

@export_group("Steering")
@export_range(0.0, 50.0, 0.1) var steer_rate: float = 5.0
## Speed (px/s) at which steering is most effective.
@export_range(0.01, 1000.0, 0.01) var steer_speed_factor: float = 0.3
## Fraction of angular velocity kept per physics step.
@export_range(0.5, 1.0, 0.001) var angular_damping: float = 0.95

@export_group("Combat")
## Hit points used in survival / battle-royale modes. Unused in race mode.
@export_range(1.0, 1000.0, 1.0) var max_health: float = 100.0
## Fraction of incoming damage absorbed by armour (0.2 = 20%).
@export_range(0.0, 0.75, 0.01) var damage_resistance: float = 0.0

@export_group("Ramming")
## Legacy linear-impact tuning retained for resource compatibility.
@export_range(0.0, 5.0, 0.01) var collision_damage: float = 0.18
@export_range(0.0, 1000.0, 5.0) var collision_min_speed: float = 70.0
## Closing speed below which contact is only cosmetic.
@export_range(0.0, 200.0, 1.0) var impact_safe_speed: float = 25.0
## Closing speed that reaches maximum base collision damage.
@export_range(25.0, 500.0, 5.0) var impact_damage_full_speed: float = 125.0
@export_range(0.0, 20.0, 0.5) var impact_min_damage: float = 5.0
@export_range(1.0, 100.0, 1.0) var impact_max_damage: float = 68.0
@export_range(1.0, 100.0, 1.0) var impact_damage_cap: float = 78.0
## Multiplies damage delivered by this vehicle to another vehicle.
@export_range(0.25, 3.0, 0.05) var ram_power: float = 1.0
@export_range(0.25, 2.0, 0.05) var front_impact_factor: float = 0.7
@export_range(0.25, 2.0, 0.05) var side_impact_factor: float = 1.35
@export_range(0.25, 2.0, 0.05) var rear_impact_factor: float = 1.15

@export_group("Looks")
@export var body_color: Color = Color(0.0, 0.784, 0.392)
@export var outline_color: Color = Color(0.0, 0.35, 0.18)
@export var front_marker_color: Color = Color(1.0, 1.0, 0.0)
@export var velocity_vector_color: Color = Color(1.0, 0.392, 0.392)


## Builds the local-space collision/render vertices of the bevelled rectangle.
func get_body_vertices() -> PackedVector2Array:
	var half_l := length * 0.5
	var half_w := width * 0.5
	var bevel: float = minf(length, width) * corner_bevel_ratio
	return PackedVector2Array([
		Vector2(half_l - bevel, half_w),
		Vector2(half_l, half_w - bevel),
		Vector2(half_l, -half_w + bevel),
		Vector2(half_l - bevel, -half_w),
		Vector2(-half_l + bevel, -half_w),
		Vector2(-half_l, -half_w + bevel),
		Vector2(-half_l, half_w - bevel),
		Vector2(-half_l + bevel, half_w),
	])


@export_group("Assets")
## Optional sprite. When set it is drawn instead of the procedural shape, so
## the car image can be replaced without touching any game logic.
@export var texture: Texture2D
## Some authored top-down sprites point upward, while vehicle physics use +X
## as forward. Rotate only the artwork without changing steering or collision.
@export_range(-180.0, 180.0, 1.0) var texture_rotation_degrees: float = 0.0

@export_group("Damage modules")
@export_range(1.0, 1000.0) var engine_health: float = 70.0
@export_range(1.0, 1000.0) var wheels_health: float = 60.0
@export_range(0.0, 1.0) var engine_damage_share: float = 0.55
@export_range(0.0, 1.0) var wheels_damage_share: float = 0.45
## Tuning profiles adjust these values. They are deliberately separate from
## armour: armour reduces the whole hit, while these multipliers describe how
## well an individual assembly survives damage that has reached the vehicle.
@export_range(0.5, 1.5, 0.01) var body_damage_multiplier: float = 1.0
@export_range(0.5, 1.5, 0.01) var engine_damage_multiplier: float = 1.0
@export_range(0.5, 1.5, 0.01) var wheels_damage_multiplier: float = 1.0
## At zero engine health the vehicle retains 85% of its healthy performance.
## Engine damage must create pressure, not turn the player into a stationary
## target; the complete healthy-to-critical speed loss is capped at 15%.
@export_range(0.85, 1.0, 0.01) var engine_min_factor: float = 0.85
@export_range(0.05, 1.0) var steering_min_factor: float = 0.45
@export_range(0.05, 1.0) var traction_min_factor: float = 0.25
## Wheels recover automatically after damage. Upgrades increase this value.
@export_range(0.0, 30.0, 0.1) var wheels_repair_rate: float = 1.5
@export_range(0.0, 15.0, 0.1) var wheels_repair_delay: float = 4.0


## Class identity continues below the headline stats. Raiders keep moving on
## damaged running gear, assault cars protect the power plant, interceptors
## trade resilience for pace, and juggernauts are genuinely hard to cripple.
func module_damage_multiplier(module: StringName) -> float:
	var class_factor := 1.0
	match vehicle_class:
		VehicleClass.RAIDER:
			class_factor = 0.90 if module == &"engine" else (0.82 if module == &"wheels" else 1.0)
		VehicleClass.INTERCEPTOR:
			class_factor = 1.10 if module == &"engine" else 1.0
		VehicleClass.ASSAULT:
			class_factor = 0.82 if module == &"engine" else (1.05 if module == &"wheels" else 1.0)
		VehicleClass.JUGGERNAUT:
			class_factor = 0.72 if module == &"engine" else (0.78 if module == &"wheels" else 1.0)
	match module:
		&"body": return clampf(body_damage_multiplier * class_factor, 0.5, 1.5)
		&"engine": return clampf(engine_damage_multiplier * class_factor, 0.5, 1.5)
		&"wheels": return clampf(wheels_damage_multiplier * class_factor, 0.5, 1.5)
	return 1.0


func class_combat_role() -> String:
	match vehicle_class:
		VehicleClass.INTERCEPTOR: return "СКОРОСТЬ · ТОЧНАЯ ТРАЕКТОРИЯ · ХРУПКИЙ ДВИГАТЕЛЬ"
		VehicleClass.ASSAULT: return "ОГНЕВАЯ МОЩЬ · ЗАЩИЩЁННЫЙ ДВИГАТЕЛЬ"
		VehicleClass.JUGGERNAUT: return "ТАРАН · МАССА · СТОЙКОСТЬ МОДУЛЕЙ"
	return "УНИВЕРСАЛ · ПОЛЕВОЙ РЕМОНТ · ЖИВУЧАЯ ХОДОВАЯ"

@export_group("Temporary boost")
@export_range(1.0, 2.0, 0.05) var boost_speed_multiplier: float = 1.25
@export_range(1.0, 3.0, 0.05) var boost_acceleration_multiplier: float = 1.65
@export_range(1.0, 3.0, 0.05) var boost_ram_multiplier: float = 1.35

@export_group("Feedback")
@export var effects_enabled: bool = true
@export var debug_vectors: bool = false
@export_range(0.01, 2.0) var impact_cooldown: float = 0.2
@export_range(1.0, 500.0) var impact_min_speed: float = 50.0
@export_range(1.0, 1000.0) var impact_full_speed: float = 400.0
@export_range(4, 64) var smoke_particles: int = 18
@export_range(4, 64) var fire_particles: int = 12
@export_range(4, 64) var spark_particles: int = 16
@export var damage_color: Color = Color(0.14, 0.08, 0.04, 0.8)

@export_group("Engine sound")
## Each chassis keeps the common engine recording but has its own audible character.
@export_range(0.4, 1.5, 0.01) var engine_pitch_base: float = 0.8
@export_range(0.2, 1.4, 0.01) var engine_pitch_range: float = 0.7
@export_range(-8.0, 8.0, 0.1) var engine_volume_offset_db: float = 0.0
