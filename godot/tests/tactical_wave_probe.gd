extends SceneTree
## Physical behavior telemetry. High HP and optional fixed supply/gun fixtures
## exist only in this test. Graphical frame measurements never use fixed-fps.
const Stats = preload("res://tests/survival_perf_stats.gd")
var options := {}
var game: Survival
var active := false
var frames: Array = []
var reports: Array = []
var actors: Array = []
var traces: Array = []
var pickups: Array = []
var last_us := 0
var tick := 0
var waypoint := 0
var phase := ""
var run_id := "tactics"

func _initialize() -> void: run.call_deferred()

func _process(_delta: float) -> bool:
	if active:
		var now := Time.get_ticks_usec()
		frames.append((now - last_us) / 1000.0)
		last_us = now
	return false

func pilot() -> void:
	var route := [Vector2(230,860),Vector2(1180,860),Vector2(1200,180),Vector2(500,150)]
	var target: Vector2 = route[waypoint % route.size()]
	if game.player.position.distance_to(target) < 100: waypoint += 1
	var error := Vector2.RIGHT.rotated(game.player.rotation).angle_to(target-game.player.position)
	Input.action_press("accelerate",0.5 if absf(error)>1.1 else 1.0)
	Input.action_release("brake")
	Input.action_release("fire")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_press("steer_right" if error>=0 else "steer_left",minf(absf(error)*1.5,1.0))

func sturdy(car: Vehicle) -> void:
	car.config = car.config.duplicate()
	car.config.max_health = 50000.0
	car.config.engine_health = 50000.0
	car.config.wheels_health = 50000.0
	car.damage.reset(car.config)

func register_actor(car: Vehicle, index: int) -> void:
	var driver := car.get_node("ArenaBot") as ArenaBot
	var row := {"index":index,"vehicle":str(car.config.display_name),"elite":car.get_meta("elite",false),
		"strategy":driver.strategy,"role":driver.team_role,"intent_s":{},"shots":0,"pickups":0,
		"first_contact_s":-1.0,"first_shot_s":-1.0,"stop_s":0.0,"longest_stop_s":0.0,"last_shot":0.0,
		"hits_on_player":0,"damage_to_player":0.0,"first_damage_s":-1.0,
		"armed_no_attack_s":0.0,"longest_armed_no_attack_s":0.0,"supply_choices":[],
		"last_pickup":0,"distance_travelled":0.0,"previous_position":car.position}
	actors.append(row)
	car.gun.fired.connect(func():
		if active:
			if row.shots==0: row.first_shot_s=tick/60.0
			row.shots += 1
			row.last_shot = tick/60.0)
	car.damaged.connect(func(_v,_a,source):
		if active and source==game.player and row.first_contact_s<0: row.first_contact_s=tick/60.0)

func supply(point: Vector2) -> void:
	var item := load("res://scenes/BonusPickup.tscn").instantiate() as BonusPickup
	item.setup(BonusPickup.Kind.WEAPON,load("res://resources/weapons/machine_gun.tres"))
	item.position=point
	game.add_child(item)
	item.collected.connect(func(_p,car):
		if not active: return
		for i in game._enemies.size():
			if car==game._enemies[i]: actors[i].pickups+=1
		pickups.append({"s":tick/60.0,"actor":game._enemies.find(car),"kind":0,"fixture":true}))

func observe() -> void:
	var snapshot := []
	var claims := {}
	for i in game._enemies.size():
		var car: Vehicle=game._enemies[i]
		if not is_instance_valid(car): continue
		var d := car.get_node("ArenaBot") as ArenaBot
		var r: Dictionary=actors[i]
		var intent := str(d._intent)
		r.intent_s[intent]=float(r.intent_s.get(intent,0.0))+1.0/60.0
		r.distance_travelled += car.position.distance_to(r.previous_position)
		r.previous_position=car.position
		var stop := car.get_speed()<12.0 and intent in ["supply","pursue","attack","reposition"]
		r.stop_s = r.stop_s+1.0/60.0 if stop else 0.0
		r.longest_stop_s=maxf(r.longest_stop_s,r.stop_s)
		var distance := car.position.distance_to(game.player.position)
		if distance<150 and r.first_contact_s<0: r.first_contact_s=tick/60.0
		var no_attack: bool=car.has_temporary_weapon() and distance<450 and tick/60.0-r.last_shot>1.0
		r.armed_no_attack_s=r.armed_no_attack_s+1.0/60.0 if no_attack else 0.0
		r.longest_armed_no_attack_s=maxf(r.longest_armed_no_attack_s,r.armed_no_attack_s)
		var locked := d._locked_pickup.get_instance_id() if is_instance_valid(d._locked_pickup) else 0
		if intent=="supply" and locked!=0:
			claims[locked]=int(claims.get(locked,0))+1
			if locked!=r.last_pickup: r.supply_choices.append({"s":tick/60.0,"pickup":locked})
		r.last_pickup=locked
		if tick%6==0:
			var path := []
			for p in d._path: path.append([p.x,p.y])
			snapshot.append({"i":i,"p":[car.position.x,car.position.y],"speed":car.get_speed(),
				"goal":[d._intent_goal.x,d._intent_goal.y],"intent":intent,"route":str(d._route_status),
				"pickup":locked,"path":path,"reverse":d._reversing,"yield":d._yield_until>d._drive_time,
				"recovery":d.recovery_requested,"detours":d.traffic_detours})
	if tick%6==0: traces.append({"s":tick/60.0,"actors":snapshot,
		"player":[game.player.position.x,game.player.position.y],"player_heading":game.player.rotation,
		"max_same_supply":claims.values().max() if not claims.is_empty() else 0})

func scenario(label: String, wave: int, seconds: float, fixture: String="") -> void:
	Stats.enabled=false
	seed(int(options.get("seed","4217")))
	game=load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	game.start_round(wave)
	await process_frame
	await physics_frame
	await process_frame
	game.bonus_spawner._rng.seed=int(options.get("seed","4217"))
	sturdy(game.player)
	actors=[];traces=[];frames=[];pickups=[];tick=0;waypoint=0
	phase=label;Stats.phase=label
	for i in game._enemies.size():
		sturdy(game._enemies[i])
		register_actor(game._enemies[i],i)
	game.player.damaged.connect(func(_v,amount,source):
		if not active or not source is Vehicle: return
		var i := game._enemies.find(source)
		if i>=0:
			actors[i].hits_on_player+=1
			actors[i].damage_to_player+=amount
			if actors[i].first_contact_s<0: actors[i].first_contact_s=tick/60.0
			if actors[i].first_damage_s<0: actors[i].first_damage_s=tick/60.0)
	game.bonus_spawner.bonus_collected.connect(func(car,kind):
		if not active: return
		var i := game._enemies.find(car)
		if i>=0: actors[i].pickups+=1
		pickups.append({"s":tick/60.0,"actor":i,"kind":kind,"fixture":false}))
	if fixture!="":
		game.bonus_spawner.set_physics_process(false)
		game.bonus_spawner.reset()
		game.player.position=Vector2(1150,860)
		game.player.rotation=PI
		game.player.freeze=true
		for i in game._enemies.size():
			var car: Vehicle=game._enemies[i]
			car.reset_to(Vector2(250+(i/2)*200,820+(i%2)*120),0.0)
			if fixture in ["armed","flank_open"]: car.activate_temporary_weapon(load("res://resources/weapons/machine_gun.tres"),999)
		if fixture=="supply":
			supply(Vector2(650,850));supply(Vector2(900,920))
		if fixture=="flank_open":
			game.player.freeze=false
			game.player.reset_to(Vector2(1150,860),0)
			for _step in 3: await physics_frame
			await process_frame
			game.player.freeze=true
			for car in game._enemies:
				var driver:=car.get_node("ArenaBot") as ArenaBot
				driver._spawn_position=car.position
				driver._passing_side=1.0 # RIGHT.orthogonal() points up in Godot.
				driver._reaction_clock=0.0
				if driver.team_role==ArenaBot.TeamRole.FLANKER:
					if options.has("flank_width"): driver.flank_width=float(options.flank_width)
					if options.has("flank_entry"): driver.flank_approach_offset=float(options.flank_entry)
	if label.begins_with("load"):
		for car in game._enemies: car.activate_temporary_weapon(load("res://resources/weapons/machine_gun.tres"),999)
	await physics_frame
	await process_frame
	for i in actors.size(): actors[i].previous_position=game._enemies[i].position
	active=true;Stats.enabled=true;last_us=Time.get_ticks_usec()
	for frame in int(seconds*60):
		if fixture=="": pilot()
		await physics_frame
		tick=frame+1
		observe()
	active=false;Stats.enabled=false
	for i in actors.size():
		var d := game._enemies[i].get_node("ArenaBot") as ArenaBot
		actors[i].erase("previous_position")
		actors[i].recovery_requested=d.recovery_requested
		actors[i].recovery_started=d.recovery_started
		actors[i].detours=d.traffic_detours
		actors[i].yield_count=d.yield_manoeuvres
	var collision_geometry := []
	for prop in get_nodes_in_group("arena_obstacles"):
		if prop is Node2D: collision_geometry.append([prop.position.x,prop.position.y,prop.rotation])
	reports.append({"label":label,"wave":wave,"seconds":seconds,"actors":actors.duplicate(true),
		"traces":traces.duplicate(true),"frames":frames.duplicate(),"pickups":pickups.duplicate(),
		"geometry":collision_geometry})
	for action in ["accelerate","brake","steer_left","steer_right","fire"]: Input.action_release(action)
	game.free();game=null
	await process_frame
	print("TACTICAL PROBE ",label," COMPLETE")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.split("=",true,1)
		if pair.size()==2: options[pair[0]]=pair[1]
	run_id=str(options.get("id","tactics"))
	DirAccess.make_dir_recursive_absolute("res://perf-output/")
	PlayerProfile.path_override="res://perf-output/"+run_id+"-profile.cfg"
	LoadoutProfile.path_override="res://perf-output/"+run_id+"-loadout.cfg"
	LoadoutProfile.save_ids(&"raider",&"machine_gun")
	if not FileAccess.file_exists(LoadoutProfile.path_override):
		printerr("TACTICAL PROBE FAIL: test loadout was not created")
		quit(1);return
	PlayerProfile.save(PlayerProfile.read())
	CareerSession.clear_selection();SurvivalRunData.selected_arena_id=&"scrapyard";SurvivalRunData.daily_mode=false
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	Stats.enabled=true
	if options.get("mode","behavior")=="performance":
		await scenario("load5",4,20)
		await scenario("load8",19,20)
	elif options.get("mode","")=="flank":
		await scenario("flank_open",3,25,"flank_open")
	else:
		await scenario("supply_fixture",2,20,"supply")
		await scenario("flank_fixture",3,20,"armed")
		await scenario("flank_open",3,25,"flank_open")
		for wave in [2,3,4]: await scenario("native_wave"+str(wave),wave,30)
	FileAccess.open("res://perf-output/"+run_id+".json",FileAccess.WRITE).store_string(JSON.stringify({
		"id":run_id,"options":options,"display":DisplayServer.get_name(),"engine":Engine.get_version_info(),
		"vsync":DisplayServer.window_get_vsync_mode(),"reports":reports,"function_times_us":Stats.calls}))
	print("TACTICAL PROBE COMPLETE ",run_id)
	quit()
