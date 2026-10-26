extends SceneTree

const CATALOG_PATH := "res://resources/vehicle_catalog.tres"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var durations: Array[int] = []
	var weak: WeakRef
	var first_id := 0
	for index in 4:
		var start := Time.get_ticks_usec()
		var catalog := ResourceLoader.load(CATALOG_PATH) as VehicleCatalog
		durations.append(Time.get_ticks_usec() - start)
		if index == 0:
			first_id = catalog.get_instance_id()
			weak = weakref(catalog)
		print("CATALOG PROBE index=", index, " load_us=", durations.back(), " cached=", ResourceLoader.has_cached(CATALOG_PATH), " same_first=", catalog.get_instance_id() == first_id, " first_alive=", weak.get_ref() != null)
		catalog = null
		await process_frame
		print("CATALOG PROBE after_release index=", index, " cached=", ResourceLoader.has_cached(CATALOG_PATH), " first_alive=", weak.get_ref() != null)
	quit()
