extends RefCounted
class_name RivalRoster

const LINEUP_SCENE := "res://scenes/RivalLineup.tscn"
const HQ_SCENE := "res://scenes/RivalHQ.tscn"

const RIVALS := [
	{"id": &"razor", "callsign": "RAZOR", "name": "РЭЙЗОР КЕЙН", "portrait": "res://assets/rivals/razor.png", "vehicle": &"viper", "role": "СПРИНТЕР", "strategy": BotController.Strategy.SPRINTER, "bio": "Чистая скорость, позднее торможение и атака на внутреннем радиусе.", "color": Color("e85c4a")},
	{"id": &"bolt", "callsign": "BOLT", "name": "БОЛТ РЕН", "portrait": "res://assets/rivals/bolt.png", "vehicle": &"nomad", "role": "СБОРЩИК", "strategy": BotController.Strategy.OPPORTUNIST, "bio": "Охотится за бонусами и меняет маршрут, если видит выгодную поставку.", "color": Color("46b9b2")},
	{"id": &"nyx", "callsign": "NYX", "name": "НИКС ВЕЙЛ", "portrait": "res://assets/rivals/nyx.png", "vehicle": &"marauder", "role": "ОХОТНИК", "strategy": BotController.Strategy.BRAWLER, "bio": "Сначала получает оружие, затем выбивает лидера из гонки.", "color": Color("9a6bd6")},
	{"id": &"grit", "callsign": "GRIT", "name": "ГРИТ МЭДДОКС", "portrait": "res://assets/rivals/grit.png", "vehicle": &"behemoth", "role": "БЛОКИРОВЩИК", "strategy": BotController.Strategy.BLOCKER, "bio": "Закрывает траекторию корпусом и отвечает тараном на любую попытку обгона.", "color": Color("a78955")},
	{"id": &"zero", "callsign": "ZERO", "name": "ЗЕРО ВОСС", "portrait": "res://assets/rivals/zero.png", "vehicle": &"phantom", "role": "ЧЕМПИОН", "strategy": BotController.Strategy.RACER, "bio": "Хладнокровный лидер сезона: стабилен, быстр и почти не допускает ошибок.", "color": Color("65cfe0")},
]
const SEASON_VEHICLES := {
	&"raider": &"dustfox",
	&"nomad": &"dustfox",
	&"viper": &"needle",
	&"phantom": &"needle",
	&"wasteland_gt": &"warhound",
	&"marauder": &"warhound",
	&"crusher": &"bastion",
	&"behemoth": &"bastion",
}


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for rival in RIVALS: result.append(rival.id)
	return result


static func at(index: int) -> Dictionary:
	return RIVALS[posmod(index, RIVALS.size())]


static func by_id(id: StringName) -> Dictionary:
	for rival in RIVALS:
		if rival.id == id: return rival
	return {}


static func display_name(id: Variant) -> String:
	var rival := by_id(StringName(id))
	return rival.callsign if not rival.is_empty() else String(id).to_upper()


static func vehicle_config(rival: Dictionary, level: int, index: int) -> VehicleConfig:
	var vehicle_id: StringName = SEASON_VEHICLES.get(rival.vehicle, rival.vehicle) if level >= 7 else rival.vehicle
	var base := LoadoutProfile.vehicle_config(vehicle_id)
	return CareerDifficulty.apply_bot_vehicle(base, level, index)


static func module_summary(level: int, index: int) -> String:
	var rival := at(index)
	var vehicle_id: StringName = SEASON_VEHICLES.get(rival.vehicle, rival.vehicle) if level >= 7 else rival.vehicle
	var ids_list := CareerDifficulty.upgrade_ids(level, index, vehicle_id)
	if ids_list.is_empty(): return "СТОК"
	var categories := {&"engine": 0, &"armor": 0, &"wheels": 0, &"weapon": 0, &"specialization": 0}
	for upgrade_id in ids_list:
		var upgrade := PlayerProfile.upgrade_config(upgrade_id)
		if upgrade != null: categories[upgrade.category] = maxi(int(categories.get(upgrade.category, 0)), upgrade.level)
	var labels: Array[String] = []
	for category in categories:
		if int(categories[category]) > 0: labels.append("%s %d" % [{&"engine":"ДВ", &"armor":"БР", &"wheels":"ХД", &"weapon":"ОР", &"specialization":"СП"}[category], categories[category]])
	return " · ".join(labels)
