extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game := load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	await process_frame
	var audio := game.audio
	check(audio._survival_music_enabled, "survival enables the original metal score")
	check(audio._music.playing and audio._combat_music.playing and audio._boss_music.playing, "all adaptive stems stay sample-aligned")
	var base_length := audio._music.stream.get_length()
	check(base_length > 40.0, "theme is a full-length loop")
	check(absf(audio._combat_music.stream.get_length() - base_length) < 0.02, "combat stem matches the base timeline")
	check(absf(audio._boss_music.stream.get_length() - base_length) < 0.02, "boss stem matches the base timeline")
	audio.set_game_intensity(1.0, 1.0, true)
	audio.set_survival_music_state(true, 3)
	audio._process(1.0)
	check(audio._combat_music.volume_db > -20.0, "combat pressure brings in the aggressive layer")
	check(audio._boss_music.volume_db > -30.0, "Arbiter phase brings in the boss breakdown")
	audio.set_survival_music_state(false, 0)
	audio._process(2.0)
	check(audio._boss_music_intensity < 0.2, "boss layer fades after the encounter")
	game.free()
	print("ARENA MUSIC: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("ARENA MUSIC FAIL: ", label)
