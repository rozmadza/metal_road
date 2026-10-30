extends SceneTree
## Covers the Survival roguelite loop: arenas, wave scenarios, draft choices,
## elite squads, boss setup and between-wave repairs.

var _failures := 0
var _game: Survival


func _initialize() -> void:
	_check_content_catalog()
	_game = load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(_game)
	_run_checks.call_deferred()


func _run_checks() -> void:
	_check_upgrade_layout()
	_check_wave_one_and_repair()
	_check_elite_wave()
	_check_boss_wave()
	_report.call_deferred()


func _check_upgrade_layout() -> void:
	var choices: Array[Dictionary] = []
	for index in 3: choices.append(SurvivalRunData.PERKS[index])
	_game.upgrade_draft.show_choices(choices, 1, 30)
	var panel := _game.upgrade_draft.get_node("Center/Panel") as Control
	var panel_rect := panel.get_global_rect()
	var viewport_size := _game.get_viewport().get_visible_rect().size
	_check(_game.upgrade_draft.get_parent() is CanvasLayer, "upgrade draft is attached to a screen-space layer")
	_check(panel_rect.position.x >= 0.0 and panel_rect.position.y >= 0.0, "upgrade panel starts inside the viewport")
	_check(panel_rect.end.x <= viewport_size.x and panel_rect.end.y <= viewport_size.y, "upgrade panel fits inside 1280x720")
	for index in 3:
		var button := _game.upgrade_draft.get_node("Center/Panel/Layout/Choices/Choice%d" % (index + 1)) as Button
		_check(button.get_global_rect().size.x >= 300.0, "upgrade card %d remains readable" % (index + 1))
	_game.upgrade_draft.hide()


func _check_content_catalog() -> void:
	_check(SurvivalRunData.ARENAS.size() >= 5, "five survival arenas are selectable")
	var mechanic_ids: Array[StringName] = []
	for entry in SurvivalRunData.ARENAS:
		var config := load(String(entry.path)) as ArenaConfig
		_check(config != null, "arena resource loads: %s" % entry.name)
		if config != null and config.mechanic_id != &"": mechanic_ids.append(config.mechanic_id)
	_check(&"press" in mechanic_ids and &"flood" in mechanic_ids and &"rockfall" in mechanic_ids, "unique arena mechanics are configured")
	_check(SurvivalRunData.PERKS.size() >= 12, "run build has at least twelve perks")
	var old_daily := SurvivalRunData.daily_mode
	SurvivalRunData.daily_mode = true
	var first := SurvivalRunData.perk_choices(2, [])
	var second := SurvivalRunData.perk_choices(2, [])
	_check(first.size() == 3, "draft offers three upgrades")
	_check(first.map(func(perk): return perk.id) == second.map(func(perk): return perk.id), "daily draft is deterministic")
	SurvivalRunData.daily_mode = old_daily
	_check(bool(SurvivalRunData.wave_plan(5).boss), "every fifth wave is a boss wave")
	_check(SurvivalRunData.wave_plan(3).id == &"elite_team", "third wave is an elite-team scenario")


func _check_wave_one_and_repair() -> void:
	_check(_game._alive_enemies() == 2 and _game._pending_enemies.size() == 1, "first wave starts with two enemies and a reinforcement")
	for enemy in _game._enemies:
		var hunter := enemy.get_node("ArenaBot") as ArenaBot
		_check(hunter.focus_player, "ordinary opponent prioritizes the player")
		_check(StringName(enemy.get_meta("squad_id", &"")) == &"", "ordinary opponents are not friendly squadmates")
	var original_health := _game.player.health
	_game.player.take_damage(40.0)
	var damaged_health := _game.player.health
	_game.start_round(2)
	var repaired_health := _game.player.health
	_check(repaired_health > damaged_health and is_equal_approx(repaired_health, original_health), "between-wave body HP is fully restored")


func _check_elite_wave() -> void:
	_game.start_round(3)
	var elites := 0
	var roles: Array[int] = []
	for enemy in _game._enemies:
		if bool(enemy.get_meta("elite", false)):
			elites += 1
			var bot := enemy.get_node("ArenaBot") as ArenaBot
			roles.append(bot.team_role)
			_check(bot.focus_player, "elite focuses the player")
			_check(StringName(enemy.get_meta("squad_id", &"")) == &"cerberus", "elite belongs to the Cerberus squad")
			_check(String(enemy.config.vehicle_id).begins_with("elite_cerberus_"), "elite uses an exclusive chassis")
			_check(enemy.config.vehicle_id not in LoadoutProfile.vehicle_ids(), "elite chassis is absent from the store catalog")
	_check(elites == 1, "first elite-team wave starts with one elite")
	_check(ArenaBot.TeamRole.VANGUARD in roles, "first elite has the Vanguard role")
	_game.start_round(8)
	var later_roles: Array[int] = []
	for enemy in _game._enemies:
		if bool(enemy.get_meta("elite", false)): later_roles.append(enemy.get_node("ArenaBot").team_role)
	_check(ArenaBot.TeamRole.VANGUARD in later_roles and ArenaBot.TeamRole.FLANKER in later_roles, "later elite squad retains distinct roles")


func _check_boss_wave() -> void:
	_game.referee_every_wave = true
	_game.start_round(1)
	_check(_game._boss == null, "Arbiter is absent while regular opponents remain")
	_game._spawn_referee()
	var first_wave_speed := _game._boss.config.max_speed
	_game.referee_every_wave = false
	_game.start_round(5)
	_check(_game._boss == null, "fifth wave begins with the elite squad, not the boss")
	_game._spawn_referee()
	_check(is_instance_valid(_game._boss), "boss vehicle spawns in the fifth-wave finale")
	if is_instance_valid(_game._boss):
		_check(is_equal_approx(first_wave_speed, 48.0), "first-wave Arbiter uses the slow teaching speed")
		_check(is_equal_approx(_game._boss.config.max_speed, 92.0), "Arbiter reaches its target speed on wave five")
		_check(bool(_game._boss.get_meta("boss", false)), "boss is tagged for UI and rewards")
		_check(_game._boss.health > _game.player.config.max_health * 2.0, "boss has a large health pool")
		_check(_game._boss.has_temporary_weapon(), "boss enters with a special weapon")
		_check(_game._boss.config.vehicle_id == &"boss_referee_arbiter", "wave five uses the exclusive Arbiter chassis")
		_check(_game._boss.get_node_or_null("RefereeBoss") is RefereeBoss, "Arbiter owns a rotating saw controller")
		var driver := _game._boss.get_node("ArenaBot") as ArenaBot
		_check(driver.focus_player and driver.external_weapon_control, "Arbiter hunts the player while boss module controls fire")
		var boss_rect: Rect2 = (_game.hud.get_node("BossPanel") as Control).get_global_rect()
		_check(boss_rect.size.x <= 260.0 and boss_rect.size.y <= 56.0 and boss_rect.position.x <= 20.0, "boss health uses a compact top-left panel")
		var escort: Vehicle
		for enemy in _game._enemies:
			if enemy != _game._boss:
				escort = enemy
				break
		if escort != null:
			var referee := _game._boss.get_node("RefereeBoss") as RefereeBoss
			referee.set_physics_process(false)
			driver.set_physics_process(false)
			escort.set_physics_process(false)
			var before := escort.health
			escort.global_position = _game._boss.to_global(referee._saw_position())
			referee._damage_saw_contacts()
			_check(escort.health < before, "Arbiter saw damages bots caught in its path")
			_game._boss.rotation = 0.0
			_game.player.global_position = _game._boss.global_position + Vector2(140.0, 0.0)
			referee.flame_state = RefereeBoss.FlameState.COOLDOWN
			referee.flame_timer = 0.0
			referee._update_flamethrower(0.0)
			_check(referee.flame_state == RefereeBoss.FlameState.WARNING, "Arbiter telegraphs a medium-range flame burst")
			referee.flame_timer = 0.0
			referee._update_flamethrower(0.0)
			referee._update_flamethrower(0.0)
			_check(_game._boss.gun._firing, "Arbiter fires only after its warning window")


func _report() -> void:
	print("SURVIVAL ROGUELITE: %s" % ("PASS" if _failures == 0 else "FAIL"))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("SURVIVAL ROGUELITE ok: ", label)
	else:
		_failures += 1
		print("SURVIVAL ROGUELITE FAIL: ", label)
