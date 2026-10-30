extends SceneTree
const Wreck=preload("res://scripts/destroyed_vehicle_wreck.gd")
const Manager=preload("res://scripts/destroyed_vehicle_wrecks.gd")
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("WRECK LIFE ","ok: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func settle() -> void:
	for i in 4:await process_frame;await physics_frame
func kill(game:Survival) -> Dictionary:
	var enemy:Vehicle=game._enemies.filter(func(e):return is_instance_valid(e) and e.alive)[0]
	enemy.reset_to(Vector2(700,850),0)
	await settle()
	var data:={"position":enemy.position,"angle":enemy.rotation,"config":enemy.config}
	enemy.take_weapon_damage(100000,&"body",game.player,&"machine_gun")
	var score:=game._score
	enemy.died.emit(enemy)
	check(game._score==score,"duplicate death cannot score twice")
	await settle()
	return data
func run() -> void:
	PlayerProfile.path_override="res://wreck-life-profile.cfg";LoadoutProfile.path_override="res://wreck-life-loadout.cfg"
	var game:=load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game);game.set_physics_process(false)
	await settle()
	var data:Dictionary=await kill(game)
	check(game.destroyed_wrecks.get_child_count()==1,"one wreck per ordinary death")
	var wreck=game.destroyed_wrecks.get_child(0)
	check(wreck.position.distance_to(data.position)<1 and absf(angle_difference(wreck.rotation,data.angle))<0.01,"death pose preserved")
	check(wreck.config==data.config and wreck.hull.points.size()>=8,"actual class configuration/hull")
	check(wreck.collision_layer==5 and wreck.collision_mask==1,"real layer5 mask1")
	check(not wreck.is_in_group("combatants") and not wreck.has_method("take_damage"),"indestructible noncombatant")
	game.start_round(2);await settle()
	check(is_instance_valid(wreck) and wreck.get_parent()==game.destroyed_wrecks,"wave retains same wreck")
	check(game.player.health==game.player.config.max_health,"full wave recovery preserved")
	wreck.lifetime=0.05
	await create_timer(3.0).timeout
	check(not is_instance_valid(wreck),"TTL fade frees visual and body")
	for i in 7:
		var source:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
		game.add_child(source);source.position=Vector2(300+i*110,860)
		source._die();game.destroyed_wrecks.queue_vehicle(source)
		await settle()
	check(game.destroyed_wrecks.get_child_count()==5,"capacity remains5")
	check(game.destroyed_wrecks.get_child(0).position.x>=500,"oldest idle wreck evicted deterministically")
	check(Manager.LIFETIME==25 and Manager.MAX_ACTIVE==5,"central defaults25s/5")
	game.start_round(5);await settle()
	game._spawn_referee()
	var boss:Vehicle=game._boss
	var boss_config:=boss.config
	boss.take_damage(1000000,&"body",game.player)
	await settle()
	check(game.destroyed_wrecks.get_children().any(func(w):return w.config==boss_config and w.hull.points.size()>=8),"Arbiter actual chassis becomes cover")
	var biker:Vehicle=game._spawn_biker(Vector2(400,850),0,0)
	var biker_config:=biker.config
	biker.take_damage(100000,&"body",game.player)
	await settle()
	check(game.destroyed_wrecks.get_children().any(func(w):return w.config==biker_config and w.hull.points.size()>=8),"biker uses own small hull")
	var elite:Vehicle=game._enemies.filter(func(e):return is_instance_valid(e) and e.alive and bool(e.get_meta("elite",false)))[0]
	var elite_config:=elite.config
	elite.take_damage(1000000,&"body",game.player)
	await settle()
	check(game.destroyed_wrecks.get_children().any(func(w):return w.config==elite_config),"elite keeps own art/config")
	var queued:Vehicle=game._enemies[0]
	queued.take_damage(100000,&"body",game.player)
	game._on_retry_requested();await settle()
	check(game.destroyed_wrecks.get_child_count()==0,"same-frame death/Restart no stale wreck")
	var old_manager:WeakRef=weakref(game.destroyed_wrecks)
	await kill(game)
	game._on_retry_requested();await settle()
	check(old_manager.get_ref()==null and game.destroyed_wrecks.get_child_count()==0,"Restart frees previous session container")
	var enemy:Vehicle=game._enemies[0]
	enemy.take_damage(100000,&"body",game.player)
	game.player.take_damage(100000,&"body",enemy)
	await settle()
	check(game._session_finished and game.destroyed_wrecks.get_child_count()==0,"defeat cancels queued creation")
	game._on_retry_requested();await settle()
	# Large/deep contact during the handoff uses the old hull, bounded solver.
	enemy=game._enemies[0]
	enemy.reset_to(Vector2(700,850),0);game.player.reset_to(Vector2(700,850),0)
	await physics_frame
	enemy.take_damage(100000,&"body",game.player)
	await settle()
	for frame in 90:await physics_frame
	wreck=game.destroyed_wrecks.get_child(0)
	check(wreck.linear_velocity.is_finite() and wreck.linear_velocity.length()<=121 and game.player.linear_velocity.length()<=game.player.config.max_speed+1,"overlapped death bounded and finite")
	game.free();await settle()
	check(get_nodes_in_group("vehicle_wrecks").is_empty(),"menu/scene disposal removes bodies")
	print("WRECK LIFECYCLE: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
