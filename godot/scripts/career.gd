extends Control
class_name CareerScreen

const MENU_SCENE := "res://scenes/MainMenu.tscn"

var selected_index := 0
var _event_buttons: Array[Button] = []


func _ready() -> void:
	get_node("/root/Music").show_menu()
	%BackButton.pressed.connect(func(): SceneTransition.go(MENU_SCENE, "ВОЗВРАЩЕНИЕ В МЕНЮ"))
	%StartButton.pressed.connect(_start_selected)
	%ChampionshipButton.pressed.connect(_start_championship)
	%ChangeDriverButton.pressed.connect(func(): SceneTransition.go(DriverRoster.SELECT_SCENE, "ВЫБОР ПИЛОТА"))
	%RivalsButton.pressed.connect(func(): SceneTransition.go(RivalRoster.HQ_SCENE, "ШТАБ СОПЕРНИКОВ"))
	%DailyButton.pressed.connect(_start_daily)
	_build_events()
	_refresh()


func _build_events() -> void:
	for index in CareerSession.EVENTS.size():
		var event: Dictionary = CareerSession.EVENTS[index]
		var button := Button.new()
		button.name = "Event_%s" % event.id
		button.custom_minimum_size = Vector2(342, 38)
		button.theme_type_variation = &"IndustrialButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_select_event.bind(index))
		%EventList.add_child(button)
		_event_buttons.append(button)


func _select_event(index: int) -> void:
	selected_index = index
	_refresh()


func _refresh() -> void:
	var state := PlayerProfile.career_state()
	var profile := PlayerProfile.read()
	%Credits.text = "CREDITS  %d" % int(profile.credits)
	var driver := DriverRoster.selected()
	%DriverName.text = "%s · %s" % [driver.get("name", "БЕЗ ПИЛОТА"), driver.get("callsign", "")]
	%DriverPortrait.texture = load(driver.portrait) if not driver.is_empty() else null
	for index in _event_buttons.size():
		var event: Dictionary = CareerSession.EVENTS[index]
		var complete: bool = event.id in state.completed_events
		var unlocked: bool = CareerSession.event_unlocked(index, state)
		var marker := "✓ ПРОЙДЕНО" if complete else ("ДОСТУПНО" if unlocked else "ЗАКРЫТО")
		_event_buttons[index].text = "%02d  %s\n     %s  ·  %s" % [index + 1, event.name, event.location, marker]
		_event_buttons[index].button_pressed = index == selected_index
	_show_event(CareerSession.EVENTS[selected_index], CareerSession.event_unlocked(selected_index, state), state)
	_update_championship(state)
	var personal := RivalRoster.by_id(StringName(state.personal_rival_id))
	%RivalsButton.text = "СОПЕРНИКИ" if personal.is_empty() else "ЛИЧНЫЙ СОПЕРНИК · %s" % personal.callsign
	var daily := CareerSession.daily_event()
	var claimed: bool = StringName(daily.daily_key) in state.daily_claims
	%DailyButton.text = "КОНТРАКТ ДНЯ · %s · %s" % [daily.location, "НАГРАДА ПОЛУЧЕНА" if claimed else "+%d CREDITS" % daily.reward]
	$Margin/Layout/Footer/Hint.text = "БОССЫ %d/2  ·  МЕДАЛИ %d  ·  ежедневный контракт обновляется раз в сутки" % [state.bosses_defeated.size(), _total_medals(state)]


func _show_event(event: Dictionary, unlocked: bool, state: Dictionary) -> void:
	%EventName.text = event.name
	var level := CareerSession.difficulty_level(state)
	%EventType.text = "%s  ·  %s\nУРОВЕНЬ СОПЕРНИКОВ %d  ·  %s" % [event.type_label, event.location, level, CareerDifficulty.summary(level)]
	%Description.text = event.description
	%Objective.text = "ДОП. ЗАДАНИЕ\n%s\n+%d CREDITS" % [event.objective, event.objective_reward]
	var prize_text := "ПРИЗОВАЯ МАШИНА  %s" % _vehicle_name(event.unlock_vehicle) if event.unlock_vehicle != &"" else "ПОВТОРЯЕМАЯ НАГРАДА"
	if StringName(event.get("objective_unlock_vehicle", &"")) != &"":
		prize_text += " · ЗА ЗАДАНИЕ  %s" % _vehicle_name(event.objective_unlock_vehicle)
	%Reward.text = "НАГРАДА ЗА ПЕРВОЕ ПРОХОЖДЕНИЕ  +%d CREDITS\n%s" % [event.reward, prize_text]
	var completed: bool = event.id in state.completed_events
	var objective_done: bool = event.id in state.completed_objectives
	var medals := int(state.event_medals.get(String(event.id), 0))
	%Progress.text = "%s    %s\nМЕДАЛИ  %s%s" % ["● СОБЫТИЕ ПРОЙДЕНО" if completed else "○ СОБЫТИЕ НЕ ПРОЙДЕНО", "● ЗАДАНИЕ ВЫПОЛНЕНО" if objective_done else "○ ЗАДАНИЕ НЕ ВЫПОЛНЕНО", "★".repeat(medals), "☆".repeat(3 - medals)]
	%Progress.modulate = Color("8ae6b2") if completed else Color("c9a15b")
	%StartButton.disabled = not unlocked
	%StartButton.text = "ВЫБРАТЬ МАШИНУ" if unlocked else "СНАЧАЛА ПРОЙДИТЕ ПРЕДЫДУЩЕЕ СОБЫТИЕ"


func _update_championship(state: Dictionary) -> void:
	var index := int(state.championship_index)
	if bool(state.championship_active):
		%ChampionshipButton.text = "ПРОДОЛЖИТЬ ЧЕМПИОНАТ · ЭТАП %d/3" % [mini(index + 1, 3)]
	elif bool(state.championship_complete):
		%ChampionshipButton.text = "НАЧАТЬ ЧЕМПИОНАТ ЗАНОВО"
	else:
		%ChampionshipButton.text = "НАЧАТЬ ЧЕМПИОНАТ · 3 ЭТАПА"
	var standings: Dictionary = state.championship_points
	if standings.is_empty():
		%Standings.text = "[color=#aeb8ba]ЧЕМПИОНАТ ЕЩЁ НЕ НАЧАТ[/color]\nТри события · единая таблица · 1500 CREDITS чемпиону"
		return
	var rows: Array = []
	for name in standings:
		rows.append({"name": name, "points": int(standings[name])})
	rows.sort_custom(func(a, b): return a.points > b.points)
	var lines: Array[String] = ["[color=#eeb75f][b]ТАБЛИЦА ЧЕМПИОНАТА[/b][/color]"]
	for pair_start in range(0, rows.size(), 2):
		var columns: Array[String] = []
		for place in range(pair_start, mini(pair_start + 2, rows.size())):
			var row: Dictionary = rows[place]
			var is_player: bool = row.name == "ВЫ"
			var color := "#8ae6b2" if is_player else "#d5d8d8"
			var display: String = String(row.name) if is_player else RivalRoster.display_name(row.name)
			columns.append("[color=%s]%d. %-6s %d[/color]" % [color, place + 1, display, row.points])
		lines.append("     ".join(columns))
	%Standings.text = "\n".join(lines)


func _start_selected() -> void:
	var state := PlayerProfile.career_state()
	if not CareerSession.event_unlocked(selected_index, state):
		return
	CareerSession.select_event(CareerSession.EVENTS[selected_index].id, false)
	PreRaceSetup.request_mode(&"survival" if CareerSession.EVENTS[selected_index].type == &"arena" else &"race")
	SceneTransition.go(CareerSession.PRE_RACE_SCENE, "ПОДГОТОВКА СОБЫТИЯ")


func _start_championship() -> void:
	CareerSession.start_or_resume_championship()
	PreRaceSetup.request_mode(&"race")
	SceneTransition.go(CareerSession.PRE_RACE_SCENE, "ПОДГОТОВКА ЧЕМПИОНАТА")


func _start_daily() -> void:
	CareerSession.select_daily_challenge()
	PreRaceSetup.request_mode(&"race")
	SceneTransition.go(CareerSession.PRE_RACE_SCENE, "КОНТРАКТ ДНЯ")


func _total_medals(state: Dictionary) -> int:
	var total := 0
	for value in state.event_medals.values(): total += int(value)
	return total


func _vehicle_name(id: StringName) -> String:
	var config := LoadoutProfile.vehicle_config(id)
	return config.display_name if config != null else String(id).to_upper()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneTransition.go(MENU_SCENE, "ВОЗВРАЩЕНИЕ В МЕНЮ")

