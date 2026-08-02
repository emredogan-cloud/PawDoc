"""
PawDoc Phase 0 — asset plate slicer.

The generated plates are AI "contact sheets": one PNG holding N production
assets, saved under the spec's *unexpanded* filename placeholder. This module
splits a plate into its cells using recursive projection-profile splitting,
which handles both regular grids (4x2 icon sets) and irregular layouts
(1 big + 2 small) without a hand-authored geometry per plate.
"""
from __future__ import annotations
import numpy as np
from PIL import Image


# --------------------------------------------------------------------------
# content masks
# --------------------------------------------------------------------------
def content_mask(im: Image.Image, bg: str) -> np.ndarray:
    """Boolean mask of 'this pixel is asset, not background'."""
    a = np.asarray(im.convert("RGBA")).astype(np.int16)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    if bg == "alpha":
        return al > 24
    if bg == "white":
        # distance from white in the darkest channel
        return (255 - np.minimum(np.minimum(r, g), b)) > 18
    if bg == "black":
        return np.maximum(np.maximum(r, g), b) > 26
    raise ValueError(bg)


def detect_bg(im: Image.Image) -> str:
    """Guess the plate background from its border pixels."""
    a = np.asarray(im.convert("RGBA"))
    if a.shape[2] == 4 and a[..., 3].min() < 200:
        # a real alpha channel that is actually used
        border = np.concatenate([a[0, :, 3], a[-1, :, 3], a[:, 0, 3], a[:, -1, 3]])
        if border.mean() < 128:
            return "alpha"
    rgb = a[..., :3]
    border = np.concatenate([rgb[0, :], rgb[-1, :], rgb[:, 0], rgb[:, -1]])
    return "white" if border.mean() > 140 else "black"


# --------------------------------------------------------------------------
# recursive projection splitting
# --------------------------------------------------------------------------
def _bands(profile: np.ndarray, min_gap: int, thresh: float) -> list[tuple[int, int]]:
    """Contiguous runs where the profile exceeds `thresh`, merging small gaps."""
    on = profile > thresh
    runs, start = [], None
    for i, v in enumerate(on):
        if v and start is None:
            start = i
        elif not v and start is not None:
            runs.append((start, i))
            start = None
    if start is not None:
        runs.append((start, len(on)))
    if not runs:
        return []
    merged = [list(runs[0])]
    for s, e in runs[1:]:
        if s - merged[-1][1] < min_gap:
            merged[-1][1] = e
        else:
            merged.append([s, e])
    return [(s, e) for s, e in merged]


def split(mask: np.ndarray, axis: int, min_gap_frac=0.012, thresh_frac=0.002):
    """Split a mask along `axis` (0=rows, 1=cols) into content bands."""
    profile = mask.sum(axis=1 - axis).astype(float)
    span = mask.shape[1 - axis]
    return _bands(
        profile,
        max(4, int(mask.shape[axis] * min_gap_frac)),
        max(0.5, span * thresh_frac),
    )


def cells(mask: np.ndarray, expect: int | None = None) -> list[tuple[int, int, int, int]]:
    """
    Return (x0, y0, x1, y1) boxes, reading order.

    Rows first, then columns inside each row — so a layout of one wide hero
    above two thumbnails splits correctly, which a fixed grid cannot do.
    """
    out = []
    rows = split(mask, 0)
    for y0, y1 in rows:
        band = mask[y0:y1, :]
        for x0, x1 in split(band, 1):
            sub = band[:, x0:x1]
            ys = np.where(sub.any(axis=1))[0]
            xs = np.where(sub.any(axis=0))[0]
            if len(ys) == 0 or len(xs) == 0:
                continue
            out.append((x0 + xs[0], y0 + ys[0], x0 + xs[-1] + 1, y0 + ys[-1] + 1))
    if expect is not None and len(out) != expect:
        # one retry with a coarser gap tolerance before giving up
        for gap in (0.02, 0.03, 0.045, 0.008, 0.006):
            alt = []
            for y0, y1 in split(mask, 0, gap):
                band = mask[y0:y1, :]
                for x0, x1 in split(band, 1, gap):
                    sub = band[:, x0:x1]
                    ys = np.where(sub.any(axis=1))[0]
                    xs = np.where(sub.any(axis=0))[0]
                    if len(ys) and len(xs):
                        alt.append((x0 + xs[0], y0 + ys[0], x0 + xs[-1] + 1, y0 + ys[-1] + 1))
            if len(alt) == expect:
                return alt
    return out


# --------------------------------------------------------------------------
# background -> alpha
# --------------------------------------------------------------------------
def white_to_alpha(im: Image.Image) -> Image.Image:
    """
    Un-composite art that was rendered onto white.

    alpha = distance from white; colour is then un-premultiplied so a black
    1.5 px stroke stays black at the core and fades cleanly at the edge
    instead of turning grey.
    """
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    alpha = 255.0 - a.min(axis=2)
    nz = alpha > 0
    out = np.zeros(a.shape[:2] + (4,), np.float32)
    for c in range(3):
        ch = np.zeros_like(alpha)
        ch[nz] = 255.0 - (255.0 - a[..., c][nz]) * 255.0 / alpha[nz]
        out[..., c] = np.clip(ch, 0, 255)
    out[..., 3] = np.clip(alpha, 0, 255)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def strip_checkerboard(im: Image.Image) -> Image.Image:
    """
    Drop a transparency checkerboard that the generator rendered as pixels.

    Four doodle plates came back with the pink/white alpha grid — and in two
    cases a solid red field — baked into RGB. Both are magenta-dominant
    (red and blue well above green), which no asset in this set uses: the
    doodles are neon yellow-green and the line art is neutral dark. Keying on
    that lets the art through untouched.
    """
    a = np.asarray(im.convert("RGBA")).astype(np.int16)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    # Two plates back the checkerboard with a solid *pure red* field (g=b=0),
    # so the blue bound has to sit below green rather than above it. The neon
    # art is yellow-green (r <= g) and its orange bloom keeps blue well under
    # green, so neither is caught.
    magenta = (r > g + 38) & (b > g - 30)
    near_white = (np.minimum(np.minimum(r, g), b) > 198)
    drop = magenta | near_white
    out = a.copy()
    out[..., 3] = np.where(drop, 0, al)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def colour_key_to_alpha(im: Image.Image) -> Image.Image:
    """
    Key white out of *coloured outline* art while keeping the hue.

    Outline glyphs (the violet message-action set, the lime achievement icons)
    enclose white that is background, not fill — flood-fill would keep it
    because it is not connected to the border. Alpha therefore comes from
    distance-to-white, normalised so the stroke core reaches fully opaque, and
    RGB is left untouched so violet stays violet instead of being shifted by an
    un-premultiply.
    """
    rgb = np.asarray(im.convert("RGB")).astype(np.float32)
    d = 255.0 - rgb.min(axis=2)
    strong = d[d > 8]
    hi = np.percentile(strong, 99) if strong.size else 255.0
    alpha = np.clip(d / max(1.0, hi), 0, 1) * 255.0
    return Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")


def flood_to_alpha(im: Image.Image, tol: int = 30) -> Image.Image:
    """
    Remove the white backdrop by flood-filling inward from the border.

    A global white key cannot be used on the colour tiles: a white cloud or a
    white pictogram inside a coloured tile is indistinguishable from the
    backdrop by value alone. Only white *connected to the edge* is background.
    Anti-aliasing is preserved by re-applying the soft white key in the
    one-pixel band around the recovered silhouette.
    """
    from PIL import ImageDraw
    rgb = np.asarray(im.convert("RGB")).astype(np.int16)
    near_white = (255 - rgb.min(axis=2)) <= tol
    h, w = near_white.shape

    m = Image.fromarray(np.where(near_white, 255, 0).astype(np.uint8), "L")
    for sx, sy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
                   (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)):
        if m.getpixel((sx, sy)) == 255:
            ImageDraw.floodfill(m, (sx, sy), 128, thresh=0)
    outside = np.asarray(m) == 128

    inside = ~outside
    grown = inside.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        grown |= np.roll(inside, (dy, dx), (0, 1))
    soft = np.clip((255.0 - rgb.min(axis=2)) / max(1, tol), 0, 1)
    alpha = np.where(inside, 1.0, np.where(grown, soft, 0.0)) * 255.0

    out = np.dstack([rgb.astype(np.float32), alpha]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def dark_to_alpha(im: Image.Image, floor: int = 14) -> Image.Image:
    """Un-composite glow art rendered onto black (keeps the bloom falloff)."""
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    alpha = a.max(axis=2)
    alpha = np.clip((alpha - floor) * (255.0 / max(1, 255 - floor)), 0, 255)
    nz = alpha > 0
    out = np.zeros(a.shape[:2] + (4,), np.float32)
    for c in range(3):
        ch = np.zeros_like(alpha)
        ch[nz] = np.clip(a[..., c][nz] * 255.0 / alpha[nz], 0, 255)
        out[..., c] = ch
    out[..., 3] = alpha
    return Image.fromarray(out.astype(np.uint8), "RGBA")


# --------------------------------------------------------------------------
# finishing
# --------------------------------------------------------------------------
def square_pad(im: Image.Image, pad_frac: float = 0.06) -> Image.Image:
    """Centre on a transparent square canvas with a consistent optical margin."""
    w, h = im.size
    side = int(max(w, h) * (1 + pad_frac * 2))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - w) // 2, (side - h) // 2), im if im.mode == "RGBA" else None)
    return canvas


def fit(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.LANCZOS)
