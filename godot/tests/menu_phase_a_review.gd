extends SceneTree
## Windowed review captures at the default and widescreen sizes.
func _initialize() -> void:
	call_deferred("run")

func capture(label: String, viewport: Viewport = root) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://docs/phases/phase-a/" + label + ".png")

func run() -> void:
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await scene_changed
	await capture("menu-800")
	current_scene.get_node("%SettingsButton").pressed.emit()
	await capture("settings-800")
	current_scene.get_node("%BackButton").pressed.emit()
	current_scene.get_node("%GarageButton").pressed.emit()
	await scene_changed
	await capture("garage-800")
	current_scene.get_node("%BackButton").pressed.emit()
	await scene_changed
	# The desktop can clamp window sizes; render widescreen at an exact size.
	var wide := SubViewport.new()
	wide.size = Vector2i(1280, 720)
	wide.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(wide)
	wide.add_child(load("res://scenes/MainMenu.tscn").instantiate())
	await capture("menu-1280", wide)
	quit()
