"""Export development combat JSONL to CSV (standard-library only)."""
import argparse, csv, json
from pathlib import Path
from collections import defaultdict

def records(paths):
    for path in paths:
        with path.open(encoding='utf-8') as stream:
            for line_number, line in enumerate(stream, 1):
                if not line.strip():
                    continue
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    print(f'Ignored incomplete record: {path}:{line_number}')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--logs', type=Path, default=Path('logs/combat-telemetry'))
    parser.add_argument('--output', type=Path, default=Path('logs/combat-telemetry/report.csv'))
    parser.add_argument('--duration', type=float, help='Exact measured test duration in seconds; recommended for DPS comparisons')
    parser.add_argument('--run', help='Filter to one run_id (default: most recent server run)')
    args = parser.parse_args()
    if args.duration is not None and args.duration <= 0:
        parser.error('--duration must be positive')
    paths = sorted(args.logs.glob('events*.jsonl'))
    if not paths:
        parser.error('No telemetry JSONL files found. Run a combat test with collection enabled first.')
    run = args.run or max((str(e['run_id']) for e in records(paths)), default='')
    actions, parents = {}, set()
    minimum, maximum = None, None
    for e in records(paths):
        if str(e.get('run_id')) != run:
            continue
        t = e['monotonic_ms']; minimum = t if minimum is None else min(minimum, t); maximum = t if maximum is None else max(maximum, t)
        if e['event'] == 'action_start':
            actions[e['action_id']] = e
            if e.get('parent_action_id'):
                parents.add(e['parent_action_id'])
    duration = args.duration if args.duration is not None else max((maximum-minimum)/1000, 0.001)
    stats = {}
    def group(player, name, kind):
        skills = player.get('skills', {})
        highest = max((skills.get(s, 0) for s in ('sword', 'axe', 'club')), default=0)
        key = (player.get('guid'), player.get('name'), player.get('vocation'), player.get('level'), player.get('magic_level'), highest, skills.get('distance'), name, kind)
        return stats.setdefault(key, dict(attempts=0, successes=0, hits=0, damage=0, healing=0, mana_spent=0, mana_restored=0, blocked=0, min_damage=None, max_damage=0))
    for action_id, e in actions.items():
        if action_id not in parents and e.get('player'):
            group(e['player'],e['name'],e['kind'])['attempts'] += 1
    for e in records(paths):
        if str(e.get('run_id')) != run:
            continue
        aid = e.get('action_id', 0)
        action = actions.get(aid)
        if e['event'] == 'action_end' and action and aid not in parents:
            group(action['player'],action['name'],action['kind'])['successes'] += int(e['success'])
        elif e['event'] == 'mana_change' and action and e.get('player') and e['player'].get('guid') == action['player'].get('guid'):
            row = group(action['player'],action['name'],action['kind'])
            row['mana_spent'] += max(0,-e['delta'])
            row['mana_restored'] += max(0,e['delta'])
        elif e['event'] in ('damage','heal','blocked') and ((e.get('attacker') or {}).get('kind') == 'player' or (e['event'] == 'heal' and action)):
            attacker = e.get('attacker') or action['player']
            correlated = action and action['player'].get('guid') == attacker.get('guid')
            player = action['player'] if correlated else attacker
            name = action['name'] if correlated else (e.get('spell') or e.get('rune') or f"origin:{e.get('origin')}")
            kind = action['kind'] if correlated else 'unlinked'
            row = group(player,name,kind)
            amount = max(0,-e.get('health_delta',0))
            if e['event'] == 'damage' and amount:
                row['hits'] += 1; row['damage'] += amount
                row['min_damage'] = amount if row['min_damage'] is None else min(row['min_damage'],amount)
                row['max_damage'] = max(row['max_damage'],amount)
            elif e['event'] == 'heal': row['healing'] += max(0,e.get('health_delta',0))
            elif e['event'] == 'blocked': row['blocked'] += 1
    args.output.parent.mkdir(parents=True,exist_ok=True)
    headers = ['run_id','guid','character','vocation','level','magic_level','highest_melee_skill','distance_skill','ability','kind','attempts','successes','hits','blocked','min_damage','max_damage','mean_damage_per_hit','total_damage','total_healing','mana_spent','mana_restored','duration_seconds','damage_per_second']
    with args.output.open('w',encoding='utf-8-sig',newline='') as stream:
        writer = csv.writer(stream,delimiter=';');writer.writerow(headers)
        for key,row in sorted(stats.items(),key=lambda pair:str(pair[0])):
            writer.writerow([run,*key,row['attempts'],row['successes'],row['hits'],row['blocked'],row['min_damage'] or 0,row['max_damage'],round(row['damage']/row['hits'],2) if row['hits'] else 0,row['damage'],row['healing'],row['mana_spent'],row['mana_restored'],round(duration,3),round(row['damage']/duration,2)])
    print(f'CSV: {args.output}; run={run}; duration={duration:.3f}s; groups={len(stats)}')
    if args.duration is None:
        print('DPS uses the span of recorded events. Supply --duration for a fixed test window including idle/refill time.')

if __name__ == '__main__':
    main()
