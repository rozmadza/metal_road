extends Control
class_name SurvivalResults

signal retry_requested

func _ready() -> void:
	# Results must remain interactive even if defeat and a pause request land in
	# the same frame. Otherwise buttons still highlight but never emit pressed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	%RetryButton.pressed.connect(_retry)
	%GarageButton.pressed.connect(_open_garage)
	%MenuButton.pressed.connect(_open_menu)
	%CareerButton.pressed.connect(_open_career)
	hide()


func _retry() -> void:
	_resume_tree()
	retry_requested.emit()


func _open_garage() -> void:
	_resume_tree()
	SceneTransition.go("res://scenes/Garage.tscn", "ОТКРЫВАЕМ ГАРАЖ")


func _open_menu() -> void:
	_resume_tree()
	SceneTransition.go("res://scenes/MainMenu.tscn", "ВОЗВРАЩЕНИЕ В МЕНЮ")


func _open_career() -> void:
	_resume_tree()
	SceneTransition.go(CareerSession.CAREER_SCENE, "ЗАГРУЗКА КАРЬЕРЫ")


func _resume_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false

func show_result(result: Dictionary) -> void:
	var won: bool = result.get("status", &"DEFEAT") == &"VICTORY"
	%ResultTitle.text = "ПОБЕДА" if won else "ПОРАЖЕНИЕ"
	var summary := "РАУНД  %d\nУНИЧТОЖЕНО  %d · ОРУЖИЕМ %d\nНАНЕСЕНО УРОНА  %.0f\nВРЕМЯ  %02d:%05.2f\nКРЕДИТЫ  %d" % [
		int(result.get("round", 1)), int(result.get("kills", 0)), int(result.get("weapon_kills", 0)), float(result.get("damage", 0.0)),
		int(float(result.get("time", 0.0))) / 60, fmod(float(result.get("time", 0.0)), 60.0),
		int(result.get("credits", 0))
	]
	if int(result.get("crew_crushed", 0)) > 0 or int(result.get("crew_escaped", 0)) > 0:
		summary += "\nЭКИПАЖ СБИТ  %d · УШЛО %d" % [int(result.get("crew_crushed", 0)), int(result.get("crew_escaped", 0))]
	summary = "АРЕНА  %s\nСЧЁТ  %d · РЕКОРД %d\nЛУЧШЕЕ КОМБО  x%d · БОССОВ %d\n%s" % [
		String(result.get("arena", "АРЕНА")), int(result.get("score", 0)), int(result.get("best_score", result.get("score", 0))),
		int(result.get("best_combo", 0)), int(result.get("boss_kills", 0)), summary,
	]
	var build: Array = result.get("build", [])
	if not build.is_empty(): summary += "\n\nСБОРКА  %s" % " · ".join(build)
	if int(result.get("daily_reward", 0)) > 0: summary += "\nКОНТРАКТ ДНЯ  +%d CREDITS" % int(result.daily_reward)
	var career := bool(result.get("career_event", false))
	if career:
		summary += "\n\nСОБЫТИЕ  %s\nЗАДАНИЕ  %s" % [result.get("event_name", ""), "ВЫПОЛНЕНО" if bool(result.get("objective_completed", false)) else "НЕ ВЫПОЛНЕНО"]
		if int(result.get("career_bonus", 0)) > 0:
			summary += "\nКАРЬЕРНАЯ НАГРАДА  +%d" % int(result.career_bonus)
		var unlocked_list: Array = result.get("unlocked_vehicles", [])
		if unlocked_list.is_empty() and StringName(result.get("unlocked_vehicle", &"")) != &"": unlocked_list.append(result.unlocked_vehicle)
		for unlocked in unlocked_list:
			var config := LoadoutProfile.vehicle_config(unlocked)
			summary += "\nОТКРЫТА МАШИНА  %s" % (config.display_name if config != null else String(unlocked).to_upper())
		if not String(result.get("personal_rival", "")).is_empty():
			summary += "\nРЕЙТИНГ СЕЗОНА  %d МЕСТО · СОПЕРНИК %s" % [int(result.get("season_rank", 1)), result.personal_rival]
		var news: Array = result.get("rival_news", [])
		if not news.is_empty(): summary += "\n\nСОПЕРНИКИ УСИЛИЛИСЬ\n%s" % "\n".join(news)
	%Summary.text = summary
	%CareerButton.visible = career
	show()
	(%CareerButton if career else %RetryButton).grab_focus()
