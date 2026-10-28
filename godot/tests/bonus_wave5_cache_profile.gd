extends "res://tests/survival_catalog_comparison.gd"
## Equal synthetic survival fixture for the Arbiter + biker window.
## A private high-HP player config avoids shortening the benchmark on defeat.

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	run_id = argument("id", "bonus-wave5")
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
	game.start_round(5)
	for enemy in game._enemies.duplicate():
		if is_instance_valid(enemy) and enemy.alive:
			scripted_kills_total += 1
			enemy.take_damage(100000, &"body", game.player)
	await process_frame
	await sample("wave5_arbiter", 11)
	await sample("wave5_bikers", 12)
	await finish_run()
