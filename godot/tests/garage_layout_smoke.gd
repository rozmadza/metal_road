extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("GARAGE LAYOUT FAIL: ", label)

func run() -> void:
	var garage: Control = load("res://scenes/Garage.tscn").instantiate()
	root.add_child(garage)
	await process_frame
	await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, root.get_viewport().get_visible_rect().size)
	for node_name in [&"Credits", &"Ownership", &"PurchaseButton", &"InstalledModules", &"UpgradeSelect", &"UpgradeDetails", &"UpgradeButton", &"RaceButton", &"SurvivalButton"]:
		var node: Control = garage.get_node("%" + String(node_name))
		check(viewport_rect.encloses(node.get_global_rect()), "%s stays inside viewport" % node_name)
	garage.free()
	print("GARAGE LAYOUT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
