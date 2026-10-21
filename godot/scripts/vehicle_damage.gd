extends RefCounted
class_name VehicleDamage
## Per-instance runtime state. Shared VehicleConfig is never mutated.

var body: float
var engine: float
var wheels: float
var config: VehicleConfig

func reset(vehicle_config: VehicleConfig) -> void:
	config = vehicle_config
	body = config.max_health
	engine = config.engine_health
	wheels = config.wheels_health

func ratio(module: StringName) -> float:
	match module:
		&"body": return clampf(body / config.max_health, 0.0, 1.0)
		&"engine": return clampf(engine / config.engine_health, 0.0, 1.0)
		&"wheels": return clampf(wheels / config.wheels_health, 0.0, 1.0)
	return 0.0

func apply(amount: float, module: StringName = &"body") -> void:
	if amount <= 0 or not is_finite(amount):
		return
	match module:
		&"body":
			body = maxf(0, body - amount * config.module_damage_multiplier(&"body"))
			# Once armour panels are breached, following hits reach internal
			# assemblies more easily. The increase is noticeable but never turns
			# a single ordinary hit into an unavoidable module failure.
			var breach := lerpf(1.28, 1.0, ratio(&"body"))
			engine = maxf(0, engine - amount * config.engine_damage_share * breach * config.module_damage_multiplier(&"engine"))
			wheels = maxf(0, wheels - amount * config.wheels_damage_share * breach * config.module_damage_multiplier(&"wheels"))
		&"engine": engine = maxf(0, engine - amount * config.module_damage_multiplier(&"engine"))
		&"wheels": wheels = maxf(0, wheels - amount * config.module_damage_multiplier(&"wheels"))

func repair_wheels(amount: float) -> void:
	if amount > 0.0 and is_finite(amount):
		wheels = minf(config.wheels_health, wheels + amount)

func engine_factor() -> float:
	# Linear 0..15% performance loss. Clamp legacy/custom resources as well so
	# no old save or boss configuration can reintroduce the former 70% penalty.
	return lerpf(maxf(config.engine_min_factor, 0.85), 1.0, ratio(&"engine"))

func steering_factor() -> float:
	return lerpf(config.steering_min_factor, 1.0, ratio(&"wheels"))

func traction_factor() -> float:
	return lerpf(config.traction_min_factor, 1.0, ratio(&"wheels"))

func visual_stage() -> int:
	var remaining := ratio(&"body")
	if remaining <= 0: return 4
	if remaining <= 0.25: return 3
	if remaining <= 0.5: return 2
	if remaining <= 0.75: return 1
	return 0


func critical_module() -> StringName:
	if ratio(&"engine") <= 0.25: return &"engine"
	if ratio(&"wheels") <= 0.25: return &"wheels"
	if ratio(&"body") <= 0.25: return &"body"
	return &""
