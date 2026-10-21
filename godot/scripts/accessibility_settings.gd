extends Node
class_name AccessibilitySettings

const PATH := "user://settings.cfg"
const VERSION := 2

static var reduced_flashes := false
static var high_contrast := false
static var tutorial_enabled := true
static var screen_shake := 1.0
static var difficulty := 1 # 0 assisted, 1 standard, 2 hardcore

func _ready() -> void:
	load_settings()

static func load_settings(cfg: ConfigFile = null) -> void:
	if cfg == null:
		cfg = ConfigFile.new()
		cfg.load(PATH)
	reduced_flashes = bool(cfg.get_value("accessibility", "reduced_flashes", false))
	high_contrast = bool(cfg.get_value("accessibility", "high_contrast", false))
	tutorial_enabled = bool(cfg.get_value("accessibility", "tutorial_enabled", true))
	screen_shake = clampf(float(cfg.get_value("accessibility", "screen_shake", 1.0)), 0.0, 1.0)
	difficulty = clampi(int(cfg.get_value("accessibility", "difficulty", 1)), 0, 2)

static func save_settings(cfg: ConfigFile = null) -> void:
	if cfg == null:
		cfg = ConfigFile.new()
		cfg.load(PATH)
	cfg.set_value("settings", "settings_version", VERSION)
	cfg.set_value("accessibility", "reduced_flashes", reduced_flashes)
	cfg.set_value("accessibility", "high_contrast", high_contrast)
	cfg.set_value("accessibility", "tutorial_enabled", tutorial_enabled)
	cfg.set_value("accessibility", "screen_shake", screen_shake)
	cfg.set_value("accessibility", "difficulty", difficulty)
	cfg.save(PATH)

static func player_damage_multiplier() -> float:
	return [0.72, 1.0, 1.18][difficulty]

static func reward_multiplier() -> float:
	return [0.85, 1.0, 1.25][difficulty]

static func difficulty_label() -> String:
	return ["ПОМОЩЬ", "СТАНДАРТ", "ХАРДКОР"][difficulty]
