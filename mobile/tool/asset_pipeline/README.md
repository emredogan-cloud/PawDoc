# Phase 0 asset pipeline

Turns the generated art plates into production assets.

The generator delivered 110 PNG "plates" saved under the spec's *unexpanded*
filename placeholders — `ic-symptom-<name>.svg.png`, `mem-buddy-{01..24}@3x.webp.png`
— where each file is a contact sheet holding the whole set. This pipeline slices
them into the 291 individually-named files under `assets/`, lifts each one off
its backdrop, and re-encodes to the format the spec asks for.

## Running

```bash
cd mobile/assets
python3 -m venv /tmp/venv && /tmp/venv/bin/pip install numpy Pillow
/tmp/venv/bin/python ../tool/asset_pipeline/build.py plates.txt   # writes _out/
```

`plates.txt` is the list of plate paths relative to `assets/`. Output lands in
`assets/_out/` for review; nothing is overwritten in place.

The source plates live in `assets/_plates/` (gitignored, ~150 MB). They are the
only copy — the pipeline is not reproducible without them.

## Why it is not a one-liner

- **Slicing.** Icon plates have gutters, so cells are found by recursive
  projection-profile splitting. Photo mosaics are edge-to-edge and need an
  explicit grid; two of them are not evenly divided and use measured fractions.
- **Backdrop removal has four modes,** because a single white key is wrong for
  most of the set: it erases the white cloud inside a weather icon and the white
  pictogram inside a first-aid tile. `flood` removes only white connected to the
  border; `key` keeps hue for coloured outline glyphs; `white` is used for
  monochrome line art (whose interiors *should* drop out, so they stay tintable);
  `dark` un-composites neon art off black.
- **Resizing is premultiplied.** Cut-outs carry garbage colour beneath alpha=0,
  which a naive downscale samples into a coloured halo.
- **Some plates were defective:** four had the transparency checkerboard rendered
  as pixels, and the memory grid had `01`–`24` burned into every tile.

See `manifest.py` for the per-plate decisions and `UI_IMPLEMENTATION_ROADMAP.md`
for what remains a gap.
