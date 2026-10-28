extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var music: Node = root.get_node("Music")
	var bus := AudioServer.get_bus_index("Music")
	var effect := AudioEffectRecord.new()
	AudioServer.add_bus_effect(bus, effect)
	music._players[music._active].seek(0.0)
	effect.set_recording_active(true)
	await create_timer(music.MENU.get_length() + 1.5).timeout
	effect.set_recording_active(false)
	effect.get_recording().save_to_wav("/tmp/metal-road-music-full-loop.wav")
	print("FULL MENU LOOP: length=", music.MENU.get_length(), " final_position=", music._players[music._active].get_playback_position(), " playing=", music._players[music._active].playing)
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	quit()
