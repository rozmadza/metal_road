extends "res://tests/survival_catalog_comparison.gd"
## Graphical real-Survival supply profile; forced-spawn section is a labelled fixture.
const Probe = preload("res://tests/bonus_pickup_probe_stats.gd")

func probe_sample(label: String, seconds: float) -> void:
	Probe.phase = label
	await sample(label, seconds)
	memory_mark(label + "_end")

func forced_types() -> void:
	Probe.phase = "forced_types_fixture"
	for kind in [BonusPickup.Kind.WEAPON, BonusPickup.Kind.WEAPON, BonusPickup.Kind.REPAIR, BonusPickup.Kind.SPEED_BOOST, BonusPickup.Kind.RAM_BOOST]:
		game.bonus_spawner.reset()
		await process_frame
		game.bonus_spawner._rng.seed = 87654321
		var started := Time.get_ticks_usec()
		var pickup := game.bonus_spawner.spawn_random_bonus(kind)
		rows.append({"event": "forced_spawn", "kind": kind, "success": pickup != null, "us": Time.get_ticks_usec() - started})
		await process_frame
	game.bonus_spawner.reset()
	await process_frame

func write_probe() -> void:
	var file := FileAccess.open(outputs + run_id + "-stages.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"id": run_id, "instrumented": Probe.enabled, "events": Probe.events}))
	file.close()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	run_id = argument("id", "bonus-profile")
	var mode := argument("mode", "direct")
	Probe.enabled = argument("instrumented", "0") == "1"
	Timing.enabled = false
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
	memory_mark("before_entry")
	if mode == "menu":
		await menu_entry()
	else:
		await build(1)
	game.bonus_spawner._rng.seed = int(argument("seed", "4217"))
	repair_fixture = true
	memory_mark("after_entry")
	await probe_sample("first_two_batches", 13.0)
	if mode == "restart":
		Probe.phase = "restart_setup"
		var before := Time.get_ticks_usec()
		var old_arena := game.arena.get_instance_id()
		game._on_retry_requested()
		while game._round_start_pending >= 0 or game.arena.get_instance_id() == old_arena:
			await process_frame
		rows.append({"event": "restart", "us": Time.get_ticks_usec() - before})
		game.bonus_spawner._rng.seed = int(argument("seed", "4217"))
		memory_mark("after_restart")
		await probe_sample("after_restart_batches", 13.0)
	elif mode == "memory_loop":
		for index in 10:
			var old_arena := game.arena.get_instance_id()
			game._on_retry_requested()
			while game._round_start_pending >= 0 or game.arena.get_instance_id() == old_arena:
				await process_frame
			game.bonus_spawner._rng.seed = int(argument("seed", "4217"))
			await probe_sample("restart_%02d_supply" % index, 2.4)
		await dispose()
		for index in 5:
			await menu_entry()
			game.bonus_spawner._rng.seed = int(argument("seed", "4217"))
			await probe_sample("menu_reentry_%02d_supply" % index, 2.4)
	elif mode == "menu":
		Probe.phase = "menu_reentry_setup"
		await menu_entry()
		game.bonus_spawner._rng.seed = int(argument("seed", "4217"))
		memory_mark("after_menu_reentry")
		await probe_sample("after_menu_reentry_batches", 13.0)
	if argument("forced", "0") == "1":
		await forced_types()
	memory_mark("after_all")
	write_probe()
	await finish_run()
