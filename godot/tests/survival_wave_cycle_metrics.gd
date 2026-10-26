extends SceneTree
## Controlled comparison: 8s regular combat, 12s boss phase, scripted clears.
class CountingVFX extends CombatVFX:
	var created:=0
	func spawn_impact(p: Vector2,c: Color=Color(1.0,0.78,0.25),large_hit: bool=false) -> void:
		created+=1
		super.spawn_impact(p,c,large_hit)
	func spawn_explosion(p: Vector2,c: Color=Color(1.0,0.4,0.08),r: float=80) -> void:
		created+=1
		super.spawn_explosion(p,c,r)
	func spawn_pickup(p: Vector2,c: Color=Color(0.25,0.92,1)) -> void:
		created+=1
		super.spawn_pickup(p,c)
var collected:=0
var scripted_pickups:=0
var scripted_kills:=0
var combat_deaths:=0
var clear_deaths:=0
var clearing:=false
var tracked: Dictionary={}
var peak_vfx:=0
var errors:=0
func _initialize() -> void:
	run.call_deferred()
func sample(game: Survival,frames: int) -> void:
	for frame in frames:
		track(game)
		await physics_frame
		peak_vfx=maxi(peak_vfx,game.get_node("CombatVFX").events.size())
		if frame%240==239 and not game.bonus_spawner._active_pickups.is_empty():
			var pickup:=game.bonus_spawner._active_pickups[0]
			if is_instance_valid(pickup) and pickup.collect(game.player): scripted_pickups+=1
func track(game: Survival) -> void:
	for enemy in game._enemies:
		if not is_instance_valid(enemy) or tracked.has(enemy.get_instance_id()): continue
		tracked[enemy.get_instance_id()]=true
		enemy.died.connect(func(_vehicle):
			if clearing: clear_deaths+=1
			else: combat_deaths+=1)
func clear(game: Survival) -> void:
	track(game)
	clearing=true
	for enemy in game._enemies.duplicate():
		if is_instance_valid(enemy) and enemy.alive:
			scripted_kills+=1
			enemy.take_damage(100000,&"body",game.player)
	clearing=false
func run() -> void:
	seed(4217)
	var legacy: bool="--legacy" in OS.get_cmdline_user_args()
	PlayerProfile.path_override="res://wave_metrics_profile_"+("old" if legacy else "new")+".cfg"
	LoadoutProfile.path_override="res://wave_metrics_loadout_"+("old" if legacy else "new")+".cfg"
	CareerSession.clear_selection()
	var game:=load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	game.referee_every_wave=legacy
	var config: VehicleConfig=game.get_node("Player").config.duplicate()
	config.max_health=50000
	config.engine_health=50000
	config.wheels_health=50000
	game.get_node("Player").config=config
	game.get_node("CombatVFX").free()
	var fx:=CountingVFX.new()
	fx.name="CombatVFX"
	game.add_child(fx)
	root.add_child(game)
	game.bonus_spawner._rng.seed=4217
	game.bonus_spawner.bonus_collected.connect(func(_v,_k): collected+=1)
	var rows: Array=[]
	var total_bosses:=0
	for wave in range(1,11):
		if game._round!=wave:
			errors+=1
			break
		game.player.freeze=true
		var before_time:=game._elapsed
		var before_score:=game._score
		var before_credits:=game._credits_earned
		var before_vfx:=fx.created
		var before_pickups:=collected
		var before_scripted:=scripted_kills
		var before_combat:=combat_deaths
		var before_clear:=clear_deaths
		peak_vfx=0
		await sample(game,480)
		clear(game)
		await process_frame
		if game._wave_plan.boss:
			if not is_instance_valid(game._boss):
				errors+=1
				break
			total_bosses+=1
			await sample(game,720)
			clear(game)
			await process_frame
		if not game._round_over or not game._player_won:
			errors+=1
			break
		rows.append({"wave":wave,"seconds":game._elapsed-before_time,"destroyed":game._destroyed_enemies(),
			"boss":bool(game._wave_plan.boss),"score":game._score-before_score,
			"credits":game._credits_earned-before_credits,"perks_before_draft":game._run_perks.size(),
			"collected":collected-before_pickups,"AI_created":game._round_enemy_total,
			"VFX_created":fx.created-before_vfx,"VFX_peak":peak_vfx,
			"scripted_kills":scripted_kills-before_scripted,
			"combat_deaths":combat_deaths-before_combat,"clear_deaths_including_chains":clear_deaths-before_clear})
		for frame in 180:
			await process_frame
			if game._round==wave+1: break
		if game._round!=wave+1: errors+=1
	var report:={"legacy":legacy,"rows":rows,"bosses":total_bosses,"perks":game._run_perks.size(),
		"score":game._score,"credits":game._credits_earned,"collected":collected,"scripted_pickups":scripted_pickups,
		"VFX_created":fx.created,"scripted_kills":scripted_kills,
		"combat_deaths":combat_deaths,"clear_deaths_including_chains":clear_deaths,"errors":errors}
	FileAccess.open("res://wave-metrics-"+("old" if legacy else "new")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WAVE CYCLE ", "OLD" if legacy else "NEW"," bosses=",total_bosses," perks=",game._run_perks.size()," errors=",errors)
	game.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	quit(0 if errors==0 and rows.size()==10 else 1)
