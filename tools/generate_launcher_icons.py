"""Generate/check official SwanSport icons with Pillow LANCZOS.

The repository source is retained so regeneration is machine-independent.
Maskable outputs place the complete image inside the central safe circle.
"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/branding/official_swan_logo.jpg'

def targets():
    result = {}
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        result[f'apps/swansport_app/android/app/src/main/res/mipmap-{density}/ic_launcher.png'] = size
    ios = Path('apps/swansport_app/ios/Runner/Assets.xcassets/AppIcon.appiconset')
    for entry in json.loads((ROOT / ios / 'Contents.json').read_text(encoding='utf-8'))['images']:
        size = float(entry['size'].split('x')[0]) * float(entry['scale'].removesuffix('x'))
        result[str(ios / entry['filename'])] = round(size)
    for app in ['swansport_app', 'swansport_console']:
        result[f'apps/{app}/web/favicon.png'] = 48
        for size in [192, 512]:
            result[f'apps/{app}/web/icons/Icon-{size}.png'] = size
            result[f'apps/{app}/web/icons/Icon-maskable-{size}.png'] = size
    result['apps/swansport_app/web/icons/Icon-180.png'] = 180
    result['packages/swansport_design_system/assets/images/swan_logo.png'] = 512
    return result

def render(source, size, maskable):
    if not maskable:
        return source.resize((size, size), Image.Resampling.LANCZOS)
    # A square of side .56 fits entirely inside the maskable .4-radius circle.
    canvas = Image.new('RGB', (size, size), source.getpixel((0, 0)))
    inset = round(size * .56)
    mark = source.resize((inset, inset), Image.Resampling.LANCZOS)
    canvas.paste(mark, ((size - inset) // 2, (size - inset) // 2))
    return canvas

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    with Image.open(args.source) as original:
        source = ImageOps.exif_transpose(original).convert('RGB')
    if source.width != source.height:
        raise ValueError('Official logo must be square; no automatic crop is allowed')
    outputs = targets()
    for relative, size in outputs.items():
        destination = ROOT / relative
        expected = render(source, size, 'maskable' in relative)
        if args.check:
            with Image.open(destination) as actual:
                assert actual.format == 'PNG' and actual.mode == 'RGB', relative
                assert actual.size == (size, size), relative
                assert actual.tobytes() == expected.tobytes(), relative
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            expected.save(destination, format='PNG', optimize=True)
    print(f'{len(outputs)} icons {"verified" if args.check else "generated"}; iOS filenames derived from Contents.json')

if __name__ == '__main__':
    main()
