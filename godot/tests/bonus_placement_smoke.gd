extends SceneTree

class EmptyArena extends Arena:
	func _ready() -> void:
		_bounds = Rect2(Vector2.ZERO, config.size)

class DeniedSpawner extends BonusSpawner:
	var attempts := 0
	func _arena_position_clear(_p: Vector2, _n: RefCounted, _r: float, _o: Vector2) -> bool:
		attempts += 1
		return super._arena_position_clear(_p, _n, _r, _o)

var failures := 0
const Nav = preload("res://scripts/arena_navigation.gd")
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("PLACEMENT FAIL: ",label)
func fresh_nav(arena: Arena) -> RefCounted:
	var nav = Nav.new()
	nav.setup(arena)
	return nav
func run() -> void:
	var empty := EmptyArena.new()
	empty.config = ArenaConfig.new()
	root.add_child(empty)
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var disk := CircleShape2D.new()
	disk.radius = 2000
	wall_shape.shape = disk
	wall.add_child(wall_shape)
	empty.add_child(wall)
	await physics_frame
	await physics_frame
	var denied := DeniedSpawner.new()
	denied.setup_for_arena(empty)
	root.add_child(denied)
	denied.set_physics_process(false)
	check(denied.spawn_random_bonus() == null, "exhaustion creates no pickup")
	check(denied.attempts == 48 and denied.get_child_count() == 0, "exactly 48 attempts, no fallback")
	check(denied._time_to_event == denied.spawn_interval and denied._kind_bag.is_empty(), "failure delays and consumes no kind")
	denied._physics_process(denied.spawn_interval * 0.5)
	check(denied.attempts == 48, "no retries before cooldown")
	denied.free()
	wall.free()
	await physics_frame
	await physics_frame
	var spawner := BonusSpawner.new()
	spawner.setup_for_arena(empty)
	root.add_child(spawner)
	spawner.set_physics_process(false)
	var crate := load("res://scenes/MapProp.tscn").instantiate() as MapProp
	crate.position = Vector2(500,500)
	empty.add_child(crate)
	var spike := load("res://scenes/SpikeStrip.tscn").instantiate() as SpikeStrip
	spike.position = Vector2(700,500)
	empty.add_child(spike)
	var barrel := load("res://scenes/ExplosiveBarrel.tscn").instantiate() as ExplosiveBarrel
	barrel.position = Vector2(800,500)
	empty.add_child(barrel)
	await physics_frame
	await physics_frame
	check(not spawner._arena_position_clear(crate.position,fresh_nav(empty),40,Vector2(80,80)), "crate excludes site")
	check(not spawner._arena_position_clear(spike.position,fresh_nav(empty),40,Vector2(80,80)), "spikes exclude site")
	check(not spawner._arena_position_clear(barrel.position,fresh_nav(empty),40,Vector2(80,80)), "barrel excludes site")
	empty.config.supply_hotspots.assign([Vector2(500,500),Vector2(500,200)])
	var placed := spawner.spawn_random_bonus(BonusPickup.Kind.REPAIR)
	check(placed != null and placed.position == Vector2(500,200), "blocked hotspot skipped for valid hotspot")
	check(spawner.spawn_random_bonus() == null, "max active respected")
	crate.take_damage(1000)
	await physics_frame
	await physics_frame
	check(spawner._arena_position_clear(Vector2(500,500),fresh_nav(empty),40,Vector2(80,80)), "destroyed crate releases space immediately")
	# A continuous planner/physical wall isolates the opposite chamber.
	empty._obstacles.assign([Rect2(450,0,60,800)])
	check(not spawner._arena_position_clear(Vector2(650,200),fresh_nav(empty),40,Vector2(80,80)), "disconnected chamber rejected")
	spawner.free()
	empty.free()
	for entry in SurvivalRunData.ARENAS:
		var arena := Arena.new()
		arena.config = load(entry.path)
		root.add_child(arena)
		await physics_frame
		await physics_frame
		for id in [&"raider", &"needle", &"behemoth", &"bastion"]:
			var director := BonusSpawner.new()
			director.placement_vehicle_config = LoadoutProfile.vehicle_config(id)
			director.setup_for_arena(arena)
			director.batch_size=3
			director.minimum_weapons_per_batch=2
			director.max_active=6
			director.minimum_spawn_separation=210
			root.add_child(director)
			director.set_physics_process(false)
			director._rng.seed=4217
			director._announce_next_pickup()
			check(director._pending_pickups.size()>0 and director._pending_pickups.size()<=3, String(entry.id)+" "+String(id)+" bounded valid batch")
			if id == &"raider":
				check(director._pending_pickups.size()==3, String(entry.id)+" ordinary collector full batch")
			var points: Array[Vector2]=[]
			for pickup in director._pending_pickups:
				check(pickup.position != Vector2.ZERO, "no origin fallback")
				for other in points: check(other.distance_to(pickup.position)>=210,"separation")
				points.append(pickup.position)
			director._arm_announced_pickup()
			director._announce_next_pickup()
			for pickup in director._pending_pickups:
				for active in director._active_pickups:
					check(active.position.distance_to(pickup.position)>=210,"active-pending separation")
			director._arm_announced_pickup()
			check(director._active_pickups.size()<=6,"active cap")
			director.free()
		print("PLACEMENT arena checked: ", entry.id)
		arena.free()
		await process_frame
	print("BONUS PLACEMENT: ", "PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
