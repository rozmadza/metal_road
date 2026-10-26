extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var config := load("res://resources/default_arena.tres") as ArenaConfig
	var first := Arena.new()
	first.config = config
	root.add_child(first)
	await process_frame
	var second := Arena.new()
	second.config = config
	root.add_child(second)
	await process_frame

	check(first.get_run_variation_id() == second.get_run_variation_id(), "structured arena keeps a stable composition identity")
	check(first.get_obstacles().size() == second.get_obstacles().size(), "variation preserves gameplay obstacle count")
	var first_props := _prop_positions(first)
	var second_props := _prop_positions(second)
	check(not first_props.is_empty() and first_props == second_props, "structured arena preserves authored clusters between runs")

	first.free()
	second.free()
	print("ARENA RUN VARIATION: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func _prop_positions(arena: Arena) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for child in arena.get_children():
		if child is MapProp:
			result.append(child.position)
	return result


func check(ok: bool, label: String) -> void:
	if ok:
		print("ARENA RUN VARIATION ok: ", label)
	else:
		failures += 1
		printerr("ARENA RUN VARIATION FAIL: ", label)
