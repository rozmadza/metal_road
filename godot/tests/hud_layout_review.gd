extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for resolution in [Vector2i(800, 600), Vector2i(1024, 768), Vector2i(1366, 768)]:
		for mode in ["Main", "ArenaBattle"]:
			var view := SubViewport.new()
			view.size = resolution
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(view)
			var game: Node = load("res://scenes/%s.tscn" % mode).instantiate()
			view.add_child(game)
			if mode == "Main": game._debug_enabled = true
			await create_timer(0.25).timeout
			await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png("res://docs/sprints/bcd/%s-%d.png" % [mode, resolution.x])
			view.free()
	quit()
