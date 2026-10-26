extends SceneTree
var failures := 0
var metrics: Dictionary = {}
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("EXPANSION ","ok: " if ok else "FAIL: ",label)
func settle() -> void:
	for frame in 4: await physics_frame
	await process_frame
func cfg(id: String) -> VehicleConfig:
	return load("res://resources/vehicles/elite/referee_arbiter.tres") if id=="arbiter" else LoadoutProfile.vehicle_config(StringName(id))
func footprint_clear(arena: Arena, config: VehicleConfig, point: Vector2, angle: float, exclude: Array[RID] = []) -> bool:
	var shape := ConvexPolygonShape2D.new()
	var vertices := config.get_body_vertices()
	for i in vertices.size(): vertices[i] *= Vehicle.COLLISION_SCALE
	shape.points = vertices
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(angle,point)
	query.margin = 2
	query.exclude = exclude
	query.collision_mask = 1
	return arena.get_world_2d().direct_space_state.intersect_shape(query).is_empty()
func geometry(arena: Arena) -> Dictionary:
	var hulls: Array = []
	for r in arena.get_navigation_obstacles(): hulls.append([r.position.x,r.position.y,r.size.x,r.size.y])
	return {"size":[arena.config.size.x,arena.config.size.y],"hulls":hulls,"grid_cells":ceil(arena.config.size.x/24)*ceil(arena.config.size.y/24)}
func run() -> void:
	PlayerProfile.path_override="res://expansion_profile.cfg"
	LoadoutProfile.path_override="res://expansion_loadout.cfg"
	CareerSession.clear_selection()
	var old := Arena.new()
	old.config=load("res://tests/fixtures/scrapyard_1000x800.tres")
	root.add_child(old)
	metrics.old=geometry(old)
	old.free()
	await settle()
	var arena := Arena.new()
	arena.config=load("res://resources/default_arena.tres")
	root.add_child(arena)
	await settle()
	metrics.new=geometry(arena)
	check(arena.get_bounds().size==Vector2(1400,1000),"bounds/area1400000")
	check(arena.get_node("Walls").get_child_count()==4 and arena.get_node("ObstacleCollisions").get_child_count()==5,"same physical obstacle count")
	var before: ArenaConfig=load("res://tests/fixtures/scrapyard_1000x800.tres")
	for i in 5:
		check(arena.config.obstacles[i].size==before.obstacles[i].size,"layout object size unchanged "+str(i))
		var h: Array=metrics.new.hulls[i]
		var o: Array=metrics.old.hulls[i]
		check(abs(h[2]-o[2])<0.01 and abs(h[3]-o[3])<0.01,"actual hull size unchanged "+str(i))
	for id in ["raider","bastion","behemoth","arbiter"]:
		var config:=cfg(id)
		var probe:=Vehicle.new()
		probe.config=config
		var clearance: float=arena.navigation().clearance(probe)
		probe.free()
		for point in arena.get_spawn_points(12):
			for angle in [0.0,PI/2,PI,PI*1.5]:
				check(footprint_clear(arena,config,point,angle),"spawn physical "+id+" "+str(point)+" angle="+str(angle))
		for goal in arena.config.supply_hotspots:
			check(arena.navigation().route_result(Vector2(80,80),goal,clearance).status==&"EXACT","hotspot exact "+id+" "+str(goal))
	check(not footprint_clear(arena,cfg("arbiter"),Vector2(700,420),0),"physical query detects center collision")
	# Full standard batches at four separated pads; production budgets unchanged.
	var spawner:=BonusSpawner.new()
	spawner.setup_for_arena(arena)
	spawner.batch_size=3
	spawner.minimum_weapons_per_batch=2
	spawner.max_active=6
	spawner.minimum_spawn_separation=210
	root.add_child(spawner)
	spawner.set_physics_process(false)
	var points: Array=[]
	for trial in 12:
		spawner._rng.seed=4217+trial
		spawner._announce_next_pickup()
		check(spawner._pending_pickups.size()==3,"full supply batch "+str(trial))
		for item in spawner._pending_pickups: points.append([item.position.x,item.position.y])
		spawner._arm_announced_pickup()
		spawner._update_active_pickups(spawner.active_lifetime+0.1)
		await process_frame
	metrics.supply_positions=points
	check(arena.config.supply_hotspots.all(func(p):return points.has([p.x,p.y])),"all four supply regions used")
	spawner.free()
	arena.free()
	await settle()
	var game:=load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	await settle()
	game.player.freeze=true
	check(game.camera.limit_right==1420 and game.camera.limit_bottom==1020 and game.camera.limit_left==-20,"camera bounds include walls only")
	check(game.camera.resting_zoom==1.23 and game.camera.maximum_speed_zoom==1.0,"camera zoom unchanged")
	check(game._alive_enemies()==2 and game._pending_enemies.size()==1,"first wave stays2+1")
	game._update_reinforcements(5)
	await settle()
	check(game._alive_enemies()==3 and game._pending_enemies.is_empty(),"reinforcement appears on expanded arena")
	game.start_round(5)
	game.player.freeze=true
	for enemy in game._enemies.duplicate(): enemy.take_damage(100000,&"body",game.player)
	await settle()
	check(is_instance_valid(game._boss) and game._boss.alive,"wave5 Arbiter")
	game._boss.freeze=true
	game._boss.get_node("ArenaBot").set_physics_process(false)
	var riders:=game._spawn_biker_squad()
	check(riders>0 and riders<=6,"biker deployment budget")
	for enemy in game._enemies:
		if not is_instance_valid(enemy) or not enemy.alive: continue
		enemy.freeze=true
		enemy.get_node("ArenaBot").set_physics_process(false)
		check(footprint_clear(game.arena,enemy.config,enemy.position,enemy.rotation,[enemy.get_rid()]),"boss/rider no physical overlap "+String(enemy.config.vehicle_id))
	metrics.bikers=riders
	check(get_nodes_in_group("spike_strips")[0].position==Vector2(240,720),"relocated spike strip")
	var oil:=get_nodes_in_group("oil_spots")[0] as OilSpot
	game.player.reset_to(oil.position,0)
	await settle()
	check(game.player._surface_modifiers.has(oil),"real oil sensor at relocated position")
	game.player.reset_to(Vector2(240,720),0)
	await settle()
	check(game.player.damage.wheels<game.player.config.wheels_health,"real spike sensor damage")
	var crate:=get_nodes_in_group("arena_obstacles").filter(func(n):return n.kind==&"crate")[0] as MapProp
	crate.take_damage(1000)
	var barrel:=get_nodes_in_group("destructibles").filter(func(n):return n is ExplosiveBarrel)[0] as ExplosiveBarrel
	barrel.explode()
	game._on_retry_requested()
	await settle()
	check(game.arena.config.size==Vector2(1400,1000) and game._round==1,"Restart expanded arena")
	check(get_nodes_in_group("arena_obstacles").filter(func(n):return n.kind==&"crate" and not n.destroyed).size()==2,"Restart restores crates")
	check(get_nodes_in_group("destructibles").filter(func(n):return n is ExplosiveBarrel and not n.destroyed).size()==3,"Restart restores barrels")
	check(get_nodes_in_group("spike_strips").size()==1 and get_nodes_in_group("spike_strips")[0].position==Vector2(240,720),"Restart restores authored spike")
	game.player.reset_to(Vector2(700,860),0)
	await settle()
	game.player.freeze=true
	game.camera.snap_to_target()
	game.hud.tutorial.visible=true
	await settle()
	check(game.hud.tutorial.get_global_rect().position.y==180,"tutorial moves away from car near lower camera boundary")
	game.hud.tutorial.hide()
	metrics.failures=failures
	FileAccess.open("res://expansion-geometry.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	game.queue_free()
	await settle()
	print("ARENA EXPANSION: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
