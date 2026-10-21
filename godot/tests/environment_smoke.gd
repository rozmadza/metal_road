extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("ENVIRONMENT FAIL: ", label)

func run() -> void:
	var arena: Arena = load("res://scenes/Arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	check(arena.get_tree().get_nodes_in_group("oil_spots").size() == 1, "single oil spot spawned")
	check(arena.get_tree().get_nodes_in_group("destructibles").size() == 2, "single barrel and crate spawned")
	check(arena.get_tree().get_nodes_in_group("destructibles").filter(func(node): return node is MapProp).size() == 1, "single crate uses reusable component")
	arena.free()
	print("ENVIRONMENT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
