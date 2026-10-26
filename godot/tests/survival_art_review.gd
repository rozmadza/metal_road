extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func freeze_nodes(node: Node) -> void:
	node.set_physics_process(false)
	if node is RigidBody2D: node.freeze = true
	for child in node.get_children(): freeze_nodes(child)

func run() -> void:
	AccessibilitySettings.tutorial_enabled = false
	for resolution in [Vector2i(1280, 720), Vector2i(800, 600)]:
		var view := SubViewport.new()
		view.size = resolution
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var game := load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
		view.add_child(game)
		freeze_nodes(game)
		game.set_process(false)
		game.camera.target = null
		game.camera.use_track_limits = false
		game.camera.limit_left = -100000
		game.camera.limit_top = -100000
		game.camera.limit_right = 100000
		game.camera.limit_bottom = 100000
		game.camera.position = Vector2(500, 400)
		game.camera.position_smoothing_enabled = false
		game.camera.zoom = Vector2.ONE * (0.72 if resolution.x == 1280 else 0.55)
		game.player.position = Vector2(500, 565)
		game.player.activate_temporary_weapon(load("res://resources/weapons/rocket_launcher.tres"), 15.0)
		game.hud.update_status(game.player, 5, 3, 2, {"score": 12500, "scenario": "ЭЛИТНЫЙ ОТРЯД", "combo": 3})
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("res://docs/sprints/bcd/survival-art-%d.png" % resolution.x)
		if resolution.x == 1280:
			game.camera.zoom = Vector2.ONE * 1.23
			game.player.health = game.player.config.max_health * 0.2
			game.hud.update_status(game.player, 5, 3, 2, {"score": 12500, "scenario": "ЭЛИТНЫЙ ОТРЯД", "combo": 3, "crew_active": 4, "crew_crushed": 2, "crew_weapon_killed": 1})
			await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png("res://docs/sprints/bcd/survival-art-combat.png")
		for rect in game.hud.occupied_rects():
			if not Rect2(Vector2.ZERO, Vector2(resolution)).encloses(rect):
				printerr("HUD outside viewport: ", rect)
		view.free()
	print("SURVIVAL ART REVIEW: rendered 1280 and 800")
	quit()
