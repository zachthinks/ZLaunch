#!/usr/bin/env python3
"""Package the approved Launch Key artwork into separate macOS app icon sets."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent
catalog = root / 'Assets.xcassets'
catalog.mkdir(exist_ok=True)
(catalog / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
for name, source in [('ZLaunchIcon', 'zlaunch-v2.png'), ('ZLaunchDevIcon', 'zlaunch-dev-v2.png')]:
    target = catalog / f'{name}.appiconset'
    target.mkdir(exist_ok=True)
    entries = []
    for size in [16, 32, 128, 256, 512]:
        for scale in [1, 2]:
            filename = f'icon_{size}x{size}@{scale}x.png'
            subprocess.run(['sips', '-z', str(size * scale), str(size * scale),
                            str(root / 'Design/LaunchKey' / source), '--out', str(target / filename)],
                           check=True, stdout=subprocess.DEVNULL)
            entries.append({'idiom': 'mac', 'size': f'{size}x{size}', 'scale': f'{scale}x', 'filename': filename})
    (target / 'Contents.json').write_text(json.dumps({'images': entries, 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
print('Packaged ZLaunch and ZLaunch Dev icons at every macOS app-icon size.')
