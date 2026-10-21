extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("CINEMATIC FAIL: ", label)

func run() -> void:
	var game := (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Game
	game.spawn_bots = false
	root.add_child(game)
	await process_frame
	check(game.hud.cinematic_fx != null and game.hud.cinematic_fx.player == game.vehicle, "race cinematic overlay follows player")
	game.hud.impact_flash(30.0)
	game.hud.explosion_flash()
	game.hud.pickup_flash()
	game.hud.emp_flash()
	game.hud.finish_cinematic(true)
	check(game.hud.cinematic_fx.damage_flash > 0.0 and game.hud.cinematic_fx.explosion_flash > 0.0, "screen impulses")
	game.camera.kick(Vector2.LEFT, 8.0)
	game.camera.focus_pulse(-0.04)
	check(game.camera._kick_offset.length() > 0.0 and game.camera._zoom_pulse < 0.0, "camera recoil and focus")
	game.audio.set_game_intensity(1.0, 0.8, true)
	game.audio.set_skid_intensity(1.0)
	game.audio.play_event_cue(&"pickup")
	check(game.audio._ui.stream is AudioStreamWAV, "generated event cue")
	check(game.audio._ambience.playing and game.audio._skid.playing, "road ambience layers")
	check(game.audio._skid.volume_db > -20.0, "skid intensity mix")
	var vfx := game.get_node("CombatVFX") as CombatVFX
	vfx.spawn_explosion(Vector2(100, 100), Color.ORANGE, 70.0)
	vfx.spawn_impact(Vector2(110, 100))
	vfx.spawn_pickup(Vector2(120, 100))
	check(vfx.events.size() == 3, "shared world effects")
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Weapons")) > 0, "weapon compressor")
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Environment")) > 0, "environment reverb")
	game.free()
	print("CINEMATIC FEEDBACK: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
