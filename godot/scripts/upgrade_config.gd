extends Resource
class_name UpgradeConfig

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: StringName
@export var level: int = 1
@export var cost: int = 0
@export var required_upgrade: StringName = &""
## Empty means every class. Values use VehicleConfig.VehicleClass.
@export var allowed_classes: PackedInt32Array = PackedInt32Array()
## Empty means every vehicle. Used by the final Season 1 specializations.
@export var allowed_vehicles: PackedStringArray = PackedStringArray()
## Only one installed upgrade from the same group is allowed per vehicle.
@export var exclusive_group: StringName = &""
@export var modifiers: Dictionary = {}


func supports_class(vehicle_class: int) -> bool:
	return allowed_classes.is_empty() or vehicle_class in allowed_classes


func supports_vehicle(vehicle_id: StringName) -> bool:
	return allowed_vehicles.is_empty() or String(vehicle_id) in allowed_vehicles
