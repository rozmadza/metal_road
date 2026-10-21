extends SceneTree
## Manual visual review: opens the real garage on the class-build panel.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var garage: Control = load("res://scenes/Garage.tscn").instantiate()
	root.add_child(garage)
	await process_frame
	var selector := garage.get_node("%UpgradeSelect") as OptionButton
	for index in selector.item_count:
		if StringName(selector.get_item_metadata(index)) == &"build":
			selector.select(index)
			garage._on_upgrade_category_selected(index)
			break
