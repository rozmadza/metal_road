extends RefCounted
class_name CareerSession

const CAREER_SCENE := "res://scenes/Career.tscn"
const PRE_RACE_SCENE := "res://scenes/PreRace.tscn"
const POINTS := [10, 7, 5, 3, 2, 1]
const RIVALS := ["razor", "bolt", "nyx", "grit", "zero"]
const CHAMPIONSHIP_EVENT_COUNT := 3

const EVENTS := [
	{
		"id": &"iron_open",
		"name": "ЖЕЛЕЗНЫЙ СТАРТ",
		"type": &"classic",
		"type_label": "КЛАССИЧЕСКАЯ ГОНКА",
		"location": "IRON CIRCUIT",
		"track": "res://resources/iron_circuit.tres",
		"laps": 3,
		"description": "Три круга на быстрой индустриальной трассе. Оружие разрешено, но позиция важнее драки.",
		"objective": "ФИНИШИРОВАТЬ В ТОП-3 БЕЗ РЕМОНТА",
		"reward": 600,
		"objective_reward": 250,
		"unlock_vehicle": &"nomad",
	},
	{
		"id": &"dust_elimination",
		"name": "ПОСЛЕДНЯЯ ПЕРЕДАЧА",
		"type": &"elimination",
		"type_label": "ГОНКА НА ВЫБЫВАНИЕ",
		"location": "DUST SPIRAL",
		"track": "res://resources/dust_spiral.tres",
		"laps": 3,
		"description": "После каждого круга лидерской группы последний участник выбывает. Нельзя отсиживаться позади.",
		"objective": "УНИЧТОЖИТЬ СОПЕРНИКА ОРУЖИЕМ",
		"reward": 850,
		"objective_reward": 350,
		"unlock_vehicle": &"viper",
	},
	{
		"id": &"crown_supply_rush",
		"name": "БИТВА ЗА ПОСТАВКУ",
		"type": &"bonus_hunt",
		"type_label": "ОХОТА ЗА БОНУСАМИ",
		"location": "BROKEN CROWN",
		"track": "res://resources/broken_crown.tres",
		"laps": 99,
		"target_pickups": 3,
		"description": "Первый, кто захватит три активных поставки, выигрывает. Маршрут длиннее, а бонусы становятся точками конфликта.",
		"objective": "ЗАХВАТИТЬ 2 БОНУСА ЛИЧНО",
		"reward": 1100,
		"objective_reward": 450,
		"unlock_vehicle": &"phantom",
	},
	{
		"id": &"scrapyard_contract",
		"name": "КОНТРАКТ: УТИЛИЗАТОР",
		"type": &"arena",
		"type_label": "АРЕНА · ВЫЖИВАНИЕ",
		"location": "SCRAPYARD ARENA",
		"track": "res://resources/default_arena.tres",
		"target_rounds": 2,
		"description": "Переживите две усиленные волны на свалке. Здесь нет финиша — только последний работающий двигатель.",
		"objective": "УНИЧТОЖИТЬ 4 СОПЕРНИКОВ",
		"reward": 1250,
		"objective_reward": 500,
		"unlock_vehicle": &"marauder",
	},
	{
		"id": &"grit_boss",
		"name": "БРОНЕБОЙНЫЙ КОНТРАКТ",
		"type": &"boss_duel",
		"type_label": "БОСС · ДУЭЛЬ",
		"location": "BROKEN CROWN",
		"track": "res://resources/broken_crown.tres",
		"laps": 3,
		"boss_id": &"grit",
		"boss_weapon": "res://resources/weapons/mine_layer.tres",
		"modifier": &"scarce_supplies",
		"modifier_label": "РЕДКИЕ ПОСТАВКИ · УСИЛЕННЫЙ ТАРАН",
		"recommended_class": "JUGGERNAUT ИЛИ INTERCEPTOR",
		"threats": "МИНЫ · БЛОКИРОВКА ТРАЕКТОРИИ · ТРИ ФАЗЫ БОЯ",
		"description": "Грит вызывает вас на закрытую дуэль. Его броневик меняет тактику по мере разрушения корпуса.",
		"objective": "ПОБЕДИТЬ ГРИТА БЕЗ РЕМОНТНОГО БОНУСА",
		"reward": 1600,
		"objective_reward": 650,
		"unlock_vehicle": &"crusher",
	},
	{
		"id": &"zero_finale",
		"name": "КОРОНА ИЗ ПЕПЛА",
		"type": &"boss_duel",
		"type_label": "ФИНАЛ СЕЗОНА · БОСС",
		"location": "ASHEN CROWN",
		"track": "res://resources/ashen_crown.tres",
		"laps": 4,
		"boss_id": &"zero",
		"boss_weapon": "res://resources/weapons/rocket_launcher.tres",
		"modifier": &"overdrive",
		"modifier_label": "ОВЕРДРАЙВ · ВЫСОКАЯ СКОРОСТЬ",
		"recommended_class": "INTERCEPTOR ИЛИ ASSAULT",
		"threats": "РАКЕТЫ · ЭМИ В ФИНАЛЬНОЙ ФАЗЕ · МАКСИМАЛЬНЫЙ УРОВЕНЬ",
		"description": "Четыре круга один на один с чемпионом. Зеро меняет вооружение и темп в каждой фазе дуэли.",
		"objective": "ПОБЕДИТЬ ЗЕРО И ЗАНЯТЬ 1 МЕСТО",
		"reward": 2200,
		"objective_reward": 800,
		"unlock_vehicle": &"behemoth",
	},
	{
		"id": &"frontier_express",
		"name": "КРАСНАЯ ЧЕРТА",
		"type": &"classic",
		"type_label": "SEASON 1 · ГОНКА",
		"location": "FRONTIER EXPRESS",
		"track": "res://resources/frontier_express.tres",
		"laps": 3,
		"modifier": &"dust_storm",
		"modifier_label": "ПЫЛЕВАЯ БУРЯ · ДЛИННАЯ ТРАССА",
		"recommended_class": "INTERCEPTOR ИЛИ ASSAULT",
		"threats": "ПЕСЧАНЫЕ НАНОСЫ · НЕФТЬ · ВЗРЫВНЫЕ БОЧКИ",
		"description": "Открытие Ржавого фронтира: длинный скоростной маршрут через мёртвые нефтепромыслы.",
		"objective": "ФИНИШИРОВАТЬ В ТОП-3 И СОБРАТЬ 2 БОНУСА",
		"reward": 1450,
		"objective_reward": 550,
		"unlock_vehicle": &"dustfox",
	},
	{
		"id": &"oil_cauldron",
		"name": "НЕФТЯНОЙ КОТЁЛ",
		"type": &"arena",
		"type_label": "SEASON 1 · АРЕНА",
		"location": "OIL CAULDRON",
		"track": "res://resources/oil_cauldron_arena.tres",
		"target_rounds": 3,
		"modifier": &"dust_storm",
		"modifier_label": "БУРЯ · ВЗРЫВООПАСНАЯ ЗОНА",
		"recommended_class": "JUGGERNAUT ИЛИ ASSAULT",
		"threats": "НЕФТЯНЫЕ ПЯТНА · БОЧКИ · ПЛОТНЫЕ УКРЫТИЯ",
		"description": "Три волны на заброшенной нефтебазе. Буря скрывает противников, но не их оружие.",
		"objective": "УНИЧТОЖИТЬ 6 СОПЕРНИКОВ",
		"reward": 1750,
		"objective_reward": 650,
		"unlock_vehicle": &"bastion",
	},
	{
		"id": &"copper_ravine",
		"name": "МЕДНЫЙ ШТОРМ",
		"type": &"elimination",
		"type_label": "SEASON 1 · ВЫБЫВАНИЕ",
		"location": "COPPER RAVINE",
		"track": "res://resources/copper_ravine.tres",
		"laps": 4,
		"modifier": &"dust_storm",
		"modifier_label": "СИЛЬНАЯ БУРЯ · ТЕХНИЧЕСКИЙ МАРШРУТ",
		"recommended_class": "RAIDER ИЛИ INTERCEPTOR",
		"threats": "ЧАСТЫЕ ПОВОРОТЫ · НАНОСЫ · ГОНКА НА ВЫБЫВАНИЕ",
		"description": "Финальный маршрут биома: связки радиусных поворотов и песок, который меняет траекторию каждого круга.",
		"objective": "ПОБЕДИТЬ И НЕ ИСПОЛЬЗОВАТЬ РЕМОНТ",
		"reward": 1950,
		"objective_reward": 750,
		"unlock_vehicle": &"needle",
		"objective_unlock_vehicle": &"warhound",
	},
]

static var selected_event_id: StringName = &""
static var championship_run := false
static var dynamic_event: Dictionary = {}


static func event_by_id(id: StringName) -> Dictionary:
	if not dynamic_event.is_empty() and dynamic_event.id == id:
		return dynamic_event
	for event in EVENTS:
		if event.id == id:
			return event
	return {}


static func active_event() -> Dictionary:
	return event_by_id(selected_event_id)


static func select_event(id: StringName, as_championship: bool = false) -> void:
	selected_event_id = id
	championship_run = as_championship


static func clear_selection() -> void:
	selected_event_id = &""
	championship_run = false
	dynamic_event = {}


static func daily_event(date_key: String = "") -> Dictionary:
	if date_key.is_empty():
		date_key = Time.get_date_string_from_system()
	var seed_value := date_key.hash()
	var tracks := ["res://resources/iron_circuit.tres", "res://resources/dust_spiral.tres", "res://resources/broken_crown.tres", "res://resources/frontier_express.tres", "res://resources/copper_ravine.tres"]
	var locations := ["IRON CIRCUIT", "DUST SPIRAL", "BROKEN CROWN", "FRONTIER EXPRESS", "COPPER RAVINE"]
	var index := posmod(seed_value, tracks.size())
	return {
		"id": StringName("daily_%s" % date_key), "daily_key": StringName(date_key),
		"name": "КОНТРАКТ ДНЯ", "type": &"classic", "type_label": "ЕЖЕДНЕВНОЕ ИСПЫТАНИЕ",
		"location": locations[index], "track": tracks[index], "laps": 2 + posmod(seed_value / 7, 2),
		"description": "Повторяемый контракт с фиксированными условиями на сегодня. Лучший результат сохраняется.",
		"objective": "ФИНИШИРОВАТЬ В ТОП-3", "reward": 550 + posmod(seed_value, 4) * 100,
		"objective_reward": 0, "unlock_vehicle": &"", "repeatable": true,
		"modifier": &"overdrive" if posmod(seed_value, 2) == 0 else &"scarce_supplies",
		"modifier_label": "ОВЕРДРАЙВ" if posmod(seed_value, 2) == 0 else "РЕДКИЕ ПОСТАВКИ",
		"recommended_class": "ЛЮБОЙ КЛАСС", "threats": "УСИЛЕННЫЕ СОПЕРНИКИ · ОСОБЫЕ УСЛОВИЯ",
	}


static func select_daily_challenge(date_key: String = "") -> Dictionary:
	dynamic_event = daily_event(date_key)
	selected_event_id = dynamic_event.id
	championship_run = false
	return dynamic_event


static func difficulty_level(state: Dictionary = {}) -> int:
	if state.is_empty():
		state = PlayerProfile.career_state()
	return clampi(int(state.get("career_level", 1)) + int(state.get("championship_tier", 0)), 1, 8)


static func event_unlocked(index: int, state: Dictionary = {}) -> bool:
	if index <= 0:
		return true
	if state.is_empty():
		state = PlayerProfile.career_state()
	return EVENTS[index - 1].id in state.completed_events


static func next_championship_event(state: Dictionary = {}) -> Dictionary:
	if state.is_empty():
		state = PlayerProfile.career_state()
	var index := clampi(int(state.championship_index), 0, CHAMPIONSHIP_EVENT_COUNT - 1)
	return EVENTS[index]


static func start_or_resume_championship() -> Dictionary:
	var data := PlayerProfile.read()
	var state: Dictionary = data.career
	if not bool(state.championship_active) or int(state.championship_index) >= CHAMPIONSHIP_EVENT_COUNT:
		state.championship_active = true
		state.championship_index = 0
		state.championship_points = _empty_standings()
		state.championship_complete = false
	data.career = state
	PlayerProfile.save(data)
	var event: Dictionary = EVENTS[int(state.championship_index)]
	select_event(event.id, true)
	return event


static func record_result(result: Dictionary) -> Dictionary:
	var event := active_event()
	if event.is_empty():
		return {}
	var data := PlayerProfile.read()
	var state: Dictionary = data.career
	var completed: Array = state.completed_events
	var objectives: Array = state.completed_objectives
	var success: bool = _event_success(event, result)
	var objective_done: bool = _objective_success(event, result)
	var first_completion: bool = success and event.id not in completed
	var first_objective: bool = objective_done and event.id not in objectives
	var bonus := 0
	var unlocked := &""
	var unlocked_vehicles: Array[StringName] = []
	var is_repeatable := bool(event.get("repeatable", false))
	if is_repeatable:
		first_completion = false
		first_objective = false
		var daily_key: StringName = event.get("daily_key", event.id)
		if success and daily_key not in state.daily_claims:
			state.daily_claims.append(daily_key)
			bonus += int(event.reward)
		var previous_best := float(state.daily_best.get(String(daily_key), 0.0))
		var result_time := float(result.get("time", 0.0))
		if success and result_time > 0.0 and (previous_best <= 0.0 or result_time < previous_best):
			state.daily_best[String(daily_key)] = result_time
	if first_completion:
		completed.append(event.id)
		var event_index := EVENTS.find(event)
		state.career_level = maxi(int(state.get("career_level", 1)), event_index + 2)
		bonus += int(event.reward)
		unlocked = event.unlock_vehicle
		if unlocked != &"" and unlocked not in data.vehicles:
			data.vehicles.append(unlocked)
			data.vehicle_states[String(unlocked)] = PlayerProfile.default_vehicle_state()
			unlocked_vehicles.append(unlocked)
	if first_objective:
		objectives.append(event.id)
		bonus += int(event.objective_reward)
		var objective_unlock := StringName(event.get("objective_unlock_vehicle", &""))
		if objective_unlock != &"" and objective_unlock not in data.vehicles:
			data.vehicles.append(objective_unlock)
			data.vehicle_states[String(objective_unlock)] = PlayerProfile.default_vehicle_state()
			unlocked_vehicles.append(objective_unlock)
	var medals := _medal_count(event, result, success, objective_done)
	state.event_medals[String(event.id)] = maxi(int(state.event_medals.get(String(event.id), 0)), medals)
	if success and event.has("boss_id") and StringName(event.boss_id) not in state.bosses_defeated:
		state.bosses_defeated.append(StringName(event.boss_id))
	state.completed_events = completed
	state.completed_objectives = objectives
	_record_season_progress(state, result, first_completion, event.id)

	var championship_finished := false
	if championship_run and bool(state.championship_active):
		_apply_championship_points(state, result)
		state.championship_index = int(state.championship_index) + 1
		if int(state.championship_index) >= CHAMPIONSHIP_EVENT_COUNT:
			state.championship_active = false
			state.championship_complete = true
			championship_finished = true
			state.championship_tier = mini(4, int(state.get("championship_tier", 0)) + 1)
			if _player_is_champion(state.championship_points):
				bonus += 1500
	data.credits = int(data.credits) + bonus
	data.career = state
	PlayerProfile.save(data)
	return {
		"event_name": event.name,
		"success": success,
		"objective_completed": objective_done,
		"career_bonus": bonus,
		"unlocked_vehicle": unlocked,
		"unlocked_vehicles": unlocked_vehicles,
		"championship_finished": championship_finished,
		"championship_active": bool(state.championship_active),
		"championship_index": int(state.championship_index),
		"personal_rival": RivalRoster.display_name(state.personal_rival_id),
		"rival_news": state.last_rival_news.duplicate(),
		"season_rank": _season_rank(state),
		"season_champion": event.id == &"zero_finale" and success,
		"medals": medals,
		"boss_defeated": StringName(event.get("boss_id", &"")) if success else &"",
	}


static func _event_success(event: Dictionary, result: Dictionary) -> bool:
	match event.type:
		&"arena":
			return result.get("status", &"") == &"VICTORY"
		&"bonus_hunt":
			return bool(result.get("event_won", false))
		&"elimination":
			return result.get("status", &"") == &"FINISHED" or int(result.get("position", 99)) <= 3
		&"boss_duel":
			return result.get("status", &"") == &"FINISHED" and int(result.get("position", 99)) == 1
	return result.get("status", &"") == &"FINISHED" and int(result.get("position", 99)) <= 3


static func _objective_success(event: Dictionary, result: Dictionary) -> bool:
	match event.id:
		&"iron_open":
			return result.get("status", &"") == &"FINISHED" and int(result.get("position", 99)) <= 3 and int(result.get("repairs_used", 0)) == 0
		&"dust_elimination":
			# Legacy/simulated results without the new field remain compatible.
			return int(result.get("weapon_kills", result.get("kills", 0))) >= 1
		&"crown_supply_rush":
			return int(result.get("pickups", 0)) >= 2
		&"scrapyard_contract":
			return int(result.get("kills", 0)) >= 4
		&"zero_finale":
			var rival_positions: Dictionary = result.get("rival_positions", {})
			var zero_beaten := rival_positions.is_empty() or int(rival_positions.get("zero", 99)) > 1
			return result.get("status", &"") == &"FINISHED" and int(result.get("position", 99)) == 1 and zero_beaten
		&"grit_boss":
			return result.get("status", &"") == &"FINISHED" and int(result.get("position", 99)) == 1 and int(result.get("repairs_used", 0)) == 0
		&"frontier_express":
			return int(result.get("position", 99)) <= 3 and int(result.get("pickups", 0)) >= 2
		&"oil_cauldron":
			return int(result.get("kills", 0)) >= 6
		&"copper_ravine":
			return int(result.get("position", 99)) == 1 and int(result.get("repairs_used", 0)) == 0
	return false


static func _medal_count(event: Dictionary, result: Dictionary, success: bool, objective_done: bool) -> int:
	var medals := int(success) + int(objective_done)
	if event.type == &"arena":
		medals += int(result.get("status", &"") == &"VICTORY" and int(result.get("kills", 0)) >= 5)
	else:
		medals += int(result.get("status", &"") == &"FINISHED" and int(result.get("position", 99)) == 1)
	return mini(3, medals)


static func _record_season_progress(state: Dictionary, result: Dictionary, first_completion: bool, event_id: StringName) -> void:
	var player_position := clampi(int(result.get("position", 1 if result.get("status", &"") == &"VICTORY" else 6)), 1, 6)
	var scores_season: bool = event_id not in state.season_scored_events
	if scores_season:
		state.season_scored_events.append(event_id)
		state.season_points["player"] = int(state.season_points.get("player", 0)) + POINTS[player_position - 1]
	var positions: Dictionary = result.get("rival_positions", {})
	if positions.is_empty():
		var available := [1, 2, 3, 4, 5, 6]
		available.erase(player_position)
		var shift := int(state.get("career_level", 1)) % available.size()
		for index in RIVALS.size(): positions[RIVALS[index]] = available[(index + shift) % available.size()]
	var news: Array = []
	var closest_id := &""
	var closest_gap := 99
	for index in RIVALS.size():
		var rival_id := StringName(RIVALS[index])
		var position := clampi(int(positions.get(String(rival_id), index + 1)), 1, 6)
		if scores_season:
			state.season_points[String(rival_id)] = int(state.season_points.get(String(rival_id), 0)) + POINTS[position - 1]
		var gap := absi(position - player_position)
		if gap < closest_gap:
			closest_gap = gap
			closest_id = rival_id
		state.rivalry_scores[String(rival_id)] = int(state.rivalry_scores.get(String(rival_id), 0)) + maxi(0, 3 - gap)
		if first_completion:
			var previous := int(state.rival_levels.get(String(rival_id), 1))
			var personality_bonus := 1 if rival_id == &"zero" and int(state.career_level) >= 4 else 0
			var next_level := clampi(int(state.career_level) + int(state.championship_tier) + personality_bonus, 1, 8)
			state.rival_levels[String(rival_id)] = maxi(previous, next_level)
			if next_level > previous:
				news.append("%s: УРОВЕНЬ %d · %s" % [RivalRoster.display_name(rival_id), next_level, RivalRoster.module_summary(next_level, index)])
	if closest_id != &"":
		state.rivalry_scores[String(closest_id)] = int(state.rivalry_scores.get(String(closest_id), 0)) + 2
	var best_score := -1
	for rival_id in RIVALS:
		var score := int(state.rivalry_scores.get(String(rival_id), 0))
		if score > best_score:
			best_score = score
			state.personal_rival_id = StringName(rival_id)
	state.last_rival_news = news.slice(0, 3)


static func _season_rank(state: Dictionary) -> int:
	var player_points := int(state.season_points.get("player", 0))
	var rank := 1
	for rival_id in RIVALS:
		if int(state.season_points.get(String(rival_id), 0)) > player_points: rank += 1
	return rank


static func _apply_championship_points(state: Dictionary, result: Dictionary) -> void:
	var standings: Dictionary = state.championship_points
	if standings.is_empty():
		standings = _empty_standings()
	var player_position := clampi(int(result.get("position", 6)), 1, 6)
	var rival_order := RIVALS.duplicate()
	var shift := int(state.championship_index) % rival_order.size()
	for _step in shift:
		rival_order.push_back(rival_order.pop_front())
	var row: Array[String] = []
	var rival_index := 0
	for place in range(1, 7):
		if place == player_position:
			row.append("ВЫ")
		else:
			row.append(rival_order[rival_index])
			rival_index += 1
	for place in row.size():
		standings[row[place]] = int(standings.get(row[place], 0)) + POINTS[place]
	state.championship_points = standings


static func _empty_standings() -> Dictionary:
	var result := {"ВЫ": 0}
	for rival in RIVALS:
		result[rival] = 0
	return result


static func _player_is_champion(standings: Dictionary) -> bool:
	var player_points := int(standings.get("ВЫ", 0))
	for name in standings:
		if name != "ВЫ" and int(standings[name]) > player_points:
			return false
	return true
