extends "res://tests/survival_performance_audit.gd"
## Graphical before/after run. Scripted enemy kills and repairs are fixtures.
const Timing = preload("res://tests/survival_perf_stats.gd")

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

func memory_mark(label: String) -> void:
	rows.append({"event":"memory", "phase":label,
		"rss_kb":rss_kb(),
		"godot_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
		"godot_video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"godot_texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"catalog_cached":ResourceLoader.has_cached(LoadoutProfile.VEHICLE_CATALOG_PATH)})

func force_wave_two() -> void:
	# The round transition is genuine; kills and perk selection are scripted.
	game._pending_enemies.clear()
	for enemy in game._enemies.duplicate():
		if is_instance_valid(enemy) and enemy.alive:
			scripted_kills_total += 1
			enemy.take_damage(100000, &"body", game.player)
	await process_frame
	var start := Time.get_ticks_usec()
	game._offer_upgrade()
	var choices := SurvivalRunData.perk_choices(game._round, game._perk_ids)
	var selected: Dictionary = choices[0]
	for choice in choices:
		if choice.id != &"second_wind":
			selected = choice
			break
	game._on_perk_selected(selected)
	rows.append({"event":"actual_wave2_transition", "us":Time.get_ticks_usec()-start,
		"round":game._round, "perks":game._run_perks.size(), "scripted_kills":scripted_kills_total})
	await process_frame

func measured_restart(label: String) -> void:
	active = false
	Timing.phase = "restart_" + label
	var before := Time.get_ticks_usec()
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var arena_id := game.arena.get_instance_id()
	game._on_retry_requested()
	var request_return := Time.get_ticks_usec()
	while game._round_start_pending >= 0 or game.arena.get_instance_id() == arena_id:
		await process_frame
	var logic_ready := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var first_render := Time.get_ticks_usec()
	rows.append({"event":"restart","label":label,"request_us":request_return-before,
		"logic_ready_us":logic_ready-before,"first_render_us":first_render-before,
		"nodes_before":nodes_before,"nodes_after":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"round":game._round,"ai":game._alive_enemies(),"bullets":game.bullets.get_child_count(),
		"vfx":game.get_node("CombatVFX").events.size()})
	await sample(label, 6)

func finish_run() -> void:
	var meta := {"collector_version":2,"id":run_id,"options":options,
		"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),
		"vsync":DisplayServer.window_get_vsync_mode(),"instrumented":Timing.enabled,
		"window":root.size,"windows":windows,"setup_events":rows,
		"scripted_kills":scripted_kills_total,"scripted_full_repairs":scripted_repairs_total,
		"function_times_us":Timing.calls,"slow_events":Timing.events}
	for report in pending_reports:
		FileAccess.open(outputs + report.file, FileAccess.WRITE).store_string(JSON.stringify({"phase":report.phase,"metrics":report.metrics,"frames":report.frames}))
	FileAccess.open(outputs + run_id + "-manifest.json", FileAccess.WRITE).store_string(JSON.stringify(meta))
	await dispose()
	print("CATALOG COMPARISON COMPLETE ", run_id)
	quit()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	run_id = argument("id", "catalog-compare")
	Timing.enabled = argument("instrumented", "0") == "1"
	factor = 1.0
	DirAccess.make_dir_recursive_absolute(outputs)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	PlayerProfile.path_override = "res://perf-output/" + run_id + "-profile.cfg"
	LoadoutProfile.path_override = "res://perf-output/" + run_id + "-loadout.cfg"
	LoadoutProfile.save_ids(&"raider", &"machine_gun")
	PlayerProfile.save(PlayerProfile.read())
	CareerSession.clear_selection()
	SurvivalRunData.selected_arena_id = &"scrapyard"
	SurvivalRunData.daily_mode = false
	seed(int(argument("seed", "4217")))
	memory_mark("before_menu")
	var entry_start := Time.get_ticks_usec()
	await menu_entry()
	rows.append({"event":"first_entry_total", "us":Time.get_ticks_usec()-entry_start})
	memory_mark("after_first_entry")
	repair_fixture = true
	var first_generation := game._round_generation
	await sample("wave1_reinforcement", float(argument("wave1_seconds", "5.5")))
	rows.append({"event":"wave1_window_state", "generation_start":first_generation,
		"generation_end":game._round_generation, "active_game_s":game._elapsed,
		"alive_ai":game._alive_enemies(), "pending":game._pending_enemies.size()})
	if argument("complete_before_restart", "0") == "1":
		game._pending_enemies.clear()
		for enemy in game._enemies.duplicate():
			if is_instance_valid(enemy) and enemy.alive:
				scripted_kills_total += 1
				enemy.take_damage(100000, &"body", game.player)
		await process_frame
		rows.append({"event":"fixture_wave1_completed", "round_over":game._round_over,
			"player_won":game._player_won, "scripted_kills":scripted_kills_total})
	await measured_restart("after_immediate_restart")
	memory_mark("after_immediate_restart")
	if argument("quick", "0") == "1":
		await finish_run()
		return
	await force_wave_two()
	await sample("wave2_via_transition", 6)
	game.start_round(5)
	for enemy in game._enemies.duplicate():
		if is_instance_valid(enemy) and enemy.alive:
			scripted_kills_total += 1
			enemy.take_damage(100000, &"body", game.player)
	await process_frame
	await sample("wave5_arbiter", 11)
	await sample("wave5_bikers", 12)
	game.start_round(4)
	await sample("wave4_endurance", 60)
	await measured_restart("after_long_restart")
	memory_mark("after_long_restart")
	await dispose()
	var reentry_start := Time.get_ticks_usec()
	await menu_entry()
	rows.append({"event":"warm_reentry_total", "us":Time.get_ticks_usec()-reentry_start})
	memory_mark("after_reentry")
	await sample("repeat_entry_wave1", 6)
	await finish_run()
