"""Phase 2 of tool/nx_kit_slice.py: names, trims, resizes and writes the NX neon kit (owner uploads 2026-11-25).

Run from the repo root:  python3 tool/nx_kit_slice.py
Writes webp sprites under assets/games/<game>/nx/ and assets/ui/nx_kit/ (see the table at the bottom of this file
and docs/NX_KIT_ASSETS.md). Component indices refer to the numbered contact sheets that `--index` writes.
"""
import colorsys
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
OUT_DIR = os.environ.get('NX_KIT_OUT', os.path.join(ROOT, 'build', 'nx_kit_out'))
os.makedirs(OUT_DIR, exist_ok=True)
S = None  # nx_kit_slice module (set in main)
_cache = {}


def comps(sheet):
    if sheet not in _cache:
        a = S.keyed(sheet)
        boxes, lab = S.components(a, merge=EXPORT_MERGE.get(sheet, S.MERGE.get(sheet, 6)),
                                  min_area=S.MINA.get(sheet, 300))
        _cache[sheet] = (a, boxes, lab)
    return _cache[sheet]


EXPORT_MERGE = {'bb_sprites': 4}


def trim(img, pad=1):
    a = np.array(img)
    m = a[..., 3] > 8
    if not m.any():
        return img
    ys, xs = np.nonzero(m)
    return img.crop((max(0, xs.min() - pad), max(0, ys.min() - pad),
                     min(img.width, xs.max() + 1 + pad), min(img.height, ys.max() + 1 + pad)))


def piece(sheet, idx, split=None, part=0):
    a, boxes, lab = comps(sheet)
    img = S.to_img(S.crop(a, boxes[idx], lab))
    if split:
        w = img.width / split
        img = img.crop((round(part * w), 0, round((part + 1) * w), img.height))
        # keep the biggest blob only (no sliver of the neighbouring chip)
        from scipy import ndimage
        arr = np.array(img)
        m = arr[..., 3] > 40
        lab, k = ndimage.label(m)
        if k > 1:
            big = np.argmax(ndimage.sum(m, lab, range(1, k + 1))) + 1
            keep = ndimage.binary_dilation(lab == big, iterations=2)
            arr[..., 3] = np.where(keep, arr[..., 3], 0)
            img = Image.fromarray(arr)
    return trim(img)


def circle(img, size=192, inset=0.0):
    """Round piece: fits the disc (bbox width = diameter, shadows below are cut) into a size x size square and masks
    it with an anti-aliased circle, so the disc rim is exactly the sprite edge (fill 1)."""
    w = img.width
    sq = img.crop((0, 0, w, w)) if img.height >= w else img
    if sq.height < w:  # wider than tall: centre vertically
        c = Image.new('RGBA', (w, w), (0, 0, 0, 0))
        c.paste(sq, (0, (w - sq.height) // 2))
        sq = c
    big = sq.resize((size * 4, size * 4), Image.LANCZOS)
    m = Image.new('L', big.size, 0)
    r = size * 2 * (1 - inset)
    ImageDraw.Draw(m).ellipse((size * 2 - r, size * 2 - r, size * 2 + r, size * 2 + r), fill=255)
    arr = np.array(big)
    arr[..., 3] = (arr[..., 3].astype(np.float32) * (np.array(m) / 255.0)).astype(np.uint8)
    return Image.fromarray(arr).resize((size, size), Image.LANCZOS)


def fit(img, maxside):
    return S.fit(img, maxside)


def save(img, rel, q=88):
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p, 'WEBP', quality=q, method=6)
    WRITTEN.append(rel)


WRITTEN = []


def hue_shift(img, deg, sat=1.0, val=1.0):
    img = img.convert('RGBA')
    alpha = img.getchannel('A')
    hsv = np.array(img.convert('RGB').convert('HSV')).astype(np.float32)
    hsv[..., 0] = (hsv[..., 0] + deg / 360.0 * 256) % 256
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0, 255)
    hsv[..., 2] = np.clip(hsv[..., 2] * val, 0, 255)
    out = Image.fromarray(hsv.astype(np.uint8), 'HSV').convert('RGB').convert('RGBA')
    out.putalpha(alpha)
    return out


def gold_tint(img):
    """Neon board recoloured to gold: luminance kept, chroma mapped to a gold ramp."""
    a = np.array(img.convert('RGBA')).astype(np.float32) / 255.0
    lum = (a[..., :3] * [0.3, 0.59, 0.11]).sum(-1)
    sat = a[..., :3].max(-1) - a[..., :3].min(-1)
    gold = np.stack([np.clip(lum * 2.1, 0, 1), np.clip(lum * 1.55, 0, 1), np.clip(lum * 0.55, 0, 1)], -1)
    mix = np.clip(sat * 1.6, 0, 1)[..., None]
    rgb = a[..., :3] * (1 - mix) + gold * mix
    out = np.concatenate([rgb, a[..., 3:]], -1)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), 'RGBA')


# ---------------------------------------------------------------------------------------------------------- carrom
def carrom():
    d = 'assets/games/carrom/nx/'
    # board: key the magenta frame, trim to the board, measure the black pockets
    a = S.keyed('carrom_board')
    img = trim(S.to_img(a), pad=0)
    img = img.resize((1024, round(1024 * img.height / img.width)), Image.LANCZOS) if img.width > 1024 else img
    arr = np.array(img).astype(np.float32)
    dark = (arr[..., :3].max(-1) < 18) & (arr[..., 3] > 200)
    h, w = dark.shape
    pk = []
    from scipy import ndimage
    for (y0, y1, x0, x1) in ((0, h // 4, 0, w // 4), (0, h // 4, 3 * w // 4, w), (3 * h // 4, h, 0, w // 4),
                             (3 * h // 4, h, 3 * w // 4, w)):
        sub = dark[y0:y1, x0:x1]
        lab, n = ndimage.label(sub)
        sizes = ndimage.sum(sub, lab, range(1, n + 1))
        k = int(np.argmax(sizes)) + 1
        cy, cx = ndimage.center_of_mass(lab == k)
        pk.append(((x0 + cx) / w, (y0 + cy) / h))
    pockets = [round((pk[0][0] + pk[2][0]) / 2, 4), round((pk[0][1] + pk[1][1]) / 2, 4),
               round((pk[1][0] + pk[3][0]) / 2, 4), round((pk[2][1] + pk[3][1]) / 2, 4)]
    print('neon board pockets', pockets, pk)
    save(img, d + 'board_neon_blue.webp', 86)
    save(hue_shift(img, 70), d + 'board_neon_magenta.webp', 86)  # cyan/violet -> magenta/rose
    save(hue_shift(img, -110), d + 'board_neon_emerald.webp', 86)  # -> green/teal
    save(gold_tint(img), d + 'board_neon_gold.webp', 86)
    # piece sets: white / black / queen / striker0 / striker1 (round, rim = sprite edge)
    P = 160
    sets = {
        'neon_star': [('carrom_set_a', 4), ('carrom_set_a', 10), ('carrom_set_a', 15), ('carrom_set_a', 0),
                      ('carrom_set_a', 1)],
        'gem_duel': [('carrom_set_b', 0), ('carrom_set_b', 6), ('carrom_set_b', 14, 5, 4), ('carrom_set_b', 15),
                     ('carrom_set_b', 16)],
        'frost_night': [('carrom_set_b', 13), ('carrom_set_b', 14, 5, 0), ('carrom_set_b', 14, 5, 4),
                        ('carrom_set_b', 16), ('carrom_set_b', 15)],
        'crown_royale': [('tokens', 3), ('tokens', 4), ('tokens', 5), ('tokens', 6), ('tokens', 15)],
        'casino_suits': [('tokens', 8), ('tokens', 12), ('tokens', 10), ('tokens', 14), ('tokens', 7)],
        'classic_chips': [('tokens', 0), ('tokens', 1), ('tokens', 2), ('carrom_set_a', 2), ('carrom_set_a', 3)],
        'elements': [('tokens', 16, 8, 0), ('tokens', 16, 8, 1), ('tokens', 16, 8, 6), ('tokens', 16, 8, 2),
                     ('tokens', 16, 8, 3)],
        'beasts': [('tokens', 16, 8, 5), ('tokens', 16, 8, 7), ('tokens', 16, 8, 4), ('carrom_set_a', 2),
                   ('carrom_set_a', 3)],
    }
    roles = ['white', 'black', 'queen', 'striker0', 'striker1']
    for name, spec in sets.items():
        for role, sp in zip(roles, spec):
            src = piece(sp[0], sp[1], *(sp[2:] if len(sp) > 2 else ()))
            size = P if src.width >= P else max(48, src.width)
            save(circle(src, size, inset=0.01), d + f'pieces_{name}_{role}.webp', 90)
    # spare white/black coin designs of set A/B (shop previews of the "spare coins" chip)
    return pockets


# ----------------------------------------------------------------------------------------------------------- dice
def dice():
    for i in range(6):
        save(fit(piece('carrom_set_a', 16 + i), 128), f'assets/games/shared/dice/neon_{i + 1}.webp')
        save(fit(piece('carrom_set_b', 17 + i), 128), f'assets/games/shared/dice/marble_{i + 1}.webp')
    # purple 3D dice (108848): rounded tiles cut on the sheet's 3 x 2 grid, top face = value
    src = Image.open(os.path.join(S.UP, S.SHEETS['dice_purple'])).convert('RGBA')
    cx = [186, 544, 900]
    cy = [452, 946]
    half = 178
    for r in range(2):
        for c in range(3):
            v = r * 3 + c + 1
            t = src.crop((cx[c] - half, cy[r] - half, cx[c] + half, cy[r] + half)).resize((192, 192), Image.LANCZOS)
            m = Image.new('L', (192 * 4, 192 * 4), 0)
            ImageDraw.Draw(m).rounded_rectangle((0, 0, 192 * 4 - 1, 192 * 4 - 1), radius=150, fill=255)
            t.putalpha(m.resize((192, 192), Image.LANCZOS))
            save(t, f'assets/games/shared/dice/purple_{v}.webp')


# --------------------------------------------------------------------------------------------------------- ui kit
def ui_kit():
    d = 'assets/ui/nx_kit/'
    coin = trim(S.to_img(S.keyed('coin')))
    save(fit(coin, 128), d + 'coin.webp', 90)
    save(fit(trim(S.to_img(S.load('star'))), 128), d + 'star.webp', 90)
    save(fit(trim(S.to_img(S.load('trophy'))), 256), d + 'trophy.webp', 90)
    pb = Image.open(os.path.join(S.UP, S.SHEETS['play_button'])).convert('RGBA')
    save(trim(pb), d + 'play_button.webp', 90)
    cur = ['gold_orb', 'gem_purple', 'energy_ring', 'gem', 'toggle_on', 'toggle_off', 'btn_ring', 'orb_green',
           'orb_cyan', 'orb_orange', 'orb_gray', 'btn_close', 'btn_back']
    for i, n in enumerate(cur):
        save(fit(piece('currency_ui', i), 160), d + n + '.webp', 90)
    fb = ['bar_small', 'bar_cyan', 'bar_purple', 'badge_wings', 'die3d_purple', 'die3d_pink', 'chip_cyan',
          'chip_purple', 'chest', 'ring']
    for i, n in enumerate(fb):
        save(fit(piece('ui_frames_b', i), 384 if n.startswith('bar') else 256), d + n + '.webp', 88)
    fa = ['bar_small_b', 'panel_a', 'panel_b', 'die3d_purple_b', 'die3d_silver', 'chip_purple_b', 'chip_cyan_b',
          'bar_tiny']
    for i, n in enumerate(fa):
        save(fit(piece('ui_frames_a', i), 512 if n.startswith('panel') else 256), d + n + '.webp', 88)
    # crest shields / stickers (139192 bottom row)
    sh = [(17, None, 0, 'shield_champion'), (18, 2, 0, 'shield_football'), (18, 2, 1, 'shield_lion'),
          (19, None, 0, 'shield_eagle'), (20, None, 0, 'shield_star'), (21, 3, 0, 'sticker_trophy'),
          (21, 3, 1, 'sticker_fireball'), (21, 3, 2, 'sticker_goal')]
    for idx, sp, part, n in sh:
        save(fit(piece('tokens', idx, sp, part) if sp else piece('tokens', idx), 192), d + 'badges/' + n + '.webp', 90)


# ----------------------------------------------------------------------------------------------------------- cards
CARD_NAMES = {19: 'suit_spade', 20: 'suit_heart', 21: 'slot_cyan', 22: 'slot_cyan_b', 23: 'slot_violet',
              24: 'slot_violet_b', 25: 'suit_diamond', 26: 'suit_club', 27: 'card_back', 28: 'deck_tray',
              16: 'tray_3', 17: 'tray_4', 18: 'tray_4b'}
LUDO_NAMES = {0: 'tile_sq_a', 1: 'tile_sq_b', 2: 'tile_sq_c', 3: 'tile_sq_d', 4: 'spinner_ring', 5: 'tile_hex_a',
              6: 'tile_hex_b', 7: 'tile_hex_c', 8: 'tile_hex_d', 9: 'path_hook', 10: 'path_straight', 11: 'path_vertical',
              12: 'path_arc', 13: 'path_start', 14: 'path_diag', 15: 'path_corner'}


def cards():
    """139652 (transparent) -> UNO / card-table kit; 19001 (same layout, magenta) -> the ludo board kit. Each sprite is
    exported once (no duplicate art in the APK)."""
    for i, n in CARD_NAMES.items():
        im = piece('cards_ui', i)
        if n == 'card_back':
            im = im.rotate(90, expand=True)  # portrait card back
        save(fit(im, 320 if n in ('card_back', 'deck_tray') else 256), 'assets/ui/nx_kit/cards/' + n + '.webp', 88)
    for i, n in LUDO_NAMES.items():
        im = key_holes(piece('cards_ui_m', i))
        save(fit(im, 256), 'assets/ui/nx_kit/ludo/' + n + '.webp', 88)


# ------------------------------------------------------------------------------------------------------ basketball
def basketball():
    d = 'assets/games/basketball_battle/'
    names = ['player_blue', 'player_red', 'hoop_full', 'ball', 'ball_fast', 'ball_fire', 'fx_explosion', 'fx_swish',
             'scoreboard', 'trophy', 'medal', 'shield']
    imgs = {n: piece('bb_sprites', i) for i, n in enumerate(names)}
    for n in ('player_blue', 'player_red'):
        save(fit(imgs[n], 360), d + n + '.webp')
    for n in ('ball', 'ball_fast', 'ball_fire', 'fx_explosion', 'fx_swish', 'trophy', 'medal', 'shield'):
        save(fit(imgs[n], 256), d + n + '.webp')
    # ball sprite: round, rim = edge
    save(circle(imgs['ball'], 160, inset=0.0), d + 'ball.webp', 90)
    # hoop: backboard (glass + frame, above the ring) and the stanchion (pole + NX pad) as separate sprites
    hp = imgs['hoop_full']
    arr = np.array(hp)
    # the ring is the orange row band; find the first row from the top where orange dominates in the centre
    h, w = arr.shape[:2]
    cen = arr[:, w // 3: 2 * w // 3, :3].astype(int)
    orange = ((cen[..., 0] > 200) & (cen[..., 1] > 60) & (cen[..., 1] < 160) & (cen[..., 2] < 90)).mean(1)
    rows = np.nonzero(orange > 0.25)[0]
    ring_y = int(rows[0]) if len(rows) else int(h * 0.3)
    board = trim(hp.crop((0, 0, w, ring_y)))
    save(fit(board, 384), d + 'hoop_board.webp')
    # stanchion: the lower part below the net
    base_y = int(h * 0.47)  # below the net: the pole and the NX pad
    pole = trim(hp.crop((0, base_y, w, h)))
    save(fit(pole, 256), d + 'hoop_stand.webp')
    print('hoop ring_y', ring_y, 'base_y', base_y, 'size', hp.size)
    # scoreboard with the printed digits painted over (live numbers are drawn on top): three dark windows
    sb = imgs['scoreboard'].copy()
    sw, sh = sb.size
    dr = ImageDraw.Draw(sb)
    for (x0, y0, x1, y1) in ((0.085, 0.29, 0.355, 0.67), (0.385, 0.27, 0.625, 0.47), (0.655, 0.29, 0.925, 0.67)):
        box = (int(x0 * sw), int(y0 * sh), int(x1 * sw), int(y1 * sh))
        dr.rounded_rectangle(box, radius=int(0.03 * sh), fill=(14, 20, 38, 255), outline=(40, 60, 110, 255), width=2)
    save(fit(sb, 512), d + 'scoreboard_blank.webp')
    # arena background aligned to the 360x640 canvas (2x = 720x1280): the art's backboard sits on the physics board
    # at hoopX = 0; the painted hoop, stanchion and roof scoreboard are painted out (the live hoop slides).
    arena_bg(d)


def arena_bg(d):
    src = Image.open(os.path.join(S.UP, S.SHEETS['bb_arena'])).convert('RGB')
    a = np.array(src).astype(np.float32)
    H, W = a.shape[:2]
    # painted hoop region (full res): backboard x 290-735, y 185-430; net/rim to y 470; stanchion x 440-585 to 800
    out = a.copy()

    def mirror_fill(y0, y1, x0, x1):
        mid = (x0 + x1) // 2
        for x in range(x0, mid):
            sx = x0 - (x - x0) - 1
            out[y0:y1, x] = a[y0:y1, max(0, sx)]
        for x in range(mid, x1):
            sx = x1 + (x1 - x) - 1
            out[y0:y1, x] = a[y0:y1, min(W - 1, sx)]
    regions = REG
    for (y0, y1, x0, x1) in regions['mirror']:
        mirror_fill(y0, y1, x0, x1)
    for (y0, y1, x0, x1, sx0, sx1) in regions['tile']:
        strip = a[y0:y1, sx0:sx1]
        sw = sx1 - sx0
        for x in range(x0, x1):
            out[y0:y1, x] = strip[:, (x - x0) % sw]
    for (y0, y1, x0, x1) in regions['rowfill']:
        for y in range(y0, y1):
            left = a[y, max(0, x0 - 40):x0]
            right = a[y, x1:min(W, x1 + 40)]
            col = np.median(np.concatenate([left, right]), axis=0)
            out[y, x0:x1] = col
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    # soften the seams
    mask = Image.new('L', img.size, 0)
    md = ImageDraw.Draw(mask)
    for key in ('mirror', 'tile', 'rowfill'):
        for r in regions[key]:
            y0, y1, x0, x1 = r[:4]
            md.rectangle((x0 - 6, y0 - 6, x1 + 6, y1 + 6), fill=255)
    blur = img.filter(ImageFilter.GaussianBlur(3))
    edge = mask.filter(ImageFilter.GaussianBlur(10))
    em = np.array(edge).astype(np.float32) / 255
    inner = np.array(mask.filter(ImageFilter.MinFilter(9))).astype(np.float32) / 255
    seam = np.clip(em - inner, 0, 1)[..., None]
    img = Image.fromarray((np.array(img) * (1 - seam) + np.array(blur) * seam).astype(np.uint8))
    img.save(os.path.join(OUT_DIR, 'arena_clean_full.png'))
    # canvas placement: art backboard (x 304-720 full, y 196 top) -> physics board (86..274, 184) on 360x640
    bx0, bx1, by0 = REG['board_px']
    s = (273.83 - 86.17) / (bx1 - bx0)  # canvas units per art px
    ox = 86.17 - bx0 * s
    oy = 183.93 - by0 * s
    k = 2  # output scale (720x1280)
    canvas = Image.new('RGB', (360 * k, 640 * k))
    # fill the band above the art with its top row colour, fading into the roof
    top = np.array(img)[0:6].mean((0, 1))
    canvas.paste(tuple(int(v) for v in top), (0, 0, 360 * k, 640 * k))
    scaled = img.resize((round(W * s * k), round(H * s * k)), Image.LANCZOS)
    canvas.paste(scaled, (round(ox * k), round(oy * k)))
    ca = np.array(canvas).astype(np.float32)
    fy = round(oy * k)
    if fy > 0:
        g = np.linspace(0, 1, fy)[:, None, None]
        ca[:fy] = ca[:fy] * 0.0 + (ca[fy:fy + 1] * g + top * (1 - g) * 0.6)
    canvas = Image.fromarray(ca.astype(np.uint8))
    print('arena placement s=%.4f ox=%.1f oy=%.1f' % (s, ox, oy))
    canvas.save(os.path.join(ROOT, d + 'court_nx.webp'), 'WEBP', quality=82, method=6)
    WRITTEN.append(d + 'court_nx.webp')


REG = {}  # filled by measure_arena() before basketball()


# --------------------------------------------------------------------------------------------------- snakes & ladders
def snakes():
    d = 'assets/games/snakes_ladders/nx/'
    names = ['snake_long', 'snake_curl_a', 'snake_curl_b', 'snake_mid', 'ladder_long', 'ladder_mid', 'ladder_short',
             'grid_board', 'numbers_board', 'snake_small', 'pawn_blue', 'pawn_yellow', 'pawn_green', 'pawn_ring',
             'misc_14', 'misc_15']
    a, boxes, lab = comps('snl_kit')
    for i in range(len(boxes)):
        n = SNL_KIT.get(i)
        if not n:
            continue
        im = key_holes(piece('snl_kit', i))
        save(fit(im, 1024 if 'board' in n else 320), d + n + '.webp')
        if n == 'pawn_blue':
            save(fit(hue_shift(im, 75), 320), d + 'pawn_violet.webp')
            save(fit(hue_shift(im, 120), 320), d + 'pawn_pink.webp')
    a, boxes, lab = comps('snl_sprites')
    for i in range(len(boxes)):
        n = SNL_SPR.get(i)
        if not n:
            continue
        im = piece('snl_sprites', i)
        arr = np.array(im)
        # the cut-outs carry faint ghosts of the board numbers: drop the low-alpha haze
        arr[..., 3] = np.where(arr[..., 3] < 170, 0, arr[..., 3])
        save(fit(trim(Image.fromarray(arr)), 360), d + 'art_' + n + '.webp')
    # turn timer bar with the printed texts blanked
    tb = Image.open(os.path.join(S.UP, S.SHEETS['turn_timer'])).convert('RGBA')
    save(timer_blank(tb), d + 'turn_timer_bar.webp')
    save(clean_board(), d + 'board_neon.webp', 86)


SNL_KIT = {}
SNL_SPR = {}


def key_holes(im):
    arr = np.array(im).astype(np.float32)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    m = np.minimum(r, b) - g - 0.6 * np.abs(r - b)
    a = np.clip((170 - m) / 100.0, 0, 1)
    arr[..., 3] = np.minimum(arr[..., 3], a * 255)
    return Image.fromarray(arr.astype(np.uint8))


def timer_blank(tb):
    arr = np.array(tb).astype(np.float32)
    h, w = arr.shape[:2]
    out = arr.copy()
    for (x0, x1, y0, y1) in TIMER_TEXT:
        for y in range(y0, y1):
            row = np.concatenate([arr[y, max(0, x0 - 6):x0], arr[y, x1:x1 + 6]])
            out[y, x0:x1] = np.median(row, axis=0)
    img = Image.fromarray(out.astype(np.uint8))
    return fit(img, 900)


TIMER_TEXT = []


def clean_board():
    """Board 20574 without the two baked-in pawns (square 1 and square 68); the numbers are rebuilt from the glyphs of
    other squares on a median 'blank' square."""
    src = np.array(Image.open(os.path.join(S.UP, S.SHEETS['snl_board'])).convert('RGBA')).astype(np.float32)
    xs = [25, 120, 215, 310, 406, 500, 595, 690, 784, 880, 974]
    ys = [17, 108, 198, 290, 382, 476, 569, 664, 758, 856, 952]

    def rc(n):
        i = n - 1
        row = i // 10
        col = i % 10 if row % 2 == 0 else 9 - i % 10
        return 9 - row, col

    def box(n):
        r, c = rc(n)
        return ys[r], ys[r + 1], xs[c], xs[c + 1]
    cw, ch = 90, 88

    def cell(n):
        y0, y1, x0, x1 = box(n)
        cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
        return src[cy - ch // 2:cy + ch // 2, cx - cw // 2:cx + cw // 2]
    # blank square: median of squares the art leaves free
    free = [3, 5, 6, 7, 10, 11, 15, 16, 17, 20, 21, 22, 23, 26, 30, 31, 33, 35, 36, 39, 40, 41, 44, 45, 46, 50, 51,
            53, 54, 55, 56, 57, 58, 60, 61, 63, 66, 67, 70, 71, 73, 74, 78, 80, 81, 83, 85, 88, 89, 90, 91, 92, 93,
            95, 96, 98, 99]
    stack = np.stack([cell(n) for n in free])
    blank = np.median(stack, 0)

    def glyph(n, side):
        c = cell(n)
        diff = np.clip((c[..., :3] - blank[..., :3]).max(-1), 0, 255)
        m = (diff > 25).astype(np.float32)
        half = np.zeros_like(m)
        if side == 'l':
            half[:, :cw // 2] = 1
        elif side == 'r':
            half[:, cw // 2:] = 1
        else:
            half[:] = 1
        # only the number band (centre rows)
        band = np.zeros_like(m)
        band[ch // 4: ch * 3 // 4] = 1
        return c, m * half * band

    def put(n, parts, shift=0):
        y0, y1, x0, x1 = box(n)
        cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
        new = blank.copy()
        for (srcn, side, dx) in parts:
            c, m = glyph(srcn, side)
            m = np.roll(m, dx, axis=1)
            c = np.roll(c, dx, axis=1)
            new = new * (1 - m[..., None]) + c * m[..., None]
        reg = src[cy - ch // 2:cy + ch // 2, cx - cw // 2:cx + cw // 2]
        # feather into the original square edges
        f = np.ones((ch, cw), np.float32)
        e = 5
        for i in range(e):
            v = (i + 1) / (e + 1)
            f[i, :] = np.minimum(f[i, :], v)
            f[-1 - i, :] = np.minimum(f[-1 - i, :], v)
            f[:, i] = np.minimum(f[:, i], v)
            f[:, -1 - i] = np.minimum(f[:, -1 - i], v)
        reg[:] = reg * (1 - f[..., None]) + new * f[..., None]
    # 68 = "6" of 67 + "8" of 58 ; 1 = a single-digit square's layout: the "1" of 81 moved to the centre
    put(68, [(67, 'l', 0), (58, 'r', 0)])
    # square 1: the bottom row is taller and the pawn's base ring sits low, so the whole square is rebuilt from
    # square 5 (digit painted out with the square's own background) plus the "1" glyph of square 81
    q5 = src[858:976, 410:497].copy()
    bright = q5[..., :3].max(-1) > 120
    ys_, xs_ = np.nonzero(bright[10:-12, 10:-10])
    dy0, dy1, dx0, dx1 = ys_.min() + 10 - 3, ys_.max() + 10 + 4, xs_.min() + 10 - 3, xs_.max() + 10 + 4
    for y in range(dy0, dy1):
        q5[y, dx0:dx1] = np.median(np.concatenate([q5[y, 4:dx0 - 2], q5[y, dx1 + 2:-4]]), axis=0)
    c81, m81 = glyph(81, 'r')
    gy, gx = np.nonzero(m81)
    g = c81[gy.min():gy.max() + 1, gx.min():gx.max() + 1]
    gm = m81[gy.min():gy.max() + 1, gx.min():gx.max() + 1]
    cy_, cx_ = (dy0 + dy1) // 2, (dx0 + dx1) // 2
    ty, tx = cy_ - g.shape[0] // 2, cx_ - g.shape[1] // 2
    reg = q5[ty:ty + g.shape[0], tx:tx + g.shape[1]]
    reg[:] = reg * (1 - gm[..., None]) + g * gm[..., None]
    src[858:976, 27:114] = q5[:, :87]
    img = Image.fromarray(np.clip(src, 0, 255).astype(np.uint8))
    img.save(os.path.join(OUT_DIR, 'snl_board_clean.png'))
    return img


GLYPH1_SHIFT = 12


def main(slice_mod):
    global S
    S = slice_mod
    import json
    cfg = json.load(open(os.path.join(os.path.dirname(__file__), 'nx_kit_regions.json')))
    REG.update(cfg['arena'])
    SNL_KIT.update({int(k): v for k, v in cfg['snl_kit'].items()})
    SNL_SPR.update({int(k): v for k, v in cfg['snl_sprites'].items()})
    TIMER_TEXT.extend([tuple(x) for x in cfg['timer_text']])
    globals()['GLYPH1_SHIFT'] = cfg.get('glyph1_shift', 12)
    only = os.environ.get('NX_ONLY', '').split(',')
    steps = {'carrom': carrom, 'dice': dice, 'ui': ui_kit, 'cards': cards, 'basketball': basketball,
             'snakes': snakes}
    for k, f in steps.items():
        if only == [''] or k in only:
            r = f()
            if r is not None:
                print(k, r)
    with open(os.path.join(OUT_DIR, 'nx_kit_written.txt'), 'w') as fh:
        fh.write('\n'.join(WRITTEN))
    print('wrote', len(WRITTEN))
