extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var catalog := LoadoutProfile.vehicle_catalog()
	for id in catalog.ids():
		var config := catalog.get_vehicle(id)
		var icon := GarageVehiclePreview.card_texture(config.texture)
		var region := GarageVehiclePreview.visible_region(icon)
		check(icon.get_size() == Vector2(82, 50), "%s uses the common card canvas" % id)
		check(region.size.x >= 68.0 and region.size.x <= 82.0, "%s has normalized visual length" % id)
		check(region.size.y >= 20.0 and region.size.y <= 50.0, "%s remains readable without distortion" % id)
	print("VEHICLE CARD ICONS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("VEHICLE CARD ICON FAIL: ", label)
