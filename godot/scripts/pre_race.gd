extends Control
class_name PreRaceSetup

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const GARAGE_SCENE := "res://scenes/Garage.tscn"
const RACE_SCENE := "res://scenes/Main.tscn"
const SURVIVAL_SCENE := "res://scenes/ArenaBattle.tscn"

static var _requested_mode: StringName = &"race"

var mode: StringName = &"race"
var selected_vehicle_id: StringName = &"raider"
var comparison_vehicle_id: StringName = &"raider"
var class_filter: int = -1
var _cards: Dictionary = {}
var _card_group := ButtonGroup.new()


static func request_mode(value: StringName) -> void:
	_requested_mode = &"survival" if value == &"survival" else &"race"


func _ready() -> void:
	get_node("/root/Music").show_menu()
	mode = _requested_mode
	comparison_vehicle_id = _valid_mode_vehicle()
	selected_vehicle_id = comparison_vehicle_id
	%BackButton.pressed.connect(_back)
	%GarageButton.pressed.connect(_open_garage)
	%LineupButton.pressed.connect(func(): SceneTransition.go(RivalRoster.LINEUP_SCENE, "СОБИРАЕМ СОПЕРНИКОВ"))
	%StartButton.pressed.connect(_start_mode)
	%ArenaSelect.item_selected.connect(_on_arena_selected)
	%DailyRun.toggled.connect(_on_daily_toggled)
	for filter_button in %ClassFilters.get_children():
		filter_button.pressed.connect(_on_filter_pressed.bind(filter_button))
	_populate_cards()
	_populate_arena_selector()
	%LineupButton.visible = not CareerSession.active_event().is_empty()
	_update_mode_copy()
	_select_vehicle(selected_vehicle_id, false)
	%AllFilter.grab_focus()
	SceneTransition.warm([SURVIVAL_SCENE if mode == &"survival" else RACE_SCENE, GARAGE_SCENE])


func _populate_arena_selector() -> void:
	%ArenaSelect.clear()
	var selected_index := 0
	for index in SurvivalRunData.ARENAS.size():
		var arena: Dictionary = SurvivalRunData.ARENAS[index]
		%ArenaSelect.add_item(arena.name)
		%ArenaSelect.set_item_metadata(index, arena.id)
		if arena.id == SurvivalRunData.selected_arena_id: selected_index = index
	%ArenaSelect.select(selected_index)
	%DailyRun.button_pressed = SurvivalRunData.daily_mode
	%ArenaSelect.disabled = SurvivalRunData.daily_mode


func _on_arena_selected(index: int) -> void:
	SurvivalRunData.selected_arena_id = StringName(%ArenaSelect.get_item_metadata(index))
	_update_mode_copy()


func _on_daily_toggled(enabled: bool) -> void:
	SurvivalRunData.daily_mode = enabled
	%ArenaSelect.disabled = enabled
	_update_mode_copy()


func _valid_mode_vehicle() -> StringName:
	var saved := LoadoutProfile.mode_vehicle(mode)
	if LoadoutProfile.vehicle_catalog().has_vehicle(saved) and PlayerProfile.is_owned(&"vehicle", saved):
		return saved
	var profile := PlayerProfile.read()
	for id in LoadoutProfile.vehicle_ids():
		if id in profile.vehicles:
			return id
	return &"raider"


func _populate_cards() -> void:
	for id in LoadoutProfile.vehicle_ids():
		var config := LoadoutProfile.vehicle_config(id)
		var button := Button.new()
		button.name = "Card_%s" % id
		button.custom_minimum_size = Vector2(238, 92)
		button.theme_type_variation = &"IndustrialButton"
		button.add_theme_font_size_override("font_size", 14)
		button.toggle_mode = true
		button.button_group = _card_group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = GarageVehiclePreview.card_texture(config.texture)
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 82)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.set_meta("vehicle_id", id)
		button.set_meta("vehicle_class", int(config.vehicle_class))
		button.pressed.connect(_on_vehicle_card_pressed.bind(button))
		%VehicleGrid.add_child(button)
		_cards[id] = button
	_update_card_labels()


func _update_card_labels() -> void:
	for id in _cards:
		var config := LoadoutProfile.vehicle_config(id)
		var owned := PlayerProfile.is_owned(&"vehicle", id)
		var state := "В ГАРАЖЕ" if owned else "ЗАБЛОКИРОВАНО · %d" % PlayerProfile.price(&"vehicle", id)
		(_cards[id] as Button).text = "%s\n%s\n%s" % [config.display_name, config.class_label(), state]


func _on_vehicle_card_pressed(button: Button) -> void:
	_select_vehicle(button.get_meta("vehicle_id"), true)


func _select_vehicle(id: StringName, remember: bool) -> void:
	selected_vehicle_id = id
	var config := PlayerProfile.apply_vehicle_upgrades(LoadoutProfile.vehicle_config(id), id)
	var owned := PlayerProfile.is_owned(&"vehicle", id)
	for card_id in _cards:
		(_cards[card_id] as Button).button_pressed = card_id == id
	%VehicleName.text = config.display_name
	%VehicleClass.text = "%s  /  %s" % [config.class_label(), config.passive_name]
	%Description.text = config.description
	%Passive.text = "%s\n%s" % [config.passive_name, config.passive_description]
	%VehiclePreview.set_vehicle(config.texture)
	%VehiclePreview.set_weapon(null)
	%Stats.text = _comparison_text(config)
	var module_names: Array[String] = []
	var labels := {&"engine": "ДВИГАТЕЛЬ", &"armor": "БРОНЯ", &"wheels": "ХОДОВАЯ", &"weapon": "ОРУЖИЕ"}
	for category in PlayerProfile.VEHICLE_UPGRADE_CATEGORIES:
		var level := PlayerProfile.vehicle_upgrade_level(id, category)
		if level > 0:
			module_names.append("%s %d" % [labels[category], level])
	var build := PlayerProfile.active_vehicle_build(id)
	%Upgrades.text = "МОДУЛИ: %s\nСБОРКА: %s" % [(" · ".join(module_names) if not module_names.is_empty() else "СТАНДАРТНАЯ КОМПЛЕКТАЦИЯ"), String(build.get("name", "ШТАТНАЯ"))]
	%Ownership.text = "●  ГОТОВА К ВЫЕЗДУ" if owned else "○  ТРЕБУЕТ ПОКУПКИ В ГАРАЖЕ"
	%Ownership.modulate = Color("8ae6b2") if owned else Color("e85c3c")
	%StartButton.disabled = not owned
	if mode == &"race" and not CareerSession.active_event().is_empty():
		%StartButton.text = "НАЧАТЬ СОБЫТИЕ"
	else:
		%StartButton.text = "НАЧАТЬ ГОНКУ" if mode == &"race" else "ВЫЙТИ НА АРЕНУ"
	if remember and owned:
		LoadoutProfile.save_mode_vehicle(mode, id)


func _comparison_text(config: VehicleConfig) -> String:
	var base := PlayerProfile.apply_vehicle_upgrades(LoadoutProfile.vehicle_config(comparison_vehicle_id), comparison_vehicle_id)
	var lines: Array[String] = []
	lines.append(_stat_line("СКОРОСТЬ", config.max_speed, base.max_speed, "КМ/Ч"))
	lines.append(_stat_line("РАЗГОН", config.acceleration, base.acceleration, ""))
	lines.append(_stat_line("УПРАВЛЕНИЕ", config.steer_rate, base.steer_rate, ""))
	lines.append(_stat_line("БРОНЯ", config.damage_resistance * 100.0, base.damage_resistance * 100.0, "%"))
	lines.append(_stat_line("КУЗОВ", config.max_health, base.max_health, "HP"))
	lines.append(_stat_line("ТАРАН", config.ram_power * 100.0, base.ram_power * 100.0, "%"))
	return "\n".join(lines)


func _stat_line(label: String, value: float, baseline: float, suffix: String) -> String:
	var delta := value - baseline
	var delta_text := ""
	if absf(delta) >= 0.05:
		var color := "#8ae6b2" if delta > 0.0 else "#e88968"
		delta_text = " [color=%s](%+.1f)[/color]" % [color, delta]
	return "[color=#aeb8ba]%s[/color]  [b]%.1f%s[/b]%s" % [label, value, suffix, delta_text]


func _on_filter_pressed(button: Button) -> void:
	class_filter = int(button.get_meta("class_filter", -1))
	for id in _cards:
		var card := _cards[id] as Button
		card.visible = class_filter < 0 or int(card.get_meta("vehicle_class")) == class_filter
	var selected_card := _cards.get(selected_vehicle_id) as Button
	if selected_card == null or not selected_card.visible:
		for id in LoadoutProfile.vehicle_ids():
			if (_cards[id] as Button).visible:
				_select_vehicle(id, false)
				break


func _update_mode_copy() -> void:
	var event := CareerSession.active_event()
	%ArenaSelect.visible = mode == &"survival" and event.is_empty()
	%DailyRun.visible = mode == &"survival" and event.is_empty()
	if not event.is_empty():
		var event_resource := load(event.track)
		var event_track := event_resource as TrackConfig
		var event_arena := event_resource as ArenaConfig
		%TrackPreview.set_track(event_track)
		%Title.text = "КАРЬЕРА · ВЫБОР МАШИНЫ"
		%ModeName.text = "%s · %s" % [event.name, event.location]
		var biome_description := event_track.biome_description if event_track != null else event_arena.biome_description
		%ModeDetails.text = "%s · %s\nУГРОЗЫ: %s\nРЕКОМЕНДАЦИЯ: %s\n%s" % [event.type_label, event.get("modifier_label", "СТАНДАРТНЫЕ УСЛОВИЯ"), event.get("threats", event.objective), event.get("recommended_class", "ЛЮБОЙ КЛАСС"), biome_description]
		%StartButton.text = "НАЧАТЬ СОБЫТИЕ"
	elif mode == &"race":
		%TrackPreview.set_track(load("res://resources/iron_circuit.tres") as TrackConfig)
		%Title.text = "ПОДГОТОВКА К ГОНКЕ"
		%ModeName.text = "IRON CIRCUIT"
		%ModeDetails.text = "3 КРУГА  ·  6 УЧАСТНИКОВ  ·  ОРУЖИЕ НА ТРАССЕ"
	else:
		%TrackPreview.set_track(null)
		%Title.text = "ПОДГОТОВКА К ВЫЖИВАНИЮ"
		var selected_arena := SurvivalRunData.selected_arena()
		%ModeName.text = ("КОНТРАКТ ДНЯ · " if SurvivalRunData.daily_mode else "") + String(selected_arena.name)
		%ModeDetails.text = "5 ВОЛН · ЭЛИТНЫЕ ОТРЯДЫ · БОСС\n%s" % selected_arena.mechanic


func _start_mode() -> void:
	if not PlayerProfile.is_owned(&"vehicle", selected_vehicle_id):
		return
	LoadoutProfile.save_mode_vehicle(mode, selected_vehicle_id)
	var ids := LoadoutProfile.read_ids()
	LoadoutProfile.save_ids(selected_vehicle_id, ids.weapon)
	if mode != &"survival" and CareerStory.prepare_intro(StringName(CareerSession.active_event().get("id", &"")), RACE_SCENE):
		SceneTransition.go(CareerStory.SCENE, "ПЕРЕД СТАРТОМ")
		return
	SceneTransition.go(SURVIVAL_SCENE if mode == &"survival" else RACE_SCENE, "ВЫЕЗД НА АРЕНУ" if mode == &"survival" else "ВЫЕЗД НА СТАРТ")


func _open_garage() -> void:
	var ids := LoadoutProfile.read_ids()
	LoadoutProfile.save_ids(selected_vehicle_id, ids.weapon)
	SceneTransition.go(GARAGE_SCENE, "ОТКРЫВАЕМ ГАРАЖ")


func _back() -> void:
	SceneTransition.go(CareerSession.CAREER_SCENE if not CareerSession.active_event().is_empty() else MENU_SCENE, "ВОЗВРАЩЕНИЕ")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
