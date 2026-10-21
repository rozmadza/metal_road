extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FEEDBACK FAIL: ", label)

func run() -> void:
	var v: Vehicle = load("res://scenes/Vehicle.tscn").instantiate()
	v.config = v.config.duplicate()
	root.add_child(v)
	var stages: Array[int] = []
	v.damage_stage_changed.connect(func(_vehicle: Vehicle, stage: int): stages.append(stage))
	check(v.get_visual_size().is_equal_approx(Vector2(v.config.length, v.config.width) * Vehicle.VISUAL_SCALE), "damage uses rendered vehicle scale")
	check(v.effects.damage_overlay != null and v.effects.damage_overlay.material is ShaderMaterial, "damage is texture-clipped by shader")
	v.take_damage(50)
	v.effects._process(0)
	check(v.effects.smoke.emitting and not v.effects.flame.emitting, "50 percent smoke")
	check(v.get_hud_state().damage_stage == 2 and stages == [2], "HUD and signal expose visual damage stage")
	v.take_damage(25)
	v.effects._process(0)
	check(v.effects.flame.emitting, "critical fire")
	v.repair_full()
	check(v.damage.visual_stage() == 0 and v.effects.repair_flash_time > 0.0, "full repair clears scars and triggers feedback")
	v.config.effects_enabled = false
	v.effects.reset()
	v.effects._process(0)
	v.effects.impact(1)
	check(not v.effects.smoke.emitting and not v.effects.flame.emitting and not v.effects.sparks.emitting, "config disables particles")
	v.reset_to(Vector2.ZERO, 0)
	var wall := StaticBody2D.new()
	root.add_child(wall)
	v._last_velocity = Vector2(300, 0)
	v._on_body_entered(wall)
	check(v.health == v.config.max_health, "race wall feedback does not introduce damage")
	var hud: DebugHUD = load("res://scenes/HUD.tscn").instantiate()
	root.add_child(hud)
	v.take_damage(35, &"engine")
	hud.update_info(v, {}, false)
	check(hud.modules.bars[1].value < 100 and hud.modules.bars[0].value == 100, "HUD shows independent class-adjusted modules")
	hud.free()
	wall.free()
	v.free()
	print("FEEDBACK: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
