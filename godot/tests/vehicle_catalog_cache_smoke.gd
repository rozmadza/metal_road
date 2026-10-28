extends SceneTree

const CATALOG_PATH := "res://resources/vehicle_catalog.tres"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("CATALOG CACHE FAIL: ", label)

func run() -> void:
	var start := Time.get_ticks_usec()
	var catalog := LoadoutProfile.vehicle_catalog()
	var initial_us := Time.get_ticks_usec() - start
	check(catalog != null and catalog.vehicles.size() == 12, "all catalog entries")
	var source_id := catalog.get_instance_id()
	var weak: WeakRef = weakref(catalog)
	catalog = null
	await process_frame
	check(weak.get_ref() != null and ResourceLoader.has_cached(CATALOG_PATH), "strong catalog lifetime")
	var warm_total_us := 0
	var warm_max_us := 0
	for index in 50:
		start = Time.get_ticks_usec()
		var again := LoadoutProfile.vehicle_catalog()
		var spent := Time.get_ticks_usec() - start
		warm_total_us += spent
		warm_max_us = maxi(warm_max_us, spent)
		check(again.get_instance_id() == source_id, "one catalog instance %d" % index)
		again = null
	var ids := LoadoutProfile.vehicle_ids()
	check(ids.size() == 12, "twelve vehicle ids")
	var snapshots := {}
	for id in ids:
		var base := LoadoutProfile.vehicle_catalog().get_vehicle(id)
		var config := LoadoutProfile.vehicle_config(id)
		check(config != base, "independent config %s" % id)
		check(config.vehicle_id == base.vehicle_id and is_equal_approx(config.max_health, base.max_health), "unchanged stats %s" % id)
		for property in base.get_property_list():
			var name: String = str(property.name)
			if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or name in ["resource_path", "resource_scene_unique_id"]:
				continue
			var source_value: Variant = base.get(name)
			var copy_value: Variant = config.get(name)
			check(copy_value == source_value, "copied property %s.%s" % [id, name])
		snapshots[id] = {"health": base.max_health, "speed": base.max_speed, "texture": base.texture}
		config.max_health += 33.0
		config.max_speed += 10.0
		check(is_equal_approx(base.max_health, snapshots[id].health), "source health immutable %s" % id)
		check(is_equal_approx(base.max_speed, snapshots[id].speed), "source speed immutable %s" % id)
		check(config.texture == base.texture, "same artwork %s" % id)
	for id in ids:
		var fresh := LoadoutProfile.vehicle_config(id)
		check(is_equal_approx(fresh.max_health, snapshots[id].health), "fresh health %s" % id)
		check(is_equal_approx(fresh.max_speed, snapshots[id].speed), "fresh speed %s" % id)
	check(LoadoutProfile.vehicle_config(&"unknown").vehicle_id == ids[0], "legacy fallback")
	print("CATALOG CACHE initial_us=", initial_us, " warm_50_total_us=", warm_total_us, " warm_max_us=", warm_max_us, " instances=1 entries=", ids.size())
	print("CATALOG CACHE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
