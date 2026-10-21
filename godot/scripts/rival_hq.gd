extends Control
class_name RivalHQ

var selected_index := 0
var buttons: Array[Button] = []


func _ready() -> void:
	%BackButton.pressed.connect(func(): SceneTransition.go(CareerSession.CAREER_SCENE, "ВОЗВРАЩЕНИЕ В КАРЬЕРУ"))
	for index in RivalRoster.RIVALS.size():
		var rival: Dictionary = RivalRoster.RIVALS[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(310, 54)
		button.theme_type_variation = &"IndustrialButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select.bind(index))
		%RivalList.add_child(button)
		buttons.append(button)
	var personal := StringName(PlayerProfile.career_state().personal_rival_id)
	for index in RivalRoster.RIVALS.size():
		if RivalRoster.RIVALS[index].id == personal: selected_index = index
	_refresh()


func _select(index: int) -> void:
	selected_index = index
	_refresh()


func _refresh() -> void:
	var state := PlayerProfile.career_state()
	var rival: Dictionary = RivalRoster.RIVALS[selected_index]
	for index in buttons.size():
		var item: Dictionary = RivalRoster.RIVALS[index]
		var level := int(state.rival_levels.get(String(item.id), 1))
		buttons[index].text = "%s  ·  УР. %d\n%s" % [item.callsign, level, item.role]
		buttons[index].button_pressed = index == selected_index
	var level := int(state.rival_levels.get(String(rival.id), 1))
	var vehicle := LoadoutProfile.vehicle_config(rival.vehicle)
	%Portrait.texture = load(rival.portrait)
	%RivalName.text = rival.name
	%Role.text = "%s · УРОВЕНЬ %d" % [rival.role, level]
	%Bio.text = rival.bio
	%Vehicle.text = "%s · %s\nМОДУЛИ: %s" % [vehicle.display_name, vehicle.class_label(), RivalRoster.module_summary(level, selected_index)]
	%Rivalry.text = "ЛИЧНЫЙ СОПЕРНИК" if state.personal_rival_id == rival.id else "НАПРЯЖЕНИЕ: %d" % int(state.rivalry_scores.get(String(rival.id), 0))
	_update_standings(state)


func _update_standings(state: Dictionary) -> void:
	var rows: Array = [{"name":"ВЫ", "points":int(state.season_points.get("player", 0)), "player":true}]
	for rival in RivalRoster.RIVALS: rows.append({"name":rival.callsign, "points":int(state.season_points.get(String(rival.id), 0)), "player":false})
	rows.sort_custom(func(a, b): return a.points > b.points)
	var lines: Array[String] = ["[color=#eeb75f][b]РЕЙТИНГ СЕЗОНА[/b][/color]"]
	for index in rows.size():
		var row: Dictionary = rows[index]
		lines.append("[color=%s]%d. %-7s  %d[/color]" % ["#82e2b5" if row.player else "#d7dada", index + 1, row.name, row.points])
	%Standings.text = "\n".join(lines)
	%News.text = "\n".join(state.last_rival_news) if not state.last_rival_news.is_empty() else "СОПЕРНИКИ ГОТОВЯТСЯ К СЛЕДУЮЩЕМУ ЭТАПУ."


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): SceneTransition.go(CareerSession.CAREER_SCENE, "ВОЗВРАЩЕНИЕ В КАРЬЕРУ")
