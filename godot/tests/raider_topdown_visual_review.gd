extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var garage: Control = load("res://scenes/Garage.tscn").instantiate()
	root.add_child(garage)
	await process_frame
	garage.get_node("%VehicleSelect").select(0)
	garage._on_vehicle_selected(0)
