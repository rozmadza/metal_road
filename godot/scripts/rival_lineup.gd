extends Control
class_name RivalLineup


func _ready() -> void:
	%BackButton.pressed.connect(func(): SceneTransition.go(CareerSession.PRE_RACE_SCENE, "ВОЗВРАЩЕНИЕ К ВЫБОРУ") )
	var event := CareerSession.active_event()
	%EventName.text = "%s · %s" % [event.get("name", "СВОБОДНАЯ ГОНКА"), event.get("location", "IRON CIRCUIT")]
	_build_player_card()
	if not event.is_empty():
		var state := PlayerProfile.career_state()
		for index in RivalRoster.RIVALS.size(): _add_rival_card(RivalRoster.RIVALS[index], int(state.rival_levels.get(String(RivalRoster.RIVALS[index].id), 1)), index)


func _build_player_card() -> void:
	var driver := DriverRoster.selected()
	var vehicle_id := LoadoutProfile.mode_vehicle(PreRaceSetup._requested_mode)
	var vehicle := LoadoutProfile.vehicle_config(vehicle_id)
	_add_card(driver.get("portrait", ""), driver.get("name", "ВЫ"), "ВАШ ЭКИПАЖ", vehicle.display_name if vehicle != null else "RAIDER", "ВЫБРАННАЯ МАШИНА", Color("70d7ac"))


func _add_rival_card(rival: Dictionary, level: int, index: int) -> void:
	var vehicle := LoadoutProfile.vehicle_config(rival.vehicle)
	_add_card(rival.portrait, rival.name, "%s · УР. %d" % [rival.role, level], vehicle.display_name, RivalRoster.module_summary(level, index), rival.color)


func _add_card(portrait_path: String, title: String, subtitle: String, vehicle: String, modules: String, accent: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 150)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(120, 138)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture = load(portrait_path) if not portrait_path.is_empty() else null
	row.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 18)
	info.add_child(name_label)
	var role := Label.new()
	role.text = subtitle
	role.add_theme_color_override("font_color", accent)
	info.add_child(role)
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; info.add_child(spacer)
	var car := Label.new(); car.text = vehicle; car.add_theme_font_size_override("font_size", 15); info.add_child(car)
	var module_label := Label.new(); module_label.text = modules; module_label.add_theme_color_override("font_color", Color("aeb8ba")); module_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.add_child(module_label)
	%Grid.add_child(panel)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): SceneTransition.go(CareerSession.PRE_RACE_SCENE, "ВОЗВРАЩЕНИЕ К ВЫБОРУ")
