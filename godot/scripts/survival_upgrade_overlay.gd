extends Control
class_name SurvivalUpgradeOverlay

signal perk_selected(perk: Dictionary)
var _choices: Array[Dictionary] = []

func _ready() -> void:
	hide()
	for index in 3:
		(get_node("Center/Panel/Layout/Choices/Choice%d" % (index + 1)) as Button).pressed.connect(_choose.bind(index))

func show_choices(choices: Array[Dictionary], round_number: int, repair_percent: int) -> void:
	_choices = choices
	%Heading.text = "ВОЛНА %d ПРОЙДЕНА" % round_number
	%Subheading.text = "КУЗОВ ДО 100%% В НАЧАЛЕ ВОЛНЫ · ВЫБЕРИТЕ УСИЛЕНИЕ" if repair_percent == 100 else "ПОЛЕВОЙ РЕМОНТ %d%% · ВЫБЕРИТЕ ОДНО УСИЛЕНИЕ" % repair_percent
	for index in 3:
		var button := get_node("Center/Panel/Layout/Choices/Choice%d" % (index + 1)) as Button
		var perk: Dictionary = choices[index]
		button.text = "%s\n%s" % [perk.name, perk.description]
	show()
	(get_node("Center/Panel/Layout/Choices/Choice1") as Button).grab_focus()

func _choose(index: int) -> void:
	if index < 0 or index >= _choices.size(): return
	hide()
	perk_selected.emit(_choices[index])
