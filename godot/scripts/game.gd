extends Node2D
class_name Game
## Main coordinator for the Godot port.
##
## Mirrors the Phase 4 Python `Game`: it wires up the track, vehicle, camera
## and HUD, feeds player commands into the vehicle and handles restart.
## Physics runs on Godot's fixed 60 Hz tick (see Project Settings -> Physics).

@onready var track: Track = $Track
@onready var vehicle: Vehicle = $Vehicle
@onready var camera: FollowCamera = $Camera
@onready var audio: AudioManager = $AudioManager
@onready var hud: DebugHUD = $HUD
@onready var bullets: Node2D = $Bullets

## Toggle the AI opponents. Tests disable them to keep physics deterministic.
@export var spawn_bots: bool = true

var _input_handler := InputHandler.new()
var _debug_enabled := false
var _bots: Array = []
var participants: Array[Vehicle] = []
var race_status: Dictionary = {}
var kills: Dictionary = {}
var weapon_kills: Dictionary = {}
var damage_dealt: Dictionary = {}
var progress := RaceProgress.new()
var elapsed := 0.0
var race_over := false
var finish_order: Array[Vehicle] = []
var result: Dictionary = {}
@onready var results: Control = $Results/RaceResults
var bonus_spawner: BonusSpawner
var _countdown_remaining := 0.0
var _countdown_step := 0
var _last_lap_announced := false
var career_event: Dictionary = {}
var event_type: StringName = &"classic"
var bonus_scores: Dictionary = {}
var repair_scores: Dictionary = {}
var _elimination_checkpoint := 0
var boss_vehicle: Vehicle
var _boss_phase := 1
var _boss_base_speed := 0.0
var _boss_base_acceleration := 0.0
var _story_rival: Vehicle
var _story_ahead := false
var _story_initialized := false
var _story_radio_cooldown := 0.0


func _enter_tree() -> void:
	career_event = CareerSession.active_event()
	if career_event.is_empty():
		return
	event_type = career_event.type
	var event_track := load(career_event.track) as TrackConfig
	var track_node := get_node_or_null("Track") as Track
	if event_track != null and track_node != null:
		track_node.config = event_track.duplicate() as TrackConfig
		track_node.config.laps = int(career_event.laps)


func _ready() -> void:
	vehicle.set_meta("player_vehicle", true)
	if DisplayServer.get_name() != "headless":
		_apply_loadout()
	bonus_spawner = BonusSpawner.new()
	bonus_spawner.name = "BonusSpawner"
	bonus_spawner.spawn_interval = 2.5
	bonus_spawner.first_spawn_delay = 2.0
	bonus_spawner.warning_duration = 0.7
	bonus_spawner.active_lifetime = 22.0
	bonus_spawner.max_active = 3
	add_child(bonus_spawner)
	bonus_spawner.setup_for_track(track)
	bonus_spawner.bonus_collected.connect(_on_bonus_collected)
	results.retry_requested.connect(_reset_race)
	hud.pause_overlay.restart_requested.connect(_reset_race)
	hud.pause_overlay.menu_requested.connect(func(): SceneTransition.go(CareerSession.CAREER_SCENE if not career_event.is_empty() else "res://scenes/MainMenu.tscn", "ВЫХОД С ТРАССЫ"))
	vehicle.impacted.connect(audio.play_collision)
	vehicle.impacted.connect(_on_vehicle_impact)
	if vehicle.gun != null:
		vehicle.gun.fired.connect(_on_weapon_fired)
	if spawn_bots:
		_bots = get_tree().get_nodes_in_group("bots")
		if career_event.get("type", &"") == &"boss_duel":
			_trim_to_boss_duel()
		var career_state := PlayerProfile.career_state()
		for bot_index in _bots.size():
			var bot = _bots[bot_index]
			if not career_event.is_empty():
				var bot_vehicle := bot.get_parent() as Vehicle
				var rival := RivalRoster.by_id(StringName(career_event.get("boss_id", &""))) if career_event.get("type", &"") == &"boss_duel" else RivalRoster.at(bot_index)
				var rival_level := int(career_state.rival_levels.get(String(rival.id), CareerSession.difficulty_level(career_state)))
				bot_vehicle.reconfigure(RivalRoster.vehicle_config(rival, rival_level, bot_index))
				bot_vehicle.set_meta("rival_id", rival.id)
				if career_event.get("id", &"") == &"iron_open" and rival.id == &"razor":
					_story_rival = bot_vehicle
				bot_vehicle.self_modulate = rival.color
				(bot as BotController).strategy = int(rival.strategy)
				(bot as BotController)._apply_strategy()
				CareerDifficulty.configure_race_bot(bot as BotController, rival_level, bot_index)
			(bot as BotController).setup(track, vehicle)
			(bot.get_parent() as Vehicle).impacted.connect(audio.play_collision)
			if career_event.get("type", &"") == &"boss_duel":
				_configure_boss(bot.get_parent() as Vehicle, bot as BotController)
	else:
		for bot in get_tree().get_nodes_in_group("bots"):
			bot.get_parent().queue_free()
	participants.append(vehicle)
	for bot in _bots:
		participants.append(bot.get_parent() as Vehicle)
	track.config.lane_count = participants.size()
	_apply_event_modifier()
	track.queue_redraw()
	for car in participants:
		car.died.connect(_on_racer_died)
		car.damaged.connect(_on_racer_damaged)
		if car == vehicle:
			car.damage_stage_changed.connect(_on_player_damage_stage_changed)
	hud.configure_race(track, participants)
	if career_event.get("id", &"") == &"iron_open":
		hud.configure_story_identity(DriverRoster.selected(), RivalRoster.by_id(&"razor"))
		hud.track_story_rival(_story_rival)
	audio.set_biome_profile(track.config.biome_id)
	audio.set_engine_profile(vehicle.config)
	if track.weather != null:
		track.weather.storm_changed.connect(_on_storm_changed)
	for barrel in get_tree().get_nodes_in_group("destructibles"):
		if barrel is ExplosiveBarrel:
			barrel.exploded.connect(_on_track_barrel_exploded)
	_reset_race()


func _on_storm_changed(active: bool) -> void:
	hud.show_banner("ПЫЛЕВАЯ БУРЯ · СЦЕПЛЕНИЕ СНИЖЕНО" if active else "БУРЯ СТИХАЕТ", 1.8)
	audio.play_event_cue(&"emp" if active else &"pickup")


func _apply_loadout() -> void:
	var ids := LoadoutProfile.read_ids()
	var vehicle_id: StringName = ids.vehicle if PlayerProfile.is_owned(&"vehicle", ids.vehicle) else &"raider"
	vehicle.config = PlayerProfile.apply_vehicle_upgrades(LoadoutProfile.vehicle_config(vehicle_id), vehicle_id)
	if not career_event.is_empty():
		vehicle.config = DriverRoster.apply_passive(vehicle.config, StringName(PlayerProfile.career_state().get("driver_id", &"")))

func _physics_process(delta: float) -> void:
	var commands := _input_handler.get_commands()
	if commands["restart"]:
		_reset_race()
		return
	if race_over: return
	if _countdown_remaining > 0.0:
		_update_countdown(delta)
		vehicle.apply_control(0.0, 1.0, 0.0, false)
		return
	elapsed += delta
	for car in participants:
		if race_status[car] == &"RACING":
			track.apply_surface_to(car)
			var previous_laps := progress.laps(car)
			var finished := progress.advance(car, delta)
			if progress.laps(car) > previous_laps:
				car.repair_full()
				if car == vehicle and not finished:
					hud.show_banner("КРУГ ПРОЙДЕН · ПОЛНЫЙ РЕМОНТ", 1.4)
			if finished:
				_finish_racer(car)
				if race_over: return
	if event_type == &"elimination":
		_check_elimination_event()
	if event_type != &"bonus_hunt" and not _last_lap_announced and progress.laps(vehicle) == track.config.laps - 1:
		_last_lap_announced = true
		hud.show_banner("ПОСЛЕДНИЙ КРУГ", 1.6)
	var throttle: float = commands["throttle"]
	var brake: float = commands["brake"]
	# Arcade reverse: holding the brake key at a standstill backs the car up.
	# Without this the player can get permanently wedged into a corner.
	if brake > 0.0 and vehicle.get_forward_speed() < 20.0:
		throttle = -0.6
		brake = 0.0
	vehicle.apply_control(throttle, brake, commands["steer"], commands["fire"])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hud.pause_overlay.toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _input_handler.is_debug_toggle_pressed():
		_debug_enabled = not _debug_enabled
		track.set_debug_enabled(_debug_enabled)
	hud.update_info(vehicle, _input_handler.get_commands(), _debug_enabled)
	hud.update_race(get_race_position(vehicle), participants.size(), mini(progress.laps(vehicle) + 1, track.config.laps), track.config.laps, elapsed, _event_status_text())
	_update_story_radio(delta)
	audio.set_engine_intensity(_engine_intensity())
	var health_ratio := vehicle.health / maxf(vehicle.config.max_health, 1.0) if vehicle.config != null else 1.0
	var pressure := clampf(float(get_race_position(vehicle) - 1) / maxf(float(participants.size() - 1), 1.0), 0.0, 1.0)
	audio.set_game_intensity(_engine_intensity(), maxf(pressure * 0.55, 1.0 - health_ratio), health_ratio <= 0.28)
	audio.set_skid_intensity(clampf(absf(vehicle.get_lateral_speed()) / 260.0, 0.0, 1.0) * _engine_intensity())
	_update_boss_phase()


func _update_story_radio(delta: float) -> void:
	if _story_rival == null or not is_instance_valid(_story_rival) or race_over or _countdown_remaining > 0.0:
		return
	if not progress.entries.has(vehicle) or not progress.entries.has(_story_rival):
		return
	_story_radio_cooldown = maxf(0.0, _story_radio_cooldown - delta)
	var ahead := progress.total_progress(vehicle) > progress.total_progress(_story_rival)
	if not _story_initialized:
		_story_initialized = true
		_story_ahead = ahead
		return
	if ahead == _story_ahead or _story_radio_cooldown > 0.0:
		return
	_story_ahead = ahead
	_story_radio_cooldown = 14.0
	if ahead:
		hud.show_story_radio(String(DriverRoster.selected().get("name", "ПИЛОТ")), "Рэйзор, теперь ты смотришь на мой бампер.")
	else:
		hud.show_story_radio("РЭЙЗОР", "Рано праздновать. До финиша ещё далеко.")


## Rebuilds the race state: puts the vehicle back on the start line.
func _reset_race() -> void:
	race_over = false
	elapsed = 0.0
	finish_order.clear()
	result.clear()
	_last_lap_announced = false
	_story_initialized = false
	_story_radio_cooldown = 0.0
	_elimination_checkpoint = 0
	_boss_phase = 1
	bonus_scores.clear()
	repair_scores.clear()
	results.hide()
	if bonus_spawner != null:
		bonus_spawner.reset()
	var start_angle := track.get_start_angle()
	var longest := 0.0
	var widest := 0.0
	for car in participants:
		longest = maxf(longest, car.config.length * Vehicle.COLLISION_SCALE.x)
		widest = maxf(widest, car.config.width * Vehicle.COLLISION_SCALE.y)
	var start_grid := track.get_start_grid(participants.size(), longest, widest)
	_clear_bullets()
	for bot in _bots:
		(bot as BotController).reset()
		bot.set_physics_process(true)
	for index in participants.size():
		participants[index].reset_to(start_grid[index], start_angle)
	if boss_vehicle != null and is_instance_valid(boss_vehicle):
		boss_vehicle.config.max_speed = _boss_base_speed
		boss_vehicle.config.acceleration = _boss_base_acceleration
		var boss_weapon := load(String(career_event.get("boss_weapon", "res://resources/weapons/heavy_machine_gun.tres"))) as WeaponConfig
		boss_vehicle.activate_temporary_weapon(boss_weapon, 9999.0)
	for car in participants:
		race_status[car] = &"RACING"
		kills[car] = 0
		weapon_kills[car] = 0
		damage_dealt[car] = 0.0
		bonus_scores[car] = 0
		repair_scores[car] = 0
		if track.config.combat_enabled:
			car.add_to_group("combatants")
		else:
			car.remove_from_group("combatants")
	# Use intended reset positions before the deferred physics teleport executes.
	progress.reset(track, participants)
	for car in participants:
		var entry: Dictionary = progress.entries[car]
		entry.position = car._reset_position
		entry.projection = track.get_progress_along_track(car._reset_position)
		entry.progress = entry.projection
	camera.target = vehicle
	camera.set_bounds(track.get_bounds())
	camera.snap_to_target()
	hud.reset_cinematic()
	if DisplayServer.get_name() != "headless":
		_countdown_remaining = 3.2
		_countdown_step = 3
		hud.show_banner("3", 0.7)
		audio.play_event_cue(&"countdown")
		for bot in _bots:
			bot.set_physics_process(false)
	else:
		_countdown_remaining = 0.0


func _update_countdown(delta: float) -> void:
	var before := ceili(_countdown_remaining)
	_countdown_remaining = maxf(0.0, _countdown_remaining - delta)
	var after := ceili(_countdown_remaining)
	if after != before and after > 0 and after <= 3:
		_countdown_step = after
		hud.show_banner(str(after), 0.7)
		audio.play_event_cue(&"countdown")
	if _countdown_remaining <= 0.0:
		hud.show_banner("СТАРТ!", 0.9)
		audio.play_event_cue(&"start")
		camera.focus_pulse(-0.045)
		for bot in _bots:
			bot.set_physics_process(true)


func _clear_bullets(deferred: bool = false) -> void:
	for bullet in bullets.get_children():
		if deferred: bullet.queue_free()
		else: bullet.free()


func _on_weapon_fired() -> void:
	audio.play_weapon_fire(vehicle.gun.config)
	var recoil := 9.0 if vehicle.gun.config.weapon_type in [WeaponConfig.WeaponType.ROCKET, WeaponConfig.WeaponType.SHOTGUN] else 3.5
	camera.kick(-Vector2.RIGHT.rotated(vehicle.global_rotation), recoil)

func _on_vehicle_impact(intensity: float) -> void:
	camera.shake(3.0 + intensity * 7.0, 0.12)


func _on_track_barrel_exploded(_position: Vector2, _radius: float) -> void:
	audio.play_explosion()
	camera.shake(13.0, 0.28)
	hud.explosion_flash()
	var vfx := get_tree().get_first_node_in_group("combat_vfx") as CombatVFX
	if vfx != null: vfx.spawn_explosion(_position, Color(1.0, 0.38, 0.06), _radius)


func _engine_intensity() -> float:
	if vehicle.config == null or vehicle.config.max_speed <= 0.0:
		return 0.0
	return clampf(absf(vehicle.get_forward_speed()) / vehicle.config.max_speed, 0.0, 1.0)


func _on_racer_damaged(target: Vehicle, amount: float, source: Node) -> void:
	if is_instance_valid(source) and damage_dealt.has(source):
		damage_dealt[source] += amount
	if target == vehicle:
		camera.shake(clampf(1.5 + amount * 0.12, 2.0, 7.0), 0.1)
		hud.impact_flash(amount)
		if is_instance_valid(source): camera.kick(target.global_position.direction_to(source.global_position), minf(amount * 0.25, 8.0))
		if target.is_emp_disabled():
			hud.emp_flash()
			audio.play_event_cue(&"emp")


func _on_player_damage_stage_changed(_vehicle: Vehicle, stage: int) -> void:
	match stage:
		1: hud.show_banner("КУЗОВ ПОЦАРАПАН", 0.8)
		2: hud.show_banner("СЕРЬЁЗНЫЕ ПОВРЕЖДЕНИЯ", 1.0)
		3: hud.show_banner("КРИТИЧЕСКОЕ СОСТОЯНИЕ", 1.2)
		4: hud.show_banner("МАШИНА УНИЧТОЖЕНА", 1.2)


func _on_racer_died(car: Vehicle) -> void:
	race_status[car] = &"DNF"
	if is_instance_valid(car.last_attacker) and kills.has(car.last_attacker):
		kills[car.last_attacker] += 1
		if car.last_weapon_id != &"":
			weapon_kills[car.last_attacker] += 1
	audio.play_explosion()
	if car == boss_vehicle and event_type == &"boss_duel" and not race_over:
		racing_boss_victory()
		return
	if car == vehicle:
		hud.explosion_flash()
		hud.finish_cinematic(true)
	if car == vehicle: _end_race()


func racing_boss_victory() -> void:
	race_status[vehicle] = &"FINISHED"
	finish_order.append(vehicle)
	audio.play_finish()
	hud.show_banner("БОСС ПОВЕРЖЕН", 1.8)
	hud.finish_cinematic(true)
	_end_race()


func _finish_racer(car: Vehicle) -> void:
	race_status[car] = &"FINISHED"
	finish_order.append(car)
	_stop_racer(car)
	if car == vehicle:
		audio.play_finish()
		hud.finish_cinematic(true)
		camera.focus_pulse(-0.075)
		_end_race()


func _stop_racer(car: Vehicle) -> void:
	car.apply_control(0, 0, 0, false)
	car.remove_from_group("combatants")
	if car.gun != null: car.gun.set_firing(false)
	car.linear_velocity = Vector2.ZERO
	car.angular_velocity = 0
	call_deferred("_freeze_racer", car)
	var driver := car.get_node_or_null("BotController")
	if driver != null: driver.set_physics_process(false)


func get_race_position(car: Vehicle) -> int:
	var ordered := participants.duplicate()
	ordered.sort_custom(_ahead)
	return ordered.find(car) + 1


func _ahead(a: Vehicle, b: Vehicle) -> bool:
	var a_finished := finish_order.find(a)
	var b_finished := finish_order.find(b)
	if a_finished >= 0 or b_finished >= 0:
		if a_finished < 0: return false
		if b_finished < 0: return true
		return a_finished < b_finished
	if (race_status[a] == &"DNF") != (race_status[b] == &"DNF"):
		return race_status[b] == &"DNF"
	var difference := progress.total_progress(a) - progress.total_progress(b)
	return difference > 0 if not is_zero_approx(difference) else participants.find(a) < participants.find(b)


func _end_race() -> void:
	if race_over: return
	race_over = true
	var event_position := _event_position(vehicle)
	var placement_reward: int = int(PlayerProfile.economy().race_rewards.get(event_position, 0))
	var lap_reward: int = progress.laps(vehicle) * PlayerProfile.economy().race_lap_reward
	var damage_reward: int = floori(damage_dealt[vehicle] / 100.0) * PlayerProfile.economy().damage_reward_per_100
	var credits_earned: int = roundi((placement_reward + lap_reward + damage_reward + kills[vehicle] * PlayerProfile.economy().race_kill_reward) * AccessibilitySettings.reward_multiplier())
	var profile := PlayerProfile.read()
	profile.credits = int(profile.credits) + credits_earned
	PlayerProfile.save(profile)
	result = {"status": race_status[vehicle], "position": event_position,
		"participants": participants.size(), "time": elapsed,
		"laps": progress.laps(vehicle), "target_laps": track.config.laps,
		"kills": kills[vehicle], "weapon_kills": weapon_kills[vehicle], "damage": damage_dealt[vehicle], "credits": credits_earned,
		"pickups": int(bonus_scores.get(vehicle, 0)),
		"repairs_used": int(repair_scores.get(vehicle, 0)),
		"event_won": event_position == 1}
	if not career_event.is_empty():
		result.rival_positions = _rival_positions()
	var selected_vehicle: StringName = LoadoutProfile.read_ids().vehicle
	PlayerProfile.record_vehicle_result(selected_vehicle, &"race", result)
	if not career_event.is_empty():
		var career_summary := CareerSession.record_result(result)
		result.merge(career_summary, true)
		result.career_event = true
		result.credits = int(result.credits) + int(career_summary.get("career_bonus", 0))
		result.championship_run = CareerSession.championship_run
	for car in participants: _stop_racer(car)
	_clear_bullets(true)
	results.show_result(result)


func _rival_positions() -> Dictionary:
	var ordered := participants.duplicate()
	ordered.sort_custom(_ahead)
	var positions := {}
	for index in ordered.size():
		var car := ordered[index] as Vehicle
		if car != vehicle and car.has_meta("rival_id"):
			positions[String(car.get_meta("rival_id"))] = index + 1
	return positions


func _on_bonus_collected(collector: Vehicle, kind: BonusPickup.Kind) -> void:
	if not bonus_scores.has(collector):
		return
	bonus_scores[collector] = int(bonus_scores[collector]) + 1
	if kind == BonusPickup.Kind.REPAIR:
		repair_scores[collector] = int(repair_scores.get(collector, 0)) + 1
	if collector == vehicle:
		hud.show_banner("БОНУС ЗАХВАЧЕН · %d/%d" % [bonus_scores[collector], _bonus_target()], 1.1)
		audio.play_event_cue(&"repair" if kind == BonusPickup.Kind.REPAIR else &"pickup")
		hud.pickup_flash(Color(0.3, 1.0, 0.55) if kind == BonusPickup.Kind.REPAIR else Color(0.25, 0.82, 1.0))
		camera.focus_pulse(-0.025)
		var vfx := get_tree().get_first_node_in_group("combat_vfx") as CombatVFX
		if vfx != null: vfx.spawn_pickup(collector.global_position, Color(0.3, 1.0, 0.55) if kind == BonusPickup.Kind.REPAIR else Color(0.25, 0.82, 1.0))
	if event_type == &"bonus_hunt" and int(bonus_scores[collector]) >= _bonus_target() and not race_over:
		for car in participants:
			if race_status[car] == &"RACING":
				race_status[car] = &"FINISHED"
		_end_race()


func _check_elimination_event() -> void:
	var leader_laps := 0
	for car in participants:
		if race_status[car] == &"RACING":
			leader_laps = maxi(leader_laps, progress.laps(car))
	while leader_laps > _elimination_checkpoint and _elimination_checkpoint < track.config.laps - 1:
		_elimination_checkpoint += 1
		_eliminate_last_racer()


func _eliminate_last_racer() -> void:
	var racing: Array[Vehicle] = []
	for car in participants:
		if race_status[car] == &"RACING":
			racing.append(car)
	if racing.size() <= 1:
		return
	racing.sort_custom(func(a: Vehicle, b: Vehicle): return progress.total_progress(a) < progress.total_progress(b))
	var eliminated := racing[0]
	if eliminated == vehicle:
		hud.show_banner("ВЫ ВЫБЫЛИ", 1.4)
	else:
		hud.show_banner("СОПЕРНИК ВЫБЫЛ · ОСТАЛОСЬ %d" % (racing.size() - 1), 1.2)
	eliminated.take_damage(eliminated.config.max_health * 10.0, &"body", null)


func _event_position(car: Vehicle) -> int:
	if event_type != &"bonus_hunt":
		return get_race_position(car)
	var ordered := participants.duplicate()
	ordered.sort_custom(func(a: Vehicle, b: Vehicle):
		var score_difference := int(bonus_scores.get(a, 0)) - int(bonus_scores.get(b, 0))
		return score_difference > 0 if score_difference != 0 else progress.total_progress(a) > progress.total_progress(b)
	)
	return ordered.find(car) + 1


func _bonus_target() -> int:
	return int(career_event.get("target_pickups", 3))


func _event_status_text() -> String:
	match event_type:
		&"elimination":
			var alive := 0
			for car in participants:
				if race_status.get(car) == &"RACING": alive += 1
			return "ВЫБЫВАНИЕ · ОСТАЛОСЬ %d" % alive
		&"bonus_hunt":
			return "БОНУСЫ %d/%d" % [int(bonus_scores.get(vehicle, 0)), _bonus_target()]
		&"boss_duel":
			return "ДУЭЛЬ · ФАЗА %d/3" % _boss_phase
	return ""


func _freeze_racer(car: Vehicle) -> void:
	if is_instance_valid(car) and (race_over or race_status.get(car) != &"RACING"):
		car.freeze = true
		car.collision_layer = 0
		car.collision_mask = 0


func _trim_to_boss_duel() -> void:
	if _bots.is_empty(): return
	var keeper: Node = _bots[0]
	for bot in _bots.duplicate():
		if bot != keeper:
			bot.get_parent().free()
	_bots = [keeper]


func _configure_boss(car: Vehicle, controller: BotController) -> void:
	boss_vehicle = car
	car.set_meta("boss", true)
	car.config = car.config.duplicate() as VehicleConfig
	car.config.max_health *= 1.75
	car.config.damage_resistance = minf(0.62, car.config.damage_resistance + 0.16)
	car.config.ram_power += 0.28
	car.reconfigure(car.config)
	_boss_base_speed = car.config.max_speed
	_boss_base_acceleration = car.config.acceleration
	controller.cruise_throttle = 1.0
	controller.fire_range += 140.0
	var weapon := load(String(career_event.get("boss_weapon", "res://resources/weapons/heavy_machine_gun.tres"))) as WeaponConfig
	car.activate_temporary_weapon(weapon, 9999.0)


func _apply_event_modifier() -> void:
	match career_event.get("modifier", &""):
		&"scarce_supplies":
			bonus_spawner.spawn_interval = 4.8
			bonus_spawner.max_active = 1
		&"overdrive":
			for car in participants:
				car.config = car.config.duplicate() as VehicleConfig
				car.config.max_speed *= 1.08
				car.config.acceleration *= 1.06


func _update_boss_phase() -> void:
	if boss_vehicle == null or not is_instance_valid(boss_vehicle) or not boss_vehicle.alive:
		return
	var ratio := boss_vehicle.health / maxf(boss_vehicle.config.max_health, 1.0)
	var next_phase := 3 if ratio <= 0.32 else (2 if ratio <= 0.66 else 1)
	if next_phase > _boss_phase:
		_boss_phase = next_phase
		if _boss_phase == 2:
			boss_vehicle.config.max_speed *= 1.08
			boss_vehicle.activate_temporary_weapon(load("res://resources/weapons/rocket_launcher.tres"), 9999.0)
			hud.show_banner("БОСС · ФАЗА 2 · ЯРОСТЬ", 1.5)
		else:
			boss_vehicle.config.acceleration *= 1.14
			boss_vehicle.activate_temporary_weapon(load("res://resources/weapons/emp_cannon.tres"), 9999.0)
			hud.show_banner("БОСС · ФАЗА 3 · ПОСЛЕДНИЙ ШАНС", 1.8)
		camera.shake(10.0, 0.3)
	hud.update_boss(RivalRoster.display_name(career_event.get("boss_id", &"БОСС")), ratio, _boss_phase)
