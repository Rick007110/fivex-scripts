# Regenerates data/vehicles.lua from DurtyFree/gta-v-data-dumps (download vehicles.json next to this file):
#   https://raw.githubusercontent.com/DurtyFree/gta-v-data-dumps/master/vehicles.json
#   python gen_catalog.py   (writes vehicles.lua here)
import json, collections, math
d = json.load(open('vehicles.json', encoding='utf-8'))

LAND_TYPES = {'CAR': 'automobile', 'QUADBIKE': 'automobile', 'BIKE': 'bike', 'BICYCLE': 'bike'}
CLASS_TO_CAT = {
    'COMPACT': 'compacts', 'SEDAN': 'sedans', 'SUV': 'suvs', 'COUPE': 'coupes', 'MUSCLE': 'muscle',
    'SPORT_CLASSIC': 'classics', 'SPORT': 'sports', 'SUPER': 'super', 'MOTORCYCLE': 'motorcycles',
    'OFF_ROAD': 'offroad', 'VAN': 'vans', 'CYCLE': 'cycles', 'UTILITY': 'utility',
    'INDUSTRIAL': 'industrial', 'COMMERCIAL': 'commercial', 'SERVICE': 'service', 'OPEN_WHEEL': 'openwheel',
}
# (min, max) price per category
RANGE = {
    'cycles': (300, 2500), 'compacts': (6000, 22000), 'sedans': (9000, 48000), 'suvs': (18000, 85000),
    'coupes': (24000, 75000), 'muscle': (15000, 95000), 'classics': (40000, 260000), 'sports': (30000, 220000),
    'super': (180000, 950000), 'motorcycles': (3000, 65000), 'offroad': (10000, 95000), 'vans': (12000, 42000),
    'utility': (5000, 38000), 'industrial': (40000, 150000), 'commercial': (50000, 185000),
    'service': (25000, 90000), 'openwheel': (550000, 1000000),
}
# Online gimmick / armored / special vehicles without a weapons entry
EXCLUDE = {
    'voltic2': 'rocket boost', 'dune4': 'ramp buggy', 'dune5': 'ramp buggy', 'phantom2': 'ramming wedge',
    'brickade2': 'armored ram truck', 'brickade': 'armored', 'rcbandito': 'RC car', 'ruiner3': 'wrecked shell',
    'dukes2': 'armored', 'kuruma2': 'armored', 'baller5': 'armored', 'baller6': 'armored', 'cog552': 'armored',
    'cognoscenti2': 'armored', 'schafter5': 'armored', 'schafter6': 'armored', 'xls2': 'armored',
    'wastelander': 'special vehicle', 'hauler2': 'special vehicle', 'phantom3': 'special vehicle',
}
EXCLUDED_CLASSES = {'EMERGENCY', 'MILITARY', 'RAIL', 'PLANE', 'HELICOPTER', 'BOAT'}

def en(x):
    s = (x or {}).get('English') if isinstance(x, dict) else None
    return s if s and s.upper() != 'NULL' else ''

rows, skipped = [], collections.Counter()
for v in d:
    model = v['Name'].lower()
    if v['Type'] not in LAND_TYPES: skipped['type ' + v['Type']] += 1; continue
    if v['Class'] in EXCLUDED_CLASSES or v['Class'] not in CLASS_TO_CAT: skipped['class ' + v['Class']] += 1; continue
    if v['Weapons']: skipped['weapons'] += 1; continue
    if model in EXCLUDE: skipped['gimmick/armored'] += 1; continue
    name = en(v['DisplayName']) or model.capitalize()
    brand = en(v['ManufacturerDisplayName'])
    score = (min(v['MaxSpeed'] or 0, 70) / 70) * 0.45 + min(v['Acceleration'] or 0, 0.6) / 0.6 * 0.35 + min(v['MaxTraction'] or 0, 3.5) / 3.5 * 0.2
    flags = set(v['Flags'] or [])
    if 'FLAG_RICH_CAR' in flags: score *= 1.15
    if 'FLAG_POOR_CAR' in flags: score *= 0.8
    rows.append(dict(model=model, name=name, brand=brand, cat=CLASS_TO_CAT[v['Class']], type=LAND_TYPES[v['Type']],
                     score=score, drift=model.startswith('drift'), dlc=v['DlcName']))

# price: position of score within its category, eased
bycat = collections.defaultdict(list)
for r in rows: bycat[r['cat']].append(r)
def nice(p):
    step = 100 if p < 5000 else 500 if p < 20000 else 1000 if p < 100000 else 5000
    return int(round(p / step) * step)
for cat, lst in bycat.items():
    lo, hi = RANGE[cat]
    lst.sort(key=lambda r: r['score'])
    n = len(lst)
    for i, r in enumerate(lst):
        t = 0.5 if n == 1 else i / (n - 1)   # rank within class
        r['price'] = nice(lo + (hi - lo) * (t ** 1.6))

# unique labels: brand + name, disambiguate duplicates
def full(r): return (r['brand'] + ' ' + r['name']).strip() if r['brand'] else r['name']
counts = collections.Counter(full(r) for r in rows)
for r in rows:
    r['label'] = full(r)
    if counts[r['label']] > 1:
        r['label'] += ' (Drift)' if r['drift'] else ''
for r in rows:  # still duplicated (true variants): append model code
    pass
import re
ROMAN = {1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V', 6: 'VI', 7: 'VII', 8: 'VIII', 9: 'IX', 10: 'X'}
counts = collections.Counter(r['label'] for r in rows)
for r in rows:
    # base model (no trailing digit) keeps the plain name; variants get their model code
    m = re.search(r'(\d+)$', r['model'])
    if counts[r['label']] > 1 and m:
        r['label'] = f"{r['label']} {ROMAN.get(int(m.group(1)), m.group(1))}"
counts = collections.Counter(r['label'] for r in rows)
for r in rows:
    if counts[r['label']] > 1 and not r['label'].endswith(')'):
        r['label'] = f"{r['label']} ({r['model']})"

ORDER = list(RANGE.keys())
rows.sort(key=lambda r: (ORDER.index(r['cat']), r['price'], r['label']))

def lua_str(s): return "'" + s.replace(chr(92), chr(92)*2).replace("'", chr(92) + "'") + "'"
out = []
out.append('-- GENERATED catalog of base-game land vehicles (do not hand-edit lists; tweak prices freely).')
out.append('-- Source: DurtyFree/gta-v-data-dumps vehicles.json (game data up to ' + max(set(r['dlc'] for r in rows if r['dlc'].startswith('mp20'))) + ').')
out.append('-- Excluded: vehicles with weapons, emergency, military, aircraft, boats, trains, trailers,')
out.append('-- and online gimmick/armored variants: ' + ', '.join(sorted(EXCLUDE)) + '.')
out.append('-- Prices are generated from class + handling data. Scale them all with Config.PriceMultiplier.')
out.append('-- brand = manufacturer, label = full name shown in menus, type = server spawn type.')
out.append('GeneratedCatalog = {')
cur = None
for r in rows:
    if r['cat'] != cur:
        cur = r['cat']; out.append(f'\n    -- {cur}')
    t = '' if r['type'] == 'automobile' else f", type = '{r['type']}'"
    out.append(f"    {{ model = {lua_str(r['model'])}, label = {lua_str(r['label'])}, brand = {lua_str(r['brand'])}, price = {r['price']}, category = '{r['cat']}'{t} }},")
out.append('}')
open('vehicles.lua', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('kept', len(rows)); print(dict(skipped))
print({c: len(l) for c, l in bycat.items()})
for m in ['panto','blista','asea','sultan','elegy2','zentorno','adder','t20','faggio','bati','bmx','phantom','bulldozer','taxi','formula','dominator','granger','tornado2','tornado3']:
    r = next((x for x in rows if x['model'] == m), None); print(m, r and (r['label'], r['price']))
dups=[r['label'] for r in rows if '(' in r['label'] and r['label'].endswith(')') and r['model'] in r['label']]
print('model-suffixed', len(dups), dups[:30])
