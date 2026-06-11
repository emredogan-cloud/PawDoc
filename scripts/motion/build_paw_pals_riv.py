#!/usr/bin/env python3
"""Paw Pals .riv builder (M2 flagship — PAWDOC_MOTION_ROADMAP.md A10/matrix #9).

Authors assets/motion/paw_pals_v1.riv programmatically: 7 species artboards
(dog cat rabbit guinea_pig bird reptile other) @256x256, each with the shared
state machine design `pal` (inputs tap/happy/sleepy/attentive; states
idle/tilt/happyBeat/attentive/sleep — blink lives inside idle as an eye-scale
beat with a per-species cycle length so lists never blink in sync).

Format ground truth: the rive-0.13.20 runtime parser (pure-Dart renderer).
Binary layout: RIVE magic, varuint major(7)/minor(0)/fileId, empty ToC, then a
flat object stream (typeKey, then propertyKey/value pairs, 0-terminated) whose
ordering drives the runtime importer stack:
  Backboard | per artboard: Artboard, components (ids = insertion order,
  artboard=0), interpolators, LinearAnimations (KeyedObject->KeyedProperty->
  KeyFrames), StateMachine, inputs, Layer, states (stateToId = in-layer index),
  transitions (attach to the latest state), conditions (inputId = input index).

Budget: whole file <=300KB (enforced here + in mobile tests).
"""
import os
import struct
import sys

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "mobile", "assets", "motion", "paw_pals_v1.riv")

# ---- palette (matches the species icon set fixed in M0/F-5) ----
DEEP = 0xFF007479    # outline teal
TEAL = 0xFF00A1A3    # body teal
MINT = 0xFFA9E8DE
CREAM = 0xFFFFFDEF
INK = 0xFF063F44     # eyes
CORAL = 0xFFFF8A65
BLUSH = 0xFFFFAB8F
WHITE = 0xFFFFFFFF

FPS = 60


class W:
    def __init__(self):
        self.b = bytearray()

    def u8(self, v): self.b.append(v & 0xFF)

    def varuint(self, v):
        while True:
            byte = v & 0x7F
            v >>= 7
            if v:
                self.b.append(byte | 0x80)
            else:
                self.b.append(byte)
                return

    def f32(self, v): self.b += struct.pack('<f', float(v))

    def u32(self, v): self.b += struct.pack('<I', v & 0xFFFFFFFF)

    def string(self, s):
        raw = s.encode('utf-8')
        self.varuint(len(raw))
        self.b += raw


# property encoders by field type
def enc(w, ftype, value):
    if ftype == 'uint':
        w.varuint(int(value))
    elif ftype == 'double':
        w.f32(value)
    elif ftype == 'color':
        w.u32(value)
    elif ftype == 'string':
        w.string(value)
    elif ftype == 'bool':
        w.u8(1 if value else 0)
    else:
        raise ValueError(ftype)


# (propertyKey, fieldType) — extracted from rive-0.13.20 generated sources
P = {
    'name': (4, 'string'), 'parentId': (5, 'uint'),
    'width': (7, 'double'), 'height': (8, 'double'), 'clip': (196, 'bool'),
    'x': (13, 'double'), 'y': (14, 'double'),
    'rotation': (15, 'double'), 'scaleX': (16, 'double'), 'scaleY': (17, 'double'),
    'opacity': (18, 'double'),
    'pw': (20, 'double'), 'ph': (21, 'double'),  # ParametricPath width/height
    'blendMode': (23, 'uint'),
    'vx': (24, 'double'), 'vy': (25, 'double'), 'vradius': (26, 'double'),
    'isClosed': (32, 'bool'),
    'colorValue': (37, 'color'),
    'thickness': (47, 'double'),
    'objectId': (51, 'uint'), 'propertyKey': (53, 'uint'),
    'animName': (55, 'string'), 'fps': (56, 'uint'), 'duration': (57, 'uint'),
    'loopValue': (59, 'uint'),
    'ix1': (63, 'double'), 'iy1': (64, 'double'), 'ix2': (65, 'double'), 'iy2': (66, 'double'),
    'frame': (67, 'uint'), 'interpType': (68, 'uint'), 'interpId': (69, 'uint'),
    'kfValue': (70, 'double'),
    'smName': (138, 'string'), 'boolValue': (141, 'bool'),
    'animationId': (149, 'uint'), 'stateToId': (151, 'uint'),
    'tflags': (152, 'uint'), 'inputId': (155, 'uint'), 'opValue': (156, 'uint'),
    'tduration': (158, 'uint'), 'exitTime': (160, 'uint'),
    'cornerTL': (31, 'double'),
}

# typeKeys
T = {
    'Backboard': 23, 'Artboard': 1, 'Node': 2, 'Shape': 3, 'Ellipse': 4,
    'Rectangle': 7, 'PointsPath': 16, 'StraightVertex': 5,
    'SolidColor': 18, 'Fill': 20, 'Stroke': 24,
    'LinearAnimation': 31, 'KeyedObject': 25, 'KeyedProperty': 26,
    'KeyFrameDouble': 30, 'CubicEaseInterpolator': 28,
    'StateMachine': 53, 'StateMachineLayer': 57, 'AnimationState': 61,
    'EntryState': 63, 'AnyState': 62, 'ExitState': 64, 'StateTransition': 65,
    'StateMachineTrigger': 58, 'StateMachineBool': 59,
    'TransitionTriggerCondition': 68, 'TransitionBoolCondition': 71,
}

# transition flags
FLAG_EXIT_TIME = 1 << 2
FLAG_EXIT_PCT = 1 << 3


def obj(w, type_name, **props):
    w.varuint(T[type_name])
    for k, v in props.items():
        key, ftype = P[k]
        w.varuint(key)
        enc(w, ftype, v)
    w.varuint(0)


class ArtboardBuilder:
    """Tracks artboard-local ids (insertion order; artboard itself = 0)."""

    def __init__(self, w, name):
        self.w = w
        self.next_id = 0
        self.anim_count = 0
        obj(w, 'Artboard', name=name, width=256.0, height=256.0, clip=True)
        self.id_artboard = self.alloc()

    def alloc(self):
        i = self.next_id
        self.next_id += 1
        return i

    # -- components ---------------------------------------------------------
    def node(self, parent, x=0.0, y=0.0, name='n'):
        obj(self.w, 'Node', name=name, parentId=parent, x=x, y=y)
        return self.alloc()

    def shape(self, parent, x, y, name='s', rotation=None, opacity=None,
              scaleX=None, scaleY=None):
        props = dict(name=name, parentId=parent, x=x, y=y, blendMode=3)
        if rotation is not None:
            props['rotation'] = rotation
        if opacity is not None:
            props['opacity'] = opacity
        if scaleX is not None:
            props['scaleX'] = scaleX
        if scaleY is not None:
            props['scaleY'] = scaleY
        obj(self.w, 'Shape', **props)
        return self.alloc()

    def ellipse(self, parent, w_, h_):
        obj(self.w, 'Ellipse', parentId=parent, pw=w_, ph=h_)
        return self.alloc()

    def rect(self, parent, w_, h_, radius=0.0):
        obj(self.w, 'Rectangle', parentId=parent, pw=w_, ph=h_, cornerTL=radius)
        return self.alloc()

    def triangle(self, parent, pts, radius=10.0):
        obj(self.w, 'PointsPath', parentId=parent, isClosed=True)
        pid = self.alloc()
        for (px, py) in pts:
            obj(self.w, 'StraightVertex', parentId=pid, vx=px, vy=py,
                vradius=radius)
            self.alloc()
        return pid

    def fill(self, parent, color):
        obj(self.w, 'Fill', parentId=parent)
        fid = self.alloc()
        obj(self.w, 'SolidColor', parentId=fid, colorValue=color)
        self.alloc()
        return fid

    def stroke(self, parent, color, thickness):
        obj(self.w, 'Stroke', parentId=parent, thickness=thickness)
        sid = self.alloc()
        obj(self.w, 'SolidColor', parentId=sid, colorValue=color)
        self.alloc()
        return sid

    def interpolator(self, x1, y1, x2, y2):
        obj(self.w, 'CubicEaseInterpolator', ix1=x1, iy1=y1, ix2=x2, iy2=y2)
        return self.alloc()

    # -- animation ----------------------------------------------------------
    def animation(self, name, duration, loop, tracks):
        """tracks: {target_id: {property_name: [(frame, value), ...]}}"""
        obj(self.w, 'LinearAnimation', animName=name, fps=FPS,
            duration=duration, loopValue=loop)
        self.alloc()
        idx = self.anim_count
        self.anim_count += 1
        for target, props in tracks.items():
            obj(self.w, 'KeyedObject', objectId=target)
            self.alloc()
            for prop, kfs in props.items():
                obj(self.w, 'KeyedProperty', propertyKey=P[prop][0])
                self.alloc()
                for (frame, value) in kfs:
                    obj(self.w, 'KeyFrameDouble', frame=frame, kfValue=value,
                        interpType=2, interpId=self.ease)
                    self.alloc()
        return idx

    # -- state machine ------------------------------------------------------
    def state_machine(self, anim_ids):
        """anim_ids: dict name->animation index. Returns nothing; emits the
        full `pal` machine. Input order: tap, happy, sleepy, attentive."""
        w = self.w
        obj(w, 'StateMachine', animName='pal')
        self.alloc()
        for trig in ('tap', 'happy'):
            obj(w, 'StateMachineTrigger', smName=trig)
            self.alloc()
        obj(w, 'StateMachineBool', smName='sleepy', boolValue=False)
        self.alloc()
        obj(w, 'StateMachineTrigger', smName='attentive')
        self.alloc()
        IN_TAP, IN_HAPPY, IN_SLEEPY, IN_ATTENTIVE = 0, 1, 2, 3

        obj(w, 'StateMachineLayer', smName='main')
        self.alloc()

        # State emission order defines stateToId indices:
        # 0 Entry, 1 idle, 2 tilt, 3 happy, 4 attentive, 5 sleep
        S_IDLE, S_TILT, S_HAPPY, S_ATTENTIVE, S_SLEEP = 1, 2, 3, 4, 5

        def state(anim_name):
            obj(w, 'AnimationState', animationId=anim_ids[anim_name])
            self.alloc()

        def transition(to, flags=0, duration=0, exit_time=0, conditions=()):
            obj(w, 'StateTransition', stateToId=to, tflags=flags,
                tduration=duration, exitTime=exit_time)
            self.alloc()
            for (ctype, input_id, op) in conditions:
                if ctype == 'trigger':
                    obj(w, 'TransitionTriggerCondition', inputId=input_id)
                else:
                    obj(w, 'TransitionBoolCondition', inputId=input_id,
                        opValue=op)
                self.alloc()

        # Entry -> idle (immediate)
        obj(w, 'EntryState')
        self.alloc()
        transition(S_IDLE)

        back = dict(flags=FLAG_EXIT_TIME | FLAG_EXIT_PCT, exit_time=100,
                    duration=120)

        # idle + its outgoing transitions
        state('idle')
        transition(S_TILT, duration=80, conditions=[('trigger', IN_TAP, 0)])
        transition(S_HAPPY, duration=80, conditions=[('trigger', IN_HAPPY, 0)])
        transition(S_ATTENTIVE, duration=80,
                   conditions=[('trigger', IN_ATTENTIVE, 0)])
        transition(S_SLEEP, duration=300,
                   conditions=[('bool', IN_SLEEPY, 0)])  # equal -> true

        state('tilt')
        transition(S_IDLE, **back)
        state('happy')
        transition(S_IDLE, **back)
        state('attentive')
        transition(S_IDLE, **back)
        state('sleep')
        transition(S_IDLE, duration=300,
                   conditions=[('bool', IN_SLEEPY, 1)])  # notEqual -> false


# ---------------------------------------------------------------------------
# Species face construction. Shared skull: root node at (128,140); breath/
# tilt/bounce key the root; ears/eyes/extras key their own shapes.
# ---------------------------------------------------------------------------
def build_species(ab, spec):
    w = ab.w
    root = ab.node(0, x=128.0, y=140.0, name='root')

    ids = {'root': root}
    deep = spec.get('outline', DEEP)
    body = spec['body']
    stroke_w = 7.0

    # ears / crest behind the head
    for ename, e in spec.get('ears', {}).items():
        s = ab.shape(root, e['x'], e['y'], name=ename,
                     rotation=e.get('rot', 0.0))
        if e['kind'] == 'ellipse':
            ab.ellipse(s, e['w'], e['h'])
        else:
            ab.triangle(s, e['pts'], radius=e.get('radius', 12.0))
        ab.fill(s, e.get('color', body))
        ab.stroke(s, deep, stroke_w)
        ids[ename] = s

    # head
    head = ab.shape(root, 0.0, 0.0, name='head')
    ab.ellipse(head, spec['head_w'], spec['head_h'])
    ab.fill(head, body)
    ab.stroke(head, deep, stroke_w)
    ids['head'] = head

    # muzzle / belly patch
    if 'muzzle' in spec:
        m = spec['muzzle']
        mz = ab.shape(root, m['x'], m['y'], name='muzzle')
        ab.ellipse(mz, m['w'], m['h'])
        ab.fill(mz, m.get('color', CREAM))
        ids['muzzle'] = mz

    # spots (reptile/guinea accents)
    for i, sp in enumerate(spec.get('spots', [])):
        s = ab.shape(root, sp[0], sp[1], name=f'spot{i}')
        ab.ellipse(s, sp[2], sp[2])
        ab.fill(s, MINT)

    # blush
    for bx in (-1, 1):
        b = ab.shape(root, bx * spec.get('blush_dx', 52.0),
                     spec.get('blush_dy', 18.0), name=f'blush{bx}',
                     opacity=0.85)
        ab.ellipse(b, 24.0, 14.0)
        ab.fill(b, BLUSH)

    # eyes (blink = scaleY beat; widen = scale up)
    eye_dx = spec.get('eye_dx', 30.0)
    eye_dy = spec.get('eye_dy', -10.0)
    eye_r = spec.get('eye_r', 13.0)
    for side, sx in (('eyeL', -1), ('eyeR', 1)):
        e = ab.shape(root, sx * eye_dx, eye_dy, name=side)
        ab.ellipse(e, eye_r * 2, eye_r * 2)
        ab.fill(e, INK)
        ids[side] = e
        hl = ab.shape(e, -eye_r * 0.3, -eye_r * 0.35, name=side + 'hl')
        ab.ellipse(hl, eye_r * 0.55, eye_r * 0.55)
        ab.fill(hl, WHITE)

    # nose / beak
    if 'nose' in spec:
        n = spec['nose']
        ns = ab.shape(root, n.get('x', 0.0), n['y'], name='nose')
        if n['kind'] == 'ellipse':
            ab.ellipse(ns, n['w'], n['h'])
        else:
            ab.triangle(ns, n['pts'], radius=n.get('radius', 6.0))
        ab.fill(ns, n.get('color', deep))
        if n.get('stroke'):
            ab.stroke(ns, n['stroke'], 5.0)
        ids['nose'] = ns

    # mouth — gentle smile: open 3-vertex path with a big corner radius on
    # the mid vertex renders as a soft arc (stroke only, no fill)
    if spec.get('mouth', True):
        mw = spec.get('mouth_w', 30.0)
        mo = ab.shape(root, 0.0, spec.get('mouth_dy', 30.0), name='mouth')
        obj(ab.w, 'PointsPath', parentId=mo, isClosed=False)
        pid = ab.alloc()
        for (px, py) in [(-mw / 2, 0.0), (0.0, mw * 0.38), (mw / 2, 0.0)]:
            obj(ab.w, 'StraightVertex', parentId=pid, vx=px, vy=py,
                vradius=mw * 0.5)
            ab.alloc()
        ab.stroke(mo, deep, 5.5)
        ids['mouth'] = mo

    # sleep "z" — hidden by default; only the sleep animation keys it visible
    z = ab.shape(root, 62.0, -64.0, name='z', opacity=0.0)
    ab.rect(z, 18.0, 4.0, radius=2.0)
    zm = ab.shape(z, 0.0, 8.0, name='zmid', rotation=-0.85)
    ab.rect(zm, 18.0, 4.0, radius=2.0)
    zb = ab.shape(z, 0.0, 16.0, name='zbot')
    ab.rect(zb, 18.0, 4.0, radius=2.0)
    ids['z'] = z

    return ids


def build_animations(ab, ids, spec):
    """idle/tilt/happy/attentive/sleep. Cycle length varies per species so
    avatar lists never blink in sync (the 'seeded blink' acceptance)."""
    cyc = spec['idle_frames']          # e.g. 312 = 5.2s
    blink = spec['blink_at']
    root, eyeL, eyeR = ids['root'], ids['eyeL'], ids['eyeR']
    half = cyc // 2

    def blink_track():
        return [(0, 1.0), (blink, 1.0), (blink + 5, 0.08),
                (blink + 9, 0.08), (blink + 14, 1.0), (cyc, 1.0)]

    idle = ab.animation('idle', cyc, 1, {
        root: {'scaleX': [(0, 1.0), (half, 1.018), (cyc, 1.0)],
               'scaleY': [(0, 1.0), (half, 1.035), (cyc, 1.0)]},
        eyeL: {'scaleY': blink_track()},
        eyeR: {'scaleY': blink_track()},
    })

    tilt = ab.animation('tilt', 24, 0, {
        root: {'rotation': [(0, 0.0), (10, 0.21), (17, 0.21), (24, 0.0)]},
    })

    # happy beat — shared bounce + the species part beat
    part = ids.get(spec.get('happy_part', ''), None)
    happy_tracks = {
        root: {'y': [(0, 140.0), (12, 128.0), (26, 142.5), (38, 140.0)]},
    }
    if part is not None:
        happy_tracks[part] = {
            'rotation': [(0, spec.get('part_rot0', 0.0)),
                         (10, spec.get('part_rot0', 0.0) + spec.get('part_beat', 0.35)),
                         (22, spec.get('part_rot0', 0.0) - spec.get('part_beat', 0.35) * 0.4),
                         (38, spec.get('part_rot0', 0.0))]}
    happy = ab.animation('happy', 40, 0, happy_tracks)

    # attentive — eyes widen + slight lift, settles back (500ms)
    attentive = ab.animation('attentive', 30, 0, {
        eyeL: {'scaleX': [(0, 1.0), (8, 1.16), (24, 1.16), (30, 1.0)],
               'scaleY': [(0, 1.0), (8, 1.16), (24, 1.16), (30, 1.0)]},
        eyeR: {'scaleX': [(0, 1.0), (8, 1.16), (24, 1.16), (30, 1.0)],
               'scaleY': [(0, 1.0), (8, 1.16), (24, 1.16), (30, 1.0)]},
        root: {'y': [(0, 140.0), (8, 135.0), (24, 135.0), (30, 140.0)]},
    })

    # sleep — eyes closed, slow deep breath (5s), z fades in/out
    sleep = ab.animation('sleep', 300, 1, {
        eyeL: {'scaleY': [(0, 0.08), (300, 0.08)]},
        eyeR: {'scaleY': [(0, 0.08), (300, 0.08)]},
        root: {'scaleX': [(0, 1.0), (150, 1.03), (300, 1.0)],
               'scaleY': [(0, 1.0), (150, 1.05), (300, 1.0)]},
        ids['z']: {'opacity': [(0, 0.0), (60, 0.85), (220, 0.85), (290, 0.0), (300, 0.0)]},
    })

    return {'idle': idle, 'tilt': tilt, 'happy': happy,
            'attentive': attentive, 'sleep': sleep}


# Per-species look + rhythm. Angles in radians; coords relative to root.
SPECIES = {
    'dog': dict(
        body=CREAM, head_w=150.0, head_h=132.0,
        ears={'earL': dict(kind='ellipse', x=-68.0, y=-44.0, w=52.0, h=86.0,
                           rot=0.45, color=TEAL),
              'earR': dict(kind='ellipse', x=68.0, y=-44.0, w=52.0, h=86.0,
                           rot=-0.45, color=MINT)},
        muzzle=dict(x=0.0, y=22.0, w=78.0, h=56.0),
        nose=dict(kind='ellipse', y=14.0, w=30.0, h=22.0),
        eye_dx=34.0, eye_dy=-12.0, eye_r=13.0, mouth_dy=34.0,
        happy_part='earL', part_rot0=0.45, part_beat=0.4,
        idle_frames=312, blink_at=150,
    ),
    'cat': dict(
        body=TEAL, head_w=146.0, head_h=126.0,
        ears={'earL': dict(kind='tri', x=-52.0, y=-66.0, rot=-0.12,
                           pts=[(-26.0, 28.0), (0.0, -34.0), (26.0, 28.0)],
                           color=TEAL),
              'earR': dict(kind='tri', x=52.0, y=-66.0, rot=0.12,
                           pts=[(-26.0, 28.0), (0.0, -34.0), (26.0, 28.0)],
                           color=TEAL)},
        muzzle=dict(x=0.0, y=24.0, w=70.0, h=48.0, color=CREAM),
        nose=dict(kind='tri', y=12.0,
                  pts=[(-11.0, -6.0), (11.0, -6.0), (0.0, 10.0)],
                  color=CORAL, radius=4.0),
        eye_dx=33.0, eye_dy=-10.0, eye_r=12.0, mouth_dy=32.0,
        happy_part='earR', part_rot0=0.12, part_beat=-0.3,
        idle_frames=366, blink_at=204,
    ),
    'rabbit': dict(
        body=CREAM, head_w=138.0, head_h=124.0,
        ears={'earL': dict(kind='ellipse', x=-34.0, y=-92.0, w=40.0, h=120.0,
                           rot=-0.12, color=CREAM),
              'earR': dict(kind='ellipse', x=34.0, y=-92.0, w=40.0, h=120.0,
                           rot=0.12, color=MINT)},
        nose=dict(kind='tri', y=10.0,
                  pts=[(-9.0, -5.0), (9.0, -5.0), (0.0, 8.0)],
                  color=CORAL, radius=3.0),
        eye_dx=30.0, eye_dy=-8.0, eye_r=12.0, mouth_dy=28.0,
        happy_part='earL', part_rot0=-0.12, part_beat=-0.35,
        idle_frames=282, blink_at=126,
    ),
    'guinea_pig': dict(
        body=CREAM, head_w=156.0, head_h=128.0,
        ears={'earL': dict(kind='ellipse', x=-58.0, y=-56.0, w=42.0, h=38.0,
                           rot=-0.3, color=CORAL),
              'earR': dict(kind='ellipse', x=58.0, y=-56.0, w=42.0, h=38.0,
                           rot=0.3, color=CORAL)},
        nose=dict(kind='ellipse', y=12.0, w=24.0, h=16.0, color=CORAL),
        spots=[(-44.0, -44.0, 26.0), (46.0, -46.0, 22.0)],
        eye_dx=36.0, eye_dy=-14.0, eye_r=12.0, mouth_dy=34.0,
        happy_part='earR', part_rot0=0.3, part_beat=0.45,
        idle_frames=330, blink_at=180,
    ),
    'bird': dict(
        body=TEAL, head_w=140.0, head_h=132.0,
        ears={'crest': dict(kind='ellipse', x=0.0, y=-76.0, w=26.0, h=56.0,
                            rot=0.0, color=MINT),
              'crestL': dict(kind='ellipse', x=-22.0, y=-70.0, w=22.0, h=46.0,
                             rot=-0.5, color=MINT)},
        muzzle=dict(x=0.0, y=30.0, w=88.0, h=52.0, color=CREAM),
        nose=dict(kind='tri', y=4.0,
                  pts=[(-16.0, -8.0), (16.0, -8.0), (0.0, 18.0)],
                  color=CORAL, radius=5.0, stroke=0xFFC8502E),
        eye_dx=34.0, eye_dy=-16.0, eye_r=13.0, mouth=False,
        happy_part='crest', part_rot0=0.0, part_beat=0.5,
        idle_frames=300, blink_at=132,
    ),
    'reptile': dict(
        body=TEAL, head_w=166.0, head_h=128.0,
        ears={},
        muzzle=dict(x=0.0, y=26.0, w=96.0, h=50.0, color=0xFFF2FBF4),
        spots=[(-34.0, -44.0, 18.0), (6.0, -52.0, 13.0), (40.0, -42.0, 16.0)],
        eye_dx=44.0, eye_dy=-26.0, eye_r=15.0, mouth_dy=34.0, mouth_w=44.0,
        happy_part='eyeR', part_rot0=0.0, part_beat=0.18,
        idle_frames=348, blink_at=216,
    ),
    'other': dict(  # the paw mascot — pads as 'ears', a face on the pad
        body=TEAL, head_w=150.0, head_h=128.0,
        ears={'toeL': dict(kind='ellipse', x=-58.0, y=-70.0, w=44.0, h=54.0,
                           rot=-0.35, color=MINT),
              'toeM': dict(kind='ellipse', x=0.0, y=-84.0, w=46.0, h=58.0,
                           rot=0.0, color=MINT),
              'toeR': dict(kind='ellipse', x=58.0, y=-70.0, w=44.0, h=54.0,
                           rot=0.35, color=MINT)},
        eye_dx=30.0, eye_dy=-6.0, eye_r=12.0, mouth_dy=30.0,
        happy_part='toeM', part_rot0=0.0, part_beat=0.3,
        idle_frames=318, blink_at=162,
    ),
}


def main():
    w = W()
    # header
    for c in b'RIVE':
        w.u8(c)
    w.varuint(7)   # major
    w.varuint(0)   # minor
    w.varuint(1)   # fileId
    w.varuint(0)   # empty ToC (all property keys are known to the runtime)

    obj(w, 'Backboard')

    for name, spec in SPECIES.items():
        ab = ArtboardBuilder(w, name)
        ids = build_species(ab, spec)
        # shared easing for all keyframes (sine-ish in-out)
        ab.ease = ab.interpolator(0.45, 0.0, 0.55, 1.0)
        anims = build_animations(ab, ids, spec)
        ab.state_machine(anims)

    data = bytes(w.b)
    budget = 300 * 1024
    assert len(data) <= budget, f'riv busts budget: {len(data)}'
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'wb') as f:
        f.write(data)
    print(f'paw_pals_v1.riv: {len(data)//1024}KB ({len(data)} bytes), '
          f'{len(SPECIES)} artboards')
    return 0





# ---------------------------------------------------------------------------
# --preview: PIL render of the same scene graph (proportion/palette check
# without the rive runtime; stroke joins are approximate, geometry is exact).
# ---------------------------------------------------------------------------
def _hex(c):
    return ((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF, (c >> 24) & 0xFF)


def render_preview(out_dir):
    from PIL import Image, ImageDraw
    os.makedirs(out_dir, exist_ok=True)
    SS = 4  # supersample
    tiles = []

    def ellipse_layer(size, w_, h_, fill_c, outline=None, owidth=0):
        img = Image.new('RGBA', size, (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = size[0] / 2, size[1] / 2
        box = [cx - w_ / 2, cy - h_ / 2, cx + w_ / 2, cy + h_ / 2]
        d.ellipse(box, fill=_hex(fill_c),
                  outline=_hex(outline) if outline else None, width=owidth)
        return img

    for name, spec in SPECIES.items():
        W_, H_ = 256 * SS, 256 * SS
        img = Image.new('RGBA', (W_, H_), (0, 0, 0, 0))
        rx, ry = 128 * SS, 140 * SS
        deep = spec.get('outline', DEEP)
        sw = int(7 * SS)

        def paste_rot(layer, x, y, rot_rad):
            rotated = layer.rotate(-rot_rad * 57.2958, resample=Image.BICUBIC,
                                   expand=False)
            img.alpha_composite(rotated,
                                (int(rx + x * SS - rotated.width / 2),
                                 int(ry + y * SS - rotated.height / 2)))

        for ename, e in spec.get('ears', {}).items():
            if e['kind'] == 'ellipse':
                lay = ellipse_layer((int(e['w'] * SS * 2.2), int(e['h'] * SS * 2.2)),
                                    e['w'] * SS, e['h'] * SS,
                                    e.get('color', spec['body']), deep, sw)
            else:
                pts = e['pts']
                wmax = max(abs(p[0]) for p in pts) * 2 + 30
                hmax = max(abs(p[1]) for p in pts) * 2 + 30
                lay = Image.new('RGBA', (int(wmax * SS), int(hmax * SS)), (0, 0, 0, 0))
                dd = ImageDraw.Draw(lay)
                cx, cy = lay.width / 2, lay.height / 2
                dd.polygon([(cx + p[0] * SS, cy + p[1] * SS) for p in pts],
                           fill=_hex(e.get('color', spec['body'])),
                           outline=_hex(deep), width=sw)
            paste_rot(lay, e['x'], e['y'], e.get('rot', 0.0))

        d = ImageDraw.Draw(img)

        def ell(x, y, w_, h_, fill_c, outline=None, ow=0, alpha=255):
            box = [rx + (x - w_ / 2) * SS, ry + (y - h_ / 2) * SS,
                   rx + (x + w_ / 2) * SS, ry + (y + h_ / 2) * SS]
            f = _hex(fill_c)
            f = (f[0], f[1], f[2], alpha)
            d.ellipse(box, fill=f, outline=_hex(outline) if outline else None,
                      width=ow)

        ell(0, 0, spec['head_w'], spec['head_h'], spec['body'], deep, sw)
        if 'muzzle' in spec:
            m = spec['muzzle']
            ell(m['x'], m['y'], m['w'], m['h'], m.get('color', CREAM))
        for sp in spec.get('spots', []):
            ell(sp[0], sp[1], sp[2], sp[2], MINT)
        for bx in (-1, 1):
            ell(bx * spec.get('blush_dx', 52.0), spec.get('blush_dy', 18.0),
                24, 14, BLUSH, alpha=216)
        eye_dx, eye_dy = spec.get('eye_dx', 30.0), spec.get('eye_dy', -10.0)
        er = spec.get('eye_r', 13.0)
        for sx in (-1, 1):
            ell(sx * eye_dx, eye_dy, er * 2, er * 2, INK)
            ell(sx * eye_dx - er * 0.3, eye_dy - er * 0.35, er * 0.55, er * 0.55, WHITE)
        if 'nose' in spec:
            n = spec['nose']
            if n['kind'] == 'ellipse':
                ell(n.get('x', 0.0), n['y'], n['w'], n['h'], n.get('color', deep))
            else:
                pts = [(rx + (n.get('x', 0.0) + p[0]) * SS,
                        ry + (n['y'] + p[1]) * SS) for p in n['pts']]
                d.polygon(pts, fill=_hex(n.get('color', deep)))
        if spec.get('mouth', True):
            mw = spec.get('mouth_w', 30.0)
            my_ = spec.get('mouth_dy', 30.0)
            d.arc([rx - mw / 2 * SS, ry + (my_ - mw * 0.42) * SS,
                   rx + mw / 2 * SS, ry + (my_ + mw * 0.30) * SS],
                  start=35, end=145, fill=_hex(deep), width=int(5.5 * SS))

        img = img.resize((256, 256), Image.LANCZOS)
        img.save(os.path.join(out_dir, f'{name}.png'))
        tiles.append(img)

    strip = Image.new('RGBA', (256 * len(tiles), 256), (26, 26, 46, 255))
    for i, t in enumerate(tiles):
        strip.alpha_composite(t, (i * 256, 0))
    strip.save(os.path.join(out_dir, '_all.png'))
    print(f'previews -> {out_dir}')


if __name__ == '__main__':
    if '--preview' in sys.argv:
        render_preview('/tmp/paw_pals_preview')
        sys.exit(0)
    sys.exit(main())
