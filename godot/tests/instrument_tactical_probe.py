"""Apply optional AI timings to a disposable project copy, never production."""
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
p = root / 'scripts/arena_bot.gd'
s = p.read_text()
for name, signature, args, label in [
    ('get_commands', 'delta: float = 0.0', 'delta', 'ai.commands'),
    ('_try_traffic_detour', '', '', 'ai.detour'),
]:
    if f'func _probe{name}(' in s:
        continue
    result_type = 'Dictionary' if name == 'get_commands' else 'bool'
    old = f'func {name}({signature}) -> {result_type}:\n'
    wrapper = (f'func {name}({signature}) -> {result_type}:\n'
               '\tvar started := Time.get_ticks_usec()\n'
               f'\tvar value := _probe{name}({args})\n'
               '\tpreload("res://tests/survival_perf_stats.gd").record('
               f'"{label}", Time.get_ticks_usec() - started)\n'
               '\treturn value\n\n\n'
               f'func _probe{name}({signature}) -> {result_type}:\n')
    assert s.count(old) == 1, (p, name)
    s = s.replace(old, wrapper)
p.write_text(s)

p = root / 'scripts/tutorial_coach.gd'
s = p.read_text()
old = 'func _complete() -> void:\n'
if 'func _probe_complete()' not in s:
    assert s.count(old) == 1
    s = s.replace(old, old + '\tvar started := Time.get_ticks_usec()\n'
                  '\t_probe_complete()\n'
                  '\tpreload("res://tests/survival_perf_stats.gd").record('
                  '"ui.tutorial_complete", Time.get_ticks_usec() - started)\n\n\n'
                  'func _probe_complete() -> void:\n')
    p.write_text(s)
