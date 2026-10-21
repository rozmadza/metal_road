extends RefCounted
class_name CareerStory
## Authored, fact-checked dialogue for career encounters.

const SCENE := "res://scenes/CareerDialogue.tscn"
static var pending: Dictionary = {}


static func featured_rival(event_id: StringName) -> Dictionary:
	if event_id == &"iron_open":
		return RivalRoster.by_id(&"razor")
	return {}


static func prepare_intro(event_id: StringName, destination: String) -> bool:
	var rival := featured_rival(event_id)
	if rival.is_empty():
		return false
	var driver := DriverRoster.selected()
	if driver.is_empty():
		return false
	var hero_reply: String = {
		&"mara": "Первый поворот уже просчитан. Увидимся на выходе.",
		&"rook": "Скорость хороша, пока машина доживает до финиша.",
		&"flint": "Тогда посмотрим, кто из нас оставит след впереди.",
	}.get(driver.id, "Встретимся на финише.")
	pending = {
		"event_id": event_id,
		"chapter": "ЖЕЛЕЗНЫЙ СТАРТ · ПЕРЕД ГОНКОЙ",
		"detail": "IRON CIRCUIT · ПЕРВАЯ ВСТРЕЧА",
		"driver": driver,
		"rival": rival,
		"lines": [
			{"speaker": &"razor", "text": "Новичкам на этой трассе оставляют только пыль. Держись позади."},
			{"speaker": driver.id, "text": hero_reply},
		],
		"destination": destination,
		"back": CareerSession.PRE_RACE_SCENE,
	}
	return true


static func prepare_outro(result: Dictionary) -> bool:
	if not bool(result.get("career_event", false)) or CareerSession.active_event().get("id", &"") != &"iron_open":
		return false
	var driver := DriverRoster.selected()
	var rival := featured_rival(&"iron_open")
	if driver.is_empty() or rival.is_empty():
		return false
	var player_place := int(result.get("position", 6))
	var rival_place := int(result.get("rival_positions", {}).get("razor", 6))
	var destroyed := StringName(result.get("status", &"")) == &"DNF"
	var won_duel := not destroyed and player_place < rival_place
	var razor_text := "Ты оставил машину на трассе. Вернись, когда сможешь доехать до конца." if destroyed else (
		"Сегодня ты был впереди. На следующем старте я заберу эту позицию обратно." if won_duel else
		"Я видел тебя в зеркале. В следующий раз держись ближе.")
	var hero_text: String = {
		&"mara": "Ошибку я запомнила. Следующий заезд начну иначе." if not won_duel else "Теперь ему придётся менять план. Я свой уже подготовила.",
		&"rook": "Сначала восстановлю машину. Потом вернусь за этой позицией." if not won_duel else "Машина выдержала. Теперь проверим, выдержит ли он реванш.",
		&"flint": "В следующий раз отпущу тормоз раньше." if not won_duel else "Теперь пусть попробует догнать меня.",
	}.get(driver.id, "Это ещё не конец.")
	pending = {
		"event_id": &"iron_open",
		"chapter": "ЖЕЛЕЗНЫЙ СТАРТ · ПОСЛЕ ГОНКИ",
		"detail": "ВАШЕ МЕСТО %d · РЭЙЗОР %d" % [player_place, rival_place],
		"driver": driver,
		"rival": rival,
		"lines": [
			{"speaker": &"razor", "text": razor_text},
			{"speaker": driver.id, "text": hero_text},
		],
		"destination": CareerSession.CAREER_SCENE,
		"back": CareerSession.CAREER_SCENE,
	}
	return true


static func clear() -> void:
	pending = {}
