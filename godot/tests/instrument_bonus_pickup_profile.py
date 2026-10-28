#!/usr/bin/env python3
"""Instrument BonusPickup only in a disposable copy of the project."""
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve()
assert root != pathlib.Path(__file__).resolve().parents[1], "refusing source checkout"


def replace_once(text, old, new):
    assert text.count(old) == 1, old[:90]
    return text.replace(old, new, 1)


spawner = root / "scripts/bonus_spawner.gd"
source = spawner.read_text()
source = replace_once(source, "class_name BonusSpawner\n", 'class_name BonusSpawner\nconst BonusProbe = preload("res://tests/bonus_pickup_probe_stats.gd")\n')
start = source.index("func _create_pickup(")
end = source.index("\n\nfunc _draw_kind()", start)
source = source[:start] + '''func _create_pickup(chosen_kind: int, is_armed: bool, reserved_positions: Array[Vector2] = []) -> BonusPickup:
\tvar id := BonusProbe.begin(chosen_kind, is_armed)
\tvar all_started := Time.get_ticks_usec()
\tvar started := Time.get_ticks_usec()
\tvar location := _next_position(reserved_positions)
\tBonusProbe.record("position", Time.get_ticks_usec() - started, id, str(location.success))
\tif not location.success or pickup_scene == null:
\t\tBonusProbe.record("total_failed", Time.get_ticks_usec() - all_started, id)
\t\treturn null
\tstarted = Time.get_ticks_usec()
\tvar pickup := pickup_scene.instantiate() as BonusPickup
\tBonusProbe.record("instantiate", Time.get_ticks_usec() - started, id)
\tif pickup == null:
\t\tBonusProbe.record("total_failed", Time.get_ticks_usec() - all_started, id)
\t\treturn null
\tpickup.set_meta("_bonus_probe_id", id)
\tstarted = Time.get_ticks_usec()
\tif chosen_kind < 0:
\t\tchosen_kind = _draw_kind()
\tBonusProbe.record("kind_select", Time.get_ticks_usec() - started, id, str(chosen_kind))
\tvar weapon: WeaponConfig = null
\tif chosen_kind == BonusPickup.Kind.WEAPON:
\t\tvar path: String = weapon_paths[_rng.randi_range(0, weapon_paths.size() - 1)]
\t\tvar cached := ResourceLoader.has_cached(path)
\t\tstarted = Time.get_ticks_usec()
\t\tweapon = load(path) as WeaponConfig
\t\tBonusProbe.record("weapon_load", Time.get_ticks_usec() - started, id, ("cached" if cached else "uncached") + ":" + path)
\tstarted = Time.get_ticks_usec()
\tpickup.setup(chosen_kind as BonusPickup.Kind, weapon, is_armed)
\tBonusProbe.record("setup", Time.get_ticks_usec() - started, id)
\tstarted = Time.get_ticks_usec()
\tadd_child(pickup)
\tBonusProbe.record("tree_add_including_ready", Time.get_ticks_usec() - started, id)
\tstarted = Time.get_ticks_usec()
\tpickup.global_position = location.position
\tpickup.collected.connect(_on_collected)
\t_spawn_index += 1
\tBonusProbe.record("post_tree", Time.get_ticks_usec() - started, id)
\tBonusProbe.record("total", Time.get_ticks_usec() - all_started, id, str(chosen_kind))
\treturn pickup
''' + source[end:]
source = replace_once(source, '\tbonus_announced.emit(_current_pickup.kind, _current_pickup.global_position, warning_duration)\n', '''\tvar _post_started := Time.get_ticks_usec()
\tbonus_announced.emit(_current_pickup.kind, _current_pickup.global_position, warning_duration)
\tBonusProbe.record("announce_signal", Time.get_ticks_usec() - _post_started)
''')
source = replace_once(source, '''\t\tpickup.set_armed(true)
\t\t_register_active(pickup)
\t\tbonus_spawned.emit(pickup)
''', '''\t\tvar _post_started := Time.get_ticks_usec()
\t\tpickup.set_armed(true)
\t\tBonusProbe.record("arm_activation", Time.get_ticks_usec() - _post_started, int(pickup.get_meta("_bonus_probe_id", -1)))
\t\t_post_started = Time.get_ticks_usec()
\t\t_register_active(pickup)
\t\tBonusProbe.record("active_register", Time.get_ticks_usec() - _post_started, int(pickup.get_meta("_bonus_probe_id", -1)))
\t\t_post_started = Time.get_ticks_usec()
\t\tbonus_spawned.emit(pickup)
\t\tBonusProbe.record("spawn_signal", Time.get_ticks_usec() - _post_started, int(pickup.get_meta("_bonus_probe_id", -1)))
''')
spawner.write_text(source)

pickup = root / "scripts/bonus_pickup.gd"
source = pickup.read_text()
source = replace_once(source, "class_name BonusPickup\n", 'class_name BonusPickup\nconst BonusProbe = preload("res://tests/bonus_pickup_probe_stats.gd")\n')
start = source.index("func _ready()")
end = source.index("\n\nfunc setup(", start)
source = source[:start] + '''func _ready() -> void:
\tvar id := int(get_meta("_bonus_probe_id", -1))
\tvar all_started := Time.get_ticks_usec()
\tvar started := Time.get_ticks_usec()
\tadd_to_group("bonus_pickups")
\tBonusProbe.record("ready.group", Time.get_ticks_usec() - started, id)
\tstarted = Time.get_ticks_usec()
\tcollision_layer = 0
\tcollision_mask = 1
\tbody_entered.connect(_on_body_entered)
\tBonusProbe.record("ready.sensor_config", Time.get_ticks_usec() - started, id)
\tstarted = Time.get_ticks_usec()
\tmonitoring = armed
\tBonusProbe.record("ready.monitor", Time.get_ticks_usec() - started, id)
\tstarted = Time.get_ticks_usec()
\t_build_badge()
\tBonusProbe.record("ready.badge_build", Time.get_ticks_usec() - started, id)
\tstarted = Time.get_ticks_usec()
\t_update_badge()
\tBonusProbe.record("ready.badge_update", Time.get_ticks_usec() - started, id)
\tqueue_redraw()
\tBonusProbe.record("ready.total", Time.get_ticks_usec() - all_started, id)
''' + source[end:]
source = replace_once(source, '\t_badge = Label.new()\n', '''\tvar _started := Time.get_ticks_usec()
\t_badge = Label.new()
\tBonusProbe.record("badge.label_new", Time.get_ticks_usec() - _started, int(get_meta("_bonus_probe_id", -1)))
''')
source = replace_once(source, '\t_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE\n\tadd_child(_badge)\n', '''\t_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tBonusProbe.record("badge.properties_including_label", Time.get_ticks_usec() - _started, int(get_meta("_bonus_probe_id", -1)))
\t_started = Time.get_ticks_usec()
\tadd_child(_badge)
\tBonusProbe.record("badge.tree_add", Time.get_ticks_usec() - _started, int(get_meta("_bonus_probe_id", -1)))
''')
source = replace_once(source, 'func _draw() -> void:\n\tvar edge := _kind_color()\n', '''func _draw() -> void:
\tif not has_meta("_bonus_probe_drawn"):
\t\tset_meta("_bonus_probe_drawn", true)
\t\tvar started := Time.get_ticks_usec()
\t\t_draw_original()
\t\tBonusProbe.record("draw.first", Time.get_ticks_usec() - started, int(get_meta("_bonus_probe_id", -1)))
\telse:
\t\t_draw_original()


func _draw_original() -> void:
\tvar edge := _kind_color()
''')
pickup.write_text(source)
print("instrumented", spawner, pickup)
