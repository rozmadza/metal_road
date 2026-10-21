extends Control

const MENU := "res://scenes/MainMenu.tscn"

func _ready() -> void:
	%BackButton.pressed.connect(func(): SceneTransition.go(MENU, "ВОЗВРАЩЕНИЕ В МЕНЮ"))
	%Slot1.pressed.connect(_select_slot.bind(1))
	%Slot2.pressed.connect(_select_slot.bind(2))
	%Slot3.pressed.connect(_select_slot.bind(3))
	_refresh()

func _select_slot(slot: int) -> void:
	PlayerProfile.set_active_slot(slot)
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("settings", "profile_slot", PlayerProfile.active_slot)
	cfg.save("user://settings.cfg")
	_refresh()

func _refresh() -> void:
	var data := PlayerProfile.read()
	var career: Dictionary = data.career
	var races := 0
	var wins := 0
	var kills := 0
	var damage := 0.0
	for state in data.vehicle_states.values():
		races += int(state.races)
		wins += int(state.wins)
		kills += int(state.kills)
		damage += float(state.damage_dealt)
	%SlotLabel.text = "ПРОФИЛЬ %d" % PlayerProfile.active_slot
	var event_total := CareerSession.EVENTS.size()
	%Summary.text = "УРОВЕНЬ КАРЬЕРЫ  %d\nCREDITS  %d\nМАШИНЫ  %d/8\nСОБЫТИЯ  %d/%d\nБОССЫ  %d/2\nМЕДАЛИ  %d/%d" % [career.career_level, data.credits, data.vehicles.size(), career.completed_events.size(), event_total, career.bosses_defeated.size(), _medals(career), event_total * 3]
	var survival: Dictionary = career.get("survival_records", {})
	%Stats.text = "ЗАЕЗДЫ  %d\nПОБЕДЫ  %d\nУНИЧТОЖЕНО  %d\nНАНЕСЕНО УРОНА  %d\nРЕКОРД ВЫЖИВАНИЯ  %d · ВОЛНА %d · БОССЫ %d\nКОНТРАКТЫ ДНЯ  %d" % [races, wins, kills, roundi(damage), int(survival.get("best_score", 0)), int(survival.get("best_round", 0)), int(survival.get("boss_kills", 0)), career.daily_claims.size() + career.survival_daily_claims.size()]
	var achievements := [
		["ПЕРВАЯ КРОВЬ", kills >= 1], ["ДОРОЖНЫЙ ВОИН", wins >= 10],
		["КОЛЛЕКЦИОНЕР", data.vehicles.size() >= 12], ["ОХОТНИК НА БОССОВ", career.bosses_defeated.size() >= 2],
		["РЖАВАЯ КОРОНА", bool(career.championship_complete)], ["ИДЕАЛЬНЫЙ СЕЗОН", _medals(career) >= CareerSession.EVENTS.size() * 3],
	]
	var lines: Array[String] = []
	for item in achievements: lines.append("[color=%s]%s  %s[/color]" % ["#8ae6b2" if item[1] else "#657073", "◆" if item[1] else "◇", item[0]])
	%Achievements.text = "\n".join(lines)
	for slot in [1, 2, 3]:
		var summary := PlayerProfile.slot_summary(slot)
		var button: Button = get_node("Margin/Layout/Header/Slots/Slot%d" % slot)
		button.text = "%d · %s" % [slot, ("УР. %d · %d СОБ." % [summary.level, summary.events]) if summary.exists else "ПУСТО"]
		button.button_pressed = slot == PlayerProfile.active_slot

func _medals(career: Dictionary) -> int:
	var total := 0
	for value in career.event_medals.values(): total += int(value)
	return total

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): SceneTransition.go(MENU, "ВОЗВРАЩЕНИЕ В МЕНЮ")
