extends SceneTree
## Real-time rendered benchmark and scripted-player observations. No fixed-fps.
const Stats=preload("res://tests/survival_perf_stats.gd")
var game: Survival
var options: Dictionary={}
var phase:="setup"
var run_id:="audit"
var factor:=1.0
var rows: Array=[]
var windows: Array=[]
var frames: Array=[]
var pending_reports: Array=[]
var metrics: Dictionary={}
var active:=false
var last_frame_us:=0
var stage_start_us:=0
var counts_at:=0
var counts:=[0,0,0,0,0]
var tracked: Dictionary={}
var waypoint:=0
var next_repair:=0.0
var next_burst:=0.0
var repair_fixture:=false
var burst_fixture:=false
var scripted_clear:=false
var natural_mode:=false
var range_fixture:=false
var capturing:=false
var collisions_this_frame:=0
var damage_this_frame:=0.0
var scripted_repairs_total:=0
var scripted_kills_total:=0
var first_session_wall:=0
var peak_probe_us:=0
var failures:=0
var outputs:="res://perf-output/"
var route: Array[Vector2]=[Vector2(1260,150),Vector2(1260,850),Vector2(700,850),Vector2(150,850),Vector2(150,150),Vector2(700,150)]
func _initialize() -> void: run.call_deferred()
func argument(name: String, fallback: String) -> String: return str(options.get(name,fallback))
func new_metrics() -> Dictionary:
	return {"damage_received":0.0,"damage_dealt":0.0,"first_contact_s":-1.0,"first_weapon_s":-1.0,"first_hostile_damage_s":-1.0,"repair_pickups":0,"pickups":0,"natural_deaths":0,"scripted_kills":0,"shots":0,"impact_signals":0,"idle_over5_s":0.0,"idle_max_s":0.0,"player_idle_over5_s":0.0,"player_idle_max_s":0.0,"player_activity_us":Time.get_ticks_usec(),"idle_now":0.0,"ended":false,"end_reason":"window_limit","scripted_repairs":0}
func _process(_delta: float) -> bool:
	if game==null or not is_instance_valid(game): return false
	var probe_start:=Time.get_ticks_usec()
	var now:=probe_start
	var elapsed:=(now-stage_start_us)/1000000.0
	if game.player.alive and not game._round_over:
		if repair_fixture and elapsed>=next_repair:
			game.player.repair_full()
			next_repair=elapsed+0.25
			scripted_repairs_total+=1
			if active: metrics.scripted_repairs+=1
		if range_fixture: Input.action_press("fire")
		elif argument("pilot","1")!="0": pilot()
	else:
		Input.action_release("accelerate")
		Input.action_release("brake")
		Input.action_release("fire")
		Input.action_release("steer_left")
		Input.action_release("steer_right")
	if not active: return false
	if burst_fixture and elapsed>=next_burst:
		next_burst=elapsed+0.5
		var fx:=game.get_node("CombatVFX") as CombatVFX
		for i in 70: fx.spawn_impact(game.player.position+Vector2((i%10-5)*15,(i/10-3)*15))
		for i in 10: fx.spawn_explosion(game.player.position+Vector2((i%5-2)*40,(i/5-1)*40))
	if now>=counts_at:
		counts_at=now+100000
		track()
		var ai:=0
		for enemy in game._enemies:
			if is_instance_valid(enemy) and enemy.alive:
				var driver:=enemy.get_node_or_null("ArenaBot") as ArenaBot
				if driver!=null and driver.is_physics_processing(): ai+=1
		var fx_count:=0
		for fx in get_nodes_in_group("combat_vfx"): fx_count+=fx.events.size()
		counts=[ai,game.bullets.get_child_count(),fx_count,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),game._run_perks.size()]
	var dt:=(now-last_frame_us)/1000.0
	last_frame_us=now
	var idle: float=game._combat_idle
	if metrics.first_contact_s<0:
		for enemy in game._enemies:
			if is_instance_valid(enemy) and enemy.alive and enemy.position.distance_to(game.player.position)<=250:
				metrics.first_contact_s=elapsed
	metrics.idle_max_s=maxf(metrics.idle_max_s,idle)
	if idle>=5.0: metrics.idle_over5_s+=dt/1000.0
	var player_idle: float=(now-int(metrics.player_activity_us))/1000000.0
	metrics.player_idle_max_s=maxf(metrics.player_idle_max_s,player_idle)
	if player_idle>=5.0: metrics.player_idle_over5_s+=dt/1000.0
	# Engine monitor values are captured per rendered frame, not GPU busy %.
	frames.append([now,dt,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
		RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS),
		counts[0],game.bullets.get_child_count(),game.get_node("CombatVFX").events.size(),counts[3],collisions_this_frame,damage_this_frame,
		game.player.health,game.player.get_speed(),counts[4],Time.get_ticks_usec()-probe_start])
	collisions_this_frame=0
	damage_this_frame=0.0
	return false
func pilot() -> void:
	var target: Vector2=route[waypoint%route.size()]
	# Pickups are reached by ordinary driving; no collect(), teleport or grants.
	var nearest:=INF
	for item in get_nodes_in_group("bonus_pickups"):
		if not item.armed or item.collected_once: continue
		if item.kind==BonusPickup.Kind.WEAPON and game.player.has_temporary_weapon(): continue
		if item.kind==BonusPickup.Kind.REPAIR and game.player.health>game.player.config.max_health*0.8: continue
		var d: float=game.player.position.distance_to(item.position)
		if d<nearest and d<420:
			nearest=d
			target=item.global_position
	if nearest==INF and game.player.position.distance_to(target)<100: waypoint+=1
	var forward:=Vector2.RIGHT.rotated(game.player.rotation)
	var error:=forward.angle_to(target-game.player.position)
	var steering:=clampf(error*1.5,-1,1)
	Input.action_press("accelerate",0.5 if absf(error)>1.1 else 1.0)
	Input.action_release("brake")
	if steering>=0:
		Input.action_release("steer_left")
		Input.action_press("steer_right",steering)
	else:
		Input.action_release("steer_right")
		Input.action_press("steer_left",-steering)
	if game.player.has_temporary_weapon(): Input.action_press("fire")
	else: Input.action_release("fire")
func track() -> void:
	for car in get_nodes_in_group("combatants"):
		if not car is Vehicle or tracked.has(car.get_instance_id()): continue
		tracked[car.get_instance_id()]=true
		car.damaged.connect(on_damage)
		car.impacted.connect(func(_value):
			collisions_this_frame+=1
			if active: metrics.impact_signals+=1)
		car.died.connect(func(_car):
			if active and _car!=game.player:
				if scripted_clear: metrics.scripted_kills+=1
				else: metrics.natural_deaths+=1)
		car.gun.fired.connect(func():
			if active:
				metrics.shots+=1
				if car==game.player: metrics.player_activity_us=Time.get_ticks_usec())
func on_damage(target: Vehicle, amount: float, source: Node) -> void:
	if not active or scripted_clear: return
	damage_this_frame+=amount
	if target==game.player: metrics.damage_received+=amount
	elif source==game.player: metrics.damage_dealt+=amount
	if (target==game.player and source is Vehicle) or source==game.player:
		metrics.player_activity_us=Time.get_ticks_usec()
		if metrics.first_hostile_damage_s<0: metrics.first_hostile_damage_s=(Time.get_ticks_usec()-stage_start_us)/1000000.0
func on_pickup(car: Vehicle, kind: BonusPickup.Kind) -> void:
	if not active or car!=game.player: return
	metrics.pickups+=1
	if kind==BonusPickup.Kind.REPAIR: metrics.repair_pickups+=1
	if kind==BonusPickup.Kind.WEAPON and metrics.first_weapon_s<0: metrics.first_weapon_s=(Time.get_ticks_usec()-stage_start_us)/1000000.0
func build(wave: int) -> void:
	active=false
	Stats.phase="build_wave_"+str(wave)
	tracked.clear()
	var started:=Time.get_ticks_usec()
	game=load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	if wave>1: game.start_round(wave)
	game.bonus_spawner._rng.seed=int(argument("seed","4217"))
	game.bonus_spawner.bonus_collected.connect(on_pickup)
	waypoint=0
	next_repair=0
	next_burst=0
	track()
	rows.append({"event":"scene_build","wave":wave,"us":Time.get_ticks_usec()-started,"arena":game.arena.config.size,"player_vehicle":str(game.player.config.vehicle_id),"player_hp":game.player.config.max_health})
	await process_frame
func menu_entry() -> void:
	Stats.phase="menu_entry"
	var started:=Time.get_ticks_usec()
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await scene_changed
	current_scene.get_node("%SurvivalButton").pressed.emit()
	while not current_scene is PreRaceSetup or SceneTransition.is_busy(): await process_frame
	current_scene.get_node("%StartButton").pressed.emit()
	while not current_scene is Survival or SceneTransition.is_busy(): await process_frame
	game=current_scene as Survival
	tracked.clear()
	game.bonus_spawner._rng.seed=int(argument("seed","4217"))
	game.bonus_spawner.bonus_collected.connect(on_pickup)
	track()
	rows.append({"event":"menu_to_survival","us":Time.get_ticks_usec()-started})
func dispose() -> void:
	active=false
	for action in ["accelerate","brake","steer_left","steer_right","fire"]: Input.action_release(action)
	if is_instance_valid(game): game.free()
	game=null
	await process_frame
func sample(label: String, seconds: float, keep_after_defeat: bool=false) -> void:
	phase=label
	Stats.phase=label
	metrics=new_metrics()
	frames=[]
	counts_at=0
	stage_start_us=Time.get_ticks_usec()
	metrics.game_time_start=game._elapsed
	last_frame_us=stage_start_us
	next_repair=0
	next_burst=0
	active=true
	while (Time.get_ticks_usec()-stage_start_us)/1000000.0<seconds*factor:
		await process_frame
		if not keep_after_defeat and (not game.player.alive or game._round_over):
			metrics.ended=true
			metrics.end_reason="defeat" if not game.player.alive else "wave_complete"
			break
	active=false
	metrics.elapsed_wall_s=(Time.get_ticks_usec()-stage_start_us)/1000000.0
	metrics.active_game_s=game._elapsed-float(metrics.game_time_start)
	metrics.round=game._round
	metrics.alive_ai_end=game._alive_enemies()
	metrics.perks=game._run_perks.size()
	metrics.player_kills=game._kills
	metrics.nodes_end=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	metrics.pending=game._pending_enemies.size()
	var filename:=run_id+"-"+label+".json"
	pending_reports.append({"file":filename,"phase":label,"metrics":metrics.duplicate(true),"frames":frames})
	windows.append({"label":label,"file":filename,"metrics":metrics.duplicate(true),"frames":frames.size()})
	print("PERF WINDOW ",label," frames=",frames.size()," elapsed=",metrics.elapsed_wall_s," reason=",metrics.end_reason)
func shot(label: String) -> void:
	if not capturing: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(outputs+run_id+"-"+label+".png")
func stress_eight(weapons: bool=false, convergence: bool=false) -> void:
	game._clear_enemies()
	game._pending_enemies.clear()
	game._reinforcement_timer=0
	game._round_enemy_total=8
	var spawns:=game.arena.get_spawn_points(9)
	if convergence: game.player.reset_to(Vector2(700,850),0)
	for i in 8:
		var position: Vector2=spawns[i+1]
		if convergence: position=Vector2(700,850)+Vector2.RIGHT.rotated(i*TAU/8)*140.0
		var car:=game._spawn_bot(position,i)
		if weapons: car.activate_temporary_weapon(load("res://resources/weapons/machine_gun.tres"),30)
		if convergence:
			car.rotation=(game.player.position-car.position).angle()
			car.linear_velocity=(game.player.position-car.position).normalized()*160.0
	if weapons: game.player.activate_temporary_weapon(load("res://resources/weapons/machine_gun.tres"),30)
	track()
func restart_measure() -> void:
	active=false
	Stats.phase="restart"
	var before:=Time.get_ticks_usec()
	var nodes_before:=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var arena_id:=game.arena.get_instance_id()
	game._on_retry_requested()
	var request_return:=Time.get_ticks_usec()
	while game._round_start_pending>=0 or game.arena.get_instance_id()==arena_id: await process_frame
	var logic_ready:=Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var first_render:=Time.get_ticks_usec()
	rows.append({"event":"restart","request_us":request_return-before,"logic_ready_us":logic_ready-before,"first_render_us":first_render-before,"nodes_before":nodes_before,"nodes_after":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"old_arena":arena_id,"new_arena":game.arena.get_instance_id(),"round":game._round,"ai":game._alive_enemies(),"bullets":game.bullets.get_child_count(),"vfx":game.get_node("CombatVFX").events.size()})
	await sample("post_restart",6)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.split("=",true,1)
		if pair.size()==2: options[pair[0]]=pair[1]
	run_id=argument("id","audit")
	factor=float(argument("scale","1"))
	Stats.enabled=argument("instrumented","0")=="1"
	capturing=argument("shots","0")=="1"
	DirAccess.make_dir_recursive_absolute(outputs)
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	PlayerProfile.path_override="res://perf-output/"+run_id+"-profile.cfg"
	LoadoutProfile.path_override="res://perf-output/"+run_id+"-loadout.cfg"
	LoadoutProfile.save_ids(&"raider",&"machine_gun")
	PlayerProfile.save(PlayerProfile.read())
	CareerSession.clear_selection()
	SurvivalRunData.selected_arena_id=&"scrapyard"
	SurvivalRunData.daily_mode=false
	seed(int(argument("seed","4217")))
	var meta:={"collector_version":2,"id":run_id,"options":options,"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),"vsync":DisplayServer.window_get_vsync_mode(),"window":root.size,"physics_hz":Engine.physics_ticks_per_second,"instrumented":Stats.enabled,"time_scale":Engine.time_scale,"fields":["timestamp_us","wall_frame_ms","engine_process_ms","engine_physics_ms","viewport_cpu_ms","viewport_gpu_ms","draw_calls","physics_active","collision_pairs","ai","projectiles","combat_vfx_events","nodes","impact_signals","damage_all","player_hp","player_speed","perks","probe_us"]}
	if argument("mode","suite")=="firing_range":
		await build(1)
		stress_eight()
		range_fixture=true
		burst_fixture=true
		game.player.reset_to(Vector2(700,760),0)
		game.player.activate_temporary_weapon(load("res://resources/weapons/shotgun.tres"),30)
		for i in game._enemies.size():
			var car: Vehicle=game._enemies[i]
			var direction:=Vector2.RIGHT.rotated(i*TAU/8)
			car.position=Vector2(700,760)+direction*200
			car.rotation=direction.angle()
			car.linear_velocity=Vector2.ZERO
			car.get_node("ArenaBot").set_physics_process(false)
			car.activate_temporary_weapon(load("res://resources/weapons/shotgun.tres"),30)
			car.apply_control(0,0,0,true)
		game.camera.snap_to_target()
		await sample("firing_range",20)
		await shot("firing_range")
	elif argument("mode","suite")=="menu_entry":
		await menu_entry()
		await sample("menu_wave1",12)
		await shot("menu_entry")
	elif argument("mode","suite")=="sustain":
		repair_fixture=true
		for wave in [1,2,3,4]:
			await build(wave)
			await sample("sustained_wave"+str(wave),18)
			await shot("sustained"+str(wave))
			await dispose()
	elif argument("mode","suite")=="natural":
		natural_mode=true
		await build(1)
		await sample("natural_wave1",90)
		await shot("natural_end")
	else:
		await build(1)
		await sample("wave1_start",5)
		if game.player.alive and not game._round_over: await sample("wave1_three",14)
		await shot("wave1")
		await dispose()
		for wave in [2,3,4]:
			await build(wave)
			await sample("wave"+str(wave),18)
			await shot("wave"+str(wave))
			await dispose()
		await build(5)
		repair_fixture=true
		scripted_clear=true
		for enemy in game._enemies.duplicate():
			if is_instance_valid(enemy) and enemy.alive:
				scripted_kills_total+=1
				enemy.take_damage(100000,&"body",game.player)
		scripted_clear=false
		await process_frame
		await process_frame
		await sample("wave5_boss_entry",11)
		await sample("wave5_bikers",18)
		await shot("boss")
		await dispose()
		await build(1)
		stress_eight()
		await sample("eight_ai",18)
		await shot("eight")
		await dispose()
		await build(1)
		stress_eight(true)
		burst_fixture=true
		await sample("fire_vfx_burst",14)
		await shot("vfx")
		burst_fixture=false
		await dispose()
		await build(1)
		stress_eight(false,true)
		await sample("collision_burst",5,true)
		await shot("collision")
		await dispose()
		await build(4)
		await sample("endurance",60)
		await restart_measure()
		await shot("restart")
	meta.windows=windows
	meta.setup_events=rows
	meta.scripted_kills=scripted_kills_total
	meta.scripted_full_repairs=scripted_repairs_total
	meta.function_times_us=Stats.calls
	meta.slow_events=Stats.events
	meta.probe_notes="Counts cached every100ms. Signal counters per-frame. Native TIME_PROCESS/PHYSICS are last-second MAXIMA, not frame samples. WALL clock, no fixed-fps. Free repairs in labelled load fixtures. JSON writes deferred until measurements end."
	for report in pending_reports:
		FileAccess.open(outputs+report.file,FileAccess.WRITE).store_string(JSON.stringify({"phase":report.phase,"metrics":report.metrics,"frames":report.frames}))
	FileAccess.open(outputs+run_id+"-manifest.json",FileAccess.WRITE).store_string(JSON.stringify(meta))
	await dispose()
	print("PERFORMANCE AUDIT COMPLETE ",run_id)
	quit()
