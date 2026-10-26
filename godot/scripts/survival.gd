extends Node2D
class_name Survival
## Battle-royale survival mode.
##
## The player fights rounds of AI cars in an arena. Clearing a round advances
## to the next one with one more enemy; being destroyed ends the run. The last
## car standing wins the round.

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const CERBERUS_VANGUARD := preload("res://resources/vehicles/elite/cerberus_vanguard.tres")
const CERBERUS_FLANKER := preload("res://resources/vehicles/elite/cerberus_flanker.tres")
const CERBERUS_SUPPORT := preload("res://resources/vehicles/elite/cerberus_support.tres")
const REFEREE_CONFIG := preload("res://resources/vehicles/elite/referee_arbiter.tres")
const REFEREE_FLAMETHROWER := preload("res://resources/weapons/referee_flamethrower.tres")
const EMP_CANNON := preload("res://resources/weapons/emp_cannon.tres")
const HEAVY_MACHINE_GUN := preload("res://resources/weapons/heavy_machine_gun.tres")
const REFEREE_BIKER := preload("res://resources/vehicles/elite/referee_biker.tres")
const BIKER_PISTOL := preload("res://resources/weapons/biker_pistol.tres")
const ESCAPING_CREW_SCENE := preload("res://scenes/EscapingCrew.tscn")
const CREW_REMAINS_SCENE := preload("res://scenes/CrewRemains.tscn")

const BIKERS_PER_SQUAD := 6
const BIKER_FIRST_DEPLOY_DELAY := 10.0
const BIKER_DEPLOY_INTERVAL := 36.0
const CREW_CRUSH_SCORE := 350
const CREW_WEAPON_SCORE := 350

## Vehicle scene used to spawn the AI opponents.
@export var bot_scene: PackedScene

@onready var arena: Arena = $Arena
@onready var player: Vehicle = $Player
@onready var bullets: Node2D = $Bullets
@onready var camera: FollowCamera = $Camera
@onready var hud: ArenaHUD = $HUD
@onready var audio: AudioManager = $AudioManager
@onready var results: Control = $Results/SurvivalResults
@onready var upgrade_draft: SurvivalUpgradeOverlay = $DraftLayer/UpgradeDraft

@export_range(1, 20, 1) var starting_enemies: int = 5
@export_range(1, 20, 1) var max_enemies: int = 6
@export_range(0.5, 10.0, 0.1) var round_end_delay: float = 1.2
## Internal A/B switch; normal sessions use SurvivalRunData.wave_plan.boss.
@export var referee_every_wave := false

const BOT_COLORS := [
	Color(1.0, 0.55, 0.55),
	Color(0.55, 0.7, 1.0),
	Color(0.6, 1.0, 0.6),
	Color(1.0, 0.85, 0.45),
	Color(0.85, 0.6, 1.0),
	Color(0.5, 1.0, 0.95),
]

var _input_handler := InputHandler.new()
var _enemies: Array[Vehicle] = []
var _round: int = 0
var _round_over := false
var _round_timer := 0.0
var _player_won := false
var _round_enemy_total := 0
var _kills := 0
var _weapon_kills := 0
var _damage_dealt := 0.0
var _damage_reward_blocks := 0
var _credits_earned := 0
var _elapsed := 0.0
var bonus_spawner: BonusSpawner
var career_event: Dictionary = {}
var arena_hazards: ArenaHazardDirector
var _wave_plan: Dictionary = {}
var _run_perks: Array[Dictionary] = []
var _perk_ids: Array = []
var _perk_effects: Array = []
var _choosing_perk := false
var _score := 0
var _combo := 0
var _best_combo := 0
var _combo_timer := 0.0
var _boss_kills := 0
var _round_elapsed := 0.0
var _combat_idle := 0.0
var _hunt_announced := false
var _sudden_death := false
var _second_wind_used := false
var _boss: Vehicle
var _boss_phase := 0
var _boss_ability_timer := 0.0
var _biker_deploy_timer := 0.0
var _biker_squads_deployed := 0
var _referee_spawned := false
var _referee_spawn_pending := false
var _round_start_pending := -1
const FIRST_WAVE_REINFORCEMENT_DELAY := 5.0
var _pending_enemies: Array[Dictionary] = []
var _reinforcement_timer := 0.0
var _reinforcement_requested := false
var _using_joypad := false
var _input_device := 0
var _round_generation := 0
var _base_player_config: VehicleConfig
var _crew_crushed := 0
var _crew_weapon_killed := 0
var _crew_escaped := 0
var _session_finished := false
var _initial_arena_config: ArenaConfig
var _arena_generation := 0


func _enter_tree() -> void:
	var event := CareerSession.active_event()
	var arena_config: ArenaConfig
	if event.get("type", &"") == &"arena":
		arena_config = load(String(event.get("track", ""))) as ArenaConfig
	else:
		arena_config = load(String(SurvivalRunData.selected_arena().path)) as ArenaConfig
	var arena_node := get_node_or_null("Arena") as Arena
	if arena_config != null and arena_node != null:
		arena_node.config = arena_config


func _ready() -> void:
	player.set_meta("player_vehicle", true)
	player.set_meta("survival_pickups", true)
	career_event = CareerSession.active_event()
	if not career_event.is_empty() and career_event.type != &"arena":
		career_event = {}
	if DisplayServer.get_name() != "headless":
		_apply_loadout()
	_base_player_config = player.config.duplicate() as VehicleConfig
	_initial_arena_config = arena.config.duplicate(true) as ArenaConfig
	bonus_spawner = BonusSpawner.new()
	bonus_spawner.name = "BonusSpawner"
	add_child(bonus_spawner)
	bonus_spawner.setup_for_arena(arena)
	bonus_spawner.bonus_announced.connect(_on_bonus_announced)
	bonus_spawner.bonus_collected.connect(_on_bonus_collected)
	player.impacted.connect(audio.play_collision)
	player.impacted.connect(_on_player_impact)
	if player.gun != null:
		player.gun.fired.connect(_on_weapon_fired)
	player.died.connect(_on_vehicle_died)
	player.damaged.connect(_on_vehicle_damaged)
	player.damage_stage_changed.connect(_on_player_damage_stage_changed)
	results.retry_requested.connect(_on_retry_requested)
	upgrade_draft.perk_selected.connect(_on_perk_selected)
	hud.pause_overlay.restart_requested.connect(_on_retry_requested)
	hud.pause_overlay.menu_requested.connect(func(): SceneTransition.go(CareerSession.CAREER_SCENE if not career_event.is_empty() else MENU_SCENE, "ВЫХОД С АРЕНЫ"))
	camera.target = player
	# A structured arena has authored perimeter walls. Include the wall, not
	# the old extra 20 units of empty exterior; retain zoom/car screen scale.
	if arena.config.structured_scrapyard:
		camera.margin = arena.config.wall_thickness
		hud.avoid_tutorial_overlap = true
	camera.set_bounds(arena.get_bounds())
	audio.set_biome_profile(arena.config.biome_id)
	audio.enable_survival_metal()
	audio.set_engine_profile(player.config)
	_setup_arena_systems()
	start_round(1)


func _setup_arena_systems() -> void:
	_setup_spike_strips()
	arena_hazards = ArenaHazardDirector.new()
	arena_hazards.name = "ArenaHazardDirector"
	arena_hazards.setup(arena.config, SurvivalRunData.daily_seed() if SurvivalRunData.daily_mode else 0)
	arena.add_child(arena_hazards)
	var generation := _round_generation
	arena_hazards.hazard_announced.connect(func(text):
		if _events_allowed() and generation == _arena_generation: hud.show_message(text, 2.2))
	arena_hazards.hazard_triggered.connect(func(_text):
		if _events_allowed() and generation == _arena_generation: audio.play_event_cue(&"critical"))
	if arena.weather != null:
		arena.weather.storm_changed.connect(_on_storm_changed)
	for barrel in arena.get_tree().get_nodes_in_group("destructibles"):
		if barrel is ExplosiveBarrel and arena.is_ancestor_of(barrel):
			barrel.exploded.connect(_on_barrel_exploded.bind(generation))


func _events_allowed() -> bool:
	return not _session_finished and not _round_over and _round_start_pending < 0


func _restore_arena() -> void:
	_clear_enemies()
	_clear_crew()
	bonus_spawner.reset()
	arena.free()
	arena = preload("res://scenes/Arena.tscn").instantiate() as Arena
	arena.name = "Arena"
	arena.config = _initial_arena_config.duplicate(true) as ArenaConfig
	add_child(arena)
	move_child(arena, 0)
	bonus_spawner.setup_for_arena(arena)
	_arena_generation = _round_generation
	_setup_arena_systems()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player._surface_modifiers.clear()
	player.clear_surface_modifier()
	player._surface_traction_factor = 1.0
	player._surface_steering_factor = 1.0
	player._collision_cooldowns.clear()
	bonus_spawner.process_mode = Node.PROCESS_MODE_INHERIT
	bullets.process_mode = Node.PROCESS_MODE_INHERIT
	var vfx := $CombatVFX as CombatVFX
	vfx.events.clear()
	vfx.set_process(false)
	vfx.queue_redraw()
	camera.set_bounds(arena.get_bounds())
	hud.pause_overlay.resume()


func _finish_session() -> void:
	_session_finished = true
	_round_generation += 1
	_referee_spawn_pending = false
	_round_start_pending = -1
	_stop_session_world.call_deferred(_round_generation)


func _stop_session_world(generation: int) -> void:
	if generation != _round_generation or not _session_finished: return
	for group_name in [&"escaping_crew", &"crew_remains"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_ancestor_of(node): node.process_mode = Node.PROCESS_MODE_DISABLED
	for node in [arena, bonus_spawner, bullets, player] + _enemies:
		if not is_instance_valid(node): continue
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is Vehicle:
			node.gun.set_firing(false)
			node.freeze = true
	for node in bonus_spawner.get_children():
		if node is BonusPickup: node.set_armed(false)


func _on_storm_changed(active: bool) -> void:
	if not _events_allowed(): return
	hud.show_message("ПЫЛЕВАЯ БУРЯ · СЦЕПЛЕНИЕ СНИЖЕНО" if active else "БУРЯ СТИХАЕТ", 1.8)
	audio.play_event_cue(&"emp" if active else &"pickup")


func _apply_loadout() -> void:
	var ids := LoadoutProfile.read_ids()
	var vehicle_id: StringName = ids.vehicle if PlayerProfile.is_owned(&"vehicle", ids.vehicle) else &"raider"
	var selected_config := PlayerProfile.apply_vehicle_upgrades(LoadoutProfile.vehicle_config(vehicle_id), vehicle_id)
	if not career_event.is_empty():
		selected_config = DriverRoster.apply_passive(selected_config, StringName(PlayerProfile.career_state().get("driver_id", &"")))
	player.reconfigure(selected_config)

func _setup_spike_strips() -> void:
	var scene := preload("res://scenes/SpikeStrip.tscn")
	for point in arena.config.spike_strip_positions:
		var spike := scene.instantiate() as SpikeStrip
		arena.add_child(spike)
		spike.position = point


func _physics_process(_delta: float) -> void:
	var commands := _input_handler.get_commands()
	if commands["restart"]:
		_request_round_start(1)
		return
	if player.alive and not _round_over:
		if _events_allowed():
			_update_reinforcements(_delta)
			var offer := BonusPickup.weapon_offer_for(player)
			if offer != null and (commands["interact"] or not player.has_temporary_weapon()):
				offer.collect(player, bool(commands["interact"]))
		arena.apply_surface_to(player)
		if arena_hazards != null: arena_hazards.apply_surface_to(player)
		for enemy in _enemies:
			if is_instance_valid(enemy) and enemy.alive:
				arena.apply_surface_to(enemy)
				if arena_hazards != null: arena_hazards.apply_surface_to(enemy)
		player.apply_player_control(commands["throttle"], commands["brake"], commands["steer"], commands["fire"], _delta)
	else:
		player.apply_control(0.0, 0.0, 0.0, false)


func _process(delta: float) -> void:
	if _session_finished: return
	var enemies_alive := _alive_enemies()
	var offer := BonusPickup.weapon_offer_for(player) if _events_allowed() and player.alive and player.has_temporary_weapon() else null
	hud.show_interaction("%s — заменить оружие · %s" % [InputBindings.interaction_key_label(_using_joypad, _input_device), BonusPickup.weapon_badge(offer.weapon_config)] if offer != null else "")
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if _combo_timer <= 0.0: _combo = 0
	var run_info := {
		"score": _score, "combo": _combo,
		"scenario": String(_wave_plan.get("name", "")), "time": _round_elapsed,
		"boss": _boss, "crew_active": _active_crew_count(), "crew_crushed": _crew_crushed,
		"crew_weapon_killed": _crew_weapon_killed,
	}
	hud.update_status(player, enemies_alive + _pending_enemies.size(), _round, _destroyed_enemies(enemies_alive), run_info)
	audio.set_engine_intensity(_engine_intensity())
	var health_ratio := player.health / maxf(player.config.max_health, 1.0) if player.config != null else 1.0
	var pressure := clampf(float(enemies_alive) / maxf(float(_round_enemy_total), 1.0), 0.0, 1.0)
	audio.set_game_intensity(_engine_intensity(), maxf(pressure * 0.72, 1.0 - health_ratio), health_ratio <= 0.28)
	audio.set_survival_music_state(is_instance_valid(_boss) and _boss.alive, _boss_phase)
	audio.set_skid_intensity(clampf(absf(player.get_lateral_speed()) / 240.0, 0.0, 1.0) * _engine_intensity())
	if player.alive and not _round_over:
		_elapsed += delta
		_round_elapsed += delta
		_combat_idle += delta
		_update_combat_director()
		_update_boss(delta)
		# Signals remain the fast path, but the round must also recover if several
		# cars explode in one physics step or an opponent leaves the tree directly.
		if _round_enemy_total > 0 and enemies_alive == 0:
			_complete_combat_phase()
	if _round_over and _round_timer > 0.0 and not _choosing_perk:
		_round_timer -= delta
		if _player_won:
			hud.show_message(
				"ВОЛНА %d ПРОЙДЕНА\nВЫБОР УЛУЧШЕНИЯ ЧЕРЕЗ %.1f С" % [_round, maxf(_round_timer, 0.0)],
				0.2
			)
		if _round_timer <= 0.0 and _player_won:
			_offer_upgrade()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.25):
		_using_joypad = true
		_input_device = event.device
	elif event is InputEventKey or event is InputEventMouseButton:
		_using_joypad = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hud.pause_overlay.toggle()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Rounds
# ---------------------------------------------------------------------------

func start_round(round_number: int) -> void:
	_round_generation += 1
	_round_start_pending = -1
	_referee_spawn_pending = false
	_pending_enemies.clear()
	_reinforcement_timer = 0.0
	_reinforcement_requested = false
	hud.show_interaction("")
	if round_number == 1 and _round > 0:
		_restore_arena()
	_session_finished = false
	if round_number == 1:
		_kills = 0
		_weapon_kills = 0
		_damage_dealt = 0.0
		_damage_reward_blocks = 0
		_credits_earned = 0
		_elapsed = 0.0
		_score = 0
		_combo = 0
		_combo_timer = 0.0
		_best_combo = 0
		_boss_kills = 0
		_crew_crushed = 0
		_crew_weapon_killed = 0
		_crew_escaped = 0
		_run_perks.clear()
		_perk_ids.clear()
		_perk_effects.clear()
		player.reconfigure(_base_player_config.duplicate() as VehicleConfig)
		results.hide()
		upgrade_draft.hide()
		if arena.tire_tracks != null:
			arena.tire_tracks.clear_tracks()
	_round = round_number
	_round_over = false
	_round_timer = 0.0
	_player_won = false
	_round_enemy_total = 0
	_round_elapsed = 0.0
	_combat_idle = 0.0
	_hunt_announced = false
	_sudden_death = false
	_second_wind_used = false
	_boss = null
	_boss_phase = 0
	_biker_squads_deployed = 0
	_referee_spawned = false
	_choosing_perk = false
	_wave_plan = SurvivalRunData.wave_plan(round_number)
	if referee_every_wave or bool(career_event.get("requires_arbiter", false)):
		_wave_plan.boss = true
	_boss_ability_timer = 5.0 if _wave_plan.boss else 0.0
	_biker_deploy_timer = BIKER_FIRST_DEPLOY_DELAY if _wave_plan.boss else 0.0
	_clear_bullets()
	_clear_enemies()
	_clear_crew()
	if bonus_spawner != null:
		var supply_rate := float(_wave_plan.get("supply_rate", 1.0))
		var boosted_supply: bool = _wave_plan.id == &"supply_rush" or &"supply_magnet" in _perk_effects
		bonus_spawner.spawn_interval = 5.0 / supply_rate
		bonus_spawner.first_spawn_delay = 2.8 / supply_rate
		bonus_spawner.warning_duration = 1.0
		bonus_spawner.active_lifetime = 26.0
		bonus_spawner.batch_size = 4 if boosted_supply else 3
		bonus_spawner.minimum_weapons_per_batch = 3 if boosted_supply else 2
		bonus_spawner.minimum_spawn_separation = 210.0
		bonus_spawner.max_active = bonus_spawner.batch_size * 2
		# Reset only after applying the new wave timing; the first batch must use
		# the faster delay immediately, including on wave one.
		bonus_spawner.reset()

	var enemy_count := _enemy_count()
	var spawns := arena.get_spawn_points(enemy_count + 1)
	if spawns.size() < enemy_count + 1:
		push_error("Arena returned %d spawn points for %d survival vehicles" % [spawns.size(), enemy_count + 1])
		_end_round(false)
		return
	if round_number == 1:
		player.reset_to(spawns[0], 0.0)
	else:
		var repair_fraction := 0.3 + (0.15 if &"wave_repair" in _perk_effects else 0.0)
		player.reset_for_next_wave(spawns[0], 0.0, repair_fraction)
	player.add_to_group("combatants")
	_round_enemy_total = enemy_count
	for i in enemy_count:
		if round_number == 1 and i >= 2:
			_pending_enemies.append({"index":i,"position":spawns[i+1]})
		else:
			_spawn_bot(spawns[i + 1], i)
	_reinforcement_timer = FIRST_WAVE_REINFORCEMENT_DELAY if not _pending_enemies.is_empty() else 0.0
	camera.snap_to_target()
	hud.reset_cinematic()
	var enemies_alive := _alive_enemies()
	hud.update_status(player, enemies_alive + _pending_enemies.size(), _round, _destroyed_enemies(enemies_alive))
	hud.show_message("ВОЛНА %d · %s" % [_round, _wave_plan.name], 1.8)


func _update_reinforcements(delta: float) -> void:
	if _pending_enemies.is_empty() or _reinforcement_requested: return
	_reinforcement_timer -= delta
	if _reinforcement_timer <= 0:
		_reinforcement_requested = true
		_spawn_reinforcement_deferred.call_deferred(_round_generation)


func _spawn_reinforcement_deferred(generation: int) -> void:
	if generation != _round_generation or not _events_allowed() or not player.alive: return
	_reinforcement_requested = false
	if _pending_enemies.is_empty(): return
	var entry: Dictionary = _pending_enemies[0]
	# Reuse authored valid spawn anchors, but do not spawn on a moving car.
	var spawn: Vector2 = entry.position
	var found := false
	var candidates := arena.get_spawn_points(_enemy_count()+1)
	candidates.push_front(spawn)
	for candidate in candidates:
		var clear := true
		for node in get_tree().get_nodes_in_group("combatants"):
			if node is Vehicle and node.alive and node.global_position.distance_to(candidate) < 100:
				clear = false
				break
		if clear:
			spawn = candidate
			found = true
			break
	if not found:
		_reinforcement_timer = 0.5
		return
	_pending_enemies.pop_front()
	_spawn_bot(spawn, int(entry.index))


func _enemy_count() -> int:
	return int(_wave_plan.get("enemies", mini(starting_enemies + _round - 1, max_enemies)))


func _spawn_bot(spawn: Vector2, index: int, force_boss: bool = false) -> Vehicle:
	var bot: Vehicle = bot_scene.instantiate()
	var is_boss := force_boss
	var is_elite := not is_boss and index < int(_wave_plan.get("elites", 0))
	var catalog_ids := LoadoutProfile.vehicle_ids()
	if not catalog_ids.is_empty():
		bot.config = LoadoutProfile.vehicle_config(catalog_ids[(index + _round * 2) % catalog_ids.size()])
	if is_boss:
		bot.config = REFEREE_CONFIG
	elif is_elite:
		bot.config = [CERBERUS_VANGUARD, CERBERUS_FLANKER, CERBERUS_SUPPORT][index % 3]
	elif not career_event.is_empty():
		var rival := RivalRoster.at(index)
		var state := PlayerProfile.career_state()
		var rival_level := int(state.rival_levels.get(String(rival.id), CareerSession.difficulty_level(state)))
		bot.config = RivalRoster.vehicle_config(rival, rival_level, index)
		bot.set_meta("rival_id", rival.id)
	bot.config = _scaled_bot_config(bot.config, is_elite, is_boss)
	bot.set_meta("elite", is_elite)
	bot.set_meta("boss", is_boss)
	bot.set_meta("exclusive_vehicle", is_elite or is_boss)
	bot.set_meta("boss_name", "АРБИТР" if is_boss else "")
	bot.set_meta("squad_id", &"referee" if is_boss else (&"cerberus" if is_elite else &""))
	# Elite and boss textures already carry their faction livery. Tinting them
	# would destroy the shared palette and make role recognition harder.
	bot.self_modulate = Color.WHITE if is_elite or is_boss else BOT_COLORS[index % BOT_COLORS.size()]
	add_child(bot)
	bot.global_position = spawn
	bot.rotation = (player.global_position - spawn).angle()
	bot.died.connect(_on_vehicle_died)
	bot.impacted.connect(audio.play_collision)
	bot.damaged.connect(_on_vehicle_damaged)
	bot.add_to_group("combatants")

	var controller := ArenaBot.new()
	controller.name = "ArenaBot"
	controller.add_to_group("arena_bots")
	controller.arena = arena
	controller.strategy = index % ArenaBot.Strategy.size()
	controller.team_role = ArenaBot.TeamRole.VANGUARD if is_boss else (index % 3) + 1
	# Every opponent treats the player as the primary objective. Ordinary cars
	# keep separate squad ids, so collisions and friendly fire still hurt them.
	controller.focus_player = true
	controller.external_weapon_control = is_boss
	if is_boss:
		controller.avoid_radius = 175.0
		controller.avoid_weight = 2.65
		controller.wall_avoid_margin = 125.0
		controller.hazard_avoid_radius = 155.0
		controller.stuck_speed = 14.0
		controller.stuck_timeout = 0.72
		controller.reverse_duration = 1.45
	if not career_event.is_empty() and not is_elite and not is_boss:
		var rival := RivalRoster.at(index)
		controller.strategy = _arena_strategy_for(rival.id)
		CareerDifficulty.configure_arena_bot(controller, int(PlayerProfile.career_state().rival_levels.get(String(rival.id), 1)), index)
	bot.add_child(controller)
	if is_boss:
		# Strategy defaults are applied in ArenaBot._ready; restore the dedicated
		# long-vehicle navigation envelope afterwards.
		controller.avoid_radius = 175.0
		controller.avoid_weight = 2.65
		controller.wall_avoid_margin = 125.0
		controller.hazard_avoid_radius = 155.0
		controller.stuck_speed = 14.0
		controller.stuck_timeout = 0.72
		controller.reverse_duration = 1.45
	if is_boss:
		_boss = bot
		bot.activate_temporary_weapon(REFEREE_FLAMETHROWER, 999.0)
		var referee := RefereeBoss.new()
		referee.name = "RefereeBoss"
		bot.add_child(referee)
		referee.flame_warning.connect(_on_referee_flame_warning)
	elif is_elite:
		match index % 3:
			0: bot.activate_ram_boost(999.0)
			1: bot.activate_temporary_weapon(EMP_CANNON, 999.0)
			2: bot.activate_temporary_weapon(HEAVY_MACHINE_GUN, 999.0)
	_enemies.append(bot)
	return bot


func _spawn_referee() -> void:
	if not bool(_wave_plan.get("boss", false)) or _referee_spawned or _round_over or not player.alive:
		return
	_referee_spawn_pending = false
	_referee_spawned = true
	var spawn_points := arena.get_spawn_points(maxi(_enemy_count() + 1, 6))
	var spawn := arena.get_bounds().get_center()
	var farthest_distance := -1.0
	for candidate in spawn_points:
		var distance := player.global_position.distance_squared_to(candidate)
		if distance > farthest_distance:
			farthest_distance = distance
			spawn = candidate
	var boss := _spawn_bot(spawn, _enemies.size(), true)
	_round_enemy_total += 1
	_boss_ability_timer = 3.0
	_biker_deploy_timer = BIKER_FIRST_DEPLOY_DELAY
	hud.show_message("АРБИТР ВЫХОДИТ НА АРЕНУ\nСКОРОСТЬ: %.0f КМ/Ч" % boss.config.max_speed, 2.4)
	audio.play_event_cue(&"critical")
	camera.shake(8.0, 0.35)


## Death signals can arrive while Godot is flushing physics contacts. Runtime
## boss creation is therefore deferred and tied to the current wave generation.
func _request_referee_spawn() -> void:
	if not bool(_wave_plan.get("boss", false)) or _referee_spawned or _referee_spawn_pending or _round_over or not player.alive:
		return
	_referee_spawn_pending = true
	var generation := _round_generation
	_spawn_referee_deferred.call_deferred(generation)


func _spawn_referee_deferred(generation: int) -> void:
	if generation != _round_generation:
		return
	_referee_spawn_pending = false
	if _alive_enemies() == 0 and _pending_enemies.is_empty():
		_spawn_referee()


## Restart input is sampled in `_physics_process`; teardown and respawning must
## happen after the physics server has finished flushing collision queries.
func _request_round_start(round_number: int) -> void:
	if _round_start_pending >= 0:
		return
	_round_start_pending = maxi(1, round_number)
	_round_generation += 1
	_execute_round_start.call_deferred(_round_generation)


func _execute_round_start(generation: int) -> void:
	if generation != _round_generation: return
	var round_number := _round_start_pending
	_round_start_pending = -1
	if round_number >= 1:
		start_round(round_number)


func _scaled_bot_config(base: VehicleConfig, elite: bool, boss: bool) -> VehicleConfig:
	var result := base.duplicate() as VehicleConfig
	var tier := float(maxi(0, _round - 1))
	result.max_health *= 1.0 + minf(tier * 0.075, 0.7)
	result.engine_health *= 1.0 + minf(tier * 0.05, 0.45)
	result.wheels_health *= 1.0 + minf(tier * 0.05, 0.45)
	result.acceleration *= 1.0 + minf(tier * 0.025, 0.22)
	result.max_speed = minf(220.0, result.max_speed + minf(tier * 2.0, 18.0))
	if elite:
		result.max_health *= 1.45
		result.damage_resistance = minf(0.55, result.damage_resistance + 0.08)
		result.weapon_damage_multiplier += 0.14
		result.ram_power += 0.15
	if boss:
		result.max_health *= 2.65
		result.engine_health *= 1.8
		result.wheels_health *= 1.8
		result.damage_resistance = minf(0.62, result.damage_resistance + 0.14)
		result.ram_power += 0.35
		# The first Arbiter is deliberately slow. Each completed wave teaches
		# the player the encounter at a higher pace, reaching the original
		# fifth-wave speed and then staying capped there.
		var speed_progress := clampf(float(_round - 1) / 4.0, 0.0, 1.0)
		result.max_speed = lerpf(48.0, 92.0, speed_progress)
	return result


func _arena_strategy_for(rival_id: StringName) -> int:
	match rival_id:
		&"razor": return ArenaBot.Strategy.HUNTER
		&"bolt": return ArenaBot.Strategy.SCAVENGER
		&"nyx": return ArenaBot.Strategy.HUNTER
		&"grit": return ArenaBot.Strategy.BRAWLER
	return ArenaBot.Strategy.SURVIVOR


func _spawn_biker_squad() -> int:
	if not is_instance_valid(_boss) or not _boss.alive or _round_over or not player.alive:
		return 0
	if _alive_biker_count() > 0:
		return 0
	var forward := Vector2.RIGHT.rotated(_boss.rotation)
	var side := forward.rotated(PI * 0.5)
	var bounds := arena.get_bounds().grow(-42.0)
	var spawned := 0
	var accepted_positions: Array[Vector2] = []
	for index in BIKERS_PER_SQUAD:
		var row := index / 3
		var lane := float(index % 3) - 1.0
		var position := _boss.global_position - forward * (82.0 + float(row) * 52.0) + side * lane * 42.0
		position = _find_clear_biker_spawn(position, accepted_positions, bounds, forward)
		if not position.is_finite(): continue
		_spawn_biker(position, _boss.rotation, index)
		accepted_positions.append(position)
		spawned += 1
	_round_enemy_total += spawned
	_biker_squads_deployed += 1
	if spawned > 0:
		hud.show_message("АРБИТР ВЫПУСКАЕТ СТАЮ · МОТОЦИКЛИСТЫ ×%d" % spawned, 2.0)
		audio.play_event_cue(&"critical")
	return spawned


func _find_clear_biker_spawn(
	preferred: Vector2,
	accepted_positions: Array[Vector2],
	bounds: Rect2,
	forward: Vector2
) -> Vector2:
	var candidates: Array[Vector2] = [preferred]
	# Near a wall the formation would otherwise be clamped into one pile. Fan
	# fallback candidates around the Referee until each rider owns a clear lane.
	for radius in [105.0, 155.0, 210.0]:
		for slot in 12:
			var offset_angle := PI + (float(slot) - 5.5) * (TAU / 12.0)
			candidates.append(_boss.global_position + forward.rotated(offset_angle) * radius)
	for candidate in candidates:
		candidate.x = clampf(candidate.x, bounds.position.x, bounds.end.x)
		candidate.y = clampf(candidate.y, bounds.position.y, bounds.end.y)
		if _biker_spawn_is_clear(candidate, accepted_positions) and arena.navigation().free_distance(candidate, forward, 85.0, 20.0) > 60.0:
			return candidate
	# Search nearby open lanes instead of placing a rider inside a small prop.
	var fallback := Vector2(INF, INF)
	var nearest := INF
	for y in range(int(bounds.position.y), int(bounds.end.y), 50):
		for x in range(int(bounds.position.x), int(bounds.end.x), 50):
			var candidate := Vector2(x, y)
			var distance := candidate.distance_squared_to(preferred)
			if distance < nearest and _biker_spawn_is_clear(candidate, accepted_positions) and arena.navigation().free_distance(candidate, forward, 85.0, 20.0) > 60.0:
				nearest = distance
				fallback = candidate
	return fallback


func _biker_spawn_is_clear(position: Vector2, accepted_positions: Array[Vector2]) -> bool:
	if not arena.navigation().point_clear(position, 34.0):
		return false
	for obstacle in arena.get_obstacles():
		if obstacle.grow(34.0).has_point(position):
			return false
	for accepted in accepted_positions:
		if accepted.distance_squared_to(position) < 50.0 * 50.0:
			return false
	for node in get_tree().get_nodes_in_group("combatants"):
		var body := node as Node2D
		if is_instance_valid(body) and body.global_position.distance_squared_to(position) < 62.0 * 62.0:
			return false
	return true


func _spawn_biker(spawn: Vector2, angle: float, index: int) -> Vehicle:
	var biker := bot_scene.instantiate() as Vehicle
	biker.config = REFEREE_BIKER.duplicate() as VehicleConfig
	# Keep them fast throughout the run, but never grow them into armoured cars.
	biker.config.max_speed = minf(184.0, biker.config.max_speed + float(maxi(_round - 1, 0)) * 0.35)
	biker.set_meta("biker", true)
	biker.set_meta("elite", false)
	biker.set_meta("boss", false)
	biker.set_meta("exclusive_vehicle", true)
	biker.set_meta("squad_id", &"referee")
	biker.set_meta("boss_name", "")
	add_child(biker)
	biker.global_position = spawn
	biker.rotation = angle + (float(index % 3) - 1.0) * 0.08
	biker.died.connect(_on_vehicle_died)
	biker.impacted.connect(audio.play_collision)
	biker.damaged.connect(_on_vehicle_damaged)
	biker.add_to_group("combatants")
	biker.activate_temporary_weapon(BIKER_PISTOL, 9999.0)

	var controller := ArenaBot.new()
	controller.name = "ArenaBot"
	controller.add_to_group("arena_bots")
	controller.arena = arena
	controller.strategy = ArenaBot.Strategy.HUNTER
	controller.team_role = ArenaBot.TeamRole.FLANKER if index % 2 == 0 else ArenaBot.TeamRole.NONE
	controller.focus_player = true
	controller.cruise_throttle = 1.0
	controller.preferred_range = 195.0 + float(index % 3) * 24.0
	controller.avoid_radius = 112.0
	controller.avoid_weight = 2.75
	controller.wall_avoid_margin = 95.0
	controller.hazard_avoid_radius = 125.0
	controller.stuck_speed = 16.0
	controller.stuck_timeout = 0.62
	controller.reverse_duration = 0.9
	controller.fire_range = 390.0
	controller.fire_angle = 0.31
	controller.retreat_health_ratio = 0.0
	biker.add_child(controller)
	controller.preferred_range = 195.0 + float(index % 3) * 24.0
	_enemies.append(biker)
	return biker


func _alive_biker_count() -> int:
	var count := 0
	for enemy in _enemies:
		if is_instance_valid(enemy) and enemy.alive and bool(enemy.get_meta("biker", false)):
			count += 1
	return count


func _spawn_crew_from_vehicle(vehicle: Vehicle) -> int:
	if vehicle == null or bool(vehicle.get_meta("boss", false)) or bool(vehicle.get_meta("biker", false)):
		return 0
	if bool(vehicle.get_meta("crew_released", false)):
		return 0
	vehicle.set_meta("crew_released", true)
	return _spawn_crew_at(vehicle.global_position, vehicle.global_rotation, Vector2(vehicle.config.length, vehicle.config.width))


func _queue_crew_from_vehicle(vehicle: Vehicle) -> void:
	if vehicle == null or bool(vehicle.get_meta("boss", false)) or bool(vehicle.get_meta("biker", false)):
		return
	if bool(vehicle.get_meta("crew_released", false)):
		return
	# Vehicle deaths may be delivered while PhysicsServer is flushing contacts.
	# Capture the wreck position and add the Area2D runners on the deferred frame.
	vehicle.set_meta("crew_released", true)
	_spawn_crew_deferred.call_deferred(vehicle.global_position, vehicle.global_rotation, Vector2(vehicle.config.length, vehicle.config.width), _round_generation)


func _spawn_crew_deferred(wreck_position: Vector2, wreck_rotation: float, wreck_size: Vector2, generation: int) -> void:
	if generation == _round_generation and _events_allowed():
		_spawn_crew_at(wreck_position, wreck_rotation, wreck_size)


func _spawn_crew_at(wreck_position: Vector2, wreck_rotation: float, wreck_size: Vector2) -> int:
	if _session_finished: return 0
	var outward := arena.get_bounds().get_center().direction_to(wreck_position)
	if outward.is_zero_approx():
		outward = Vector2.RIGHT
	var spawned := 0
	for role in [EscapingCrew.Role.PILOT, EscapingCrew.Role.MECHANIC]:
		var side := -1.0 if role == EscapingCrew.Role.PILOT else 1.0
		var direction := outward.rotated(side * 0.72).normalized()
		var crew := ESCAPING_CREW_SCENE.instantiate() as EscapingCrew
		crew.setup(role, arena, direction)
		add_child(crew)
		var local_direction := direction.rotated(-wreck_rotation)
		var half_length := wreck_size.x * Vehicle.COLLISION_SCALE.x * 0.5
		var half_width := wreck_size.y * Vehicle.COLLISION_SCALE.y * 0.5
		var exit_distance := minf(
			half_length / maxf(absf(local_direction.x), 0.001),
			half_width / maxf(absf(local_direction.y), 0.001)
		)
		crew.global_position = wreck_position + direction * (exit_distance + 13.0)
		var generation := _round_generation
		crew.crushed.connect(func(runner, vehicle):
			if generation == _round_generation: _on_crew_crushed(runner, vehicle))
		crew.weapon_killed.connect(func(runner, attacker):
			if generation == _round_generation: _on_crew_weapon_killed(runner, attacker))
		crew.escaped.connect(func(runner):
			if generation == _round_generation: _on_crew_escaped(runner))
		spawned += 1
	return spawned


func _on_crew_crushed(crew: EscapingCrew, crushing_vehicle: Vehicle) -> void:
	if crew == null or not _events_allowed():
		return
	_leave_crew_remains(crew)
	if crushing_vehicle != player or _round_over:
		return
	_crew_crushed += 1
	_award_crew_score(crew, CREW_CRUSH_SCORE)


func _on_crew_weapon_killed(crew: EscapingCrew, attacker: Node) -> void:
	if crew == null or not _events_allowed():
		return
	_leave_crew_remains(crew)
	if attacker != player or _round_over:
		return
	_crew_weapon_killed += 1
	_award_crew_score(crew, CREW_WEAPON_SCORE)


func _leave_crew_remains(crew: EscapingCrew) -> void:
	var remains := CREW_REMAINS_SCENE.instantiate() as CrewRemains
	remains.setup(crew.role)
	add_child(remains)
	remains.global_position = crew.global_position
	remains.rotation = crew.rotation + randf_range(-0.35, 0.35)


func _award_crew_score(crew: EscapingCrew, base_score: int) -> void:
	_combo += 1
	_best_combo = maxi(_best_combo, _combo)
	_combo_timer = maxf(_combo_timer, 5.0)
	var reward := base_score + (_combo - 1) * 55
	_score += reward
	hud.show_message("ЭКИПАЖ НЕ УШЁЛ · +%d · КОМБО x%d" % [reward, _combo], 1.25)
	audio.play_event_cue(&"impact")
	camera.kick(-crew.escape_direction, 3.0)


func _on_crew_escaped(_crew: EscapingCrew) -> void:
	if not _events_allowed(): return
	_crew_escaped += 1


func _active_crew_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("escaping_crew"):
		# Only one survival scene exists; the ancestry check also protects editor
		# tests that may instantiate an isolated crew object next to the game.
		if is_instance_valid(node) and is_ancestor_of(node):
			count += 1
	return count


func _on_vehicle_died(vehicle: Vehicle) -> void:
	if not _events_allowed(): return
	if vehicle != player and not _enemies.has(vehicle): return
	audio.play_explosion()
	var vfx := get_tree().get_first_node_in_group("combat_vfx") as CombatVFX
	if vfx != null: vfx.spawn_explosion(vehicle.global_position, Color(1.0, 0.36, 0.06), 90.0)
	if vehicle == player:
		hud.explosion_flash()
		hud.finish_cinematic(true)
		if &"second_wind" in _perk_effects and not _second_wind_used and not _round_over:
			_second_wind_used = true
			player.reset_to(player.global_position, player.rotation)
			player.damage.body = player.config.max_health * 0.32
			player.damage.engine = player.config.engine_health * 0.45
			player.damage.wheels = player.config.wheels_health * 0.55
			player.add_to_group("combatants")
			hud.finish_cinematic(false)
			hud.show_message("ВТОРОЕ ДЫХАНИЕ · МАШИНА СНОВА В БОЮ", 2.0)
			audio.play_event_cue(&"repair")
			return
	if _round_over:
		return
	if vehicle == player:
		_end_round(false)
		return
	_queue_crew_from_vehicle(vehicle)
	if vehicle.last_attacker == player:
		_kills += 1
		_combo += 1
		_best_combo = maxi(_best_combo, _combo)
		_combo_timer = 7.0
		var elite_bonus := 1.35 if bool(vehicle.get_meta("elite", false)) and &"elite_score" in _perk_effects else 1.0
		var base_score := 210.0 if bool(vehicle.get_meta("biker", false)) else 450.0
		var combo_step := 65.0 if bool(vehicle.get_meta("biker", false)) else 110.0
		_score += roundi((base_score + _combo * combo_step) * (1.0 + _combo * 0.2) * elite_bonus)
		if bool(vehicle.get_meta("boss", false)):
			_boss_kills += 1
			_score += roundi(4000.0 * elite_bonus)
		if &"kill_repair" in _perk_effects: player.repair(12.0, 8.0, 8.0)
		if &"volatile_wrecks" in _perk_effects:
			for other in _enemies:
				if is_instance_valid(other) and other != vehicle and other.alive and other.global_position.distance_to(vehicle.global_position) <= 135.0:
					other.take_damage(24.0, &"body", player)
		if vehicle.last_weapon_id != &"":
			_weapon_kills += 1
		_award_credits(PlayerProfile.economy().survival_kill_reward)
	# Keep wrecks owned until the next round, so they can be cleaned up.
	if _alive_enemies() == 0:
		_complete_combat_phase()
	else:
		var enemies_alive := _alive_enemies()
		hud.update_status(player, enemies_alive + _pending_enemies.size(), _round, _destroyed_enemies(enemies_alive))


func _complete_combat_phase() -> void:
	if not _events_allowed() or not player.alive or _alive_enemies() != 0 or not _pending_enemies.is_empty():
		return
	if bool(_wave_plan.get("boss", false)) and not _referee_spawned:
		_request_referee_spawn()
	else:
		_end_round(true)


func _end_round(won: bool) -> void:
	# Several deaths can be delivered in one frame. Never pay rewards or write
	# records twice when signal and recovery polling observe the same finale.
	if _round_over:
		return
	_round_over = true
	_round_enemy_total -= _pending_enemies.size()
	_pending_enemies.clear()
	_reinforcement_requested = false
	hud.show_interaction("")
	_referee_spawn_pending = false
	_player_won = won
	if won:
		var reward := PlayerProfile.economy().survival_round_reward
		_award_credits(reward)
		var total_credits := int(PlayerProfile.read().credits)
		if not career_event.is_empty() and _round >= int(career_event.get("target_rounds", 2)):
			_finish_career_contract(reward)
			return
		_round_timer = round_end_delay
		hud.show_message("ВОЛНА %d ПРОЙДЕНА · СЧЁТ %d\n+%d CREDITS   ВСЕГО %d" % [_round, _score, reward, total_credits], round_end_delay)
	else:
		_round_timer = 0.0
		_finish_session()
		hud.show_message("ПОРАЖЕНИЕ — РАУНД %d (R — заново)" % _round, 999.0)
		var run_result := _run_result(&"DEFEAT")
		PlayerProfile.record_vehicle_result(LoadoutProfile.read_ids().vehicle, &"survival", run_result)
		run_result.merge(PlayerProfile.record_survival_run(run_result), true)
		if not career_event.is_empty():
			var career_summary := CareerSession.record_result(run_result)
			run_result.merge(career_summary, true)
			run_result.career_event = true
			run_result.credits = int(run_result.credits) + int(career_summary.get("career_bonus", 0))
		results.show_result(run_result)


func _finish_career_contract(_round_reward: int) -> void:
	_round_timer = 0.0
	_finish_session()
	hud.show_message("КОНТРАКТ ВЫПОЛНЕН", 999.0)
	var run_result := _run_result(&"VICTORY")
	PlayerProfile.record_vehicle_result(LoadoutProfile.read_ids().vehicle, &"survival", run_result)
	run_result.merge(PlayerProfile.record_survival_run(run_result), true)
	var career_summary := CareerSession.record_result(run_result)
	run_result.merge(career_summary, true)
	run_result.career_event = true
	run_result.credits = int(run_result.credits) + int(career_summary.get("career_bonus", 0))
	results.show_result(run_result)


func _run_result(status: StringName) -> Dictionary:
	return {
		"status": status, "round": _round, "kills": _kills, "weapon_kills": _weapon_kills,
		"damage": _damage_dealt, "time": _elapsed, "credits": _credits_earned,
		"score": _score, "best_combo": _best_combo, "boss_kills": _boss_kills,
		"crew_crushed": _crew_crushed, "crew_weapon_killed": _crew_weapon_killed, "crew_escaped": _crew_escaped,
		"build": _run_perks.map(func(perk): return perk.name),
		"arena": arena.config.biome_name,
		"daily_key": SurvivalRunData.daily_key() if SurvivalRunData.daily_mode else "",
	}


func _alive_enemies() -> int:
	var count := 0
	for enemy in _enemies:
		if is_instance_valid(enemy) and enemy.alive:
			count += 1
	return count


func _destroyed_enemies(enemies_alive: int = -1) -> int:
	if enemies_alive < 0:
		enemies_alive = _alive_enemies()
	return maxi(0, _round_enemy_total - enemies_alive - _pending_enemies.size())

func _award_credits(amount: int) -> void:
	amount = roundi(amount * AccessibilitySettings.reward_multiplier())
	_credits_earned += amount
	var profile := PlayerProfile.read()
	profile.credits = int(profile.credits) + amount
	PlayerProfile.save(profile)

func _on_vehicle_damaged(target: Vehicle, amount: float, source: Node) -> void:
	if not _events_allowed(): return
	if target != player and not _enemies.has(target): return
	_combat_idle = 0.0
	_hunt_announced = false
	if target != player and source == player:
		_damage_dealt += amount
		_score += roundi(amount * (8.0 + _combo * 1.5))
		var earned_blocks := floori(_damage_dealt / 100.0)
		if earned_blocks > _damage_reward_blocks:
			_award_credits((earned_blocks - _damage_reward_blocks) * PlayerProfile.economy().damage_reward_per_100)
			_damage_reward_blocks = earned_blocks
	elif target == player:
		_combo = 0
		_combo_timer = 0.0
		camera.shake(clampf(1.5 + amount * 0.12, 2.0, 7.0), 0.1)
		hud.impact_flash(amount)
		if is_instance_valid(source): camera.kick(target.global_position.direction_to(source.global_position), minf(amount * 0.25, 8.0))
		if target.is_emp_disabled():
			hud.emp_flash()
			audio.play_event_cue(&"emp")


func _on_player_damage_stage_changed(_vehicle: Vehicle, stage: int) -> void:
	if not _events_allowed(): return
	match stage:
		1: hud.show_message("КУЗОВ ПОЦАРАПАН", 0.8)
		2: hud.show_message("СЕРЬЁЗНЫЕ ПОВРЕЖДЕНИЯ", 1.0)
		3: hud.show_message("КРИТИЧЕСКОЕ СОСТОЯНИЕ", 1.2)
		4: hud.show_message("МАШИНА УНИЧТОЖЕНА", 1.2)

func _on_retry_requested() -> void:
	_request_round_start(1)


func _offer_upgrade() -> void:
	_choosing_perk = true
	var choices := SurvivalRunData.perk_choices(_round, _perk_ids)
	var repair_percent := 45 if &"wave_repair" in _perk_effects else 30
	upgrade_draft.show_choices(choices, _round, repair_percent)
	if DisplayServer.get_name() == "headless":
		# Keep automated round/death checks deterministic: Second Wind changes
		# the death contract by design, while human players choose it explicitly.
		var automated_choice: Dictionary = choices[0]
		for choice in choices:
			if choice.id != &"second_wind":
				automated_choice = choice
				break
		_select_perk_deferred.call_deferred(automated_choice, _round_generation)


func _select_perk_deferred(perk: Dictionary, generation: int) -> void:
	if generation == _round_generation and not _session_finished:
		_on_perk_selected(perk)


func _on_perk_selected(perk: Dictionary) -> void:
	if not _choosing_perk or _session_finished: return
	_choosing_perk = false
	upgrade_draft.hide()
	get_viewport().gui_release_focus()
	_run_perks.append(perk)
	_perk_ids.append(perk.id)
	var effect := StringName(perk.get("effect", &""))
	if effect != &"": _perk_effects.append(effect)
	_apply_run_perk(perk)
	hud.show_message("УСТАНОВЛЕНО: %s" % perk.name, 1.2)
	start_round(_round + 1)


func _apply_run_perk(perk: Dictionary) -> void:
	var body := player.damage.body
	var engine := player.damage.engine
	var wheels := player.damage.wheels
	var upgraded := player.config.duplicate() as VehicleConfig
	for key in perk.get("modifiers", {}):
		if key in upgraded:
			upgraded.set(key, float(upgraded.get(key)) + float(perk.modifiers[key]))
	player.reconfigure(upgraded)
	player.damage.body = minf(body, upgraded.max_health)
	player.damage.engine = minf(engine, upgraded.engine_health)
	player.damage.wheels = minf(wheels, upgraded.wheels_health)


func _update_combat_director() -> void:
	if _combat_idle >= 9.0 and not _hunt_announced:
		_hunt_announced = true
		for enemy in _enemies:
			if not is_instance_valid(enemy) or not enemy.alive: continue
			enemy.last_attacker = player
			var controller := enemy.get_node_or_null("ArenaBot") as ArenaBot
			if controller != null:
				controller.focus_player = true
				controller.cruise_throttle = minf(1.0, controller.cruise_throttle + 0.08)
		hud.show_message("РЕЖИССЁР: ОХОТА НА ИГРОКА", 1.6)
	if _combat_idle >= 18.0:
		_combat_idle = 0.0
		_hunt_announced = false
		if bonus_spawner != null: bonus_spawner.spawn_random_bonus(BonusPickup.Kind.WEAPON)
	if _round_elapsed >= 72.0 and not _sudden_death:
		_sudden_death = true
		for enemy in _enemies:
			if not is_instance_valid(enemy): continue
			var controller := enemy.get_node_or_null("ArenaBot") as ArenaBot
			if controller != null:
				controller.focus_player = true
				controller.cruise_throttle = 1.0
				controller.fire_range += 120.0
		if arena_hazards != null: arena_hazards._clock = minf(arena_hazards._clock, 2.0)
		hud.show_message("ВНЕЗАПНАЯ СМЕРТЬ · ВСЕ ПРОТИВ ВАС", 2.0)
		audio.play_event_cue(&"critical")


func _update_boss(delta: float) -> void:
	if not is_instance_valid(_boss) or not _boss.alive: return
	var ratio := _boss.health / maxf(_boss.config.max_health, 1.0)
	var phase := 3 if ratio <= 0.33 else (2 if ratio <= 0.66 else 1)
	if phase != _boss_phase:
		_boss_phase = phase
		var referee := _boss.get_node_or_null("RefereeBoss") as RefereeBoss
		if referee != null:
			referee.set_phase(phase)
		var phase_name: String = ["", "ПРИГОВОР", "ЯРОСТЬ", "КАЗНЬ"][phase]
		hud.show_message("АРБИТР · ФАЗА %d · %s" % [phase, phase_name], 1.8)
		audio.play_event_cue(&"critical")
	_boss_ability_timer -= delta
	if _boss_ability_timer <= 0.0:
		_boss_ability_timer = maxf(3.8, 7.5 - _boss_phase)
		for enemy in _enemies:
			if is_instance_valid(enemy) and enemy.alive:
				enemy.last_attacker = player
	# The cooldown only runs while the arena is clear of riders. Otherwise a
	# long-lived squad could be replaced almost immediately after its last loss.
	if _alive_biker_count() == 0:
		_biker_deploy_timer -= delta
		if _biker_deploy_timer <= 0.0:
			_spawn_biker_squad()
			_biker_deploy_timer = BIKER_DEPLOY_INTERVAL


func _on_referee_flame_warning() -> void:
	if not _round_over:
		hud.show_message("АРБИТР: ОГНЕННЫЙ ЗАЛП", 1.1)
		audio.play_event_cue(&"critical")


func _on_bonus_announced(kind: BonusPickup.Kind, _world_position: Vector2, duration: float) -> void:
	if not _events_allowed(): return
	var delivery := "ПАРТИЯ ×%d · ОРУЖИЕ И ПОДДЕРЖКА" % bonus_spawner.batch_size if bonus_spawner != null and bonus_spawner.batch_size > 1 else BonusPickup.kind_label(kind)
	hud.show_message("ДОСТАВКА: %s\nАКТИВАЦИЯ ЧЕРЕЗ %.0f С" % [delivery, duration], duration)
	audio.play_event_cue(&"countdown")


func _on_bonus_collected(vehicle: Vehicle, kind: BonusPickup.Kind) -> void:
	if not _events_allowed(): return
	var message := "ВЫ ЗАБРАЛИ" if vehicle == player else "СОПЕРНИК ЗАБРАЛ"
	hud.show_message("%s: %s" % [message, BonusPickup.kind_label(kind)], 1.4)
	if vehicle == player:
		_score += 180 + _combo * 25
		if &"weapon_duration" in _perk_effects and kind == BonusPickup.Kind.WEAPON:
			player.weapon_time_remaining *= 1.35
		if &"supply_magnet" in _perk_effects:
			match kind:
				BonusPickup.Kind.WEAPON: player.weapon_time_remaining *= 1.45
				BonusPickup.Kind.SPEED_BOOST: player.boost_time_remaining *= 1.45
				BonusPickup.Kind.RAM_BOOST: player.ram_boost_time_remaining *= 1.45
		audio.play_event_cue(&"repair" if kind == BonusPickup.Kind.REPAIR else &"pickup")
		hud.pickup_flash(Color(0.3, 1.0, 0.55) if kind == BonusPickup.Kind.REPAIR else Color(0.25, 0.82, 1.0))
		hud.readout.update_vehicle(player)
		camera.focus_pulse(-0.025)
	var vfx := get_tree().get_first_node_in_group("combat_vfx") as CombatVFX
	if vfx != null: vfx.spawn_pickup(vehicle.global_position, Color(0.3, 1.0, 0.55) if kind == BonusPickup.Kind.REPAIR else Color(0.25, 0.82, 1.0))


func _clear_enemies() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.hide()
			enemy.remove_from_group("combatants")
			enemy.queue_free()
	_enemies.clear()


func _clear_crew() -> void:
	for group_name in [&"escaping_crew", &"crew_remains"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node) and is_ancestor_of(node):
				node.process_mode = Node.PROCESS_MODE_DISABLED
				node.hide()
				node.queue_free()


func _clear_bullets() -> void:
	for bullet in bullets.get_children():
		bullet.free()


func _on_weapon_fired() -> void:
	if not _events_allowed(): return
	audio.play_weapon_fire(player.gun.config)
	var recoil := 9.0 if player.gun.config.weapon_type in [WeaponConfig.WeaponType.ROCKET, WeaponConfig.WeaponType.SHOTGUN] else 3.5
	camera.kick(-Vector2.RIGHT.rotated(player.global_rotation), recoil)

func _on_player_impact(intensity: float) -> void:
	if not _events_allowed(): return
	camera.shake(3.0 + intensity * 7.0, 0.12)

func _on_barrel_exploded(_position: Vector2, _radius: float, generation: int = -1) -> void:
	if not _events_allowed() or (generation >= 0 and generation != _arena_generation): return
	audio.play_explosion()
	camera.shake(13.0, 0.28)
	hud.explosion_flash()
	var vfx := get_tree().get_first_node_in_group("combat_vfx") as CombatVFX
	if vfx != null: vfx.spawn_explosion(_position, Color(1.0, 0.38, 0.06), _radius)


func _engine_intensity() -> float:
	if player.config == null or player.config.max_speed <= 0.0:
		return 0.0
	return clampf(absf(player.get_forward_speed()) / player.config.max_speed, 0.0, 1.0)
