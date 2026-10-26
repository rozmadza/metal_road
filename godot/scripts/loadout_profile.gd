extends RefCounted
class_name LoadoutProfile

const PATH := "user://loadout.cfg"
const VERSION := 2
const VEHICLE_CATALOG_PATH := "res://resources/vehicle_catalog.tres"
# Compatibility aliases for older scripts. New code reads the catalog.
const VEHICLE_IDS := [&"raider", &"nomad", &"dustfox", &"viper", &"phantom", &"needle", &"wasteland_gt", &"marauder", &"warhound", &"crusher", &"behemoth", &"bastion"]
const WEAPON_IDS := [&"machine_gun", &"heavy_machine_gun", &"shotgun"]
const VEHICLE_PATHS := {
	&"raider": "res://resources/vehicles/raider.tres",
	&"viper": "res://resources/vehicles/viper.tres",
	&"crusher": "res://resources/vehicles/crusher.tres",
	&"wasteland_gt": "res://resources/vehicles/wasteland_gt.tres",
	&"nomad": "res://resources/vehicles/nomad.tres",
	&"phantom": "res://resources/vehicles/phantom.tres",
	&"marauder": "res://resources/vehicles/marauder.tres",
	&"behemoth": "res://resources/vehicles/behemoth.tres",
	&"dustfox": "res://resources/vehicles/dustfox.tres",
	&"needle": "res://resources/vehicles/needle.tres",
	&"warhound": "res://resources/vehicles/warhound.tres",
	&"bastion": "res://resources/vehicles/bastion.tres",
}
const WEAPON_PATHS := {
	&"machine_gun": "res://resources/weapons/machine_gun.tres",
	&"heavy_machine_gun": "res://resources/weapons/heavy_machine_gun.tres",
	&"shotgun": "res://resources/weapons/shotgun.tres",
}
static var path_override := ""
static var _vehicle_catalog: VehicleCatalog


static func _path() -> String:
	return path_override if not path_override.is_empty() else PATH

static func read_ids() -> Dictionary:
	var cfg := ConfigFile.new()
	var load_error := cfg.load(_path())
	if load_error == OK and not _loadout_config_is_valid(cfg):
		load_error = ERR_FILE_CORRUPT
	if load_error != OK:
		# A previous headless Godot process can still be releasing the profile
		# file. Retry briefly so a normal scene transition never falls back to
		# the default loadout by accident.
		for _attempt in 4:
			OS.delay_msec(75)
			load_error = cfg.load(_path())
			if load_error == OK and not _loadout_config_is_valid(cfg):
				load_error = ERR_FILE_CORRUPT
			if load_error == OK:
				break
	if load_error != OK and FileAccess.file_exists(_backup_path()):
		load_error = cfg.load(_backup_path())
		if load_error == OK and not _loadout_config_is_valid(cfg):
			load_error = ERR_FILE_CORRUPT
		if load_error == OK:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(_backup_path()), ProjectSettings.globalize_path(_path()))
	return {
		"vehicle": StringName(cfg.get_value("loadout", "vehicle", &"raider")),
		"weapon": StringName(cfg.get_value("loadout", "weapon", &"machine_gun")),
		"race_vehicle": StringName(cfg.get_value("loadout", "race_vehicle", cfg.get_value("loadout", "vehicle", &"raider"))),
		"survival_vehicle": StringName(cfg.get_value("loadout", "survival_vehicle", cfg.get_value("loadout", "vehicle", &"raider"))),
	}

static func save_ids(vehicle_id: StringName, weapon_id: StringName) -> void:
	var cfg := ConfigFile.new()
	cfg.load(_path())
	cfg.set_value("loadout", "version", VERSION)
	cfg.set_value("loadout", "vehicle", vehicle_id)
	cfg.set_value("loadout", "weapon", weapon_id)
	_save_config_safely(cfg)

static func mode_vehicle(mode: StringName) -> StringName:
	var ids := read_ids()
	return ids.survival_vehicle if mode == &"survival" else ids.race_vehicle

static func save_mode_vehicle(mode: StringName, vehicle_id: StringName) -> void:
	var cfg := ConfigFile.new()
	cfg.load(_path())
	cfg.set_value("loadout", "version", VERSION)
	cfg.set_value("loadout", "survival_vehicle" if mode == &"survival" else "race_vehicle", vehicle_id)
	if not cfg.has_section_key("loadout", "vehicle"):
		cfg.set_value("loadout", "vehicle", vehicle_id)
	if not cfg.has_section_key("loadout", "weapon"):
		cfg.set_value("loadout", "weapon", &"machine_gun")
	_save_config_safely(cfg)


static func _backup_path() -> String:
	return _path() + ".bak"


static func _loadout_config_is_valid(cfg: ConfigFile) -> bool:
	return (
		cfg.has_section_key("loadout", "vehicle")
		and cfg.has_section_key("loadout", "weapon")
	)


static func _save_config_safely(cfg: ConfigFile) -> bool:
	var target := _path()
	var temporary := target + ".tmp"
	if cfg.save(temporary) != OK:
		push_error("Could not write temporary loadout: %s" % temporary)
		return false
	var validation := ConfigFile.new()
	if validation.load(temporary) != OK or int(validation.get_value("loadout", "version", 0)) != VERSION:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		push_error("Temporary loadout failed validation: %s" % temporary)
		return false
	var absolute_target := ProjectSettings.globalize_path(target)
	var absolute_temporary := ProjectSettings.globalize_path(temporary)
	var absolute_backup := ProjectSettings.globalize_path(_backup_path())
	if FileAccess.file_exists(target):
		var current := ConfigFile.new()
		if current.load(target) == OK:
			DirAccess.copy_absolute(absolute_target, absolute_backup)
		DirAccess.remove_absolute(absolute_target)
	var rename_error := DirAccess.rename_absolute(absolute_temporary, absolute_target)
	if rename_error != OK:
		if FileAccess.file_exists(_backup_path()):
			DirAccess.copy_absolute(absolute_backup, absolute_target)
		push_error("Could not commit loadout: %s" % target)
		return false
	return true

static func vehicle_config(vehicle_id: StringName) -> VehicleConfig:
	var base := vehicle_catalog().get_vehicle(vehicle_id)
	# Callers may tune stats for a race, career event or Survival wave.
	# Keep the catalog's source configs unchanged for the next vehicle/session.
	return base.duplicate() as VehicleConfig if base != null else null

static func vehicle_catalog() -> VehicleCatalog:
	if _vehicle_catalog == null:
		_vehicle_catalog = load(VEHICLE_CATALOG_PATH) as VehicleCatalog
	return _vehicle_catalog

static func vehicle_ids() -> Array[StringName]:
	return vehicle_catalog().ids()

static func weapon_config(weapon_id: StringName) -> WeaponConfig:
	var path: String = WEAPON_PATHS.get(weapon_id, WEAPON_PATHS[&"machine_gun"])
	return load(path) as WeaponConfig
