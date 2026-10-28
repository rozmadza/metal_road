extends SceneTree
const Tactics = preload("res://scripts/survival_wave_tactics.gd")
var failures := 0
var game: Survival

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		printerr("TACTICAL WAVES FAIL: ",label)

func pickup(point: Vector2) -> BonusPickup:
	var item:=load("res://scenes/BonusPickup.tscn").instantiate() as BonusPickup
	item.setup(BonusPickup.Kind.WEAPON,load("res://resources/weapons/shotgun.tres"))
	item.position=point
	game.add_child(item)
	return item

func run() -> void:
	PlayerProfile.path_override="user://tactics-smoke-profile.cfg"
	LoadoutProfile.path_override="user://tactics-smoke-loadout.cfg"
	CareerSession.clear_selection()
	SurvivalRunData.daily_mode=false
	SurvivalRunData.selected_arena_id=&"scrapyard"
	game=load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	check(game._enemies.size()==2 and game._pending_enemies.size()==1,"wave1 staged 2+1 unchanged")
	for wave in range(1,16):
		game.start_round(wave)
		var cycle:=posmod(wave-1,5)+1
		check(bool(game._wave_plan.boss)==(cycle==5),"boss schedule "+str(wave))
		if wave<=5: check(game._wave_plan.enemies==[3,4,4,5,3][wave-1],"wave count "+str(wave))
		var elite_count:=0
		for i in game._enemies.size():
			var car: Vehicle=game._enemies[i]
			var d:=car.get_node("ArenaBot") as ArenaBot
			d.set_physics_process(false)
			if car.get_meta("elite",false):
				elite_count+=1
				check(d.team_role==i%3+1,"elite config and role match "+str(wave))
			if cycle in [1,5]:
				check(d.strategy==i%ArenaBot.Strategy.size() and not d.exclusive_supply_targets,"unchanged cycle "+str(wave))
			else:
				var profile:=Tactics.profile(game._wave_plan.id,i)
				check(d.strategy==profile.strategy and d.team_role==profile.team_role,"runtime profile "+str(wave))
		check(elite_count==int(game._wave_plan.elites) if wave!=1 else elite_count==0,"real elite count "+str(wave))
		game.bonus_spawner.set_physics_process(false)
		game.bonus_spawner.reset()
		await process_frame
	# Keep actual physics/footprints for route rejection; only decisions are stepped.
	game.start_round(2)
	game.set_process(false);game.set_physics_process(false)
	game.bonus_spawner.set_physics_process(false)
	game.bonus_spawner.reset()
	for i in game._enemies.size():
		var car: Vehicle=game._enemies[i]
		car.get_node("ArenaBot").set_physics_process(false)
		car.reset_to(Vector2(260+i*80,860),0)
	game.player.reset_to(Vector2(1200,860),PI)
	for _step in 3: await physics_frame
	await process_frame
	var first:=pickup(Vector2(760,860))
	var second:=pickup(Vector2(1040,860))
	var a:=game._enemies[0].get_node("ArenaBot") as ArenaBot
	var b:=game._enemies[2].get_node("ArenaBot") as ArenaBot
	var attacker:=game._enemies[1].get_node("ArenaBot") as ArenaBot
	for d in [a,b,attacker]:
		d._intent=&"pursue";d._intent_age=3.0;d._locked_pickup=null
	print("SUPPLY SETUP ",a.vehicle.position," ",b.vehicle.position," radius=",a.supply_search_radius," strategy=",a.strategy," armed=",a.vehicle.has_temporary_weapon()," pickups=",get_nodes_in_group("bonus_pickups").size()," distances=",a.vehicle.position.distance_to(first.position),"/",b.vehicle.position.distance_to(second.position))
	a._update_intent(0)
	b._update_intent(0)
	attacker._update_intent(0)
	print("SUPPLY CHOICES ",a._intent,"/",a._locked_pickup," ",b._intent,"/",b._locked_pickup)
	check(a._intent==&"supply" and b._intent==&"supply" and a._locked_pickup!=b._locked_pickup,"two collectors choose distinct supplies")
	check(attacker._intent in [&"attack",&"pursue"],"combat slot continues toward player")
	var claimed:=a._locked_pickup
	if claimed==null:
		game.free();quit(1);return
	check(b._pickup_claimed(claimed),"live local claim observed")
	a.vehicle.alive=false
	check(not b._pickup_claimed(claimed),"death releases claim")
	a.vehicle.alive=true
	a._intent=&"yield"
	check(not b._pickup_claimed(claimed),"yield releases claim")
	a._intent=&"supply"
	a._pickup_progress=a.vehicle.position.distance_to(claimed.position)
	a._pickup_stall=3.0
	a._watch_pickup_progress(0.1)
	check(a._locked_pickup==null and a._intent==&"pursue","stalled supply abandons pursuit")
	check(float(a._pickup_ignore_until.get(claimed.get_instance_id(),0))>a._drive_time,"stalled target has cooldown")
	first.free();second.free()
	a._locked_pickup=null;b._locked_pickup=null
	var blocked:=pickup(game.arena.config.obstacles[0].get_center())
	a.supply_search_radius=680
	a._locked_pickup=blocked
	a._set_intent(&"supply",blocked.position)
	a._path_clock=0
	a._path.clear()
	a._update_path(0)
	check(a._route_status!=&"EXACT" and a._locked_pickup==null,"blocked supply releases target on nonexact route")
	a._update_intent(0)
	check(a._intent!=&"supply","ignored inaccessible supply is not immediately reacquired")
	blocked.free()
	game.start_round(3)
	game.bonus_spawner.set_physics_process(false);game.bonus_spawner.reset()
	await physics_frame;await process_frame
	for car in game._enemies:
		car.get_node("ArenaBot").set_physics_process(false)
		car.activate_temporary_weapon(load("res://resources/weapons/machine_gun.tres"),999)
	a=game._enemies[0].get_node("ArenaBot") as ArenaBot
	b=game._enemies[1].get_node("ArenaBot") as ArenaBot
	a.vehicle.position=Vector2(100,500);b.vehicle.position=Vector2(100,500)
	game.player.position=Vector2(800,500);game.player.rotation=0
	game.player.linear_velocity=Vector2.ZERO
	a._intent=&"pursue";b._intent=&"pursue";b._passing_side=-1.0
	b._spawn_position=b.vehicle.position
	a._update_intent(0);b._update_intent(0)
	print("FLANK GOALS ",a._intent_goal,"/",b._intent_goal," role=",b.team_role," width=",b.flank_width)
	check(absf(a._intent_goal.y-game.player.position.y)<1 and absf(b._intent_goal.y-game.player.position.y)>150,"Flanker target differs from direct pursuit")
	check(b._intent_goal.x<game.player.position.x-150,"Flanker enters side lane before opponent")
	check(b.flank_width==180 and game._wave_plan.elites==1,"first elite wave still has just Vanguard elite")
	# Career arena must retain the preexisting rival strategy mapping/defaults.
	game.career_event={"type":&"arena"}
	game.start_round(2)
	for car in game._enemies:
		var d:=car.get_node("ArenaBot") as ArenaBot
		check(not d.exclusive_supply_targets and d.supply_search_radius==680 and d.flank_width==135 and d.flank_approach_offset==0,"Career arena defaults unchanged")
		check(d.strategy==game._arena_strategy_for(car.get_meta("rival_id")),"Career rival strategy unchanged")
	game.free()
	await process_frame
	print("TACTICAL WAVES: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
