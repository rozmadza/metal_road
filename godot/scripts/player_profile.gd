extends RefCounted
class_name PlayerProfile

const PATH := "user://profile.cfg"
const VERSION := 10
static var path_override := ""
static var active_slot := 1
const ECONOMY_PATH := "res://resources/economy_config.tres"
const UPGRADE_PATHS := {
	&"engine_1": "res://resources/upgrades/engine_1.tres",
	&"engine_2": "res://resources/upgrades/engine_2.tres",
	&"engine_3": "res://resources/upgrades/engine_3.tres",
	&"armor_1": "res://resources/upgrades/armor_1.tres",
	&"armor_2": "res://resources/upgrades/armor_2.tres",
	&"armor_3": "res://resources/upgrades/armor_3.tres",
	&"wheels_1": "res://resources/upgrades/wheels_1.tres",
	&"wheels_2": "res://resources/upgrades/wheels_2.tres",
	&"wheels_3": "res://resources/upgrades/wheels_3.tres",
	&"armament_1": "res://resources/upgrades/armament_1.tres",
	&"armament_2": "res://resources/upgrades/armament_2.tres",
	&"armament_3": "res://resources/upgrades/armament_3.tres",
	&"handling_1": "res://resources/upgrades/handling_1.tres",
	&"durability_1": "res://resources/upgrades/durability_1.tres",
	&"weapon_damage_1": "res://resources/upgrades/weapon_damage_1.tres",
	&"weapon_rate_1": "res://resources/upgrades/weapon_rate_1.tres",
	&"dustfox_scavenger": "res://resources/upgrades/dustfox_scavenger.tres",
	&"dustfox_runner": "res://resources/upgrades/dustfox_runner.tres",
	&"needle_redline": "res://resources/upgrades/needle_redline.tres",
	&"needle_ghost": "res://resources/upgrades/needle_ghost.tres",
	&"warhound_suppressor": "res://resources/upgrades/warhound_suppressor.tres",
	&"warhound_hunter": "res://resources/upgrades/warhound_hunter.tres",
	&"bastion_siege": "res://resources/upgrades/bastion_siege.tres",
	&"bastion_fortress": "res://resources/upgrades/bastion_fortress.tres",
}
const VEHICLE_UPGRADE_CATEGORIES := [&"engine", &"armor", &"wheels", &"weapon"]
const VEHICLE_UPGRADE_IDS := {
	&"engine": [&"engine_1", &"engine_2", &"engine_3"],
	&"armor": [&"armor_1", &"armor_2", &"armor_3"],
	&"wheels": [&"wheels_1", &"wheels_2", &"wheels_3"],
	&"weapon": [&"armament_1", &"armament_2", &"armament_3"],
}
const VEHICLE_SPECIALIZATION_IDS := {
	&"dustfox": [&"dustfox_scavenger", &"dustfox_runner"],
	&"needle": [&"needle_redline", &"needle_ghost"],
	&"warhound": [&"warhound_suppressor", &"warhound_hunter"],
	&"bastion": [&"bastion_siege", &"bastion_fortress"],
}
## Reversible class builds. Permanent module levels answer "how powerful is
## the car", while a build answers "how does it fight today". Every bonus has
## a visible trade-off so there is no universally correct preset.
const VEHICLE_BUILD_PROFILES := {
	0: [
		{"id": &"factory", "name": "ШТАТНАЯ", "unlock": 0, "description": "Сбалансированная заводская настройка без штрафов.", "modifiers": {}},
		{"id": &"raider_scavenger", "name": "СТАЛКЕР", "unlock": 2, "description": "Полевой ремонт и живучесть узлов; ниже максимальная скорость.", "modifiers": {"engine_health": 12.0, "wheels_health": 14.0, "wheels_repair_rate": 1.4, "engine_damage_multiplier": -0.08, "wheels_damage_multiplier": -0.10, "max_speed": -7.0}},
		{"id": &"raider_runner", "name": "КУРЬЕР", "unlock": 5, "description": "Темп и контроль для сбора бонусов; облегчённый кузов хуже держит удар.", "modifiers": {"max_speed": 9.0, "acceleration": 110.0, "traction": 1.4, "passive_bonus_duration_multiplier": 0.12, "max_health": -12.0, "body_damage_multiplier": 0.10}},
	],
	1: [
		{"id": &"factory", "name": "ШТАТНАЯ", "unlock": 0, "description": "Сбалансированная заводская настройка без штрафов.", "modifiers": {}},
		{"id": &"interceptor_apex", "name": "АПЕКС", "unlock": 2, "description": "Предельный разгон и скорость; двигатель ещё уязвимее.", "modifiers": {"max_speed": 12.0, "acceleration": 150.0, "passive_apex_duration": 0.7, "engine_damage_multiplier": 0.12, "max_health": -8.0}},
		{"id": &"interceptor_ghost", "name": "ПРИЗРАК", "unlock": 5, "description": "Точная ходовая и защищённые колёса; меньше огневой мощи.", "modifiers": {"steer_rate": 0.55, "traction": 2.2, "wheels_damage_multiplier": -0.18, "wheels_repair_rate": 0.8, "weapon_damage_multiplier": -0.10}},
	],
	2: [
		{"id": &"factory", "name": "ШТАТНАЯ", "unlock": 0, "description": "Сбалансированная заводская настройка без штрафов.", "modifiers": {}},
		{"id": &"assault_gunship", "name": "КАНОНЕРКА", "unlock": 2, "description": "Максимальный урон и темп огня; слабее броня и ходовая.", "modifiers": {"weapon_damage_multiplier": 0.18, "weapon_fire_rate_multiplier": 0.14, "damage_resistance": -0.05, "wheels_damage_multiplier": 0.12}},
		{"id": &"assault_breacher", "name": "ПРОЛОМ", "unlock": 5, "description": "Таран и защищённый силовой блок; хуже поворачивает.", "modifiers": {"ram_power": 0.24, "max_health": 14.0, "engine_damage_multiplier": -0.14, "steer_rate": -0.45, "traction": -1.0}},
	],
	3: [
		{"id": &"factory", "name": "ШТАТНАЯ", "unlock": 0, "description": "Сбалансированная заводская настройка без штрафов.", "modifiers": {}},
		{"id": &"juggernaut_fortress", "name": "КРЕПОСТЬ", "unlock": 2, "description": "Тяжёлая защита кузова и узлов; заметно ниже темп движения.", "modifiers": {"max_health": 24.0, "damage_resistance": 0.07, "body_damage_multiplier": -0.10, "engine_damage_multiplier": -0.10, "max_speed": -10.0, "acceleration": -100.0}},
		{"id": &"juggernaut_ram", "name": "ТАРАН", "unlock": 5, "description": "Разгон массы и сокрушительный удар; менее стабильная ходовая.", "modifiers": {"ram_power": 0.32, "acceleration": 120.0, "wheels_health": 12.0, "steer_rate": -0.35, "wheels_damage_multiplier": 0.10}},
	],
}

static func economy() -> EconomyConfig:
	return load(ECONOMY_PATH) as EconomyConfig

static func read() -> Dictionary:
	var cfg := ConfigFile.new()
	var err := cfg.load(_path())
	if err == OK and not _profile_config_is_valid(cfg):
		err = ERR_FILE_CORRUPT
	if err != OK:
		# Version 7 introduced three protected profile slots. Migrate the old
		# single-profile save into slot one without touching the original file.
		if path_override.is_empty() and active_slot == 1 and FileAccess.file_exists(PATH):
			_ensure_profile_directory()
			DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(_path()))
			err = cfg.load(_path())
			if err == OK and not _profile_config_is_valid(cfg):
				err = ERR_FILE_CORRUPT
	if err != OK:
		# Recover transparently from an interrupted/corrupt write.
		if FileAccess.file_exists(_backup_path()):
			err = cfg.load(_backup_path())
			if err == OK and not _profile_config_is_valid(cfg):
				err = ERR_FILE_CORRUPT
			if err == OK:
				DirAccess.copy_absolute(ProjectSettings.globalize_path(_backup_path()), ProjectSettings.globalize_path(_path()))
	if err != OK:
		var defaults := _default_profile()
		save(defaults)
		return defaults
	var version := int(cfg.get_value("profile", "save_version", 1))
	var owned := _names(cfg.get_value("profile", "owned_vehicles", PackedStringArray(["raider"])))
	var raw_states: Dictionary = cfg.get_value("profile", "vehicle_states", {})
	var states := _normalized_states(raw_states, owned)
	var legacy_upgrades := _names(cfg.get_value("profile", "vehicle_upgrades", PackedStringArray()))
	var selected_vehicle: StringName = LoadoutProfile.read_ids().vehicle
	if version < 2 and not legacy_upgrades.is_empty():
		var migration_id := selected_vehicle if selected_vehicle in owned else &"raider"
		var migrated: Dictionary = states.get(String(migration_id), _default_vehicle_state())
		migrated.upgrades = legacy_upgrades.duplicate()
		states[String(migration_id)] = migrated
	var data := {
		"credits": int(cfg.get_value("profile", "credits", economy().starting_credits)),
		"vehicles": owned,
		"weapons": _names(cfg.get_value("profile", "owned_weapons", PackedStringArray(["machine_gun"]))),
		"vehicle_states": states,
		"weapon_upgrades": _names(cfg.get_value("profile", "weapon_upgrades", PackedStringArray())),
		"career": _normalize_career_state(cfg.get_value("profile", "career", {})),
	}
	var career_unlocks_changed := _sync_career_vehicle_unlocks(data)
	data.vehicle_upgrades = _state_from_data(data, selected_vehicle).upgrades.duplicate()
	if version < VERSION or career_unlocks_changed:
		save(data)
	return data

static func save(data: Dictionary) -> bool:
	var owned: Array = _names(data.get("vehicles", [&"raider"]))
	var states := _normalized_states(data.get("vehicle_states", {}), owned)
	# Accept old in-memory profile dictionaries during the migration window.
	if data.has("vehicle_upgrades") and states.values().all(func(state): return (state as Dictionary).upgrades.is_empty()):
		var selected: StringName = LoadoutProfile.read_ids().vehicle
		if selected not in owned:
			selected = &"raider"
		var selected_state: Dictionary = states.get(String(selected), _default_vehicle_state())
		selected_state.upgrades = _names(data.vehicle_upgrades)
		states[String(selected)] = selected_state
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "save_version", VERSION)
	cfg.set_value("profile", "credits", int(data.get("credits", economy().starting_credits)))
	cfg.set_value("profile", "owned_vehicles", PackedStringArray(_strings(owned)))
	cfg.set_value("profile", "owned_weapons", PackedStringArray(_strings(data.get("weapons", [&"machine_gun"]))))
	cfg.set_value("profile", "vehicle_states", states)
	cfg.set_value("profile", "weapon_upgrades", PackedStringArray(_strings(data.get("weapon_upgrades", []))))
	cfg.set_value("profile", "career", _normalize_career_state(data.get("career", {})))
	_ensure_profile_directory()
	var target := _path()
	var temporary := target + ".tmp"
	if cfg.save(temporary) != OK:
		push_error("Could not write temporary player profile: %s" % temporary)
		return false
	# Never replace a usable profile with an incomplete temporary file.
	var validation := ConfigFile.new()
	if validation.load(temporary) != OK or int(validation.get_value("profile", "save_version", 0)) != VERSION:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		push_error("Temporary player profile failed validation: %s" % temporary)
		return false
	var absolute_target := ProjectSettings.globalize_path(target)
	var absolute_temporary := ProjectSettings.globalize_path(temporary)
	var absolute_backup := ProjectSettings.globalize_path(_backup_path())
	if FileAccess.file_exists(target):
		var current := ConfigFile.new()
		# Preserve the last known-good backup if the primary file is corrupt.
		if current.load(target) == OK:
			DirAccess.copy_absolute(absolute_target, absolute_backup)
		DirAccess.remove_absolute(absolute_target)
	var rename_error := DirAccess.rename_absolute(absolute_temporary, absolute_target)
	if rename_error != OK:
		if FileAccess.file_exists(_backup_path()):
			DirAccess.copy_absolute(absolute_backup, absolute_target)
		push_error("Could not commit player profile: %s" % target)
		return false
	return true


static func set_active_slot(slot: int) -> void:
	active_slot = clampi(slot, 1, 3)


static func slot_summary(slot: int) -> Dictionary:
	var previous := active_slot
	active_slot = clampi(slot, 1, 3)
	var path := _path()
	if not FileAccess.file_exists(path):
		active_slot = previous
		return {"slot": slot, "exists": false, "label": "ПУСТОЙ ПРОФИЛЬ"}
	var data := read()
	var career: Dictionary = data.career
	var summary := {
		"slot": slot, "exists": true,
		"credits": int(data.credits),
		"level": int(career.career_level),
		"events": (career.completed_events as Array).size(),
		"driver": String(career.driver_id),
	}
	active_slot = previous
	return summary


static func erase_slot(slot: int) -> void:
	var previous := active_slot
	active_slot = clampi(slot, 1, 3)
	for path in [_path(), _backup_path(), _path() + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	active_slot = previous

static func is_owned(kind: StringName, id: StringName) -> bool:
	var data := read()
	return id in (data.vehicles if kind == &"vehicle" else data.weapons)

static func price(kind: StringName, id: StringName) -> int:
	var config := economy()
	return int(config.vehicle_prices.get(id, 0) if kind == &"vehicle" else config.weapon_prices.get(id, 0))

static func purchase(kind: StringName, id: StringName) -> bool:
	var data := read()
	if not purchase_data(data, kind, id):
		return false
	save(data)
	return true

static func purchase_data(data: Dictionary, kind: StringName, id: StringName) -> bool:
	var owned: Array = data.vehicles if kind == &"vehicle" else data.weapons
	if id in owned:
		return true
	if kind == &"vehicle" and not bool(vehicle_purchase_availability(id, data).allowed):
		return false
	var cost := price(kind, id)
	if int(data.credits) < cost:
		return false
	data.credits = int(data.credits) - cost
	owned.append(id)
	if kind == &"vehicle":
		data.vehicles = owned
		if not data.has("vehicle_states"):
			data.vehicle_states = {}
		data.vehicle_states[String(id)] = _default_vehicle_state()
	else:
		data.weapons = owned
	return true


static func vehicle_purchase_availability(id: StringName, data: Dictionary = {}) -> Dictionary:
	if data.is_empty(): data = read()
	var vehicle := LoadoutProfile.vehicle_config(id)
	if vehicle == null: return {"allowed": false, "reason": "НЕИЗВЕСТНАЯ МАШИНА"}
	if id in data.vehicles: return {"allowed": true, "reason": "МАШИНА В ГАРАЖЕ"}
	if vehicle.career_unlock_event != &"":
		var career: Dictionary = data.career
		var progress: Array = career.completed_objectives if vehicle.career_unlock_objective else career.completed_events
		if vehicle.career_unlock_event not in progress:
			return {"allowed": false, "reason": "НАГРАДА РЖАВОГО ФРОНТИРА"}
	if int(data.credits) < price(&"vehicle", id):
		return {"allowed": false, "reason": "НЕДОСТАТОЧНО CREDITS"}
	return {"allowed": true, "reason": "ДОСТУПНО ДЛЯ ПОКУПКИ"}

static func sell_vehicle(id: StringName) -> int:
	var data := read()
	var refund := sell_vehicle_data(data, id)
	if refund <= 0:
		return 0
	save(data)
	return refund

static func sell_vehicle_data(data: Dictionary, id: StringName) -> int:
	if id == &"raider" or id not in data.vehicles or data.vehicles.size() <= 1:
		return 0
	var refund := int(round(price(&"vehicle", id) * economy().vehicle_sell_ratio))
	data.vehicles.erase(id)
	data.credits = int(data.credits) + refund
	# State stays archived so selling and repurchasing never destroys progress.
	return refund

static func upgrade_config(id: StringName) -> UpgradeConfig:
	return load(UPGRADE_PATHS.get(id, "")) as UpgradeConfig

static func upgrade_ids(kind: StringName, vehicle_id: StringName = &"") -> Array:
	var data := read()
	if kind != &"vehicle":
		return data.weapon_upgrades
	return vehicle_upgrade_ids(vehicle_id, data)

static func vehicle_upgrade_ids(vehicle_id: StringName, data: Dictionary = {}) -> Array:
	if data.is_empty():
		data = read()
	if vehicle_id == &"":
		vehicle_id = LoadoutProfile.read_ids().vehicle
	return _state_from_data(data, vehicle_id).upgrades.duplicate()

static func vehicle_state(vehicle_id: StringName) -> Dictionary:
	return _state_from_data(read(), vehicle_id).duplicate(true)


static func career_state() -> Dictionary:
	return _normalize_career_state(read().get("career", {})).duplicate(true)


static func default_vehicle_state() -> Dictionary:
	return _default_vehicle_state()


static func vehicle_upgrade_level(vehicle_id: StringName, category: StringName, data: Dictionary = {}) -> int:
	var owned := vehicle_upgrade_ids(vehicle_id, data)
	var level := 0
	for id in VEHICLE_UPGRADE_IDS.get(category, []):
		if id in owned:
			var upgrade := upgrade_config(id)
			if upgrade != null:
				level = maxi(level, upgrade.level)
	return level


static func next_vehicle_upgrade(vehicle_id: StringName, category: StringName, data: Dictionary = {}) -> UpgradeConfig:
	var owned := vehicle_upgrade_ids(vehicle_id, data)
	for id in VEHICLE_UPGRADE_IDS.get(category, []):
		if id not in owned:
			return upgrade_config(id)
	return null


static func specialization_options(vehicle_id: StringName) -> Array[UpgradeConfig]:
	var result: Array[UpgradeConfig] = []
	for id in VEHICLE_SPECIALIZATION_IDS.get(vehicle_id, []):
		var upgrade := upgrade_config(id)
		if upgrade != null: result.append(upgrade)
	return result


static func installed_specialization(vehicle_id: StringName, data: Dictionary = {}) -> UpgradeConfig:
	var owned := vehicle_upgrade_ids(vehicle_id, data)
	for option in specialization_options(vehicle_id):
		if option.id in owned: return option
	return null


static func vehicle_build_options(vehicle_id: StringName) -> Array:
	var config := LoadoutProfile.vehicle_config(vehicle_id)
	if config == null: return []
	return (VEHICLE_BUILD_PROFILES.get(int(config.vehicle_class), []) as Array).duplicate(true)


static func vehicle_build_points(vehicle_id: StringName, data: Dictionary = {}) -> int:
	var result := 0
	for category in VEHICLE_UPGRADE_CATEGORIES:
		result += vehicle_upgrade_level(vehicle_id, category, data)
	return result


static func active_vehicle_build(vehicle_id: StringName, data: Dictionary = {}) -> Dictionary:
	if data.is_empty(): data = read()
	var selected: StringName = StringName(_state_from_data(data, vehicle_id).get("build", &"factory"))
	var options := vehicle_build_options(vehicle_id)
	for option in options:
		if StringName(option.id) == selected: return option
	return options[0] if not options.is_empty() else {}


static func vehicle_build_availability(vehicle_id: StringName, build_id: StringName, data: Dictionary = {}) -> Dictionary:
	if data.is_empty(): data = read()
	if vehicle_id not in data.vehicles:
		return {"allowed": false, "reason": "СНАЧАЛА КУПИТЕ МАШИНУ"}
	for option in vehicle_build_options(vehicle_id):
		if StringName(option.id) != build_id: continue
		var required := int(option.unlock)
		var points := vehicle_build_points(vehicle_id, data)
		if points < required:
			return {"allowed": false, "reason": "НУЖНО %d УРОВНЕЙ МОДУЛЕЙ · ЕСТЬ %d" % [required, points]}
		return {"allowed": true, "reason": "ГОТОВО К УСТАНОВКЕ"}
	return {"allowed": false, "reason": "НЕИЗВЕСТНАЯ СБОРКА"}


static func set_vehicle_build(vehicle_id: StringName, build_id: StringName) -> bool:
	var data := read()
	if not bool(vehicle_build_availability(vehicle_id, build_id, data).allowed): return false
	var state := _state_from_data(data, vehicle_id)
	state.build = build_id
	data.vehicle_states[String(vehicle_id)] = state
	return save(data)


static func upgrade_availability(id: StringName, vehicle_id: StringName, data: Dictionary = {}) -> Dictionary:
	if data.is_empty():
		data = read()
	var upgrade := upgrade_config(id)
	if upgrade == null:
		return {"allowed": false, "reason": "НЕИЗВЕСТНЫЙ МОДУЛЬ"}
	if vehicle_id not in data.vehicles:
		return {"allowed": false, "reason": "СНАЧАЛА КУПИТЕ МАШИНУ"}
	var owned := vehicle_upgrade_ids(vehicle_id, data)
	if id in owned:
		return {"allowed": false, "reason": "УЖЕ УСТАНОВЛЕНО"}
	if upgrade.required_upgrade != &"" and upgrade.required_upgrade not in owned:
		return {"allowed": false, "reason": "ТРЕБУЕТ ПРЕДЫДУЩИЙ УРОВЕНЬ"}
	var vehicle := LoadoutProfile.vehicle_config(vehicle_id)
	if vehicle == null or not upgrade.supports_class(int(vehicle.vehicle_class)) or not upgrade.supports_vehicle(vehicle_id):
		return {"allowed": false, "reason": "УРОВЕНЬ III НЕДОСТУПЕН ЭТОМУ КЛАССУ"}
	if upgrade.exclusive_group != &"":
		for owned_id in owned:
			var owned_upgrade := upgrade_config(owned_id)
			if owned_upgrade != null and owned_upgrade.exclusive_group == upgrade.exclusive_group:
				return {"allowed": false, "reason": "АЛЬТЕРНАТИВНАЯ ВЕТКА УЖЕ ВЫБРАНА"}
	if int(data.credits) < upgrade.cost:
		return {"allowed": false, "reason": "НЕДОСТАТОЧНО CREDITS"}
	return {"allowed": true, "reason": "ГОТОВО К УСТАНОВКЕ"}

static func purchase_upgrade(id: StringName, kind: StringName, vehicle_id: StringName = &"") -> bool:
	var data := read()
	var upgrade := upgrade_config(id)
	if upgrade == null:
		return false
	if kind == &"vehicle":
		if vehicle_id == &"":
			vehicle_id = LoadoutProfile.read_ids().vehicle
		if vehicle_id not in data.vehicles:
			return false
		var state := _state_from_data(data, vehicle_id)
		var owned: Array = state.upgrades
		if id in owned:
			return true
		if not bool(upgrade_availability(id, vehicle_id, data).allowed):
			return false
		data.credits = int(data.credits) - upgrade.cost
		owned.append(id)
		state.upgrades = owned
		data.vehicle_states[String(vehicle_id)] = state
	else:
		var weapon_owned: Array = data.weapon_upgrades
		if id in weapon_owned:
			return true
		if int(data.credits) < upgrade.cost:
			return false
		data.credits = int(data.credits) - upgrade.cost
		weapon_owned.append(id)
		data.weapon_upgrades = weapon_owned
	save(data)
	return true

static func apply_vehicle_upgrades(config: VehicleConfig, vehicle_id: StringName = &"") -> VehicleConfig:
	if vehicle_id == &"":
		vehicle_id = config.vehicle_id
	var data := read()
	var result := apply_vehicle_upgrades_from(config, vehicle_upgrade_ids(vehicle_id, data))
	var build := active_vehicle_build(vehicle_id, data)
	if not build.is_empty(): _apply_modifiers(result, build.modifiers)
	# Core modules keep the established 200 km/h progression ceiling. A chosen
	# high-performance build may then trade durability for a small over-cap.
	_finalize_vehicle_config(result, 220.0)
	return result

static func apply_vehicle_upgrades_from(config: VehicleConfig, ids: Array) -> VehicleConfig:
	var result := config.duplicate() as VehicleConfig
	for id in ids:
		var upgrade := upgrade_config(id)
		if upgrade != null and upgrade.category in [&"engine", &"armor", &"wheels", &"weapon", &"handling", &"durability", &"specialization"]:
			_apply_modifiers(result, upgrade.modifiers)
	_finalize_vehicle_config(result)
	return result

static func apply_weapon_upgrades(config: WeaponConfig) -> WeaponConfig:
	return apply_weapon_upgrades_from(config, read().weapon_upgrades)

static func apply_weapon_upgrades_from(config: WeaponConfig, ids: Array) -> WeaponConfig:
	var result := config.duplicate() as WeaponConfig
	for id in ids:
		var upgrade := upgrade_config(id)
		if upgrade != null:
			_apply_modifiers(result, upgrade.modifiers)
	return result

static func record_vehicle_result(vehicle_id: StringName, mode: StringName, result: Dictionary) -> void:
	var data := read()
	var state := _state_from_data(data, vehicle_id)
	state.races = int(state.races) + 1
	state.kills = int(state.kills) + int(result.get("kills", 0))
	state.damage_dealt = float(state.damage_dealt) + float(result.get("damage", 0.0))
	var won: bool = result.get("status", &"") in [&"FINISHED", &"VICTORY"] and (mode != &"race" or int(result.get("position", 99)) == 1)
	if won:
		state.wins = int(state.wins) + 1
	if mode == &"race":
		var finish := int(result.get("position", 0))
		if finish > 0 and (int(state.best_finish) == 0 or finish < int(state.best_finish)):
			state.best_finish = finish
		var race_time := float(result.get("time", 0.0))
		if result.get("status", &"") == &"FINISHED" and race_time > 0.0 and (float(state.best_time) <= 0.0 or race_time < float(state.best_time)):
			state.best_time = race_time
	else:
		state.survival_best_round = maxi(int(state.survival_best_round), int(result.get("round", 0)))
	data.vehicle_states[String(vehicle_id)] = state
	save(data)


static func record_survival_run(result: Dictionary) -> Dictionary:
	var data := read()
	var career: Dictionary = data.career
	var records: Dictionary = career.survival_records
	var score := int(result.get("score", 0))
	var round_number := int(result.get("round", 0))
	var combo := int(result.get("best_combo", 0))
	records.best_score = maxi(int(records.get("best_score", 0)), score)
	records.best_round = maxi(int(records.get("best_round", 0)), round_number)
	records.best_combo = maxi(int(records.get("best_combo", 0)), combo)
	records.boss_kills = int(records.get("boss_kills", 0)) + int(result.get("boss_kills", 0))
	var daily_key := String(result.get("daily_key", ""))
	var daily_reward := 0
	if not daily_key.is_empty():
		var daily_scores: Dictionary = records.get("daily_scores", {})
		daily_scores[daily_key] = maxi(int(daily_scores.get(daily_key, 0)), score)
		records.daily_scores = daily_scores
		if int(result.get("boss_kills", 0)) > 0 and StringName(daily_key) not in career.survival_daily_claims:
			career.survival_daily_claims.append(StringName(daily_key))
			daily_reward = 1000
			data.credits = int(data.credits) + daily_reward
	career.survival_records = records
	data.career = career
	save(data)
	return {"best_score": int(records.best_score), "best_round": int(records.best_round), "best_combo": int(records.best_combo), "daily_reward": daily_reward}

static func _default_profile() -> Dictionary:
	return {
		"credits": economy().starting_credits,
		"vehicles": [&"raider"],
		"weapons": [&"machine_gun"],
		"vehicle_states": {"raider": _default_vehicle_state()},
		"vehicle_upgrades": [],
		"weapon_upgrades": [],
		"career": _default_career_state(),
	}

static func _default_vehicle_state() -> Dictionary:
	return {
		"upgrades": [], "build": &"factory", "races": 0, "wins": 0, "best_finish": 0,
		"best_time": 0.0, "kills": 0, "damage_dealt": 0.0,
		"survival_best_round": 0,
	}


static func _sync_career_vehicle_unlocks(data: Dictionary) -> bool:
	var changed := false
	var career: Dictionary = data.career
	var unlocks := {
		&"dustfox": [&"frontier_express", false],
		&"bastion": [&"oil_cauldron", false],
		&"needle": [&"copper_ravine", false],
		&"warhound": [&"copper_ravine", true],
	}
	for vehicle_id in unlocks:
		var rule: Array = unlocks[vehicle_id]
		var progress: Array = career.completed_objectives if bool(rule[1]) else career.completed_events
		if rule[0] in progress and vehicle_id not in data.vehicles:
			data.vehicles.append(vehicle_id)
			data.vehicle_states[String(vehicle_id)] = _default_vehicle_state()
			changed = true
	return changed


static func _default_career_state() -> Dictionary:
	return {
		"driver_id": &"",
		"career_level": 1,
		"championship_tier": 0,
		"season_points": {},
		"season_scored_events": [],
		"rival_levels": {},
		"rivalry_scores": {},
		"personal_rival_id": &"",
		"last_rival_news": [],
		"completed_events": [],
		"completed_objectives": [],
		"event_medals": {},
		"bosses_defeated": [],
		"daily_claims": [],
		"daily_best": {},
		"survival_daily_claims": [],
		"survival_records": {"best_score": 0, "best_round": 0, "best_combo": 0, "boss_kills": 0, "daily_scores": {}},
		"tutorial_complete": false,
		"championship_active": false,
		"championship_complete": false,
		"championship_index": 0,
		"championship_points": {},
	}


static func _normalize_career_state(raw: Variant) -> Dictionary:
	var state := _default_career_state()
	if raw is Dictionary:
		for key in state:
			if raw.has(key):
				state[key] = raw[key]
	state.completed_events = _names(state.completed_events)
	state.completed_objectives = _names(state.completed_objectives)
	state.bosses_defeated = _names(state.bosses_defeated)
	state.daily_claims = _names(state.daily_claims)
	state.survival_daily_claims = _names(state.survival_daily_claims)
	state.season_scored_events = _names(state.season_scored_events)
	state.driver_id = StringName(state.driver_id)
	state.career_level = maxi(1, int(state.career_level))
	state.championship_tier = maxi(0, int(state.championship_tier))
	state.personal_rival_id = StringName(state.personal_rival_id)
	for dictionary_key in ["season_points", "rival_levels", "rivalry_scores"]:
		if not state[dictionary_key] is Dictionary: state[dictionary_key] = {}
	for dictionary_key in ["event_medals", "daily_best"]:
		if not state[dictionary_key] is Dictionary: state[dictionary_key] = {}
	if not state.survival_records is Dictionary: state.survival_records = _default_career_state().survival_records.duplicate(true)
	for key in ["best_score", "best_round", "best_combo", "boss_kills"]:
		state.survival_records[key] = maxi(0, int(state.survival_records.get(key, 0)))
	if not state.survival_records.get("daily_scores", {}) is Dictionary: state.survival_records.daily_scores = {}
	if not state.last_rival_news is Array: state.last_rival_news = []
	for rival_id in RivalRoster.ids():
		state.season_points[String(rival_id)] = int(state.season_points.get(String(rival_id), 0))
		state.rival_levels[String(rival_id)] = maxi(1, int(state.rival_levels.get(String(rival_id), 1)))
		state.rivalry_scores[String(rival_id)] = maxi(0, int(state.rivalry_scores.get(String(rival_id), 0)))
	if not state.championship_points is Dictionary:
		state.championship_points = {}
	else:
		var migrated_points := {"ВЫ": int(state.championship_points.get("ВЫ", 0))}
		var legacy_ids := {"RAZOR":"razor", "BOLT":"bolt", "MARA":"nyx", "NYX":"nyx", "GRIT":"grit", "ZERO":"zero"}
		for legacy_id in legacy_ids:
			var target: String = legacy_ids[legacy_id]
			migrated_points[target] = int(migrated_points.get(target, 0)) + int(state.championship_points.get(legacy_id, 0))
		for rival_id in RivalRoster.ids():
			var key := String(rival_id)
			migrated_points[key] = maxi(int(migrated_points.get(key, 0)), int(state.championship_points.get(key, 0)))
		state.championship_points = migrated_points
	return state

static func _normalized_states(raw: Dictionary, owned: Array) -> Dictionary:
	var result := {}
	for key in raw:
		result[String(key)] = _normalize_vehicle_state(raw[key])
	for id in owned:
		if not result.has(String(id)):
			result[String(id)] = _default_vehicle_state()
	return result

static func _normalize_vehicle_state(raw: Variant) -> Dictionary:
	var state := _default_vehicle_state()
	if raw is Dictionary:
		for key in state:
			if raw.has(key):
				state[key] = raw[key]
	state.upgrades = _names(state.upgrades)
	state.build = StringName(state.build)
	return state

static func _state_from_data(data: Dictionary, vehicle_id: StringName) -> Dictionary:
	if not data.has("vehicle_states"):
		data.vehicle_states = {}
	var key := String(vehicle_id)
	var state := _normalize_vehicle_state(data.vehicle_states.get(key, _default_vehicle_state()))
	data.vehicle_states[key] = state
	return state

static func _apply_modifiers(target: Resource, modifiers: Dictionary) -> void:
	for key in modifiers:
		if key in target:
			target.set(key, float(target.get(key)) + float(modifiers[key]))


static func _finalize_vehicle_config(config: VehicleConfig, max_speed_cap: float = 200.0) -> void:
	config.max_speed = clampf(config.max_speed, 70.0, max_speed_cap)
	config.acceleration = maxf(config.acceleration, 300.0)
	config.max_health = maxf(config.max_health, 35.0)
	config.damage_resistance = clampf(config.damage_resistance, 0.0, 0.75)
	config.weapon_damage_multiplier = maxf(config.weapon_damage_multiplier, 0.55)
	config.weapon_fire_rate_multiplier = maxf(config.weapon_fire_rate_multiplier, 0.55)
	config.body_damage_multiplier = clampf(config.body_damage_multiplier, 0.5, 1.5)
	config.engine_damage_multiplier = clampf(config.engine_damage_multiplier, 0.5, 1.5)
	config.wheels_damage_multiplier = clampf(config.wheels_damage_multiplier, 0.5, 1.5)

static func _names(value: Variant) -> Array:
	var result: Array = []
	for item in value:
		result.append(StringName(item))
	return result

static func _path() -> String:
	return path_override if not path_override.is_empty() else "user://profiles/slot_%d/profile.cfg" % active_slot


static func _backup_path() -> String:
	return _path() + ".bak"


static func _profile_config_is_valid(cfg: ConfigFile) -> bool:
	return (
		cfg.has_section_key("profile", "credits")
		and cfg.has_section_key("profile", "owned_vehicles")
	)


static func _ensure_profile_directory() -> void:
	if not path_override.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://profiles/slot_%d" % active_slot))

static func _strings(value: Array) -> Array[String]:
	var result: Array[String] = []
	for item in value:
		result.append(String(item))
	return result
