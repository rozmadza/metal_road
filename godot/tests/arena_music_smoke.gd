extends SceneTree

var failures := 0
var music: Node

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("ARENA MUSIC FAIL: ", label)

func settle() -> void:
	music._process(2.0)
	check(music._players.filter(func(p): return p.playing).size() == 1, "one composition after fade")
	check(music._players.size() == 2, "fixed two-player pool")

func freeze_enemies(game: Survival) -> void:
	game.player.freeze = true
	for enemy in game._enemies:
		if is_instance_valid(enemy):
			enemy.freeze = true
			enemy.gun.set_physics_process(false)
			enemy.get_node("ArenaBot").set_physics_process(false)

func kill_enemies(game: Survival) -> void:
	for enemy in game._enemies.duplicate():
		if is_instance_valid(enemy) and enemy.alive:
			enemy.take_damage(100000, &"body", game.player)

func run() -> void:
	PlayerProfile.path_override = "user://music_smoke_profile.cfg"
	LoadoutProfile.path_override = "user://music_smoke_loadout.cfg"
	CareerSession.clear_selection()
	music = root.get_node("Music")
	check(music.state == music.State.MUSIC_MENU, "startup menu")
	var slot: int = music._active
	var player: AudioStreamPlayer = music._players[slot]
	player.seek(12.0)
	for path in ["MainMenu", "Garage", "MainMenu", "PreRace"]:
		var screen: Node = load("res://scenes/%s.tscn" % path).instantiate()
		root.add_child(screen)
		await process_frame
		check(music._active == slot and player.playing, "menu continuity " + path)
		check(player.get_playback_position() >= 12.0, "menu playback position retained")
		check(music._fade_duration == 0.0, "no repeated menu fade")
		screen.free()
	var game := load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	await process_frame
	freeze_enemies(game)
	check(music.state == music.State.MUSIC_SURVIVAL, "enter survival")
	check(is_equal_approx(music._fade_duration, 1.2), "menu to survival duration")
	settle()
	player = music._players[music._active]
	player.seek(12.0)
	for wave in [2, 3, 4, 5]:
		game.start_round(wave)
		freeze_enemies(game)
		check(music._players[music._active] == player and music._fade_duration == 0.0, "ordinary wave continuity " + str(wave))
	check(player.get_playback_position() >= 12.0, "wave playback position retained")
	check(music.state == music.State.MUSIC_SURVIVAL, "wave five before spawn")
	game._update_reinforcements(5.0)
	freeze_enemies(game)
	kill_enemies(game)
	check(music.state == music.State.MUSIC_SURVIVAL, "deferred spawn still survival")
	await process_frame
	freeze_enemies(game)
	check(is_instance_valid(game._boss) and music.state == music.State.MUSIC_ARBITER, "actual boss spawn")
	settle()
	game._spawn_biker_squad()
	freeze_enemies(game)
	game._boss.take_damage(100000, &"body", game.player)
	check(not game._round_over and music.state == music.State.MUSIC_ARBITER, "boss death with riders retains theme")
	kill_enemies(game)
	check(game._round_over and music.state == music.State.MUSIC_SURVIVAL, "full phase completion")
	check(is_equal_approx(music._fade_duration, 1.5), "boss to survival duration")
	settle()
	game.start_round(5)
	game._spawn_referee()
	check(music.state == music.State.MUSIC_ARBITER, "second boss encounter")
	var old_token: int = game.audio._music_session
	game._on_retry_requested()
	await process_frame
	freeze_enemies(game)
	check(music.state == music.State.MUSIC_SURVIVAL, "restart from boss")
	music.set_boss(old_token, true)
	check(music.state == music.State.MUSIC_SURVIVAL, "stale session rejected")
	settle()
	game.hud.pause_overlay.toggle()
	var previous_state: int = music.state
	var previous_player: AudioStreamPlayer = music._players[music._active]
	await process_frame
	check(paused and not previous_player.can_process(), "music follows existing pause policy")
	game.hud.pause_overlay.resume()
	check(music.state == previous_state and previous_player.playing, "resume retains composition")
	game.start_round(5)
	game._spawn_referee()
	game.player.take_damage(100000)
	check(game.results.visible and music.state == music.State.MUSIC_ARBITER, "defeat results retain theme")
	old_token = game.audio._music_session
	game.free()
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	music.set_boss(old_token, true)
	check(music.state == music.State.MUSIC_MENU, "exit and freed owner rejected")
	settle()
	var bus := AudioServer.get_bus_index("Music")
	var old_db := AudioServer.get_bus_volume_db(bus)
	AudioServer.set_bus_volume_db(bus, -23.0)
	for iteration in 12:
		game = load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
		root.add_child(game)
		game.audio.set_survival_music_state(true)
		game.free()
		music.show_menu()
	settle()
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus), -23.0), "user volume survives transitions")
	AudioServer.set_bus_volume_db(bus, old_db)
	check(music._players.all(func(p): return p.bus == "Music"), "players routed to Music")
	menu.free()
	var race: Game = load("res://scenes/Main.tscn").instantiate()
	race.spawn_bots = false
	root.add_child(race)
	check(music.state == music.State.MUSIC_RACE, "Race keeps its own music")
	check(music._players[music._active].stream == race.audio.config.music, "original Race resource")
	race.free()
	# Seek across each actual playback boundary. No finished handler/recreation.
	for stream in [music.MENU, music.SURVIVAL, music.ARBITER]:
		music._request(music.State.MUSIC_MENU, stream, 0.0)
		player = music._players[music._active]
		check(stream.loop and stream.loop_offset == 0.0 and player.pitch_scale == 1.0, "native loop and authored pitch")
		player.seek(stream.get_length() - 0.12)
		await create_timer(0.45).timeout
		var position := player.get_playback_position()
		check(player.playing and position < 1.0, "playback crosses loop boundary " + stream.resource_path)
	music.show_menu()
	settle()
	print("ARENA MUSIC: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
