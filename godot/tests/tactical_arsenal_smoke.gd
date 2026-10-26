extends SceneTree
## Contract test for weapon identities, burst/ammo rules and tactical effects.

const WEAPONS := [
	"machine_gun", "heavy_machine_gun", "shotgun", "rocket_launcher",
	"mine_layer", "flamethrower", "emp_cannon",
]

var failures := 0
var world: Node2D
var bullets: Node2D


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("TACTICAL ARSENAL FAIL: ", label)


func vehicle_at(position: Vector2) -> Vehicle:
	var vehicle := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	world.add_child(vehicle)
	vehicle.global_position = position
	vehicle.freeze = true
	vehicle.add_to_group("combatants")
	return vehicle


func run() -> void:
	world = Node2D.new()
	root.add_child(world)
	bullets = Node2D.new()
	bullets.add_to_group("bullets")
	world.add_child(bullets)
	var types: Dictionary = {}
	for id in WEAPONS:
		var config := load("res://resources/weapons/%s.tres" % id) as WeaponConfig
		check(config != null, "%s loads" % id)
		if config != null:
			types[config.weapon_type] = true
			check(config.texture != null, "%s has raster roof art" % id)
			check(config.magazine_size > 0 and config.reload_time > 0.0, "%s has ammo rules" % id)
			check(not config.tactical_role.is_empty(), "%s explains tactical role" % id)
	check(types.size() == 6, "all six weapon behaviours are represented")

	var shooter := vehicle_at(Vector2.ZERO)
	var gun := shooter.gun
	gun._bullets_parent = bullets
	var shotgun := load("res://resources/weapons/shotgun.tres") as WeaponConfig
	gun.equip(shotgun)
	gun._shoot()
	check(bullets.get_child_count() == shotgun.projectiles_per_shot, "shotgun creates a real pellet spread")
	check(gun.ammo == shotgun.magazine_size - 1, "burst consumes one shell")
	gun.ammo = 0
	gun._cooldown = 0.0
	gun.set_firing(true)
	gun._physics_process(0.02)
	check(gun.reload_remaining > 0.0, "empty magazine starts reload")
	gun.set_firing(false)
	gun._physics_process(shotgun.reload_time + 0.1)
	check(gun.ammo == shotgun.magazine_size, "reload refills magazine")
	for child in bullets.get_children(): child.free()

	var near_target := vehicle_at(Vector2(35, 0))
	var side_target := vehicle_at(Vector2(78, 0))
	var rocket := load("res://resources/weapons/rocket_launcher.tres") as WeaponConfig
	var projectile := (load("res://scenes/Bullet.tscn") as PackedScene).instantiate() as Bullet
	bullets.add_child(projectile)
	projectile.setup(Vector2(35, 0), Vector2.RIGHT, rocket, shooter)
	var near_before := near_target.health
	var side_before := side_target.health
	projectile._detonate()
	check(near_target.health < near_before and side_target.health < side_before, "rocket damages a group with falloff")
	check(near_target.last_weapon_id == &"rocket_launcher", "weapon kill source is recorded")

	var emp := load("res://resources/weapons/emp_cannon.tres") as WeaponConfig
	var emp_projectile := (load("res://scenes/Bullet.tscn") as PackedScene).instantiate() as Bullet
	bullets.add_child(emp_projectile)
	emp_projectile.setup(side_target.global_position, Vector2.RIGHT, emp, shooter)
	var emp_health_before := side_target.health
	emp_projectile._apply_hit(side_target, emp.bullet_damage)
	check(side_target.is_emp_disabled(), "EMP temporarily disrupts target controls")
	check(side_target.emp_time_remaining >= 3.0, "EMP duration is applied")
	check(side_target.health < emp_health_before, "EMP also deals a small amount of body HP damage")

	var flame := load("res://resources/weapons/flamethrower.tres") as WeaponConfig
	shooter.linear_velocity = Vector2(145.0, 28.0)
	var flame_projectile := (load("res://scenes/Bullet.tscn") as PackedScene).instantiate() as Bullet
	bullets.add_child(flame_projectile)
	flame_projectile.setup(Vector2.ZERO, Vector2.RIGHT, flame, shooter)
	var relative_flame_velocity := flame_projectile.velocity - shooter.linear_velocity
	check(is_equal_approx(relative_flame_velocity.length(), flame.bullet_speed), "flamethrower range stays constant while its carrier moves")
	var crew := (load("res://scenes/EscapingCrew.tscn") as PackedScene).instantiate() as EscapingCrew
	crew.setup(EscapingCrew.Role.PILOT, null, Vector2.RIGHT)
	world.add_child(crew)
	crew.global_position = Vector2(500, 500)
	var crew_projectile := (load("res://scenes/Bullet.tscn") as PackedScene).instantiate() as Bullet
	bullets.add_child(crew_projectile)
	crew_projectile.setup(crew.global_position - Vector2(10, 0), Vector2.RIGHT, load("res://resources/weapons/machine_gun.tres") as WeaponConfig, shooter)
	crew_projectile._physics_process(0.03)
	check(not crew._active and crew.health == 0.0, "one fast projectile kills crew while crossing it between frames")
	crew.free()
	var aim_crew := (load("res://scenes/EscapingCrew.tscn") as PackedScene).instantiate() as EscapingCrew
	aim_crew.setup(EscapingCrew.Role.PILOT, null, Vector2.RIGHT)
	world.add_child(aim_crew)
	aim_crew.global_position = Vector2(600, 630)
	shooter.global_position = Vector2(300, 600)
	gun.equip(load("res://resources/weapons/machine_gun.tres") as WeaponConfig)
	gun._shoot()
	var assisted_shot := bullets.get_child(bullets.get_child_count() - 1) as Bullet
	check(assisted_shot.velocity.y > 0.0, "gunfire nudges toward crew near the firing line")
	shooter.global_position = Vector2.ZERO
	var guided_rocket := (load("res://scenes/Bullet.tscn") as PackedScene).instantiate() as Bullet
	bullets.add_child(guided_rocket)
	guided_rocket.setup(Vector2(500, 630), Vector2.UP, rocket, shooter)
	guided_rocket._guide_rocket(0.1)
	check(guided_rocket.velocity.x > 0.0, "guided rocket can steer toward fleeing crew")
	aim_crew.free()

	var mine := load("res://resources/weapons/mine_layer.tres") as WeaponConfig
	shooter.activate_temporary_weapon(mine, 20.0)
	gun._bullets_parent = bullets
	gun._shoot()
	var deployed := bullets.get_child(bullets.get_child_count() - 1) as Bullet
	check(deployed.weapon_type == WeaponConfig.WeaponType.MINE, "mine layer deploys a persistent hazard")
	check(deployed.is_in_group("weapon_hazards"), "bots can identify deployed mines")
	var pursuer := vehicle_at(Vector2(-80, 0))
	var bot := BotController.new()
	shooter.add_child(bot)
	bot.vehicle = shooter
	check(bot._should_fire(), "racing bot drops a mine only when pursued from behind")
	deployed.global_position = Vector2(300, 300)
	pursuer.global_position = deployed.global_position + Vector2(70, 0)
	deployed.age = mine.effect_duration
	check(not deployed._mine_has_target(), "armed mine ignores a vehicle inside blast radius without contact")
	deployed._physics_process(0.02)
	check(not deployed.detonated, "passing nearby does not detonate the mine")
	pursuer.global_position = deployed.global_position
	check(deployed._mine_has_target(), "mine detects a vehicle over its casing")
	deployed._physics_process(0.02)
	check(deployed.detonated, "driving over an armed mine detonates it")

	var hud_state := shooter.get_hud_state()
	check(hud_state.weapon_texture == mine.texture, "HUD exposes current weapon icon")
	check("БОЕЗАПАС" in hud_state.weapon_state, "HUD exposes ammunition")
	var dust_event := CareerSession.event_by_id(&"dust_elimination")
	check(not CareerSession._objective_success(dust_event, {"kills": 1, "weapon_kills": 0}), "ram kill does not satisfy weapon contract")
	check(CareerSession._objective_success(dust_event, {"kills": 1, "weapon_kills": 1}), "weapon kill satisfies career contract")
	var iron_event := CareerSession.event_by_id(&"iron_open")
	check(CareerSession._objective_success(iron_event, {"status": &"FINISHED", "position": 3, "repairs_used": 0}), "clean top-three finish satisfies no-repair contract")
	check(not CareerSession._objective_success(iron_event, {"status": &"FINISHED", "position": 2, "repairs_used": 1}), "using repair fails no-repair contract")
	world.free()
	print("TACTICAL ARSENAL: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
