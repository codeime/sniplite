#!/bin/sh
# Makes Resources/AppIcon.icns from Resources/AppIcon.png (1024 px): every size macOS wants, each
# PNG compressed as small as it goes without changing a pixel, written into the .icns as it is
# (iconutil would compress them again, worse). build.sh uses the result; run this again after
# changing the icon. Needs Python 3 with Pillow (pip3 install pillow).
set -e
cd "$(dirname "$0")"
python3 - <<'PY'
import io, struct
from PIL import Image
master = Image.open('Resources/AppIcon.png').convert('RGBA')
# icns entry types for PNG data, by pixel size (and which point size they serve)
# (an @2x of one size that is the 1x of the next, the same pixels, is stored once: macOS picks by pixels)
types = [('icp4', 16), ('icp5', 32), ('ic12', 64), ('ic07', 128), ('ic08', 256), ('ic09', 512), ('ic10', 1024)]
cache, chunks = {}, b''
for kind, px in types:
    if px not in cache:
        buf = io.BytesIO()
        master.resize((px, px), Image.LANCZOS).save(buf, 'PNG', optimize=True, compress_level=9)
        cache[px] = buf.getvalue()
    data = cache[px]
    chunks += kind.encode() + struct.pack('>I', len(data) + 8) + data
open('Resources/AppIcon.icns', 'wb').write(b'icns' + struct.pack('>I', len(chunks) + 8) + chunks)
PY
echo "made Resources/AppIcon.icns ($(du -h Resources/AppIcon.icns | cut -f1))"
