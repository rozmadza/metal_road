extends RefCounted
class_name DriverRoster

const SELECT_SCENE := "res://scenes/DriverSelect.tscn"

const DRIVERS := [
	{
		"id": &"mara",
		"name": "МАРА ВЕЙЛ",
		"callsign": "ШТУРМАН",
		"portrait": "res://assets/characters/mara.png",
		"bio": "Хладнокровный тактик дорожных войн. Мара заранее видит точку конфликта и превращает любой найденный арсенал в преимущество.",
		"passive": "АРСЕНАЛ: +10% к урону оружия и +18% ко времени действия бонусов.",
	},
	{
		"id": &"rook",
		"name": "РУК МЭДДОКС",
		"callsign": "МЕХАНИК",
		"portrait": "res://assets/characters/rook.png",
		"bio": "Ветеран мастерских и арен. Рук усиливает силовой каркас и знает, как довезти машину до финиша после самого жёсткого тарана.",
		"passive": "ЖЕЛЕЗНАЯ ВОЛЯ: +10% прочности и +5% сопротивления урону.",
	},
	{
		"id": &"flint",
		"name": "ФЛИНТ РЭЙ",
		"callsign": "ПИЛОТ",
		"portrait": "res://assets/characters/flint.png",
		"bio": "Рискованный гонщик нового поколения. Флинт поздно тормозит, быстро выходит из поворотов и выигрывает за счёт темпа.",
		"passive": "КРАСНАЯ ЗОНА: +8% к ускорению и +6% к скорости поворота руля.",
	},
]


static func by_id(id: StringName) -> Dictionary:
	for driver in DRIVERS:
		if driver.id == id:
			return driver
	return {}


static func selected() -> Dictionary:
	return by_id(StringName(PlayerProfile.career_state().get("driver_id", &"")))


static func apply_passive(config: VehicleConfig, id: StringName) -> VehicleConfig:
	var result := config.duplicate() as VehicleConfig
	match id:
		&"mara":
			result.weapon_damage_multiplier *= 1.10
			result.passive_bonus_duration_multiplier *= 1.18
		&"rook":
			result.max_health *= 1.10
			result.engine_health *= 1.10
			result.wheels_health *= 1.10
			result.damage_resistance = minf(0.75, result.damage_resistance + 0.05)
		&"flint":
			result.acceleration *= 1.08
			result.steer_rate *= 1.06
	return result
