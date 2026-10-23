# Splits ../shapes_v4/shape_*.svg into parts for index.html -> shapes.js
#   skin:   [body path]            (first path: the coloured silhouette)
#   tex:    clipPath + clipped <g> (texture / stripes / closed eyes, drawn inside the body)
#   whites: eye whites             pupils: dark circles (clipped to their white or bare)
#   rest:   everything else (legs, spots)
import glob, json, os, re

here = os.path.dirname(os.path.abspath(__file__))
out = []
for f in sorted(glob.glob(os.path.join(here, '..', 'shapes_v4', 'shape_*.svg'))):
    s = open(f).read()
    vb = re.search(r'viewBox="([^"]+)"', s).group(1)
    inner = s[s.index('>') + 1:s.rindex('</svg>')]
    parts, i = [], 0
    while i < len(inner):
        if inner.startswith('<clipPath', i):
            j = inner.index('</clipPath>', i) + len('</clipPath>')
            j = inner.index('</g>', j) + 4 if inner.startswith('<g', j) else inner.index('/>', j) + 2   # its consumer
        else:
            j = inner.index('/>', i) + 2
        parts.append(inner[i:j]); i = j
    c = {'id': re.search(r'shape_(\d+)', f).group(1), 'viewBox': vb, 'skin': [parts[0]], 'tex': '', 'whites': [], 'pupils': [], 'rest': []}
    for p in parts[1:]:
        if '<g' in p: c['tex'] += p
        elif 'fill="#ffffff"' in p: c['whites'].append(p)
        elif re.search(r'<circle[^>]*fill="#1c1a1f"', p): c['pupils'].append(p)
        else: c['rest'].append(p)
    out.append(c)
open(os.path.join(here, 'shapes.js'), 'w').write('window.CHAR_SVGS = ' + json.dumps(out) + ';\n')
print(len(out), 'shapes')
