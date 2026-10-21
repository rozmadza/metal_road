extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("BONUS PICKUP FAIL: ", label)

func run() -> void:
	var vehicle := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	root.add_child(vehicle)
	await process_frame
	check(not vehicle.gun.enabled, "new vehicle starts without weapon")
	vehicle.reset_to(Vector2.ZERO, 0.0)
	check(not vehicle.gun.enabled, "match reset disables weapon")
	var weapon_pickup := (load("res://scenes/BonusPickup.tscn") as PackedScene).instantiate() as BonusPickup
	root.add_child(weapon_pickup)
	var pickup_shape := weapon_pickup.get_node("CollisionShape2D") as CollisionShape2D
	check(pickup_shape.shape is CircleShape2D and pickup_shape.shape.radius >= 50.0, "pickup has generous collection radius")
	weapon_pickup.setup(BonusPickup.Kind.WEAPON, load("res://resources/weapons/shotgun.tres"))
	check(weapon_pickup.get_node_or_null("TypeBadge") != null, "weapon pickup has a readable type badge")
	check(weapon_pickup.get_node("TypeBadge").text == "ДРОБОВИК", "weapon badge names the actual weapon")
	check(weapon_pickup.collect(vehicle), "weapon pickup collected")
	check(vehicle.has_temporary_weapon(), "temporary weapon enabled")
	check(is_equal_approx(vehicle.weapon_time_remaining, 25.0), "weapon lasts 25 seconds")
	check(vehicle.gun.config.display_name == "ДРОБОВИК", "pickup chooses weapon config")
	vehicle._physics_process(25.1)
	check(not vehicle.has_temporary_weapon(), "weapon expires")

	var boost_pickup := (load("res://scenes/BonusPickup.tscn") as PackedScene).instantiate() as BonusPickup
	root.add_child(boost_pickup)
	boost_pickup.setup(BonusPickup.Kind.SPEED_BOOST)
	var base_speed := vehicle.config.max_speed
	check(boost_pickup.collect(vehicle), "boost pickup collected")
	check(vehicle.get_current_max_speed() > base_speed, "boost raises temporary maximum speed")
	check(vehicle.get_current_max_speed() <= 200.0, "boost respects absolute 200 km/h cap")
	check("С" in vehicle.get_hud_state().weapon_state, "HUD exposes bonus countdown")
	vehicle._physics_process(8.1)
	check(not vehicle.is_boost_active(), "boost expires")

	vehicle.damage.body = vehicle.config.max_health - 40.0
	var repair_pickup := (load("res://scenes/BonusPickup.tscn") as PackedScene).instantiate() as BonusPickup
	root.add_child(repair_pickup)
	repair_pickup.setup(BonusPickup.Kind.REPAIR)
	check(repair_pickup.collect(vehicle), "repair pickup collected")
	check(vehicle.health > vehicle.config.max_health - 40.0, "repair restores body health")

	var ram_pickup := (load("res://scenes/BonusPickup.tscn") as PackedScene).instantiate() as BonusPickup
	root.add_child(ram_pickup)
	ram_pickup.setup(BonusPickup.Kind.RAM_BOOST)
	check(ram_pickup.collect(vehicle), "ram pickup collected")
	check(vehicle.is_ram_boost_active(), "ram boost becomes active")

	var spawner := BonusSpawner.new()
	root.add_child(spawner)
	spawner.setup_for_track((load("res://scenes/Track.tscn") as PackedScene).instantiate())
	var track := spawner.track
	root.add_child(track)
	await process_frame
	var spawned := spawner.spawn_random_bonus(BonusPickup.Kind.WEAPON)
	check(spawned != null and track.is_point_on_track(spawned.global_position), "race bonus spawns on track")
	check(is_equal_approx(spawner.spawn_interval, 8.0), "bonus cooldown is eight seconds")
	check(spawner.max_active == 1, "only one contested bonus can be active")

	var director := BonusSpawner.new()
	director.setup_for_track(track)
	root.add_child(director)
	director._physics_process(director.first_spawn_delay - director.warning_duration + 0.1)
	var preview := director.get_child(0) as BonusPickup
	check(preview != null and not preview.armed, "bonus is announced before activation")
	check(not preview.collect(vehicle), "announced bonus cannot be collected early")
	director._physics_process(director.warning_duration + 0.1)
	check(preview.armed, "announced bonus activates after three seconds")
	var weapon_badges := {}
	for weapon_id in ["machine_gun", "heavy_machine_gun", "shotgun", "rocket_launcher", "mine_layer", "flamethrower", "emp_cannon"]:
		var config := load("res://resources/weapons/%s.tres" % weapon_id) as WeaponConfig
		weapon_badges[BonusPickup.weapon_badge(config)] = BonusPickup.weapon_accent(config)
	check(weapon_badges.size() == 7, "all arena weapons have distinct readable badges")
	print("BONUS PICKUP: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
