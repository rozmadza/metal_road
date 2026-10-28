extends "res://tests/survival_catalog_comparison.gd"
## Equal 60-second active-combat fixture, followed by Restart and menu re-entry.

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	run_id = argument("id", "bonus-wave4-endurance")
	Timing.enabled = true
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
	await menu_entry()
	game.player.config = game.player.config.duplicate(true)
	game.player.config.max_health = 10000.0
	game.player.damage.reset(game.player.config)
	repair_fixture = true
	game.start_round(4)
	await sample("wave4_endurance", 60)
	await measured_restart("after_long_restart")
	memory_mark("after_long_restart")
	await dispose()
	await menu_entry()
	memory_mark("after_reentry")
	await sample("repeat_entry_wave1", 6)
	await finish_run()
