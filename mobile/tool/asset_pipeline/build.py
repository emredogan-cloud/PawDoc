#!/usr/bin/env python3
"""
Phase 0 driver — turn the generated plates into production assets.

Run from mobile/assets. Writes into `_out/` so nothing is destroyed until the
result has been reviewed.
"""
from __future__ import annotations
import json, os, re, sys, shutil
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slicer import (content_mask, detect_bg, cells, white_to_alpha,
                    dark_to_alpha, flood_to_alpha, colour_key_to_alpha,
                    strip_checkerboard)
import manifest as M

OUT = "_out"
report = {"sliced": [], "single": [], "skipped": [], "gaps": []}


# --------------------------------------------------------------------------
def bleed(im: Image.Image, iters: int = 12) -> Image.Image:
    """
    Push opaque RGB outward into transparent pixels.

    Generated cut-outs carry garbage colour (magenta, red) beneath alpha=0.
    Downscaling samples those pixels and produces a coloured halo, so the
    colour has to be extended before any resize.
    """
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    rgb, al = a[..., :3].copy(), a[..., 3].copy()
    known = al > 8
    if known.all() or not known.any():
        return im
    for _ in range(iters):
        if known.all():
            break
        k = known.astype(np.float32)
        acc = np.zeros_like(rgb)
        cnt = np.zeros_like(k)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            acc += np.roll(rgb * k[..., None], (dy, dx), (0, 1))
            cnt += np.roll(k, (dy, dx), (0, 1))
        fill = (~known) & (cnt > 0)
        rgb[fill] = (acc[fill] / cnt[fill][..., None])
        known |= fill
    out = np.dstack([rgb, al]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def resize_pm(im: Image.Image, size) -> Image.Image:
    """Resize in premultiplied space so edges never darken or fringe."""
    im = bleed(im)
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255.0
    pm = np.dstack([a[..., :3] * a[..., 3:4], a[..., 3:4]])
    r = Image.fromarray((pm * 255).astype(np.uint8), "RGBA").resize(size, Image.LANCZOS)
    b = np.asarray(r).astype(np.float32) / 255.0
    al = b[..., 3:4]
    rgb = np.divide(b[..., :3], al, out=np.zeros_like(b[..., :3]), where=al > 0)
    return Image.fromarray(
        (np.dstack([np.clip(rgb, 0, 1), al]) * 255).astype(np.uint8), "RGBA")


def square(im: Image.Image, pad=0.06) -> Image.Image:
    w, h = im.size
    s = int(max(w, h) * (1 + pad * 2))
    c = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    c.paste(im, ((s - w) // 2, (s - h) // 2))
    return c


def grid_boxes(w: int, h: int, rows: list[int]) -> list[tuple]:
    """Uniform grid; `rows` gives the column count of each row."""
    out, rh = [], h / len(rows)
    for ri, ncol in enumerate(rows):
        cw = w / ncol
        for ci in range(ncol):
            out.append((int(ci * cw), int(ri * rh), int((ci + 1) * cw), int((ri + 1) * rh)))
    return out


def frac_boxes(w: int, h: int, spec: list) -> list[tuple]:
    """
    Boxes from measured fractions: [(y0, y1, [x0, x1, ...]), ...].

    Needed where a mosaic is not evenly divided — the photo-quality plate puts
    its hero on the top 56% and two thumbnails below, so an even split slices
    through both.
    """
    out = []
    for y0, y1, xs in spec:
        for i in range(len(xs) - 1):
            out.append((int(xs[i] * w), int(y0 * h), int(xs[i + 1] * w), int(y1 * h)))
    return out


def content_square(im: Image.Image, dark_bg=True) -> Image.Image:
    """Centre-crop a tall/wide cell to a square around its actual subject."""
    a = np.asarray(im.convert("RGB")).astype(int)
    mask = a.max(axis=2) > 30 if dark_bg else a.min(axis=2) < 225
    ys, xs = np.where(mask)
    if len(ys) == 0:
        return im
    cy = ys.min() + int((ys.max() - ys.min()) * 0.30)
    cx = (xs.min() + xs.max()) // 2
    s = min(im.size)
    x0 = max(0, min(im.size[0] - s, cx - s // 2))
    y0 = max(0, min(im.size[1] - s, cy - s // 2))
    return im.crop((x0, y0, x0 + s, y0 + s))


def save(im: Image.Image, rel: str, fmt: str):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if fmt == "webp":
        # WEBP carries alpha. convert("RGB") silently flattened every cut-out
        # onto black — invisible until one was placed on a light-ish canvas.
        a = np.asarray(im.convert("RGBA"))[..., 3]
        mode = "RGBA" if a.min() < 250 else "RGB"
        im.convert(mode).save(p, "WEBP", quality=90, method=6)
    else:
        im.save(p, "PNG", optimize=True)
    return p, os.path.getsize(p)


# --------------------------------------------------------------------------
def do_sheet(plate: str, cfg: dict):
    im = Image.open(plate)
    if cfg.get("checkerboard"):
        im = strip_checkerboard(im)
    W, H = im.size
    names = cfg["names"]

    if cfg["mode"] == "grid":
        boxes = grid_boxes(W, H, cfg["rows"])
    elif cfg["mode"] == "frac":
        boxes = frac_boxes(W, H, cfg["frac"])
    else:
        boxes = cells(content_mask(im, detect_bg(im)), len(names))

    if len(boxes) < len(names):
        report["gaps"].append(
            f"{plate}: expected {len(names)} cells, detected {len(boxes)} "
            f"— produced {len(boxes)}, missing {names[len(boxes):]}")
    n = min(len(boxes), len(names))

    for i in range(n):
        x0, y0, x1, y1 = boxes[i]
        if cfg.get("inset"):                       # crop burned-in tile labels
            # asymmetric: the generator burned "01".."24" into the top-left of
            # every tile, and row 2 sits lower than the rest, so the top edge
            # needs a deeper cut than the other three.
            top, side = cfg["inset"] if isinstance(cfg["inset"], tuple) \
                else (cfg["inset"], cfg["inset"])
            dw = int((x1 - x0) * side)
            dt = int((y1 - y0) * top)
            db = int((y1 - y0) * side)
            x0, y0, x1, y1 = x0 + dw, y0 + dt, x1 - dw, y1 - db
        cell = im.crop((x0, y0, x1, y1))
        if cfg.get("content_square"):
            cell = content_square(cell)

        bg = cfg["bg"]
        if bg == "white":
            cell = white_to_alpha(cell)
        elif bg == "flood":
            cell = flood_to_alpha(cell)
        elif bg == "key":
            cell = colour_key_to_alpha(cell)
        elif bg == "dark" and not cfg.get("keep_bg"):
            cell = dark_to_alpha(cell)
        else:
            cell = cell.convert("RGBA")

        if bg in ("white", "dark", "flood", "key") and not cfg.get("keep_bg"):
            bb = cell.getbbox()
            if bb:
                cell = cell.crop(bb)

        size = cfg.get("size")
        if size:
            if cfg.get("square", True):
                cell = square(cell)
                cell = resize_pm(cell, (size, size))
            else:
                w, h = cell.size
                cell = resize_pm(cell, (size, max(1, int(h * size / w))))

        if cfg.get("mono"):                        # normalise to pure black + alpha
            a = np.asarray(cell).copy()
            a[..., :3] = 0
            cell = Image.fromarray(a, "RGBA")

        rel = cfg["out"].format(names[i])
        p, sz = save(cell, rel, cfg["fmt"])
        report["sliced"].append({"plate": plate, "out": rel, "bytes": sz})


def do_single(plate: str):
    """Plate holds exactly one asset; its name is the spec filename + '.png'."""
    rel = plate
    while rel.endswith(".png"):
        rel = rel[:-4]
    rel = re.split(r"\s*\+\s*|,\s*", rel)[0].strip()

    ext = os.path.splitext(rel)[1].lower()
    if ext == ".svg":                              # raster cannot satisfy an SVG spec
        rel = rel[:-4] + ".png"
        report["gaps"].append(f"{plate}: spec wants SVG; only raster exists -> {rel}")
        ext = ".png"
    elif ext not in (".png", ".webp"):
        rel += ".png"
        ext = ".png"

    im = Image.open(plate).convert("RGBA")
    _pre = im
    if plate in M.CHECKERBOARD:
        im = strip_checkerboard(im)
    if plate in M.SINGLE_FIX:
        kind, floor = M.SINGLE_FIX[plate]
        if kind == "dark":
            im = dark_to_alpha(im, floor)
            bb = im.getbbox()
            if bb:
                im = im.crop(bb)
    edge, forced = M.policy_for(rel)
    has_alpha = np.asarray(im)[..., 3].min() < 250
    fmt = forced or ("webp" if ext == ".webp" else "png")
    if fmt == "png" and not has_alpha:
        fmt = "webp"                                # nothing to preserve
    if fmt == "webp":
        rel = os.path.splitext(rel)[0] + ".webp"
    else:
        rel = os.path.splitext(rel)[0] + ".png"

    if fmt == "png":
        im = bleed(im)
    if max(im.size) > edge:
        w, h = im.size
        k = edge / max(w, h)
        im = resize_pm(im, (max(1, round(w * k)), max(1, round(h * k))))
    p, sz = save(im, rel, fmt)
    report["single"].append({"plate": plate, "out": rel, "bytes": sz})


# --------------------------------------------------------------------------
def main():
    plates = [l.strip() for l in open(sys.argv[1]) if l.strip()]
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    for p in sorted(plates):
        if p in M.OVERLAPPING:
            report["skipped"].append({"plate": p, "why": M.OVERLAPPING[p]})
            continue
        if p in M.UNSALVAGEABLE:
            report["skipped"].append({"plate": p, "why": M.UNSALVAGEABLE[p]})
            continue
        try:
            if p in M.PLATES:
                do_sheet(p, M.PLATES[p])
            else:
                do_single(p)
        except Exception as e:
            report["skipped"].append({"plate": p, "why": f"{type(e).__name__}: {e}"})

    json.dump(report, open("_out/_report.json", "w"), indent=1)
    tb = sum(r["bytes"] for r in report["sliced"] + report["single"])
    print(f"sliced   : {len(report['sliced']):4d} files")
    print(f"single   : {len(report['single']):4d} files")
    print(f"skipped  : {len(report['skipped']):4d} plates")
    print(f"gaps     : {len(report['gaps']):4d}")
    print(f"total out: {len(report['sliced'])+len(report['single'])} files, {tb/1e6:.1f} MB")
    for g in report["gaps"]:
        print("  GAP:", g)
    for s in report["skipped"]:
        print("  SKIP:", s["plate"][:60], "|", s["why"][:70])


if __name__ == "__main__":
    main()
