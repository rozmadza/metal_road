extends RefCounted
class_name BonusWeaponCache
## Seven immutable pickup configs, prepared while the match loading overlay is visible.
## Ammo, cooldowns and temporary durations live on each vehicle, not here.

const PATHS := [
	"res://resources/weapons/machine_gun.tres",
	"res://resources/weapons/heavy_machine_gun.tres",
	"res://resources/weapons/shotgun.tres",
	"res://resources/weapons/rocket_launcher.tres",
	"res://resources/weapons/mine_layer.tres",
	"res://resources/weapons/flamethrower.tres",
	"res://resources/weapons/emp_cannon.tres",
]

static var _configs: Dictionary = {}


static func is_ready() -> bool:
	return _configs.size() == PATHS.size()


static func prepare() -> bool:
	if is_ready():
		return true
	var loaded := {}
	for path in PATHS:
		var config := load(path) as WeaponConfig
		if config == null:
			push_error("Could not prepare bonus weapon: %s" % path)
			return false
		loaded[path] = config
	_configs = loaded
	return true


static func get_config(path: String) -> WeaponConfig:
	return _configs.get(path) as WeaponConfig
