extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func rss_kb() -> int:
	var file := FileAccess.open("/proc/self/status", FileAccess.READ)
	var status := ""
	if file != null:
		status = file.get_as_text()
	if status.is_empty():
		var output: Array = []
		if OS.execute("cat", ["/proc/%d/status" % OS.get_process_id()], output) == 0 and not output.is_empty():
			status = str(output[0])
	for line in status.split("\n"):
		if line.begins_with("VmRSS:"):
			return int(line.replace("VmRSS:", "").strip_edges().split(" ", false)[0])
	return -1

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("CATALOG RESTART FAIL: ", label)

func run() -> void:
	PlayerProfile.path_override = "res://catalog_restart_profile.cfg"
	LoadoutProfile.path_override = "res://catalog_restart_loadout.cfg"
	var catalog_id := LoadoutProfile.vehicle_catalog().get_instance_id()
	var game := load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	await process_frame
	var baseline_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var baseline_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var samples: Array[Dictionary] = []
	for index in 101:
		if index > 0:
			game._on_retry_requested()
			await process_frame
			await physics_frame
			await process_frame
		check(LoadoutProfile.vehicle_catalog().get_instance_id() == catalog_id, "catalog survives restart %d" % index)
		check(game._round == 1 and game._alive_enemies() == 2 and game._pending_enemies.size() == 1, "wave state %d" % index)
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		check(nodes <= baseline_nodes + 2, "node bound %d" % index)
		if index % 10 == 0:
			samples.append({"restart":index,"rss_kb":rss_kb(),"godot_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"godot_video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"nodes":nodes})
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == baseline_orphans, "orphan count")
	print("CATALOG RESTART SAMPLES: ", JSON.stringify(samples))
	game.queue_free()
	await process_frame
	print("CATALOG RESTART MEMORY: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
