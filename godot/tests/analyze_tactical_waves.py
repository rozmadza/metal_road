"""Summarize physical behavior and separately measured graphical frame time."""
import argparse
import json
import math
from pathlib import Path
from statistics import mean


def describe(values):
    v = sorted(values)
    return dict(n=len(v), mean=mean(v) if v else None,
                p95=v[math.ceil(len(v)*.95)-1] if v else None,
                p99=v[math.ceil(len(v)*.99)-1] if v else None,
                max=max(v) if v else None)


def summarize(path):
    d = json.loads(path.read_text())
    result = []
    for r in d['reports']:
        actors = r['actors']
        combat = sum(a['intent_s'].get('attack', 0)+a['intent_s'].get('pursue', 0) for a in actors)
        row = dict(run=d['id'], display=d['display'], label=r['label'], seconds=r['seconds'],
                   ai=len(actors), max_same_supply=max(t['max_same_supply'] for t in r['traces']),
                   supply_actor_s=sum(a['intent_s'].get('supply', 0) for a in actors),
                   combat_fraction=combat/(r['seconds']*len(actors)),
                   ai_pickups=sum(a['pickups'] for a in actors), shots=sum(a['shots'] for a in actors),
                   hits_on_player=sum(a.get('hits_on_player', 0) for a in actors),
                   damage_to_player=sum(a.get('damage_to_player', 0) for a in actors),
                   max_stop_s=max(a['longest_stop_s'] for a in actors),
                   max_armed_no_attack_s=max(a['longest_armed_no_attack_s'] for a in actors),
                   recovery_requests=sum(a['recovery_requested'] for a in actors),
                   recovery_started=sum(a['recovery_started'] for a in actors),
                   detours=sum(a['detours'] for a in actors), actors=actors)
        contacts = [a['first_contact_s'] for a in actors if a['first_contact_s'] >= 0]
        hits = [a.get('first_damage_s', -1) for a in actors if a.get('first_damage_s', -1) >= 0]
        row['first_contact_s'] = min(contacts, default=None)
        row['first_damage_s'] = min(hits, default=None)
        row['initial_supply_slots'] = [a['index'] for a in actors if a['supply_choices'] and a['supply_choices'][0]['s'] < 1]
        max_chase = 0
        for a in actors:
            current = 0
            age = 0
            for t in r['traces']:
                s = next(x for x in t['actors'] if x['i'] == a['index'])
                pickup = s['pickup'] if s['intent'] == 'supply' else 0
                age = age + .1 if pickup and pickup == current else (.1 if pickup else 0)
                current = pickup
                max_chase = max(max_chase, age)
        row['max_continuous_chase_s'] = max_chase
        offsets = []
        for t in r['traces']:
            if 'player' not in t or t['s'] < 1 or t['s'] > 8:
                continue
            p = t['player']
            heading = t['player_heading']
            for a in t['actors']:
                if a['i'] == 1 and a['intent'] in ['pursue', 'attack']:
                    dx, dy = a['p'][0]-p[0], a['p'][1]-p[1]
                    if math.hypot(dx, dy) > 220:
                        offsets.append(abs(-math.sin(heading)*dx+math.cos(heading)*dy))
        row['flanker_physical_lateral_1_to_8s'] = describe(offsets)
        if d['display'] != 'headless':
            frames = r['frames'][1:]
            row['frame_ms'] = describe(frames)
            row['over_16_67'] = sum(x > 16.67 for x in frames)
            row['over_33_33'] = sum(x > 33.33 for x in frames)
            row['over_100'] = sum(x > 100 for x in frames)
            row['ai_commands_us'] = describe(d['function_times_us'].get(r['label']+'::ai.commands', []))
            row['detour_calls_us'] = describe(d['function_times_us'].get(r['label']+'::ai.detour', []))
            row['ai_cpu_ms_per_sim_s'] = sum(d['function_times_us'].get(r['label']+'::ai.commands', []))/1000/r['seconds']
        result.append(row)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('folders', nargs='+', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    rows = []
    for folder in args.folders:
        for path in sorted(folder.glob('*.json')):
            if not path.name.startswith(('before-', 'after-')):
                continue
            rows.extend(summarize(path))
    args.output.write_text(json.dumps(rows, ensure_ascii=False, indent=2))
    print('Summarized', len(rows), 'windows')


if __name__ == '__main__':
    main()
