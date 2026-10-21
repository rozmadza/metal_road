extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var garage: Control = load("res://scenes/Garage.tscn").instantiate()
	root.add_child(garage)
	await process_frame
	var vehicle_index := LoadoutProfile.vehicle_ids().find(&"dustfox")
	garage.get_node("%VehicleSelect").select(vehicle_index)
	garage._on_vehicle_selected(vehicle_index)
	var upgrade_select := garage.get_node("%UpgradeSelect") as OptionButton
	upgrade_select.select(upgrade_select.item_count - 1)
	garage._on_upgrade_category_selected(upgrade_select.selected)
