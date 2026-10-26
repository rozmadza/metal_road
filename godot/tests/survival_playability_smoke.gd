extends SceneTree
## Real physics/input events; scripted damage is used only to test lifecycle.
var failures := 0
var game: Survival
const SHOTGUN = preload("res://resources/weapons/shotgun.tres")
const ROCKET = preload("res://resources/weapons/rocket_launcher.tres")
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PLAYABILITY ","ok: " if ok else "FAIL: ",label)
	if not ok: failures += 1
func settle(frames: int = 3) -> void:
	for frame in frames: await physics_frame
	await process_frame
func freeze_ai() -> void:
	game.player.freeze = true
	for enemy in game._enemies:
		enemy.freeze = true
		enemy.get_node("ArenaBot").set_physics_process(false)
		enemy.gun.set_physics_process(false)
func kill_alive() -> void:
	for enemy in game._enemies.duplicate():
		if is_instance_valid(enemy) and enemy.alive: enemy.take_damage(100000,&"body",game.player)
func pickup(kind: BonusPickup.Kind, weapon: WeaponConfig = null) -> BonusPickup:
	var item := load("res://scenes/BonusPickup.tscn").instantiate() as BonusPickup
	item.setup(kind,weapon)
	item.position = game.player.position
	item.collected.connect(func(_p,v):game._on_bonus_collected(v,kind))
	game.add_child(item)
	return item
func key(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func pad(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	event.pressed = pressed
	event.device = 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	PlayerProfile.path_override = "res://playability_profile.cfg"
	LoadoutProfile.path_override = "res://playability_loadout.cfg"
	CareerSession.clear_selection()
	InputBindings.ensure_controller_defaults()
	print("PHYSICAL JOYPADS: ",Input.get_connected_joypads())
	for action in [&"fire",&"restart",&"ui_accept",&"ui_cancel",&"steer_left",&"steer_right"]:
		check(not InputMap.action_get_events(action).any(func(e):return e is InputEventJoypadButton and e.button_index==JOY_BUTTON_X),"X does not conflict with "+String(action))
	check(InputBindings.interaction_key_label(false)=="E","keyboard prompt")
	check(InputBindings.interaction_key_label(true,0,"Xbox Wireless Controller")=="X","Xbox prompt")
	check(InputBindings.interaction_key_label(true,0,"DualSense Wireless Controller")=="□","PlayStation prompt")
	game = load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	freeze_ai()
	game.bonus_spawner.set_process(false)
	game.bonus_spawner.set_physics_process(false)
	check(game._alive_enemies()==2 and game._pending_enemies.size()==1,"two initial + one pending")
	check(game._destroyed_enemies()==0,"pending enemy is not a kill")
	kill_alive()
	check(not game._round_over and game._destroyed_enemies()==2,"early kills cannot finish pending wave")
	await settle(285)
	check(game._alive_enemies()==0 and not game._round_over,"no reinforcement before ~5 seconds")
	await settle(25)
	freeze_ai()
	check(game._alive_enemies()==1 and game._pending_enemies.is_empty(),"third enemy after ~5 seconds")
	kill_alive()
	check(game._round_over and game._player_won and game._boss==null,"ordinary finale")
	var credits := game._credits_earned
	game._end_round(true)
	check(game._credits_earned==credits,"single reward")
	game._offer_upgrade()
	await settle()
	check(game._round==2 and game._run_perks.size()==1,"draft and wave2")
	var counts := [3,4,4,5,3]
	var elites := [0,0,1,1,1]
	for wave in range(1,6):
		check(SurvivalRunData.wave_plan(wave).enemies==counts[wave-1] and SurvivalRunData.wave_plan(wave).elites==elites[wave-1],"wave composition "+str(wave))
		game.start_round(wave)
		freeze_ai()
		check(game._enemies.size()+game._pending_enemies.size()==counts[wave-1] and game._enemies.filter(func(e):return bool(e.get_meta("elite",false))).size()==elites[wave-1],"runtime composition "+str(wave))
	for wave in range(1,31):
		check(bool(SurvivalRunData.wave_plan(wave).boss)==(wave%5==0),"boss schedule "+str(wave))
	game.start_round(1)
	var old_generation := game._round_generation
	game._update_reinforcements(5)
	game._on_retry_requested()
	await settle()
	freeze_ai()
	game._spawn_reinforcement_deferred(old_generation)
	check(game._alive_enemies()==2 and game._pending_enemies.size()==1,"stale queued reinforcement rejected by Restart")
	game.player.take_damage(100000)
	await settle()
	check(game.results.visible and game._pending_enemies.is_empty(),"defeat cancels pending reinforcement")
	game.results.get_node("%RetryButton").pressed.emit()
	await settle()
	check(game.player.alive and game._alive_enemies()==2 and game._pending_enemies.size()==1,"Retry restores staged first wave")
	game.start_round(2)
	game.player.reset_to(Vector2(700,860),0)
	await settle()
	freeze_ai()
	game.bonus_spawner.set_process(false)
	game.bonus_spawner.set_physics_process(false)
	pickup(BonusPickup.Kind.WEAPON,SHOTGUN)
	await settle()
	check(game.player.gun.config==SHOTGUN and game.player.has_temporary_weapon(),"unarmed player automatically collects weapon")
	var offer := pickup(BonusPickup.Kind.WEAPON,ROCKET)
	await settle()
	check(game.player.gun.config==SHOTGUN and is_instance_valid(offer) and not offer.collected_once,"contact preserves active weapon and offer")
	key(false)
	await settle()
	check(game.hud.interaction_prompt.visible and "E" in game.hud.interaction_prompt.text,"nearby keyboard interaction prompt")
	game.player.freeze = false
	game.player.linear_velocity = Vector2(80,0)
	key(true)
	await settle(2)
	check(game.player.gun.config==ROCKET and game.player.get_speed()>10,"keyboard swap while moving")
	var second := pickup(BonusPickup.Kind.WEAPON,SHOTGUN)
	await settle()
	key(true,true)
	await settle(8)
	check(game.player.gun.config==ROCKET and is_instance_valid(second),"holding/echo cannot repeat keyboard swap")
	key(false)
	await settle()
	pad(true)
	await settle(2)
	check(game.player.gun.config==SHOTGUN,"joypad X event swaps weapon")
	game.player.freeze = true
	var third := pickup(BonusPickup.Kind.WEAPON,ROCKET)
	await settle(8)
	check(game.player.gun.config==SHOTGUN and is_instance_valid(third),"held joypad cannot repeat swap")
	check(game.hud.interaction_prompt.visible and "X" in game.hud.interaction_prompt.text and not "E —" in game.hud.interaction_prompt.text,"joypad-aware HUD prompt")
	pad(false)
	await settle()
	third.queue_free()
	var config := game.player.config.duplicate() as VehicleConfig
	config.max_health += 28
	game.player.reconfigure(config)
	game.player.damage.body = 1
	game.player.damage.engine = 1
	game.player.damage.wheels = 1
	var repair := pickup(BonusPickup.Kind.REPAIR)
	check(repair.collect(game.player),"repair pickup")
	check(game.player.health==config.max_health and game.player.damage.engine==23 and game.player.damage.wheels==25,"full body HP with perk; old engine/wheels amounts")
	check(game.hud.modules.bars[0].value==100,"repair immediately updates body HUD")
	pickup(BonusPickup.Kind.REPAIR).collect(game.player)
	check(game.player.health==config.max_health,"repair cannot exceed max HP")
	pickup(BonusPickup.Kind.SPEED_BOOST)
	await settle()
	check(game.player.is_boost_active(),"speed bonus remains automatic")
	pickup(BonusPickup.Kind.RAM_BOOST)
	await settle()
	check(game.player.is_ram_boost_active(),"ram bonus remains automatic with existing boost exclusivity")
	var bot := game._enemies[0]
	bot.activate_temporary_weapon(SHOTGUN,25)
	var bot_offer := pickup(BonusPickup.Kind.WEAPON,ROCKET)
	check(bot_offer.collect(bot) and bot.gun.config==ROCKET,"AI retains automatic replacement")
	var race_car := load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
	root.add_child(race_car)
	race_car.set_meta("player_vehicle",true)
	race_car.activate_temporary_weapon(SHOTGUN,25)
	check(pickup(BonusPickup.Kind.WEAPON,ROCKET).collect(race_car),"Race player retains old auto swap")
	race_car.damage.body = 1
	pickup(BonusPickup.Kind.REPAIR).collect(race_car)
	check(race_car.health==29,"Race repair unchanged")
	race_car.free()
	for type in ["mine_layer","machine_gun","rocket_launcher","flamethrower","emp_cannon"]:
		var bullet := load("res://scenes/Bullet.tscn").instantiate() as Bullet
		game.bullets.add_child(bullet)
		bullet.setup(Vector2(700,860),Vector2.RIGHT,load("res://resources/weapons/"+type+".tres"),game.player)
		check(bullet.z_index==(-1 if type=="mine_layer" else 0),"projectile layer "+type)
		bullet.free()
	game.queue_free()
	await settle()
	print("SURVIVAL PLAYABILITY: ","PASS" if failures==0 else "FAIL", " failures=",failures)
	quit(0 if failures==0 else 1)
