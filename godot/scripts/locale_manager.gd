extends RefCounted
class_name LocaleManager

const RU := "ru"
const EN := "en"
static var current := RU

const TEXT := {
	"race": {RU:"ГОНКА", EN:"RACE"}, "career": {RU:"КАРЬЕРА", EN:"CAREER"},
	"survival": {RU:"ВЫЖИВАНИЕ", EN:"SURVIVAL"}, "garage": {RU:"ГАРАЖ", EN:"GARAGE"},
	"progress": {RU:"ПРОГРЕСС", EN:"PROGRESS"}, "settings": {RU:"НАСТРОЙКИ", EN:"SETTINGS"},
	"quit": {RU:"ВЫХОД", EN:"QUIT"}, "back": {RU:"НАЗАД", EN:"BACK"},
	"master": {RU:"Громкость", EN:"Master volume"}, "music": {RU:"Музыка", EN:"Music"},
	"effects": {RU:"Эффекты", EN:"Effects"}, "engine": {RU:"Двигатель", EN:"Engine"},
	"fullscreen": {RU:"Полный экран", EN:"Fullscreen"}, "difficulty": {RU:"Сложность", EN:"Difficulty"},
	"shake": {RU:"Тряска камеры", EN:"Camera shake"}, "language": {RU:"Язык", EN:"Language"},
	"resolution": {RU:"Разрешение", EN:"Resolution"}, "controls": {RU:"УПРАВЛЕНИЕ", EN:"CONTROLS"},
	"flashes": {RU:"Уменьшить вспышки и ЭМИ-помехи", EN:"Reduce flashes and EMP noise"},
	"contrast": {RU:"Повышенная контрастность интерфейса", EN:"High-contrast interface"},
	"tutorial": {RU:"Показывать обучение", EN:"Show tutorial"},
}

static func tr_key(key: String) -> String:
	return TEXT.get(key, {}).get(current, key)

static func set_locale(locale: String) -> void:
	current = EN if locale == EN else RU
