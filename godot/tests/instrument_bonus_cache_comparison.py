#!/usr/bin/env python3
"""Instrument only a disposable copy for before/after performance comparisons."""
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
assert root != Path(__file__).resolve().parents[1], "refusing to edit the workspace"
sink = 'preload("res://tests/survival_perf_stats.gd")'


def replace_once(source, old, new):
    assert source.count(old) == 1, old[:100]
    return source.replace(old, new, 1)


path = root / "scripts/bonus_spawner.gd"
source = path.read_text()
source = replace_once(source,
    'func _create_pickup(chosen_kind: int, is_armed: bool, reserved_positions: Array[Vector2] = []) -> BonusPickup:\n',
    '''func _create_pickup(chosen_kind: int, is_armed: bool, reserved_positions: Array[Vector2] = []) -> BonusPickup:
	var started := Time.get_ticks_usec()
	var value: BonusPickup = _profile_original_create_pickup(chosen_kind, is_armed, reserved_positions)
	%s.record("bonus.create", Time.get_ticks_usec() - started, str(value.kind) if value != null else "failed")
	return value


func _profile_original_create_pickup(chosen_kind: int, is_armed: bool, reserved_positions: Array[Vector2] = []) -> BonusPickup:
''' % sink)
source = replace_once(source,
    'func _next_position(reserved_positions: Array[Vector2] = []) -> Dictionary:\n',
    '''func _next_position(reserved_positions: Array[Vector2] = []) -> Dictionary:
	var started := Time.get_ticks_usec()
	var value := _profile_original_next_position(reserved_positions)
	%s.record("bonus.position", Time.get_ticks_usec() - started)
	return value


func _profile_original_next_position(reserved_positions: Array[Vector2] = []) -> Dictionary:
''' % sink)
if "weapon = load(weapon_paths[" in source:
    old = '\t\tweapon = load(weapon_paths[_rng.randi_range(0, weapon_paths.size() - 1)]) as WeaponConfig\n'
    new = '''		var path: String = weapon_paths[_rng.randi_range(0, weapon_paths.size() - 1)]
		var started := Time.get_ticks_usec()
		weapon = load(path) as WeaponConfig
		%s.record("bonus.weapon_resource", Time.get_ticks_usec() - started, path)
''' % sink
    source = replace_once(source, old, new)
else:
    source = replace_once(source, '\t\tweapon = BonusCache.get_config(path)\n',
        '''		var started := Time.get_ticks_usec()
		weapon = BonusCache.get_config(path)
		%s.record("bonus.weapon_resource", Time.get_ticks_usec() - started, path)
''' % sink)
path.write_text(source)

cache_path = root / "scripts/bonus_weapon_cache.gd"
if cache_path.exists():
    source = cache_path.read_text()
    source = replace_once(source, 'static func prepare() -> bool:\n',
        '''static func prepare() -> bool:
	var started := Time.get_ticks_usec()
	var result := _profile_original_prepare()
	%s.record("bonus.cache_prepare", Time.get_ticks_usec() - started, str(result))
	return result


static func _profile_original_prepare() -> bool:
''' % sink)
    cache_path.write_text(source)

print("instrumented", root)
