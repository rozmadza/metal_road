extends Control
signal retry_requested
var _story_result: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%RetryButton.pressed.connect(_retry)
	%GarageButton.pressed.connect(_open_garage)
	%MenuButton.pressed.connect(_open_menu)
	%CareerButton.pressed.connect(_open_career)
	hide()


func _retry() -> void:
	_resume_tree()
	_story_result.clear()
	retry_requested.emit()


func _open_garage() -> void:
	_resume_tree()
	SceneTransition.go("res://scenes/Garage.tscn", "ОТКРЫВАЕМ ГАРАЖ")


func _open_menu() -> void:
	_resume_tree()
	SceneTransition.go("res://scenes/MainMenu.tscn", "ВОЗВРАЩЕНИЕ В МЕНЮ")


func _open_career() -> void:
	_resume_tree()
	if CareerStory.prepare_outro(_story_result):
		SceneTransition.go(CareerStory.SCENE, "ПОСЛЕ ГОНКИ")
		return
	SceneTransition.go(CareerSession.CAREER_SCENE, "ЗАГРУЗКА КАРЬЕРЫ")


func _resume_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false

func show_result(result: Dictionary) -> void:
	_story_result = result.duplicate(true)
	%ResultTitle.text = "ФИНИШ" if result.status == &"FINISHED" else "DNF · МАШИНА УНИЧТОЖЕНА"
	var summary := "ПОЗИЦИЯ  %d / %d\nВРЕМЯ  %02d:%05.2f\nКРУГИ  %d / %d\nУНИЧТОЖЕНО  %d · ОРУЖИЕМ %d\nНАНЕСЕНО УРОНА  %.0f\nКРЕДИТЫ  %d" % [result.position, result.participants, int(result.time) / 60, fmod(result.time, 60), result.laps, result.target_laps, result.kills, int(result.get("weapon_kills", 0)), result.damage, result.credits]
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
		if bool(result.get("season_champion", false)): summary += "\n\nВЫ — ЧЕМПИОН РЖАВОГО КУБКА"
	%Summary.text = summary
	%CareerButton.visible = career
	%CareerButton.text = "РАЗГОВОР · КАРЬЕРА" if career and CareerStory.featured_rival(StringName(CareerSession.active_event().get("id", &""))).size() > 0 else "КАРЬЕРА"
	%RetryButton.visible = not bool(result.get("championship_run", false))
	show()
	(%CareerButton if career else %RetryButton).grab_focus()
