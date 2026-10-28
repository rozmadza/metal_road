extends SceneTree

const EVIDENCE := "res://docs/reports/music-states-evidence/"
var music: Node

func _initialize() -> void:
	run.call_deferred()

func snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(EVIDENCE + label + ".png")

func run() -> void:
	PlayerProfile.path_override = "user://music_visual_profile.cfg"
	LoadoutProfile.path_override = "user://music_visual_loadout.cfg"
	CareerSession.clear_selection()
	music = root.get_node("Music")
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await create_timer(1.0).timeout
	await snapshot("01-main-menu")
	menu.free()
	var garage: Node = load("res://scenes/Garage.tscn").instantiate()
	root.add_child(garage)
	await create_timer(0.5).timeout
	await snapshot("02-garage")
	garage.free()
	var game := load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	game.player.freeze = true
	game.set_process(false)
	await create_timer(1.5).timeout
	await snapshot("03-survival")
	game.start_round(5)
	await snapshot("04-wave5-before-boss")
	game._spawn_referee()
	await create_timer(1.2).timeout
	await snapshot("05-arbiter")
	game.hud.pause_overlay.toggle()
	await snapshot("06-pause")
	game.hud.pause_overlay.resume()
	game._on_retry_requested()
	await create_timer(1.5).timeout
	await snapshot("07-restart")
	game.free()
	music.show_menu()
	music._process(2.0)
	var bus := AudioServer.get_bus_index("Music")
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(bus, record)
	for index in 3:
		var stream: AudioStreamOggVorbis = [music.MENU, music.SURVIVAL, music.ARBITER][index]
		music._request(index, stream, 0.0)
		var player: AudioStreamPlayer = music._players[music._active]
		player.seek(stream.get_length() - 1.0)
		record.set_recording_active(true)
		await create_timer(2.5).timeout
		record.set_recording_active(false)
		var capture := record.get_recording()
		capture.save_to_wav(EVIDENCE + stream.resource_path.get_file().get_basename() + "-boundary.wav")
		print("LOOP CAPTURE ", stream.resource_path, " length=", stream.get_length(), " position=", player.get_playback_position(), " playing=", player.playing)
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	print("MUSIC GRAPHICAL: COMPLETE")
	quit()
