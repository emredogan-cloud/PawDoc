#!/usr/bin/env python3
"""PawDoc Lottie asset builder (PAWDOC_MOTION_ROADMAP.md §4).

M1 "First breath": A1-A6 + matrix #8 ambient loops / one-shots.
M3 "Emotional milestones": A7 gift-open + A8 premium-welcome one-shots.

Reproducible pipeline: founder PNG illustrations -> embedded-image Lottie with
vector overlay motion (breathing transforms, blinks, sparkles, glow, ECG draw,
"z" particles). Pure stdlib + Pillow; no network, no AE.

Budget: every output ≤250KB (enforced here AND by mobile/test/motion_assets_test.dart).
Conventions: 60fps timeline, transparent background, seamless first<->last frame,
reduce-motion fallback = the source PNG (unchanged, referenced by AppMotionAsset).

Usage: python3 scripts/motion/build_m1_lottie.py
Writes into mobile/assets/motion/.
"""
import base64
import io
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ILL = os.path.join(ROOT, "mobile", "assets", "illustrations")
BRAND = os.path.join(ROOT, "mobile", "assets", "brand")
OUT = os.path.join(ROOT, "mobile", "assets", "motion")

FPS = 60
BUDGET = 250 * 1024
IMG_BUDGET = 165 * 1024  # base64 inflates ~4/3; leaves room for vectors

# Palette (sampled from the asset set in M0)
TEAL = [0.0, 0.631, 0.639]        # #00A1A3
MINT = [0.663, 0.910, 0.871]      # #A9E8DE
GLOW = [0.749, 0.937, 0.894]      # #BFEFE4
SPARK = [0.498, 0.902, 0.839]     # #7FE6D6 — reads on white halos AND dark surfaces
WHITE = [1.0, 1.0, 1.0]


# ---------------------------------------------------------------- keyframes --
def ease(vdim):
    return {"i": {"x": [0.63] * vdim, "y": [1] * vdim},
            "o": {"x": [0.37] * vdim, "y": [0] * vdim}}


def anim(frames, dim):
    """frames: [(t, value-list)] -> animated property with sine-ish easing."""
    ks = []
    for i, (t, v) in enumerate(frames):
        v = v if isinstance(v, list) else [v]
        k = {"t": t, "s": v}
        if i < len(frames) - 1:
            k.update(ease(dim))
        ks.append(k)
    return {"a": 1, "k": ks}


def static(v):
    return {"a": 0, "k": v}


def transform(pos, anchor, scale, opacity=100, rotation=0):
    return {"o": opacity if isinstance(opacity, dict) else static(opacity),
            "r": rotation if isinstance(rotation, dict) else static(rotation),
            "p": pos if isinstance(pos, dict) else static(pos),
            "a": anchor if isinstance(anchor, dict) else static(anchor),
            "s": scale if isinstance(scale, dict) else static(scale)}


# ------------------------------------------------------------------- shapes --
def group(items, pos, scale=None, opacity=None, rotation=None, anchor=None, name="g"):
    tr = {"ty": "tr",
          "p": pos if isinstance(pos, dict) else static(pos),
          "a": static(anchor or [0, 0]),
          "s": scale if isinstance(scale, dict) else static(scale or [100, 100]),
          "r": rotation if isinstance(rotation, dict) else static(rotation or 0),
          "o": opacity if isinstance(opacity, dict) else static(opacity if opacity is not None else 100),
          "sk": static(0), "sa": static(0)}
    return {"ty": "gr", "nm": name, "it": items + [tr]}


def ellipse(size):
    return {"ty": "el", "d": 1, "p": static([0, 0]), "s": static(size)}


def star(outer, inner):
    return {"ty": "sr", "sy": 1, "d": 1, "pt": static(4), "p": static([0, 0]),
            "r": static(0), "ir": static(inner), "is": static(0),
            "or": static(outer), "os": static(0)}


def fill(color, opacity=100):
    return {"ty": "fl", "c": static(color + [1]), "o": static(opacity), "r": 1}


def stroke(color, width, opacity=100):
    return {"ty": "st", "c": static(color + [1]), "o": static(opacity),
            "w": static(width), "lc": 2, "lj": 2, "ml": 4}


def path_shape(verts, closed=False):
    n = len(verts)
    return {"ty": "sh", "d": 1,
            "ks": static({"i": [[0, 0]] * n, "o": [[0, 0]] * n,
                          "v": [list(v) for v in verts], "c": closed})}


def shape_layer(name, shapes, op, ind, parent=None, ks=None, ip=0):
    layer = {"ddd": 0, "ind": ind, "ty": 4, "nm": name, "sr": 1,
             "ks": ks or transform([0, 0, 0], [0, 0, 0], [100, 100, 100]),
             "ao": 0, "shapes": shapes, "ip": ip, "op": op, "st": 0, "bm": 0}
    if parent is not None:
        layer["parent"] = parent
    return layer


def image_layer(refid, ind, pos, anchor, scale, op, name="art"):
    return {"ddd": 0, "ind": ind, "ty": 2, "nm": name, "refId": refid, "sr": 1,
            "ks": transform(pos, anchor, scale), "ao": 0,
            "ip": 0, "op": op, "st": 0, "bm": 0}


# ------------------------------------------------------------ motion pieces --
def breath_scale(op, period_f, amp_x, amp_y, base=100.0, start=0):
    """Seamless breathing scale keyframes over the whole timeline."""
    frames = []
    t = start
    while t < op:
        frames.append((t, [base, base, base]))
        frames.append((min(t + period_f / 2, op), [base + amp_x, base + amp_y, base]))
        t += period_f
    frames.append((op, [base, base, base]))
    return anim(frames, 3)


def twinkle_opacity(op, windows, peak=95):
    """windows: [(start_f, len_f)] -> opacity kf, 0 outside windows."""
    frames = [(0, [0])]
    for (s, ln) in windows:
        frames.append((max(s - 1, 0), [0]))
        frames.append((s + ln * 0.4, [peak]))
        frames.append((s + ln, [0]))
    frames.append((op, [0]))
    frames = sorted(frames, key=lambda f: f[0])
    return anim(frames, 1)


def sparkle(pos, size, windows, op, color=None, drift=0, name="spark"):
    o = twinkle_opacity(op, windows)
    rot = anim([(0, [0]), (op, [25])], 1)
    p = pos
    if drift:
        p = anim([(0, [pos[0], pos[1]]), (op, [pos[0], pos[1] - drift])], 2)
    return group([star(size, size * 0.42), fill(color or SPARK)],
                 pos=p, opacity=o, rotation=rot, name=name)


def eyelid(cx, cy, rx, ry, color, blinks, op):
    """Color-matched ellipse that scales closed/open at each blink time (frames)."""
    frames = [(0, [100, 0])]
    for b in blinks:
        frames += [(b, [100, 0]), (b + 9, [100, 100]),
                   (b + 12, [100, 100]), (b + 21, [100, 0])]
    frames.append((op, [100, 0]))
    frames = sorted(frames, key=lambda f: f[0])
    return group([ellipse([rx * 2, ry * 2]), fill(color)],
                 pos=[cx, cy - ry], anchor=[0, -ry],
                 scale=anim(frames, 2), name="eyelid")


# -------------------------------------------------------------- image prep --
def prep_image(src, target, colors=256):
    im = Image.open(src).convert("RGBA")
    bbox = im.getbbox()
    pad = 12
    bbox = (max(bbox[0] - pad, 0), max(bbox[1] - pad, 0),
            min(bbox[2] + pad, im.width), min(bbox[3] + pad, im.height))
    im = im.crop(bbox)
    scale = target / max(im.size)
    if scale < 1:
        im = im.resize((round(im.width * scale), round(im.height * scale)),
                       Image.LANCZOS)
    else:
        scale = 1.0
    for cand_colors in (colors, 192, 160, 128):
        q = im.quantize(colors=cand_colors, method=Image.FASTOCTREE)
        buf = io.BytesIO()
        q.save(buf, "PNG", optimize=True)
        if buf.tell() <= IMG_BUDGET:
            return im, buf.getvalue(), bbox, scale
    # last resort: smaller raster
    im2 = im.resize((round(im.width * 0.85), round(im.height * 0.85)), Image.LANCZOS)
    q = im2.quantize(colors=128, method=Image.FASTOCTREE)
    buf = io.BytesIO()
    q.save(buf, "PNG", optimize=True)
    return im2, buf.getvalue(), bbox, scale * 0.85


def sample(im, x, y, r=4):
    """Median color of a small patch (resized-image space) -> [r,g,b] 0..1."""
    px = im.load()
    vals = []
    for dx in range(-r, r + 1):
        for dy in range(-r, r + 1):
            xx, yy = min(max(x + dx, 0), im.width - 1), min(max(y + dy, 0), im.height - 1)
            p = px[xx, yy]
            if p[3] > 200:
                vals.append(p[:3])
    if not vals:
        return [1, 1, 1]
    vals.sort()
    m = vals[len(vals) // 2]
    return [m[0] / 255, m[1] / 255, m[2] / 255]


def composition(name, w, h, op, assets, layers, markers=None):
    c = {"v": "5.7.4", "fr": FPS, "ip": 0, "op": op, "w": round(w), "h": round(h),
         "nm": name, "ddd": 0, "assets": assets, "layers": layers}
    if markers:
        c["markers"] = markers
    return c


def emit(comp, fname):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, fname)
    data = json.dumps(comp, separators=(",", ":"))
    size = len(data.encode())
    assert size <= BUDGET, f"{fname} busts budget: {size}"
    with open(path, "w") as f:
        f.write(data)
    print(f"  {fname}: {size//1024}KB")


def img_asset(png_bytes, iw, ih):
    return {"id": "img_0", "w": iw, "h": ih, "u": "",
            "p": "data:image/png;base64," + base64.b64encode(png_bytes).decode(),
            "e": 1}


def std_canvas(im, margin=0.08):
    mw, mh = im.width * margin, im.height * margin
    W, H = im.width + 2 * mw, im.height + 2 * mh
    return W, H, mw, mh


# ------------------------------------------------------------------- assets --
def build_a1():
    """Onboarding cuddle-duo: breath (4s x2) + ground glow + 3 sparkles.
    NOTE: the art's eyes are drawn CLOSED-HAPPY -> the spec's blink track is
    not applicable; breath/glow/sparkles carry the life (documented deviation)."""
    op = 480
    im, png, bbox, scale = prep_image(os.path.join(ILL, "onboarding", "onboarding_hero_value_v1.png"), 560)
    W, H, mx, my = std_canvas(im)
    art = image_layer("img_0", 2,
                      pos=[W / 2, my + im.height * 0.96, 0],
                      anchor=[im.width / 2, im.height * 0.96, 0],
                      scale=breath_scale(op, 240, 0.5, 1.4), op=op)
    glow = shape_layer("glow", [group(
        [ellipse([im.width * 0.85, im.height * 0.10]), fill(GLOW)],
        pos=[W / 2, my + im.height * 0.80],
        opacity=anim([(0, [12]), (120, [22]), (240, [12]), (360, [22]), (480, [12])], 1))],
        op=op, ind=3)
    sparkles = shape_layer("sparkles", [
        sparkle([W * 0.20, H * 0.26], 11, [(48, 72)], op),
        sparkle([W * 0.82, H * 0.20], 13, [(204, 72)], op),
        sparkle([W * 0.74, H * 0.55], 9, [(360, 72)], op),
    ], op=op, ind=1)
    comp = composition("onboarding_hero_loop_v1", W, H, op,
                       [img_asset(png, im.width, im.height)],
                       [sparkles, art, glow],
                       markers=[{"tm": 0, "cm": "loop", "dr": op}])
    emit(comp, "onboarding_hero_loop_v1.json")


def build_a2():
    """Empty-home welcome duo: micro-breath + halo shimmer + sparkles + BLINKS
    (puppy @2.0s, kitten @4.2s — this art has open eyes; eyelids are fur-color
    sampled and parented to the image so they track the breath)."""
    op = 360
    im, png, bbox, scale = prep_image(os.path.join(ILL, "empty_states", "empty_home_welcome_v1.png"), 560)
    W, H, mx, my = std_canvas(im)
    art = image_layer("img_0", 2,
                      pos=[W / 2, my + im.height * 0.96, 0],
                      anchor=[im.width / 2, im.height * 0.96, 0],
                      scale=breath_scale(op, 180, 0.3, 0.6), op=op)

    # Eye geometry measured DIRECTLY on the prepared (trimmed+resized 522x560)
    # image — prepared-space coords avoid transform drift on a 150ms blink.
    assert im.size == (522, 560), f"prep changed ({im.size}); re-measure eye coords"
    eyes = {  # name: (cx, cy, rx, ry, fur-sample-point)
        "pupL": (126, 264, 19, 17, (126, 240)),
        "pupR": (172, 243, 24, 22, (172, 214)),
        "kitL": (398, 297, 23, 18, (398, 272)),
        "kitR": (451, 322, 28, 24, (452, 292)),
    }
    lids = []
    for name, (cx, cy, rx, ry, fur) in eyes.items():
        color = sample(im, fur[0], fur[1])
        blinks = [120] if name.startswith("pup") else [252]
        lids.append(eyelid(cx, cy, rx, ry, color, blinks, op))
    lid_layer = shape_layer("eyelids", lids, op=op, ind=1, parent=2)

    halo = shape_layer("halo", [group(
        [ellipse([im.width * 0.58, im.width * 0.58]), stroke([0.914, 0.984, 0.961], 18)],
        pos=[W * 0.50, my + im.height * 0.40],
        opacity=anim([(0, [0]), (90, [14]), (180, [0]), (270, [14]), (360, [0])], 1))],
        op=op, ind=4)
    sparkles = shape_layer("sparkles", [
        sparkle([W * 0.30, H * 0.16], 10, [(30, 66)], op),
        sparkle([W * 0.68, H * 0.12], 12, [(132, 66)], op),
        sparkle([W * 0.86, H * 0.30], 9, [(228, 66)], op),
        sparkle([W * 0.14, H * 0.38], 9, [(312, 48)], op),
    ], op=op, ind=3)
    comp = composition("empty_home_welcome_loop_v1", W, H, op,
                       [img_asset(png, im.width, im.height)],
                       [lid_layer, halo, art, sparkles],
                       markers=[{"tm": 0, "cm": "loop", "dr": op}])
    emit(comp, "empty_home_welcome_loop_v1.json")


def build_a3():
    """Sign-in heartbeat (ONE-SHOT 1.2s): ECG line sweeps across the shield,
    soft teal glow pulse at 0.9s, settle. Never loops (trust surface)."""
    op = 72
    im, png, bbox, scale = prep_image(os.path.join(BRAND, "logo_mark_v1.png"), 480)
    W, H, mx, my = std_canvas(im, margin=0.10)
    iw, ih = im.width, im.height
    settle = anim([(0, [100, 100, 100]), (54, [100, 100, 100]),
                   (63, [100.8, 100.8, 100]), (72, [100, 100, 100])], 3)
    art = image_layer("img_0", 2,
                      pos=[W / 2, my + ih / 2, 0], anchor=[iw / 2, ih / 2, 0],
                      scale=settle, op=op)

    y = ih * 0.52
    pts = [(-iw * 0.06, y), (iw * 0.30, y), (iw * 0.37, y - ih * 0.035),
           (iw * 0.43, y), (iw * 0.49, y - ih * 0.16), (iw * 0.55, y + ih * 0.10),
           (iw * 0.60, y), (iw * 0.78, y), (iw * 1.06, y)]
    ecg = shape_layer("ecg", [{"ty": "gr", "nm": "line", "it": [
        path_shape(pts),
        {"ty": "tm", "m": 1, "o": static(0),
         "s": anim([(27, [0]), (54, [100])], 1),
         "e": anim([(12, [0]), (39, [100])], 1)},
        stroke(WHITE, ih * 0.020, opacity=92),
        {"ty": "tr", "p": static([0, 0]), "a": static([0, 0]), "s": static([100, 100]),
         "r": static(0), "o": static(100), "sk": static(0), "sa": static(0)},
    ]}], op=op, ind=1, parent=2)

    glow = shape_layer("glow", [group(
        [ellipse([iw * 0.95, ih * 0.95]), fill([0.498, 0.902, 0.839])],
        pos=[W / 2, my + ih / 2],
        opacity=anim([(0, [0]), (48, [0]), (58, [30]), (72, [0])], 1))],
        op=op, ind=3)
    comp = composition("signin_heartbeat_v1", W, H, op,
                       [img_asset(png, iw, ih)], [ecg, art, glow])
    emit(comp, "signin_heartbeat_v1.json")


def build_a4():
    """Paywall sleeper: deep 4s breath x2 + one floating 'z' per cycle + arc sparkles."""
    op = 480
    im, png, bbox, scale = prep_image(os.path.join(ILL, "monetization", "paywall_peace_of_mind_v1.png"), 560)
    W, H, mx, my = std_canvas(im)
    art = image_layer("img_0", 2,
                      pos=[W / 2, my + im.height * 0.96, 0],
                      anchor=[im.width / 2, im.height * 0.96, 0],
                      scale=breath_scale(op, 240, 0.8, 1.8), op=op)

    def z_group(t0):
        zx, zy = W * 0.38, H * 0.45
        size = im.width * 0.07
        verts = [(-size / 2, -size / 2), (size / 2, -size / 2),
                 (-size / 2, size / 2), (size / 2, size / 2)]
        return group(
            [path_shape(verts), stroke([0.310, 0.702, 0.643], size * 0.18)],
            pos=anim([(t0, [zx, zy]), (t0 + 170, [zx + 14, zy - H * 0.16])], 2),
            scale=anim([(t0, [62, 62]), (t0 + 170, [112, 112])], 2),
            opacity=anim([(0, [0]), (t0, [0]), (t0 + 36, [70]), (t0 + 170, [0]), (op, [0])], 1),
            name="z")

    zs = shape_layer("zs", [z_group(30), z_group(270)], op=op, ind=1)
    sparkles = shape_layer("sparkles", [
        sparkle([W * 0.24, H * 0.30], 10, [(90, 66)], op),
        sparkle([W * 0.76, H * 0.26], 11, [(330, 66)], op),
    ], op=op, ind=3)
    comp = composition("paywall_peace_loop_v1", W, H, op,
                       [img_asset(png, im.width, im.height)],
                       [zs, art, sparkles],
                       markers=[{"tm": 0, "cm": "loop", "dr": op}])
    emit(comp, "paywall_peace_loop_v1.json")


def build_a5():
    """Family circle: the group breathes as one (raster art -> per-figure offset
    isn't possible; documented deviation) + rising sparkle drift."""
    op = 480
    im, png, bbox, scale = prep_image(os.path.join(ILL, "growth", "family_care_circle_v1.png"), 560)
    W, H, mx, my = std_canvas(im)
    art = image_layer("img_0", 2,
                      pos=[W / 2, my + im.height * 0.96, 0],
                      anchor=[im.width / 2, im.height * 0.96, 0],
                      scale=breath_scale(op, 240, 0.4, 1.0), op=op)
    sparkles = shape_layer("sparkles", [
        sparkle([W * 0.18, H * 0.34], 10, [(60, 72)], op, drift=H * 0.05),
        sparkle([W * 0.50, H * 0.14], 12, [(216, 72)], op, drift=H * 0.04),
        sparkle([W * 0.84, H * 0.30], 10, [(372, 72)], op, drift=H * 0.05),
    ], op=op, ind=1)
    comp = composition("family_circle_loop_v1", W, H, op,
                       [img_asset(png, im.width, im.height)],
                       [sparkles, art],
                       markers=[{"tm": 0, "cm": "loop", "dr": op}])
    emit(comp, "family_circle_loop_v1.json")


def build_a6():
    """Referral gift: 0.6s settle-in ONCE (marker), then a 7.4s idle loop with
    a ±2° wiggle at ~5s and a seamless full sparkle orbit. Bow flutter needs a
    rigged bow -> substituted by the wiggle+orbit (documented deviation)."""
    op = 480
    settle_end = 36
    im, png, bbox, scale = prep_image(os.path.join(ILL, "growth", "referral_gift_v1.png"), 540)
    W, H, mx, my = std_canvas(im)
    iw, ih = im.width, im.height

    scale_k = anim([(0, [92, 92, 100]), (22, [102.5, 102.5, 100]), (36, [100, 100, 100]),
                    (160, [100.4, 100.9, 100]), (258, [100, 100, 100]),
                    (380, [100.4, 100.9, 100]), (480, [100, 100, 100])], 3)
    rot_k = anim([(0, [0]), (336, [0]), (344, [-2]), (356, [2]), (364, [0]), (480, [0])], 1)
    pos_k = anim([(0, [W / 2, my + ih * 0.96 - 14, 0]), (22, [W / 2, my + ih * 0.96 + 3, 0]),
                  (36, [W / 2, my + ih * 0.96, 0]), (480, [W / 2, my + ih * 0.96, 0])], 3)
    art = {"ddd": 0, "ind": 2, "ty": 2, "nm": "gift", "refId": "img_0", "sr": 1,
           "ks": {"o": static(100), "r": rot_k, "p": pos_k,
                  "a": static([iw / 2, ih * 0.96, 0]), "s": scale_k},
           "ao": 0, "ip": 0, "op": op, "st": 0, "bm": 0}

    import math
    cx, cy = W / 2, my + ih * 0.46
    orx, ory = iw * 0.58, ih * 0.20

    def orbit(phase_deg, size, twinkles):
        steps = 12
        frames = []
        for s in range(steps + 1):
            t = settle_end + (op - settle_end) * s / steps
            a = math.radians(phase_deg + 360 * s / steps)
            frames.append((round(t), [cx + orx * math.cos(a), cy + ory * math.sin(a)]))
        return group([star(size, size * 0.42), fill(SPARK)],
                     pos=anim(frames, 2),
                     opacity=twinkle_opacity(op, twinkles), name="orbit")

    sparkles = shape_layer("orbit_sparks", [
        orbit(0, 10, [(70, 60), (300, 60)]),
        orbit(120, 12, [(150, 60), (390, 54)]),
        orbit(240, 9, [(40, 50), (230, 60)]),
    ], op=op, ind=1)
    comp = composition("referral_gift_idle_v1", W, H, op,
                       [img_asset(png, iw, ih)], [sparkles, art],
                       markers=[{"tm": 0, "cm": "settle", "dr": settle_end},
                                {"tm": settle_end, "cm": "loop", "dr": op - settle_end}])
    emit(comp, "referral_gift_idle_v1.json")


def build_history():
    """History empty 'story starts here': gentle breath + the art's own sparkle
    trail twinkling (matrix #8; production conventions follow A2)."""
    op = 360
    im, png, bbox, scale = prep_image(os.path.join(ILL, "empty_states", "empty_history_story_v1.png"), 560)
    W, H, mx, my = std_canvas(im)
    art = image_layer("img_0", 2,
                      pos=[W / 2, my + im.height * 0.96, 0],
                      anchor=[im.width / 2, im.height * 0.96, 0],
                      scale=breath_scale(op, 180, 0.4, 1.0), op=op)
    sparkles = shape_layer("trail_sparks", [
        sparkle([mx + im.width * 0.55, my + im.height * 0.58], 9, [(48, 60)], op),
        sparkle([mx + im.width * 0.72, my + im.height * 0.43], 11, [(156, 60)], op),
        sparkle([mx + im.width * 0.86, my + im.height * 0.28], 10, [(264, 60)], op),
    ], op=op, ind=1)
    comp = composition("history_empty_loop_v1", W, H, op,
                       [img_asset(png, im.width, im.height)],
                       [sparkles, art],
                       markers=[{"tm": 0, "cm": "loop", "dr": op}])
    emit(comp, "history_empty_loop_v1.json")




def build_a7():
    """Gift-open claim reveal (one-shot 2.2s): the open-gift art pops in with
    overshoot, the built-in glow heart blooms, <=12 paw-confetti particles arc
    out and fade, settles to the art's own open pose. Claim success ONLY."""
    op = 132
    im, png, bbox, scale = prep_image(os.path.join(ILL, "growth", "referral_gift_open_v1.png"), 540)
    W, H, mx, my = std_canvas(im)
    pop = anim([(0, [82, 82, 100]), (16, [105, 105, 100]),
                (28, [98.5, 98.5, 100]), (40, [100, 100, 100]),
                (op, [100, 100, 100])], 3)
    art = {"ddd": 0, "ind": 2, "ty": 2, "nm": "gift", "refId": "img_0", "sr": 1,
           "ks": {"o": anim([(0, [0]), (8, [100]), (op, [100])], 1),
                  "r": static(0),
                  "p": static([W / 2, my + im.height * 0.96, 0]),
                  "a": static([im.width / 2, im.height * 0.96, 0]),
                  "s": pop},
           "ao": 0, "ip": 0, "op": op, "st": 0, "bm": 0}

    # reward glow bloom over the art's heart region (upper center-right)
    hx, hy = W * 0.60, H * 0.30
    glow = shape_layer("glow", [group(
        [ellipse([im.width * 0.5, im.width * 0.5]), fill([1.0, 0.92, 0.70])],
        pos=[hx, hy],
        scale=anim([(0, [60, 60]), (54, [128, 128]), (op, [108, 108])], 2),
        opacity=anim([(0, [0]), (22, [42]), (66, [16]), (op, [10])], 1))],
        op=op, ind=3)

    # paw confetti: 10 particles (<=12 budget), arcs out, gone by ~1.9s
    import math
    particles = []
    palette = [SPARK, [1.0, 0.66, 0.48], MINT, [1.0, 0.92, 0.70]]
    for i in range(10):
        ang = math.radians(250 + i * 24 + (7 * i) % 11)
        dist = im.width * (0.30 + 0.05 * (i % 3))
        x0, y0 = W / 2, H * 0.46
        x1 = x0 + dist * math.cos(ang) * 1.1
        y1 = y0 + dist * math.sin(ang) - im.width * 0.10
        y2 = y1 + im.width * 0.16
        t0, tm, t1 = 10, 60, 112
        particles.append(group(
            [star(7 + (i % 3) * 2, 3 + (i % 3)), fill(palette[i % 4])],
            pos=anim([(t0, [x0, y0]), (tm, [x1, y1]), (t1, [x1 + 6, y2])], 2),
            rotation=anim([(t0, [0]), (t1, [120 + 30 * (i % 4)])], 1),
            opacity=anim([(0, [0]), (t0, [0]), (t0 + 6, [95]),
                          (tm + 24, [70]), (t1, [0]), (op, [0])], 1),
            name=f"paw{i}"))
    confetti = shape_layer("confetti", particles, op=op, ind=1)

    comp = composition("referral_gift_open_v1", W, H, op,
                       [img_asset(png, im.width, im.height)],
                       [confetti, art, glow])
    emit(comp, "referral_gift_open_v1.json")


def build_a8():
    """Welcome-to-Premium (one-shot 2.5s): the sleeper rises and stretches
    (raster art keeps eyes closed — the wake reads through the rise), six
    sparkles, warm glow bloom, settles content. No confetti cannon."""
    op = 150
    im, png, bbox, scale = prep_image(os.path.join(ILL, "monetization", "paywall_peace_of_mind_v1.png"), 540)
    W, H, mx, my = std_canvas(im)
    base_y = my + im.height * 0.96
    art = {"ddd": 0, "ind": 2, "ty": 2, "nm": "sleeper", "refId": "img_0", "sr": 1,
           "ks": {"o": anim([(0, [0]), (10, [100]), (op, [100])], 1),
                  "r": static(0),
                  "p": anim([(0, [W / 2, base_y + 6, 0]), (42, [W / 2, base_y - 9, 0]),
                             (96, [W / 2, base_y - 4, 0]), (op, [W / 2, base_y - 4, 0])], 3),
                  "a": static([im.width / 2, im.height * 0.96, 0]),
                  "s": anim([(0, [100, 100, 100]), (45, [102.5, 106, 100]),
                             (90, [100.5, 100.5, 100]), (op, [100.5, 100.5, 100])], 3)},
           "ao": 0, "ip": 0, "op": op, "st": 0, "bm": 0}
    glow = shape_layer("glow", [group(
        [ellipse([im.width * 0.9, im.height * 0.62]), fill([1.0, 0.95, 0.78])],
        pos=[W / 2, my + im.height * 0.55],
        opacity=anim([(0, [0]), (40, [30]), (110, [12]), (op, [12])], 1))],
        op=op, ind=3)
    sparkles = shape_layer("sparkles", [
        sparkle([W * (0.18 + 0.13 * i), H * (0.20 + 0.07 * (i % 3))], 9 + (i % 3) * 2,
                [(14 + i * 14, 52)], op)
        for i in range(6)
    ], op=op, ind=1)
    comp = composition("premium_welcome_v1", W, H, op,
                       [img_asset(png, im.width, im.height)],
                       [sparkles, art, glow])
    emit(comp, "premium_welcome_v1.json")


def build_a9():
    """Error 'nap' loop (M4 matrix #20, 6s): the error-pet breathes gently with
    one ear-twitch-substitute sparkle; muted register — calm, never playful."""
    op = 360
    im, png, bbox, scale = prep_image(os.path.join(ILL, "system", "system_error_calm_v1.png"), 540)
    W, H, mx, my = std_canvas(im)
    art = image_layer("img_0", 2,
                      pos=[W / 2, my + im.height * 0.96, 0],
                      anchor=[im.width / 2, im.height * 0.96, 0],
                      scale=breath_scale(op, 180, 0.4, 1.0), op=op)
    sparkles = shape_layer("sparkles", [
        sparkle([W * 0.30, H * 0.30], 8, [(96, 54)], op),
        sparkle([W * 0.72, H * 0.26], 9, [(258, 54)], op),
    ], op=op, ind=1)
    comp = composition("error_nap_loop_v1", W, H, op,
                       [img_asset(png, im.width, im.height)],
                       [sparkles, art],
                       markers=[{"tm": 0, "cm": "loop", "dr": op}])
    emit(comp, "error_nap_loop_v1.json")


if __name__ == "__main__":
    print("Building Lottie assets -> mobile/assets/motion/")
    build_a1()
    build_a2()
    build_a3()
    build_a4()
    build_a5()
    build_a6()
    build_history()
    build_a7()
    build_a8()
    build_a9()
    print("done.")
    sys.exit(0)
