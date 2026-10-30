extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("WAVE RECOVERY ","ok: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func run() -> void:
	PlayerProfile.path_override="res://wave_recovery_profile.cfg"
	LoadoutProfile.path_override="res://wave_recovery_loadout.cfg"
	var game:=load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game);game.set_physics_process(false)
	await process_frame
	var player:=game.player
	player.set_physics_process(false);player.freeze=true
	check(player.health==player.config.max_health,"wave1 full")
	for wave in [2,3,4,5,6]:
		player.health=17
		player.damage.engine=19;player.damage.wheels=23
		game._round_over=true;game._player_won=true;game._choosing_perk=true
		# No end-of-wave heal: only selected perk starts the next combat phase.
		check(player.health==17,"end of wave retains damage")
		var perk:Dictionary={"id":StringName("fixture_"+str(wave)),"name":"test","modifiers":{"max_health":28.0} if wave==3 else {}}
		game._on_perk_selected(perk)
		check(game._round==wave and player.health==player.config.max_health,"wave "+str(wave)+" full effective max")
		check(player.damage.engine==19 and player.damage.wheels==23,"no module repair")
		check(player.get_hud_state().body_health==1.0,"HUD health normalized")
		player.health-=11
		game.start_round(wave)
		check(player.health==player.config.max_health-11,"same wave cannot heal twice")
		game._on_perk_selected(perk)
		check(game._round==wave,"duplicate choice ignored")
		await process_frame
	player.health=player.config.max_health
	game.start_round(7)
	check(player.health==player.config.max_health,"healthy does not overflow")
	player.health=20
	var pickup:=load("res://scenes/BonusPickup.tscn").instantiate() as BonusPickup
	pickup.kind=BonusPickup.Kind.REPAIR;game.add_child(pickup)
	pickup._on_body_entered(player)
	check(player.health==player.config.max_health,"repair pickup still useful during wave")
	var generation:=game._round_generation
	player.take_damage(100000)
	var dead_health:=player.health
	game._choosing_perk=true
	game._select_perk_deferred({"id":&"armor","name":"test","modifiers":{"max_health":28.0}},generation)
	game.start_round(8)
	check(not player.alive and player.health==dead_health,"dead player not revived by transition")
	game._on_retry_requested()
	for frame in 4:await process_frame
	check(player.alive and player.health==player.config.max_health and game._round==1,"Retry full fresh session")
	player.health=37
	game._select_perk_deferred({"id":&"old","name":"stale"},generation)
	check(player.health==37 and game._round==1,"old generation cannot heal new session")
	# Career runs through the same coordinator but keeps its old partial repair.
	game.career_event={"target_rounds":99}
	player.damage.engine=20;player.damage.wheels=20
	game.start_round(2)
	check(is_equal_approx(player.health,37+(player.config.max_health-37)*0.3),"Career partial repair unchanged")
	game.free();await process_frame
	print("WAVE RECOVERY: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
