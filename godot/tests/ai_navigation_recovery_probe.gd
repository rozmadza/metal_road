extends "res://tests/ai_navigation_diagnostic.gd"
## Exposes actual requests, rejected starts, motion and safety cancellations.
class RecoveryDriver extends ArenaBot:
	var goal := Vector2.ZERO
	var reverse_at_entry := 0.0
	var cancellations := 0
	func _update_intent(_delta: float) -> void:
		_set_intent(&"route_test", goal)
	func get_commands(delta: float = 0.0) -> Dictionary:
		reverse_at_entry = _reversing
		var previous_cancelled := recovery_cancelled
		var result := super.get_commands(delta)
		if reverse_at_entry <= 0 and recovery_cancelled > previous_cancelled: cancellations += 1
		set_meta("reverse_requests",recovery_requested)
		set_meta("immediate_cancellations",cancellations)
		return result

func make_car(arena: Arena, id: String, p: Vector2, goal: Vector2, angle: float = 0) -> Vehicle:
	var car := load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
	car.config = (load("res://resources/vehicles/elite/referee_arbiter.tres") if id=="arbiter" else LoadoutProfile.vehicle_config(StringName(id))).duplicate()
	car.config.max_health = 50000
	car.config.engine_health = 50000
	car.config.wheels_health = 50000
	car.config.effects_enabled = false
	car.position = p
	car.rotation = angle
	if id=="arbiter": car.set_meta("boss",true)
	root.add_child(car)
	car.add_to_group("combatants")
	var driver := RecoveryDriver.new()
	driver.name = "ArenaBot"
	driver.arena = arena
	driver.goal = goal
	driver.external_weapon_control = true
	car.add_child(driver)
	return car

func state(car: Vehicle, driver: ArenaBot, frame: int, goal: Vector2) -> Dictionary:
	var result := super.state(car,driver,frame,goal)
	result.reverse_requests = driver.get_meta("reverse_requests",0)
	result.immediate_cancellations = driver.get_meta("immediate_cancellations",0)
	result.recovery_started = driver.recovery_started
	result.recovery_completed = driver.recovery_completed
	result.recovery_rejected = driver.recovery_rejected
	result.recovery_cancelled = driver.recovery_cancelled
	result.traffic_detours = driver.traffic_detours
	result.traffic_reason = str(driver.traffic_reason)
	return result
