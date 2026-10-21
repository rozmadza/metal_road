extends RefCounted
class_name CareerDifficulty


static func upgrade_ids(level: int, bot_index: int = 0, vehicle_id: StringName = &"") -> Array:
	var ids: Array = []
	if level >= 2: ids.append(&"engine_1")
	if level >= 3: ids.append(&"wheels_1")
	if level >= 4: ids.append(&"armor_1")
	if level >= 5: ids.append(&"armament_1")
	if level >= 6:
		ids.append(&"engine_2" if bot_index % 2 == 0 else &"wheels_2")
	if level >= 7: ids.append(&"armor_2")
	if level >= 8: ids.append(&"armament_2")
	if level >= 7 and PlayerProfile.VEHICLE_SPECIALIZATION_IDS.has(vehicle_id):
		var choices: Array = PlayerProfile.VEHICLE_SPECIALIZATION_IDS[vehicle_id]
		ids.append(choices[bot_index % choices.size()])
	return ids


static func apply_bot_vehicle(config: VehicleConfig, level: int, bot_index: int = 0) -> VehicleConfig:
	return PlayerProfile.apply_vehicle_upgrades_from(config, upgrade_ids(level, bot_index, config.vehicle_id))


static func configure_race_bot(bot: BotController, level: int, bot_index: int) -> void:
	var step := maxf(0.0, float(level - 1))
	bot.cruise_throttle = minf(1.0, bot.cruise_throttle + step * 0.018)
	bot.steer_gain += step * 0.08
	bot.ease_angle = maxf(0.32, bot.ease_angle - step * 0.018)
	bot.stuck_timeout = maxf(0.65, bot.stuck_timeout - step * 0.08)
	bot.fire_range += step * 22.0
	bot.fire_angle += step * 0.012


static func configure_arena_bot(bot: ArenaBot, level: int, bot_index: int) -> void:
	var step := maxf(0.0, float(level - 1))
	bot.cruise_throttle = minf(1.0, bot.cruise_throttle + step * 0.018)
	bot.steer_gain += step * 0.08
	bot.stuck_timeout = maxf(0.6, bot.stuck_timeout - step * 0.07)
	bot.fire_range += step * 25.0
	bot.fire_angle += step * 0.012
	bot.retreat_health_ratio = minf(0.48, bot.retreat_health_ratio + step * 0.025)


static func summary(level: int) -> String:
	var modules := upgrade_ids(level)
	if modules.is_empty():
		return "СТОКОВЫЕ МАШИНЫ · БАЗОВАЯ ТАКТИКА"
	return "%d МОДУЛЕЙ · УСИЛЕННЫЙ ИИ · АГРЕССИВНАЯ ТАКТИКА" % modules.size()
