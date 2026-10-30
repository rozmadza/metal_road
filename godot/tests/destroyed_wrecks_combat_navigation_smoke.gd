extends SceneTree
const Wreck=preload("res://scripts/destroyed_vehicle_wreck.gd")
var failures:=0
var metrics:Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("WRECK NAV ","ok: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func make_wreck(arena:Arena,point:Vector2,id:StringName=&"raider") -> RigidBody2D:
	var source:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
	source.config=LoadoutProfile.vehicle_config(id).duplicate();root.add_child(source)
	source.position=point
	var data:=Wreck.snapshot(source);source.free()
	var wreck:=Wreck.new();wreck.setup(data);arena.add_child(wreck)
	return wreck
func run() -> void:
	var arena:=load("res://scenes/Arena.tscn").instantiate() as Arena;root.add_child(arena)
	var vfx:=CombatVFX.new();root.add_child(vfx)
	var wreck:=make_wreck(arena,Vector2(700,850))
	wreck.freeze=true
	await physics_frame
	var nav=arena.navigation()
	var grid=nav._grid(48)
	check(not nav.point_clear(wreck.position,2),"new wreck blocks fresh navigation")
	var start:=Vector2(480,850);var goal:=Vector2(1000,850)
	var route=nav.route_result(start,goal,48)
	check(route.status==&"EXACT" and route.path.size()>1,"route detours single wreck")
	var traffic:Array[Rect2]=[]
	var snapshot=nav.with_traffic(traffic)
	wreck.position=Vector2(700,700)
	await physics_frame
	check(nav.point_clear(Vector2(700,850),2) and snapshot.point_clear(Vector2(700,850),2),"old position free including traffic snapshot")
	check(not nav.point_clear(wreck.position,2),"new position blocked immediately")
	check(nav._grid(48)==grid,"dynamic movement retains cached grid object")
	for id in ["machine_gun","heavy_machine_gun","shotgun","rocket_launcher","flamethrower","emp_cannon"]:
		var path:String="res://resources/weapons/"+id+".tres"
		if not ResourceLoader.exists(path):continue
		vfx.events.clear()
		var cfg:=load(path) as WeaponConfig
		var bullet:=Bullet.new();arena.add_child(bullet)
		bullet.setup(wreck.position-Vector2(90,0),Vector2.RIGHT,cfg,null)
		bullet.set_physics_process(false)
		for frame in 50:
			if bullet.is_queued_for_deletion() or bullet.detonated:break
			bullet._physics_process(1.0/60)
		check(bullet.is_queued_for_deletion() or bullet.detonated,"cover blocks "+id)
		check(vfx.events.size()==1,"one contact VFX "+id)
		if not vfx.events.is_empty():check(absf(vfx.events[0].position.x-(wreck.position.x-wreck.config.length*Vehicle.COLLISION_SCALE.x/2))<8,"surface contact position "+id)
		bullet.free()
	for count in [1,3,5]:
		while arena.get_children().filter(func(n):return n.is_in_group("vehicle_wrecks")).size()<count:
			make_wreck(arena,Vector2(500+count*90,500))
		var elapsed:Array[float]=[]
		for i in 30:
			await physics_frame
			wreck.position.x+=0.1
			var t:=Time.get_ticks_usec()
			nav._grid(48);nav.point_clear(start,48)
			elapsed.append((Time.get_ticks_usec()-t)/1000.0)
		elapsed.sort();var total:=0.0
		for value in elapsed:total+=value
		metrics.append({"wrecks":count,"mean_ms":total/30,"p95_ms":elapsed[28],"max_ms":elapsed.back(),"same_grid":nav._grid(48)==grid})
	wreck.free();await physics_frame
	check(nav.point_clear(Vector2(703,700),2),"deletion clears dynamic obstacle")
	var spawner:=BonusSpawner.new();arena.add_child(spawner);spawner.setup_for_arena(arena)
	for i in 5:
		var result:Dictionary=spawner._next_position()
		check(bool(result.get("success",false)),"supply remains placeable")
		if result.get("success",false):
			check(nav.point_clear(result.position,32),"supply avoids physical wrecks")
	for i in 70:vfx.spawn_impact(Vector2.ZERO)
	check(vfx.events.size()==48,"budget48 remains")
	# A dead shooter's Vehicle is now freed after handoff. Its in-flight
	# projectiles must still hit crates and splash without stale Node arguments.
	var shooter:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle;root.add_child(shooter)
	var crate:=MapProp.new();crate.kind=&"crate";crate.position=Vector2(1100,850);arena.add_child(crate)
	var bullet:=Bullet.new();arena.add_child(bullet)
	bullet.setup(crate.position,Vector2.RIGHT,load("res://resources/weapons/machine_gun.tres"),shooter)
	bullet.set_physics_process(false);shooter.free()
	check(not bullet._same_squad(null) and bullet._check_destructible_hit(),"orphaned shooter direct hit safe")
	bullet.free()
	var mine:=Bullet.new();arena.add_child(mine)
	mine.setup(Vector2(800,500),Vector2.RIGHT,load("res://resources/weapons/mine_layer.tres"),null)
	mine.set_physics_process(false);mine.age=mine.effect_duration+0.1
	check(not mine._mine_has_target(),"wrecks alone do not trigger mine")
	mine.free()
	arena.free();vfx.free();await process_frame
	FileAccess.open("res://wreck-nav-metrics.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t"))
	print("WRECK COMBAT/NAV: ","PASS" if failures==0 else "FAIL"," ",JSON.stringify(metrics))
	quit(0 if failures==0 else 1)
