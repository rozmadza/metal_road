extends SceneTree

const PROFILE_PATH := "user://career_story_visual_profile_test.cfg"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	PlayerProfile.path_override = PROFILE_PATH
	var profile := PlayerProfile.read()
	profile.career.driver_id = &"mara"
	PlayerProfile.save(profile)
	CareerSession.select_event(&"iron_open")
	var race_preview := "race" in OS.get_cmdline_user_args()
	if race_preview:
		change_scene_to_file("res://scenes/Main.tscn")
	else:
		CareerStory.prepare_intro(&"iron_open", "res://scenes/Main.tscn")
		change_scene_to_file(CareerStory.SCENE)
	await scene_changed
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/tmp/metal-road-career-hud.png" if race_preview else "/tmp/metal-road-career-story.png")
	CareerStory.clear()
	CareerSession.clear_selection()
	PlayerProfile.path_override = ""
	var path := ProjectSettings.globalize_path(PROFILE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	quit()
