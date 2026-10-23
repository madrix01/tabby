# ../frens-svgs/<set>/flat/<fren>/<fren>-<n>-<stage>.svg -> characters.js (same {id, viewBox, skin, ink} format as v3)
#   skin: the coloured parts (body, stage item, sparkles), ink: the #2b2a33 face parts (eyes, mouth), always drawn last
import glob, json, os, re

here = os.path.dirname(os.path.abspath(__file__))
out = []
for f in sorted(glob.glob(os.path.join(here, '..', 'frens-svgs', '*', 'flat', '*', '*.svg'))):
    s = open(f).read()
    kit, fren, n = re.search(r'frens-svgs/(\w+)/flat/(\w+)/\w+-(\d)-', f).groups()
    els = re.findall(r'<(?:path|circle)\b[^>]*/>', s)
    out.append({'id': f'{kit}-{fren}-{n}', 'viewBox': re.search(r'viewBox="([^"]+)"', s).group(1),
                'skin': [e for e in els if 'fill="#2b2a33"' not in e], 'ink': [e for e in els if 'fill="#2b2a33"' in e]})
open(os.path.join(here, 'characters.js'), 'w').write('window.CHAR_SVGS = ' + json.dumps(out) + ';\n')
print(len(out), 'characters')
