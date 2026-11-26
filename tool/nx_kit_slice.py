#!/usr/bin/env python3
"""Slices the owner's NX neon art sheets (uploads 2026-11-25) into individual transparent sprites.

Phase 1 (`--index`): keys the background out of every sheet, finds sprites by connected components and writes
`<out>/<sheet>/NN.png` plus a numbered contact sheet so each component can be named.
Phase 2 (default): writes the named, trimmed, resized sprites into the repo's asset folders (webp).

Backgrounds:
  magenta (#FF00FF) chroma key with soft alpha + edge despill, white (coin 18816) and near-black flood fill from the
  border (token sheet 139192), already-transparent sheets keep their alpha. The dice sheet 108848 is cut on its grid
  as rounded tiles (the dice are as dark as the lightning background, so keying would eat them).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

UP = os.environ.get('NX_KIT_UPLOADS', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build', 'nx_kit_uploads'))
SHEETS = {
    'carrom_set_a': '102363-917328e3695e.png',
    'carrom_board': '102364-e5d4360b9f6b.png',
    'ui_frames_a': '102376-030d2d5750d6.png',
    'dice_purple': '108848-ccff0c07d01b.png',
    'play_button': '137849-5dee9beef7a7.webp',
    'tokens': '139192-b245e30a118b.png',
    'bb_arena': '139206-d528893f02f9.png',
    'bb_sprites': '139207-be8cdb845950.png',
    'cards_ui': '139652-afa68049830b.png',
    'currency_ui': '139657-930f4b24c9e7.png',
    'star': '139669-18d576eaad7e.png',
    'trophy': '139671-bfa9bc908a6f.png',
    'ui_frames_b': '139674-516722a8367b.png',
    'coin': '18816-73b7a01c6df7.png',
    'carrom_set_b': '18994-65d0e0e06588.png',
    'cards_ui_m': '19001-ed5523a3d935.png',
    'snl_kit': '19070-83e42a005f15.png',
    'snl_board': '20574-705bb18fccef.png',
    'turn_timer': '20575-cfa9f0f5b89e.png',
    'snl_sprites': '20578-6b36cb11d080.png',
}
MAGENTA = {'carrom_set_a', 'carrom_board', 'carrom_set_b', 'cards_ui_m', 'snl_kit'}


def load(name):
    return np.array(Image.open(os.path.join(UP, SHEETS[name])).convert('RGBA')).astype(np.float32)


def key_magenta(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # magenta-ness: both red and blue far above green and close to each other
    m = np.minimum(r, b) - g - 0.6 * np.abs(r - b)
    alpha = np.clip((170 - m) / 100.0, 0, 1)  # m>=170 -> bg, m<=70 -> opaque
    # only pixels connected to the outside count as background (keeps pink/purple art inside sprites)
    lab, _ = ndimage.label(alpha < 0.98)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    outside = np.isin(lab, list(border))
    alpha = np.where(outside, alpha, 1.0)
    out = a.copy()
    # unmix the key colour from soft edge pixels: c = alpha*fg + (1-alpha)*M
    M = np.array([244.0, 3.0, 245.0])
    al = np.maximum(alpha, 0.05)[..., None]
    fg = (a[..., :3] - (1 - al) * M) / al
    soft = (alpha > 0) & (alpha < 1)
    out[..., :3] = np.where(soft[..., None], np.clip(fg, 0, 255), a[..., :3])
    # residual pink rim right next to the background: pull r/b toward g a little
    rim = ndimage.binary_dilation(alpha < 0.5, iterations=2) & (alpha >= 0.5)
    sp = np.clip(np.minimum(out[..., 0], out[..., 2]) - out[..., 1] - 60, 0, None) * 0.5
    out[..., 0] = np.where(rim, out[..., 0] - sp, out[..., 0])
    out[..., 2] = np.where(rim, out[..., 2] - sp, out[..., 2])
    out[..., 3] = alpha * 255
    return out


def key_flood(a, test, tol_iter=1):
    """Transparent where `test` is true AND connected to the image border."""
    bgish = test(a)
    lab, n = ndimage.label(bgish)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    # soft 1px edge
    soft = ndimage.binary_dilation(bg, iterations=1) & ~bg
    out = a.copy()
    alpha = np.where(bg, 0, 255).astype(np.float32)
    alpha[soft] = 140
    out[..., 3] = np.minimum(out[..., 3], alpha)
    return out


def keyed(name):
    a = load(name)
    if name in MAGENTA:
        return key_magenta(a)
    if name == 'coin':
        return key_flood(a, lambda x: (x[..., :3].min(-1) > 232))
    if name == 'tokens':
        return key_flood(a, lambda x: (x[..., :3].max(-1) < 22))
    return a


def components(a, merge=6, min_area=300):
    mask = a[..., 3] > 40
    if merge:
        m2 = ndimage.binary_dilation(mask, iterations=merge)
    else:
        m2 = mask
    lab, n = ndimage.label(m2)
    objs = ndimage.find_objects(lab)
    res = []
    for i, sl in enumerate(objs):
        if sl is None:
            continue
        sub = (lab[sl] == i + 1) & mask[sl]
        if sub.sum() < min_area:
            continue
        ys, xs = np.nonzero(sub)
        y0, y1 = sl[0].start + ys.min(), sl[0].start + ys.max() + 1
        x0, x1 = sl[1].start + xs.min(), sl[1].start + xs.max() + 1
        res.append((y0, x0, y1, x1, i + 1))
    # reading order: rows by centre y (tolerance = 40% of median height)
    if not res:
        return [], lab
    hs = np.median([r[2] - r[0] for r in res])
    res.sort(key=lambda r: (r[0] + r[2]) / 2)
    rows, cur = [], [res[0]]
    for r in res[1:]:
        if abs((r[0] + r[2]) / 2 - (cur[-1][0] + cur[-1][2]) / 2) < hs * 0.45:
            cur.append(r)
        else:
            rows.append(cur)
            cur = [r]
    rows.append(cur)
    ordered = []
    for row in rows:
        ordered += sorted(row, key=lambda r: r[1])
    return ordered, lab


def crop(a, box, lab=None, pad=2, isolate=True):
    y0, x0, y1, x1, li = box
    y0, x0 = max(0, y0 - pad), max(0, x0 - pad)
    y1, x1 = min(a.shape[0], y1 + pad), min(a.shape[1], x1 + pad)
    c = a[y0:y1, x0:x1].copy()
    if isolate and lab is not None:
        keep = ndimage.binary_dilation(lab[y0:y1, x0:x1] == li, iterations=1)
        c[..., 3] = np.where(keep, c[..., 3], 0)
    return c


def to_img(c):
    return Image.fromarray(np.clip(c, 0, 255).astype(np.uint8), 'RGBA')


def fit(img, maxside):
    w, h = img.size
    s = min(1.0, maxside / max(w, h))
    if s < 1:
        img = img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    return img


def contact(items, path, cell=150):
    cols = 8
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * cell, rows * (cell + 16)), (60, 60, 60, 255))
    d = ImageDraw.Draw(sheet)
    chk = Image.new('RGBA', (cell, cell), (90, 90, 90, 255))
    cd = ImageDraw.Draw(chk)
    for yy in range(0, cell, 12):
        for xx in range(0, cell, 12):
            if (xx // 12 + yy // 12) % 2:
                cd.rectangle([xx, yy, xx + 11, yy + 11], fill=(130, 130, 130, 255))
    for i, (label, im) in enumerate(items):
        x, y = (i % cols) * cell, (i // cols) * (cell + 16)
        sheet.paste(chk, (x, y + 16))
        t = im.copy()
        t.thumbnail((cell - 6, cell - 6))
        sheet.alpha_composite(t, (x + (cell - t.width) // 2, y + 16 + (cell - t.height) // 2))
        d.text((x + 3, y + 2), str(label)[:22], fill=(255, 255, 0, 255))
    sheet.save(path)


def index(out):
    os.makedirs(out, exist_ok=True)
    for name in SHEETS:
        if name in ('dice_purple', 'bb_arena', 'snl_board', 'carrom_board', 'turn_timer', 'play_button'):
            continue
        a = keyed(name)
        boxes, lab = components(a, merge=MERGE.get(name, 6), min_area=MINA.get(name, 300))
        items = []
        for i, b in enumerate(boxes):
            items.append((f'{i}', to_img(crop(a, b, lab))))
        contact(items, os.path.join(out, f'{name}.png'))
        print(name, len(boxes))


MERGE = {'bb_sprites': 10, 'cards_ui': 4, 'cards_ui_m': 4, 'currency_ui': 6, 'snl_sprites': 14, 'snl_kit': 5,
         'ui_frames_a': 8, 'ui_frames_b': 8, 'tokens': 3, 'carrom_set_a': 3, 'carrom_set_b': 3, 'star': 4, 'trophy': 8,
         'coin': 4}
MINA = {'snl_sprites': 1500, 'bb_sprites': 800, 'currency_ui': 600, 'cards_ui': 500, 'cards_ui_m': 500}

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--index', action='store_true')
    ap.add_argument('--out', default=os.path.join('build', 'nx_kit_out', 'slices'))
    args = ap.parse_args()
    if args.index:
        index(args.out)
    else:
        import nx_kit_export  # noqa: F401  (phase 2 lives next to this file)
        nx_kit_export.main(sys.modules[__name__])
