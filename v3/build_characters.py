"""Pack ../characters/*.svg into characters.js (window.CHAR_SVGS) so the page works from file:// with no fetch.
Run again after adding or editing a character: python3 build_characters.py"""
import glob, json, os, re

here = os.path.dirname(os.path.abspath(__file__))
out = []
for f in sorted(glob.glob(os.path.join(here, '..', 'characters', 'character_*.svg'))):
    s = open(f).read()
    els = [f'<{t}{a.rstrip("/")}/>' for t, a in re.findall(r'<(path|circle)\b([^>]*?)/?>', s)]
    out.append({
        'id': re.search(r'character_(\d+)', f).group(1),
        'viewBox': re.search(r'viewBox="([^"]+)"', s).group(1),
        # coloured body parts; a few traces carry a duplicate path with no fill, which would render black
        'skin': [e for e in els if 'fill="#2b2a33"' not in e and 'fill="' in e],
        'ink':  [e for e in els if 'fill="#2b2a33"' in e],       # eyes + mouth
    })
open(os.path.join(here, 'characters.js'), 'w').write('window.CHAR_SVGS = ' + json.dumps(out) + ';\n')
print(len(out), 'characters')
