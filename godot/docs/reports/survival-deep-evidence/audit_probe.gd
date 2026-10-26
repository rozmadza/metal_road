extends SceneTree
var collected := 0
var impacts := 0
var mismatch := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	PlayerProfile.path_override = "res://audit_profile.cfg"
	LoadoutProfile.path_override = "res://audit_loadout.cfg"
	AccessibilitySettings.tutorial_enabled = false
	for seed_value in [4217, 104729, 8675309]:
		seed(seed_value)
		var game := load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
		game.get_node("Arena").set_script(load("res://audit_seed_arena.gd"))
		root.add_child(game)
		await physics_frame
		game.bonus_spawner._rng.seed = seed_value
		game.arena_hazards._rng.seed = seed_value
		game.player.damaged.connect(func(_v, _a, _s): impacts += 1)
		game.bonus_spawner.bonus_collected.connect(func(_v, _k): collected += 1)
		var durable := game.player.config.duplicate() as VehicleConfig
		durable.max_health = 50000
		durable.engine_health = 50000
		durable.wheels_health = 50000
		game.player.reconfigure(durable)
		game.player.freeze = true
		if seed_value == 4217:
			for i in game.arena._obstacle_polygons.size():
				var p: PackedVector2Array = game.arena._obstacle_polygons[i]
				var box := Rect2(p[0], Vector2.ZERO)
				for v in p: box = box.expand(v)
				print("POLYGON ", i, " ", box, " vertices=", p.size())
			for id in LoadoutProfile.vehicle_ids() + ["boss_referee_arbiter"]:
				var cfg: VehicleConfig = load("res://resources/vehicles/elite/referee_arbiter.tres") if id == "boss_referee_arbiter" else LoadoutProfile.vehicle_config(id)
				var v := Vehicle.new()
				v.config = cfg
				var r: float = game.arena.navigation().clearance(v)
				var connected := 0
				var exact := 0
				for s in game.arena.get_spawn_points(9):
					for h in game.arena.config.supply_hotspots:
						var path: PackedVector2Array = game.arena.navigation().route(s,h,r)
						if not path.is_empty():
							connected += 1
							if path[-1].distance_to(h) < 1: exact += 1
				print("ROUTES ",id," footprint=",Vector2(cfg.length,cfg.width)*Vehicle.COLLISION_SCALE," clearance=",r," connected=",connected," exact=",exact,"/36")
				v.free()
		var peak_nodes := 0
		var peak_vfx := 0
		var peak_objects := 0
		var checkpoints := []
		for frame in 10800:
			await physics_frame
			if frame % 60 == 0:
				peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
				peak_objects = maxi(peak_objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
				var vfx := get_first_node_in_group("combat_vfx") as CombatVFX
				if vfx: peak_vfx = maxi(peak_vfx,vfx.events.size())
				var msg: String = game.hud._message.text
				if game.hud._message.visible and msg.begins_with("ВОЛНА ") and not msg.begins_with("ВОЛНА %d " % game._round): mismatch += 1
			# Force a full clear at 30s intervals; real AI/physics runs between clears.
			if frame % 1800 == 1500:
				for e in game._enemies.duplicate():
					if is_instance_valid(e) and e.alive: e.take_damage(100000,&"body",game.player)
			if frame % 1800 == 1560:
				for e in game._enemies.duplicate():
					if is_instance_valid(e) and e.alive: e.take_damage(100000,&"body",game.player)
			if frame % 1800 == 1740:
				checkpoints.append([game._round, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT))])
		print("SOAK seed=",seed_value," frames=10800 sim_s=180 round=",game._round," collections=",collected," damage_events=",impacts," peak_nodes=",peak_nodes," peak_objects=",peak_objects," peak_vfx=",peak_vfx," wave_mismatch=",mismatch," checkpoints=",checkpoints)
		game._on_retry_requested()
		await physics_frame
		await process_frame
		print("RESTART round=",game._round," enemies=",game._alive_enemies()," score=",game._score," crew=",game._active_crew_count()," vfx=",get_first_node_in_group("combat_vfx").events.size())
		game.queue_free()
		await process_frame
		await create_timer(2.0).timeout
		print("CLEAN nodes=",Performance.get_monitor(Performance.OBJECT_NODE_COUNT)," objects=",Performance.get_monitor(Performance.OBJECT_COUNT)," orphans=",Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		collected=0
		impacts=0
	var fx := CombatVFX.new()
	root.add_child(fx)
	for i in 70: fx.spawn_impact(Vector2.ZERO)
	print("VFX immediate=",fx.events.size())
	await create_timer(0.7).timeout
	print("VFX expired=",fx.events.size())
	fx.queue_free()
	await process_frame
	quit()
