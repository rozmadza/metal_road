extends Control
## Vehicle shop and upgrade bay. Weapons are earned as temporary pickups in a match.
@export var vehicle_config: VehicleConfig
@onready var _vehicle_select: OptionButton = %VehicleSelect
var _vehicle_id: StringName
const CORE_UPGRADE_CATEGORIES := [&"engine", &"armor", &"wheels", &"weapon"]
const UPGRADE_CATEGORIES := [&"engine", &"armor", &"wheels", &"weapon", &"build", &"specialization"]
const CATEGORY_LABELS := {
	&"engine": "ДВИГАТЕЛЬ",
	&"armor": "БРОНЯ",
	&"wheels": "ХОДОВАЯ",
	&"weapon": "ВООРУЖЕНИЕ",
	&"build": "БОЕВАЯ СБОРКА",
	&"specialization": "СПЕЦИАЛИЗАЦИЯ",
}

func _ready() -> void:
	SceneTransition.warm(["res://scenes/PreRace.tscn", "res://scenes/MainMenu.tscn"])
	_populate_selectors()
	_populate_upgrades()
	var ids := LoadoutProfile.read_ids()
	_vehicle_id = ids.vehicle if LoadoutProfile.vehicle_catalog().has_vehicle(ids.vehicle) else &"raider"
	_vehicle_select.select(maxi(0, LoadoutProfile.vehicle_ids().find(_vehicle_id)))
	_apply_selection()
	_vehicle_select.item_selected.connect(_on_vehicle_selected)
	%UpgradeSelect.item_selected.connect(_on_upgrade_category_selected)
	%BackButton.pressed.connect(_back)
	%RaceButton.pressed.connect(func(): _open_pre_race(&"race"))
	%SurvivalButton.pressed.connect(func(): _open_pre_race(&"survival"))
	%PurchaseButton.pressed.connect(_purchase_selected)
	%SellButton.pressed.connect(_sell_selected)
	%UpgradeButton.pressed.connect(_purchase_upgrade)
	%SpecializationA.pressed.connect(func(): _purchase_specialization(0))
	%SpecializationB.pressed.connect(func(): _purchase_specialization(1))
	%BuildFactory.pressed.connect(func(): _select_build(0))
	%BuildA.pressed.connect(func(): _select_build(1))
	%BuildB.pressed.connect(func(): _select_build(2))
	_refresh_economy()
	%BackButton.grab_focus()

func _populate_selectors() -> void:
	for id in LoadoutProfile.vehicle_ids():
		_vehicle_select.add_item(LoadoutProfile.vehicle_config(id).display_name)

func _on_vehicle_selected(index: int) -> void:
	_vehicle_id = LoadoutProfile.vehicle_ids()[index]
	_apply_selection()

func _apply_selection() -> void:
	vehicle_config = PlayerProfile.apply_vehicle_upgrades(LoadoutProfile.vehicle_config(_vehicle_id), _vehicle_id)
	%VehiclePreview.set_vehicle(vehicle_config.texture)
	%VehiclePreview.set_weapon(null)
	%VehiclePreview.set_modules(_module_levels())
	%VehicleName.text = vehicle_config.display_name
	%Class.text = "%s · %s" % [vehicle_config.class_label(), vehicle_config.passive_name]
	%Class.tooltip_text = "%s\n%s\n%s: %s" % [vehicle_config.description, vehicle_config.class_combat_role(), vehicle_config.passive_name, vehicle_config.passive_description]
	%Stats.text = "СКОРОСТЬ  %d КМ/Ч    РАЗГОН  %d\nУПРАВЛЕНИЕ  %.1f    БРОНЯ  %d%%\nКУЗОВ  %d HP    РЕМОНТ КОЛЁС  %.1f/С\nДВИГАТЕЛЬ ×%.2f    ХОДОВАЯ ×%.2f" % [vehicle_config.max_speed, vehicle_config.acceleration, vehicle_config.steer_rate, roundi(vehicle_config.damage_resistance * 100.0), vehicle_config.max_health, vehicle_config.wheels_repair_rate, vehicle_config.module_damage_multiplier(&"engine"), vehicle_config.module_damage_multiplier(&"wheels")]
	if PlayerProfile.is_owned(&"vehicle", _vehicle_id):
		var ids := LoadoutProfile.read_ids()
		LoadoutProfile.save_ids(_vehicle_id, ids.weapon)
	_refresh_economy()

func _populate_upgrades() -> void:
	for category in UPGRADE_CATEGORIES:
		%UpgradeSelect.add_item(CATEGORY_LABELS[category])
		%UpgradeSelect.set_item_metadata(%UpgradeSelect.item_count - 1, category)


func _on_upgrade_category_selected(_index: int) -> void:
	_refresh_upgrade_panel()

func _refresh_economy() -> void:
	var profile := PlayerProfile.read()
	%Credits.text = "CREDITS  %d" % int(profile.credits)
	var vehicle_owned := PlayerProfile.is_owned(&"vehicle", _vehicle_id)
	var purchase_availability := PlayerProfile.vehicle_purchase_availability(_vehicle_id, profile)
	%Ready.text = "●  ВАША МАШИНА" if vehicle_owned else "○  НЕ КУПЛЕНА"
	%Ready.modulate = Color("#8ae6b2") if vehicle_owned else Color("#e85c3c")
	%Ownership.text = "ВЛАДЕНИЕ: %s" % ("ДОСТУПНО" if vehicle_owned else "ТРЕБУЕТ ПОКУПКИ")
	%Ownership.modulate = Color("#8ae6b2") if vehicle_owned else Color("#e85c3c")
	if not vehicle_owned:
		%PurchaseButton.text = "КУПИТЬ МАШИНУ · %d" % PlayerProfile.price(&"vehicle", _vehicle_id) if bool(purchase_availability.allowed) else String(purchase_availability.reason)
	else:
		%PurchaseButton.text = "МАШИНА В ГАРАЖЕ"
	%PurchaseButton.disabled = vehicle_owned or not bool(purchase_availability.allowed)
	%SellButton.text = "ПРОДАТЬ · %d" % int(round(PlayerProfile.price(&"vehicle", _vehicle_id) * PlayerProfile.economy().vehicle_sell_ratio))
	%SellButton.disabled = not vehicle_owned or _vehicle_id == &"raider" or profile.vehicles.size() <= 1
	%RaceButton.disabled = not vehicle_owned
	%SurvivalButton.disabled = not vehicle_owned
	_refresh_upgrade_selector()
	_refresh_upgrade_panel()

func _purchase_selected() -> void:
	if PlayerProfile.purchase(&"vehicle", _vehicle_id):
		var ids := LoadoutProfile.read_ids()
		LoadoutProfile.save_ids(_vehicle_id, ids.weapon)
		_refresh_economy()
	else:
		%Ownership.text = "НЕДОСТАТОЧНО CREDITS"

func _sell_selected() -> void:
	var refund := PlayerProfile.sell_vehicle(_vehicle_id)
	if refund <= 0:
		return
	_vehicle_id = &"raider"
	_vehicle_select.select(LoadoutProfile.vehicle_ids().find(_vehicle_id))
	_apply_selection()
	%Ownership.text = "ПРОДАНО · +%d CREDITS" % refund

func _purchase_upgrade() -> void:
	var category := _selected_upgrade_category()
	var upgrade := PlayerProfile.next_vehicle_upgrade(_vehicle_id, category)
	if upgrade == null:
		return
	if PlayerProfile.purchase_upgrade(upgrade.id, &"vehicle", _vehicle_id):
		_apply_selection()
	else:
		var availability := PlayerProfile.upgrade_availability(upgrade.id, _vehicle_id)
		%Ownership.text = String(availability.reason)


func _purchase_specialization(index: int) -> void:
	var options := PlayerProfile.specialization_options(_vehicle_id)
	if index < 0 or index >= options.size(): return
	var upgrade := options[index]
	if PlayerProfile.purchase_upgrade(upgrade.id, &"vehicle", _vehicle_id):
		_apply_selection()
	else:
		%Ownership.text = String(PlayerProfile.upgrade_availability(upgrade.id, _vehicle_id).reason)


func _select_build(index: int) -> void:
	var options := PlayerProfile.vehicle_build_options(_vehicle_id)
	if index < 0 or index >= options.size(): return
	var option: Dictionary = options[index]
	if PlayerProfile.set_vehicle_build(_vehicle_id, StringName(option.id)):
		_apply_selection()
	else:
		%Ownership.text = String(PlayerProfile.vehicle_build_availability(_vehicle_id, StringName(option.id)).reason)


func _selected_upgrade_category() -> StringName:
	var index: int = int(%UpgradeSelect.selected)
	if index < 0 or index >= %UpgradeSelect.item_count:
		return &"engine"
	return StringName(%UpgradeSelect.get_item_metadata(index))


func _module_levels() -> Dictionary:
	var result := {}
	for category in CORE_UPGRADE_CATEGORIES:
		result[category] = PlayerProfile.vehicle_upgrade_level(_vehicle_id, category)
	return result


func _refresh_upgrade_selector() -> void:
	var levels := _module_levels()
	for index in %UpgradeSelect.item_count:
		var category: StringName = %UpgradeSelect.get_item_metadata(index)
		if category == &"specialization":
			var installed := PlayerProfile.installed_specialization(_vehicle_id)
			%UpgradeSelect.set_item_text(index, "СПЕЦИАЛИЗАЦИЯ  ·  %s" % ("ВЫБРАНА" if installed != null else "ВЫБОР"))
		elif category == &"build":
			var build := PlayerProfile.active_vehicle_build(_vehicle_id)
			%UpgradeSelect.set_item_text(index, "БОЕВАЯ СБОРКА  ·  %s" % String(build.get("name", "ШТАТНАЯ")))
		else:
			%UpgradeSelect.set_item_text(index, "%s  ·  УР. %d/3" % [CATEGORY_LABELS[category], int(levels[category])])
	var specialization := PlayerProfile.installed_specialization(_vehicle_id)
	var specialization_text := "[color=#c7a66a]СПЕЦИАЛИЗАЦИЯ: %s[/color]" % (specialization.display_name if specialization != null else "НЕ ВЫБРАНА")
	var build := PlayerProfile.active_vehicle_build(_vehicle_id)
	var build_text := "[color=#72c7d8]СБОРКА: %s[/color]" % String(build.get("name", "ШТАТНАЯ"))
	%InstalledModules.text = (
		"[color=#f2a53b][b]ДВИГАТЕЛЬ %d/3[/b][/color]  ·  [color=#72c7d8][b]БРОНЯ %d/3[/b][/color]\n"
		+ "[color=#a8d46f][b]ХОДОВАЯ %d/3[/b][/color]  ·  [color=#ef6b61][b]ОРУЖИЕ %d/3[/b][/color]\n%s  ·  %s"
	) % [levels.engine, levels.armor, levels.wheels, levels.weapon, build_text, specialization_text]
	%VehiclePreview.set_modules(levels)


func _refresh_upgrade_panel() -> void:
	var category := _selected_upgrade_category()
	if category == &"specialization":
		_refresh_specialization_panel()
		return
	if category == &"build":
		_refresh_build_panel()
		return
	%UpgradeButton.visible = true
	%SpecializationActions.visible = false
	%BuildActions.visible = false
	var current_level := PlayerProfile.vehicle_upgrade_level(_vehicle_id, category)
	var upgrade := PlayerProfile.next_vehicle_upgrade(_vehicle_id, category)
	var vehicle_owned := PlayerProfile.is_owned(&"vehicle", _vehicle_id)
	if upgrade == null:
		%UpgradeDetails.text = "[color=#8ae6b2][b]%s III[/b][/color]\nМАКСИМАЛЬНАЯ КОМПЛЕКТАЦИЯ" % CATEGORY_LABELS[category]
		%UpgradeButton.text = "МАКСИМАЛЬНЫЙ УРОВЕНЬ"
		%UpgradeButton.disabled = true
		return
	var availability := PlayerProfile.upgrade_availability(upgrade.id, _vehicle_id)
	var reason_color := "#8ae6b2" if bool(availability.allowed) else "#e88968"
	var effect_text := _upgrade_effect_text(upgrade)
	%UpgradeDetails.text = (
		"[color=#eeb75f][b]%s · УР. %d → %d[/b][/color]\n%s\n%s\n[color=%s]%s[/color]"
		% [CATEGORY_LABELS[category], current_level, upgrade.level, upgrade.description, effect_text, reason_color, availability.reason]
	)
	%UpgradeButton.text = "УСТАНОВИТЬ · %d CREDITS" % upgrade.cost
	%UpgradeButton.disabled = not vehicle_owned or not bool(availability.allowed)


func _refresh_specialization_panel() -> void:
	%UpgradeButton.visible = false
	%SpecializationActions.visible = true
	%BuildActions.visible = false
	var options := PlayerProfile.specialization_options(_vehicle_id)
	var buttons: Array[Button] = [%SpecializationA, %SpecializationB]
	if options.is_empty():
		%UpgradeDetails.text = "[color=#8b9294][b]СПЕЦИАЛИЗАЦИЯ НЕДОСТУПНА[/b][/color]\nФИНАЛЬНЫЕ ВЕТКИ ЕСТЬ У МАШИН SEASON 1"
		for button in buttons:
			button.text = "НЕДОСТУПНО"
			button.disabled = true
		return
	var installed := PlayerProfile.installed_specialization(_vehicle_id)
	var descriptions: Array[String] = []
	for index in buttons.size():
		var option := options[index]
		var availability := PlayerProfile.upgrade_availability(option.id, _vehicle_id)
		buttons[index].text = "%s · %d" % [option.display_name, option.cost]
		buttons[index].disabled = installed != null or not bool(availability.allowed)
		descriptions.append("[color=#eeb75f][b]%s[/b][/color] — %s\n%s" % [option.display_name, option.description, _upgrade_effect_text(option)])
	%UpgradeDetails.text = "\n\n".join(descriptions) + ("\n[color=#8ae6b2]ВЫБРАНО: %s[/color]" % installed.display_name if installed != null else "\n[color=#e88968]МОЖНО ВЫБРАТЬ ТОЛЬКО ОДНУ ВЕТКУ[/color]")


func _refresh_build_panel() -> void:
	%UpgradeButton.visible = false
	%SpecializationActions.visible = false
	%BuildActions.visible = true
	var options := PlayerProfile.vehicle_build_options(_vehicle_id)
	var active := PlayerProfile.active_vehicle_build(_vehicle_id)
	var buttons: Array[Button] = [%BuildFactory, %BuildA, %BuildB]
	var descriptions: Array[String] = []
	for index in buttons.size():
		if index >= options.size():
			buttons[index].visible = false
			continue
		buttons[index].visible = true
		var option: Dictionary = options[index]
		var availability := PlayerProfile.vehicle_build_availability(_vehicle_id, StringName(option.id))
		var selected := StringName(option.id) == StringName(active.get("id", &"factory"))
		buttons[index].text = ("● " if selected else "") + String(option.name)
		buttons[index].disabled = selected or not bool(availability.allowed)
		var effects := _modifier_effect_text(option.modifiers)
		var requirement := "" if int(option.unlock) == 0 else " · ОТ %d УР. МОДУЛЕЙ" % int(option.unlock)
		descriptions.append("[color=#eeb75f][b]%s[/b][/color]%s — %s\n%s" % [option.name, requirement, option.description, effects if not effects.is_empty() else "БЕЗ МОДИФИКАТОРОВ"])
	%UpgradeDetails.text = "\n".join(descriptions) + "\n[color=#72c7d8]СБОРКУ МОЖНО МЕНЯТЬ ПЕРЕД КАЖДЫМ ВЫЕЗДОМ[/color]"


func _upgrade_effect_text(upgrade: UpgradeConfig) -> String:
	return _modifier_effect_text(upgrade.modifiers)


func _modifier_effect_text(modifiers: Dictionary) -> String:
	var parts: Array[String] = []
	var labels := {
		"max_speed": ["СКОРОСТЬ", ""],
		"acceleration": ["РАЗГОН", ""],
		"max_health": ["КУЗОВ", " HP"],
		"damage_resistance": ["БРОНЯ", "%"],
		"traction": ["СЦЕПЛЕНИЕ", ""],
		"steer_rate": ["УПРАВЛЕНИЕ", ""],
		"wheels_repair_rate": ["РЕМОНТ КОЛЁС", "/С"],
		"weapon_damage_multiplier": ["УРОН ОРУЖИЯ", "%"],
		"weapon_fire_rate_multiplier": ["ТЕМП ОГНЯ", "%"],
		"ram_power": ["ТАРАН", "%"],
		"passive_bonus_duration_multiplier": ["ДЛИТЕЛЬНОСТЬ БОНУСОВ", "%"],
		"passive_apex_duration": ["АПЕКС", " С"],
		"passive_apex_cooldown": ["ПЕРЕЗАРЯДКА АПЕКСА", " С"],
		"engine_health": ["РЕСУРС ДВИГАТЕЛЯ", " HP"],
		"wheels_health": ["РЕСУРС ХОДОВОЙ", " HP"],
		"body_damage_multiplier": ["УЯЗВИМОСТЬ КУЗОВА", "%"],
		"engine_damage_multiplier": ["УЯЗВИМОСТЬ ДВИГАТЕЛЯ", "%"],
		"wheels_damage_multiplier": ["УЯЗВИМОСТЬ ХОДОВОЙ", "%"],
	}
	for key in modifiers:
		if not labels.has(String(key)):
			continue
		var value := float(modifiers[key])
		if String(key) in ["damage_resistance", "weapon_damage_multiplier", "weapon_fire_rate_multiplier", "ram_power", "passive_bonus_duration_multiplier", "body_damage_multiplier", "engine_damage_multiplier", "wheels_damage_multiplier"]:
			value *= 100.0
		var copy: Array = labels[String(key)]
		parts.append("%s %+.1f%s" % [copy[0], value, copy[1]])
	return " · ".join(parts)

func _back() -> void:
	SceneTransition.go("res://scenes/MainMenu.tscn", "ВОЗВРАЩЕНИЕ В МЕНЮ")

func _open_pre_race(mode: StringName) -> void:
	PreRaceSetup.request_mode(mode)
	SceneTransition.go("res://scenes/PreRace.tscn", "ПОДГОТОВКА ВЫЕЗДА")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
