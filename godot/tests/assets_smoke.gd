extends SceneTree
## Verifies that assets, audio and animations are wired up independently of code.

var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false

	var failures := 0
	var vcfg: VehicleConfig = load("res://resources/default_vehicle.tres")
	var tcfg: TrackConfig = load("res://resources/iron_circuit.tres")
	var acfg: AudioConfig = load("res://resources/default_audio.tres")

	failures += _check(vcfg.texture != null, "vehicle texture assigned")
	failures += _check(tcfg.surface_texture != null, "track surface texture assigned")
	failures += _check(tcfg.background_texture != null, "track background texture assigned")
	failures += _check(acfg.music != null, "music stream assigned")
	failures += _check(acfg.engine != null, "engine stream assigned")
	failures += _check(acfg.fire != null, "fire stream assigned")
	failures += _check(acfg.collision != null, "collision stream assigned")
	failures += _check(acfg.finish != null, "finish stream assigned")

	var vehicle: Node = (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate()
	var player := vehicle.get_node_or_null("AnimationPlayer") as AnimationPlayer
	failures += _check(player != null, "AnimationPlayer present")
	if player != null:
		failures += _check(player.has_animation("hit_flash"), "hit_flash animation")
		failures += _check(player.has_animation("destroyed"), "destroyed animation")
	vehicle.free()

	var hud: Node = (load("res://scenes/HUD.tscn") as PackedScene).instantiate()
	failures += _check(hud.get_node_or_null("Info") != null, "HUD is an editable scene")
	hud.free()

	print("ASSETS: %d failures" % failures)
	print("ASSETS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
	return true


func _check(condition: bool, label: String) -> int:
	if not condition:
		print("ASSETS FAIL: ", label)
		return 1
	return 0
