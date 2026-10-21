extends Resource
class_name VehicleCatalog
## Data-driven registry for every selectable vehicle.

@export var vehicles: Array[VehicleConfig] = []


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for config in vehicles:
		if config != null and config.vehicle_id != &"":
			result.append(config.vehicle_id)
	return result


func get_vehicle(vehicle_id: StringName) -> VehicleConfig:
	for config in vehicles:
		if config != null and config.vehicle_id == vehicle_id:
			return config
	return vehicles[0] if not vehicles.is_empty() else null


func has_vehicle(vehicle_id: StringName) -> bool:
	return ids().has(vehicle_id)


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var known := {}
	for config in vehicles:
		if config == null:
			errors.append("Catalog contains an empty vehicle entry")
			continue
		if config.vehicle_id == &"":
			errors.append("Vehicle has no id: %s" % config.resource_path)
		elif known.has(config.vehicle_id):
			errors.append("Duplicate vehicle id: %s" % config.vehicle_id)
		known[config.vehicle_id] = true
		if config.display_name.strip_edges().is_empty():
			errors.append("Vehicle %s has no display name" % config.vehicle_id)
	return errors
