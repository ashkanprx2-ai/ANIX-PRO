#!/usr/bin/env python3
"""NX kit batch 2 (owner uploads 2026-11-25, "new team and assets"): car-brand crests (finger-soccer teams + the carrom
"Car Club" set), two classic wood carrom boards, gold emblems, gold/navy ornaments and the classic snakes & ladders
sprites. All sheets are already transparent; sprites are found by connected components (tool/nx_kit_slice.py).

Run from the repo root: python3 tool/nx_kit_export2.py [--index]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
import nx_kit_slice as S  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
OUT_DIR = os.environ.get('NX_KIT_OUT', os.path.join(ROOT, 'build', 'nx_kit_out'))
os.makedirs(OUT_DIR, exist_ok=True)
F = {
    'cars': '142990-5d79c8e85e1e.png',
    'board_navy': '142585-08a8b8b2d75d.png',
    'board_black': '142584-f83e08c5d51a.png',
    'emblems': '142591-be0ca5c2c230.png',
    'ornaments': '142600-2af0e543aba0.png',
    'corner_large': '142597-857cf025782d.png',
    'corner_scroll': '142601-6cb193272bc2.png',
    'classic_snl': '142602-d91cf0602592.png',
}
CARS = ['mercedes', 'bmw', 'audi', 'porsche', 'ferrari', 'lamborghini', 'bentley_purple', 'bentley_green', 'bugatti',
        'mclaren', 'astonmartin', 'tesla', 'toyota', 'nissan', 'ford', 'chevrolet']
ORN = ['corner_a', 'corner_b', 'medallion', 'crest', 'divider_a', 'divider_b', 'header_a', 'header_b']
WRITTEN = []


def load(k):
    return np.array(Image.open(os.path.join(S.UP, F[k])).convert('RGBA')).astype(np.float32)


def parts(k, merge=4, min_area=600):
    a = load(k)
    a[..., 3] = np.where(a[..., 3] < 24, 0, a[..., 3])
    boxes, lab = S.components(a, merge=merge, min_area=min_area)
    return a, boxes, lab


def trim(img, pad=1):
    arr = np.array(img)
    m = arr[..., 3] > 8
    ys, xs = np.nonzero(m)
    return img.crop((max(0, xs.min() - pad), max(0, ys.min() - pad), min(img.width, xs.max() + 1 + pad),
                     min(img.height, ys.max() + 1 + pad)))


def save(img, rel, q=88):
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p, 'WEBP', quality=q, method=6)
    WRITTEN.append(rel)


def disc(img, size=256, rim=120):
    """v10 rule (tool/build_fs_v10_assets.py): the crest's inscribed circle becomes the rim at radius [rim] of [size]."""
    w, h = img.size
    d = min(w, h)
    sq = img.crop(((w - d) // 2, (h - d) // 2, (w - d) // 2 + d, (h - d) // 2 + d))
    inner = sq.resize((rim * 2 * 4, rim * 2 * 4), Image.LANCZOS)
    m = Image.new('L', inner.size, 0)
    ImageDraw.Draw(m).ellipse((0, 0, inner.width - 1, inner.height - 1), fill=255)
    arr = np.array(inner)
    arr[..., 3] = (arr[..., 3].astype(np.float32) * np.array(m) / 255).astype(np.uint8)
    inner = Image.fromarray(arr).resize((rim * 2, rim * 2), Image.LANCZOS)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(inner, (size // 2 - rim, size // 2 - rim))
    return out


def board_pockets(img):
    arr = np.array(img).astype(np.float32)
    h, w = arr.shape[:2]
    dark = (arr[..., :3].max(-1) < 40) & (arr[..., 3] > 200)
    pk = []
    for (y0, y1, x0, x1) in ((0, h // 4, 0, w // 4), (0, h // 4, 3 * w // 4, w), (3 * h // 4, h, 0, w // 4),
                             (3 * h // 4, h, 3 * w // 4, w)):
        sub = dark[y0:y1, x0:x1]
        lab, n = ndimage.label(sub)
        sizes = ndimage.sum(sub, lab, range(1, n + 1))
        k = int(np.argmax(sizes)) + 1
        cy, cx = ndimage.center_of_mass(lab == k)
        pk.append(((x0 + cx) / w, (y0 + cy) / h))
    return [round((pk[0][0] + pk[2][0]) / 2, 4), round((pk[0][1] + pk[1][1]) / 2, 4),
            round((pk[1][0] + pk[3][0]) / 2, 4), round((pk[2][1] + pk[3][1]) / 2, 4)]


def main(index=False):
    out = os.path.join(OUT_DIR, 'slices2')
    os.makedirs(out, exist_ok=True)
    res = {}
    if index:
        for k in F:
            if k.startswith('board'):
                continue
            a, boxes, lab = parts(k)
            S.contact([(str(i), trim(S.to_img(S.crop(a, b, lab)))) for i, b in enumerate(boxes)], f'{out}/{k}.png')
            print(k, len(boxes))
        return
    # car crests -> finger soccer discs (v11) + the carrom Car Club set
    # the crests' glows touch: cut the 4 x 4 grid on the sheet's opaque extent, then tighten each cell on its alpha
    a = load('cars')
    ys, xs = np.nonzero(a[..., 3] > 60)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    cw, ch = (x1 - x0) / 4, (y1 - y0) / 4
    crests = {}
    for i, n in enumerate(CARS):
        r, c = divmod(i, 4)
        cell = a[int(y0 + r * ch):int(y0 + (r + 1) * ch), int(x0 + c * cw):int(x0 + (c + 1) * cw)].copy()
        m = cell[..., 3] > 60
        lab, k = ndimage.label(m)
        if k:
            big = np.argmax(ndimage.sum(m, lab, range(1, k + 1))) + 1
            keep = ndimage.binary_dilation(lab == big, iterations=4)
            cell[..., 3] = np.where(keep, cell[..., 3], 0)
        im = trim(S.to_img(cell))
        crests[n] = im
        save(disc(im), f'assets/games/bermuda/discs/v11/car_{n}.webp', 90)
        # dominant colour for the team colour table
        arr = np.array(im.resize((64, 64))).reshape(-1, 4).astype(np.float32)
        arr = arr[arr[:, 3] > 200][:, :3]
        sat = arr.max(1) - arr.min(1)
        pick = arr[sat > np.percentile(sat, 70)] if (sat > 40).sum() > 50 else arr
        res[n] = '#%02X%02X%02X' % tuple(int(v) for v in np.median(pick, 0))
    for role, n in (('white', 'mercedes'), ('black', 'lamborghini'), ('queen', 'ferrari'), ('striker0', 'porsche'),
                    ('striker1', 'bugatti')):
        save(disc(crests[n], 160, 80), f'assets/games/carrom/nx/pieces_car_club_{role}.webp', 90)
    # classic wood boards
    for k, n in (('board_navy', 'board_classic_navy'), ('board_black', 'board_classic_black')):
        img = trim(Image.open(os.path.join(S.UP, F[k])).convert('RGBA'), 0)
        img = img.resize((1024, round(1024 * img.height / img.width)), Image.LANCZOS)
        res[n] = board_pockets(img)
        save(img, f'assets/games/carrom/nx/{n}.webp', 86)
    # emblems
    a, boxes, lab = parts('emblems')
    ems = []
    for i, b in enumerate(boxes):
        im = trim(S.to_img(S.crop(a, b, lab)))
        if im.width > im.height * 1.3:  # two emblems whose laurels touch
            w = im.width // 2
            ems += [trim(im.crop((0, 0, w, im.height))), trim(im.crop((w, 0, im.width, im.height)))]
        else:
            ems.append(im)
    for i, im in enumerate(ems):
        save(S.fit(im, 192), f'assets/ui/nx_kit/emblems/emblem_{i}.webp', 90)
    res['emblems'] = len(ems)
    # ornaments
    a, boxes, lab = parts('ornaments')
    for n, b in zip(ORN, boxes):
        save(S.fit(trim(S.to_img(S.crop(a, b, lab))), 384), f'assets/ui/nx_kit/ornate/{n}.webp', 88)
    res['ornaments'] = len(boxes)
    for k in ('corner_large', 'corner_scroll'):
        save(S.fit(trim(Image.open(os.path.join(S.UP, F[k])).convert('RGBA')), 512), f'assets/ui/nx_kit/ornate/{k}.webp')
    # classic snakes & ladders
    a, boxes, lab = parts('classic_snl', merge=2)
    names = CLASSIC
    for i, b in enumerate(boxes):
        n = names.get(i, f'part_{i}')
        im = S.to_img(S.crop(a, b, lab))
        if n.startswith('combo'):
            arr = np.array(im).astype(np.float32)
            colour = (arr[..., :3].max(-1) > 95) & (arr[..., 3] > 60)
            near = ndimage.binary_dilation(colour, iterations=3)
            snake = arr.copy()
            snake[..., 3] = np.where(near, snake[..., 3], 0)
            ladder = arr.copy()
            ladder[..., 3] = np.where(near, 0, ladder[..., 3])
            save(S.fit(trim(Image.fromarray(snake.astype(np.uint8))), 360),
                 f'assets/games/snakes_ladders/classic/{n.split(":")[1]}.webp')
            if n.split(':')[2]:
                save(S.fit(trim(Image.fromarray(ladder.astype(np.uint8))), 360),
                     f'assets/games/snakes_ladders/classic/{n.split(":")[2]}.webp')
            continue
        save(S.fit(trim(im), 360), f'assets/games/snakes_ladders/classic/{n}.webp')
    res['classic'] = len(boxes)
    print(res)
    with open(os.path.join(OUT_DIR, 'nx_kit_written2.txt'), 'w') as fh:
        fh.write('\n'.join(WRITTEN))


CLASSIC = {0: 'snake_green', 1: 'combo:snake_olive:', 2: 'snake_redwhite', 3: 'ladder_long',
           4: 'snake_orange', 5: 'ladder_mid', 6: 'combo:snake_amber:', 7: 'snake_cyan', 8: 'ladder_short'}

if __name__ == '__main__':
    main(index='--index' in sys.argv)
