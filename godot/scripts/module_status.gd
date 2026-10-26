extends VBoxContainer
class_name ModuleStatus
## Compact shared readout; values always come from Vehicle.get_hud_state().
var bars: Array[ProgressBar] = []
var labels: Array[Label] = []
var damage_label: Label
var compact_mode := false
const MODULES := ["body_health", "engine_health", "wheels_health"]
const TITLES := ["КУЗОВ", "ДВИГАТЕЛЬ", "КОЛЁСА"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 1)
	damage_label = Label.new()
	damage_label.text = "СОСТОЯНИЕ: НОРМА"
	damage_label.add_theme_font_size_override("font_size", 11)
	damage_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.65))
	add_child(damage_label)
	for title in TITLES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		add_child(row)
		var label := Label.new()
		label.custom_minimum_size.x = 76
		label.text = title
		label.add_theme_font_size_override("font_size", 11)
		row.add_child(label)
		labels.append(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(48, 5)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		row.add_child(bar)
		bars.append(bar)

func update_vehicle(vehicle: Vehicle) -> void:
	update_state(vehicle.get_hud_state())

func update_state(state: Dictionary) -> void:
	var stage := int(state.get("damage_stage", 0))
	var stage_names := ["НОРМА", "ЦАРАПИНЫ", "ПОВРЕЖДЕН", "КРИТИЧЕСКОЕ", "УНИЧТОЖЕН"]
	var stage_colors := [Color(0.35, 0.95, 0.65), Color(0.82, 0.88, 0.62), Color(1, 0.72, 0.2), Color(1, 0.28, 0.18), Color(0.62, 0.18, 0.12)]
	var safe_stage := clampi(stage, 0, stage_names.size() - 1)
	damage_label.text = "СОСТОЯНИЕ: %s" % stage_names[safe_stage]
	var critical: StringName = StringName(state.get("critical_module", &""))
	var critical_names := {&"body": "КУЗОВ", &"engine": "ДВИГАТЕЛЬ", &"wheels": "ХОДОВАЯ"}
	if critical_names.has(critical):
		damage_label.text = "%s: КРИТИЧЕСКОЕ" % critical_names[critical]
		if compact_mode: damage_label.text = "! %s: КРИТИЧНО" % critical_names[critical]
		damage_label.add_theme_color_override("font_color", Color(1, 0.28, 0.18))
	else:
		damage_label.add_theme_color_override("font_color", stage_colors[safe_stage])
		if compact_mode: damage_label.text = stage_names[safe_stage]
	for i in MODULES.size():
		var value: float = state[MODULES[i]]
		bars[i].value = value * 100
		labels[i].text = "%s %d%%" % [TITLES[i], ceili(value * 100)]
		bars[i].modulate = Color(0.35, 0.95, 0.65) if value > 0.5 else (Color(1, 0.72, 0.2) if value > 0.25 else Color(1, 0.28, 0.18))
