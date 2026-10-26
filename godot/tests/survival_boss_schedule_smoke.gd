extends SceneTree
var failures:=0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		printerr("BOSS SCHEDULE FAIL: ",label)
func disable_ai(game: Survival) -> void:
	game.player.freeze=true
	for enemy in game._enemies:
		enemy.freeze=true
		enemy.gun.set_physics_process(false)
		enemy.get_node("ArenaBot").set_physics_process(false)
func kill_alive(game: Survival) -> void:
	for enemy in game._enemies.duplicate():
		if is_instance_valid(enemy) and enemy.alive:
			enemy.take_damage(100000,&"body",game.player)
func run() -> void:
	PlayerProfile.path_override="res://boss_schedule_profile.cfg"
	LoadoutProfile.path_override="res://boss_schedule_loadout.cfg"
	CareerSession.clear_selection()
	var game:=load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	await process_frame
	for wave in range(1,16):
		game.start_round(wave)
		disable_ai(game)
		if not game._pending_enemies.is_empty():
			game._update_reinforcements(5.0)
			await process_frame
			disable_ai(game)
		var expected: bool=SurvivalRunData.wave_plan(wave).boss
		check(expected==(wave in [5,10,15]),"schedule "+str(wave))
		var regular_count:=game._enemies.size()
		var support_count:=0
		kill_alive(game)
		await process_frame
		if expected:
			check(is_instance_valid(game._boss) and game._boss.alive and not game._round_over,"boss finale "+str(wave))
			disable_ai(game)
			game._process(0)
			check(game.hud.get_node("BossPanel").visible,"boss HUD")
			game._update_boss(0.01)
			check(game._boss_phase==1,"phase one preserved")
			var riders:=game._spawn_biker_squad()
			support_count=riders
			check(riders>0,"boss support preserved")
			disable_ai(game)
			game._boss.take_damage(100000,&"body",game.player)
			check(not game._round_over,"living riders keep finale active")
			kill_alive(game)
		else:
			check(not is_instance_valid(game._boss) and not game._referee_spawn_pending,"no boss "+str(wave))
			check(game._boss_ability_timer==0 and game._biker_deploy_timer==0,"no boss timers")
			game._spawn_referee()
			check(not is_instance_valid(game._boss),"direct spawner respects plan")
			check(not game.hud.get_node("BossPanel").visible,"ordinary HUD")
		check(game._round_over and game._player_won,"wave completes "+str(wave))
		var credits:=game._credits_earned
		game._end_round(true)
		game._process(0)
		check(game._credits_earned==credits,"single reward "+str(wave))
		check("ОСТАЛОСЬ 0" in game.hud.get_node("Top/Panel/Status").text,"HUD zero enemies")
		check(game._destroyed_enemies()==regular_count+(1 if expected else 0)+support_count,"HUD total")
		if wave==1:
			game._offer_upgrade()
			await process_frame
			check(game._round==2 and game._run_perks.size()==1,"draft advances to wave2")
		print("SCHEDULE checked wave ",wave," boss=",expected)
	for wave in [1,5]:
		game.start_round(wave)
		disable_ai(game)
		# A deferred boss from this generation must not survive Retry.
		game._request_referee_spawn()
		game.player.take_damage(100000)
		check(game.results.visible,"defeat results "+str(wave))
		game.results.get_node("%RetryButton").pressed.emit()
		await process_frame
		check(game._round==1 and not game._session_finished and game._boss==null,"Retry "+str(wave))
		game.start_round(wave)
		game._on_retry_requested()
		await process_frame
		check(game._round==1 and game._boss==null,"Restart "+str(wave))
	# Existing Career contracts retain their target-round victory semantics.
	for id in [&"scrapyard_contract",&"oil_cauldron"]:
		CareerSession.select_event(id)
		var contract:=CareerSession.active_event()
		game.career_event=contract
		game.start_round(int(contract.target_rounds))
		disable_ai(game)
		kill_alive(game)
		await process_frame
		check(game.results.visible and game._session_finished and game._player_won,"Career contract "+String(id))
	game.career_event={"requires_arbiter":true,"target_rounds":99,"type":&"arena"}
	game.start_round(1)
	disable_ai(game)
	game._update_reinforcements(5.0)
	await process_frame
	disable_ai(game)
	kill_alive(game)
	await process_frame
	check(is_instance_valid(game._boss) and not game._round_over,"explicit Career Arbiter requirement")
	CareerSession.clear_selection()
	game.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("SURVIVAL BOSS SCHEDULE: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
