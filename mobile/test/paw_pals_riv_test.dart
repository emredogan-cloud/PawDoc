// M2 flagship gates for paw_pals_v1.riv.
//
// Layered verification (rive's Artboard requires a native layout lib that
// flutter_tester does not ship on CI):
//  1. ALWAYS: a pure-Dart structural walk of the binary — budget, all 7
//     species artboards, `pal` machine + 4 contract inputs, all 5 behavioral
//     animations with roadmap timings, distinct per-species blink cycles.
//  2. WHEN AVAILABLE: a real RiveFile.import + state-machine drive (runs on
//     a machine with rive_common's librive_text built; see shared_lib docs).
//  3. ALWAYS (out of band): live rig render + input reactions are item #1 of
//     the M2 on-device checklist (runtime/motion_validation/m2/).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart';

const species = ['dog', 'cat', 'rabbit', 'guinea_pig', 'bird', 'reptile', 'other'];

// ---- minimal pure-Dart .riv structural reader (mirrors rive-0.13.20) ------
class _Reader {
  _Reader(this.bytes);
  final Uint8List bytes;
  int i = 0;

  bool get eof => i >= bytes.length;
  int u8() => bytes[i++];
  int varuint() {
    var value = 0, shift = 0;
    while (true) {
      final b = u8();
      value |= (b & 0x7F) << shift;
      if (b & 0x80 == 0) return value;
      shift += 7;
    }
  }

  double f32() {
    final v = ByteData.sublistView(bytes, i, i + 4).getFloat32(0, Endian.little);
    i += 4;
    return v;
  }

  int u32() {
    final v = ByteData.sublistView(bytes, i, i + 4).getUint32(0, Endian.little);
    i += 4;
    return v;
  }

  String string() {
    final len = varuint();
    final s = String.fromCharCodes(bytes.sublist(i, i + len));
    i += len;
    return s;
  }
}

// property field types for every key the builder emits (uint/double/color/
// string/bool) — mirrors the runtime's generated coreType table.
const _fieldTypes = <int, String>{
  4: 's', 5: 'u', 7: 'd', 8: 'd', 196: 'b', 13: 'd', 14: 'd', 15: 'd',
  16: 'd', 17: 'd', 18: 'd', 20: 'd', 21: 'd', 23: 'u', 24: 'd', 25: 'd',
  26: 'd', 31: 'd', 32: 'b', 37: 'c', 47: 'd', 51: 'u', 53: 'u', 55: 's',
  56: 'u', 57: 'u', 59: 'u', 63: 'd', 64: 'd', 65: 'd', 66: 'd', 67: 'u',
  68: 'u', 69: 'u', 70: 'd', 138: 's', 141: 'b', 149: 'u', 151: 'u',
  152: 'u', 155: 'u', 156: 'u', 158: 'u', 160: 'u',
};

class _Obj {
  _Obj(this.typeKey);
  final int typeKey;
  final props = <int, dynamic>{};
}

class _ParsedArtboard {
  String name = '';
  final animations = <String, ({int duration, int fps, int loop})>{};
  String machineName = '';
  final inputs = <String, int>{}; // name -> typeKey
  int states = 0;
  int transitions = 0;
  int conditions = 0;
}

List<_ParsedArtboard> _walk(Uint8List bytes) {
  final r = _Reader(bytes);
  for (final c in 'RIVE'.codeUnits) {
    expect(r.u8(), c, reason: 'bad fingerprint');
  }
  expect(r.varuint(), 7, reason: 'major version must be 7');
  r.varuint(); // minor
  r.varuint(); // fileId
  final tocKeys = <int>[];
  for (var k = r.varuint(); k != 0; k = r.varuint()) {
    tocKeys.add(k);
  }
  for (var n = 0; n < (tocKeys.length + 3) ~/ 4; n++) {
    r.u32();
  }

  final artboards = <_ParsedArtboard>[];
  _ParsedArtboard? current;
  while (!r.eof) {
    final o = _Obj(r.varuint());
    for (var key = r.varuint(); key != 0; key = r.varuint()) {
      final t = _fieldTypes[key];
      expect(t, isNotNull, reason: 'unknown property key $key in stream');
      switch (t!) {
        case 'u':
          o.props[key] = r.varuint();
        case 'd':
          o.props[key] = r.f32();
        case 'c':
          o.props[key] = r.u32();
        case 's':
          o.props[key] = r.string();
        case 'b':
          o.props[key] = r.u8() == 1;
      }
    }
    switch (o.typeKey) {
      case 1: // Artboard
        current = _ParsedArtboard()..name = o.props[4] as String? ?? '';
        artboards.add(current);
      case 31: // LinearAnimation
        current!.animations[o.props[55] as String] = (
          duration: o.props[57] as int,
          fps: o.props[56] as int,
          loop: o.props[59] as int? ?? 0,
        );
      case 53: // StateMachine
        current!.machineName = o.props[55] as String? ?? '';
      case 58 || 59: // Trigger / Bool input
        current!.inputs[o.props[138] as String] = o.typeKey;
      case 61 || 62 || 63 || 64: // states
        current!.states++;
      case 65:
        current!.transitions++;
      case 68 || 71:
        current!.conditions++;
    }
  }
  return artboards;
}

void main() {
  final bytes = File('assets/motion/paw_pals_v1.riv').readAsBytesSync();

  test('budget: whole rig ≤300KB (roadmap A10)', () {
    expect(bytes.length, lessThanOrEqualTo(300 * 1024));
  });

  group('structural walk', () {
    late List<_ParsedArtboard> artboards;
    setUpAll(() => artboards = _walk(bytes));

    test('all 7 species artboards exist', () {
      expect(artboards.map((a) => a.name).toSet(), species.toSet());
    });

    test('every artboard carries the pal machine + 4 contract inputs', () {
      for (final a in artboards) {
        expect(a.machineName, 'pal', reason: a.name);
        expect(a.inputs.keys.toSet(), {'tap', 'happy', 'sleepy', 'attentive'},
            reason: a.name);
        expect(a.inputs['sleepy'], 59, reason: '${a.name}: sleepy must be bool');
        expect(a.inputs['tap'], 58, reason: '${a.name}: tap must be a trigger');
        expect(a.states, greaterThanOrEqualTo(6), reason: a.name);
        expect(a.transitions, greaterThanOrEqualTo(9), reason: a.name);
        expect(a.conditions, greaterThanOrEqualTo(5), reason: a.name);
      }
    });

    test('all 5 behavioral animations with roadmap timings', () {
      for (final a in artboards) {
        expect(a.animations.keys.toSet(),
            {'idle', 'tilt', 'happy', 'attentive', 'sleep'},
            reason: a.name);
        double secs(String n) =>
            a.animations[n]!.duration / a.animations[n]!.fps;
        expect(secs('tilt'), lessThanOrEqualTo(0.4), reason: a.name);
        expect(secs('happy'), lessThanOrEqualTo(0.7), reason: a.name);
        expect(secs('attentive'), closeTo(0.5, 0.01), reason: a.name);
        expect(a.animations['idle']!.loop, 1, reason: '${a.name} idle loops');
        expect(a.animations['sleep']!.loop, 1, reason: '${a.name} sleep loops');
        expect(a.animations['tilt']!.loop, 0, reason: '${a.name} tilt one-shot');
      }
    });

    test('blink cycles distinct per species, inside the 4–7s band', () {
      final cycles = <double>{};
      for (final a in artboards) {
        final idle = a.animations['idle']!;
        final secs = idle.duration / idle.fps;
        expect(secs, inInclusiveRange(4.0, 7.0), reason: a.name);
        cycles.add(secs);
      }
      expect(cycles, hasLength(species.length),
          reason: 'no two species may share a blink rhythm (list desync)');
    });
  });

  test('runtime import + state machine drive (needs rive native layout lib)',
      () {
    RiveFile file;
    try {
      file = RiveFile.import(ByteData.sublistView(bytes));
    } on ArgumentError {
      markTestSkipped(
          'rive_common native layout lib unavailable under flutter_tester '
          '(no librive_text.so on this host) — runtime import is verified '
          'live as item #1 of the M2 device checklist.');
      return;
    }
    expect(file.artboards, hasLength(species.length));
    final artboard =
        file.artboards.firstWhere((a) => a.name == 'dog').instance();
    final controller = StateMachineController.fromArtboard(artboard, 'pal')!;
    artboard.addController(controller);
    artboard.advance(0.5);
    (controller.findSMI('tap') as SMITrigger).fire();
    artboard.advance(0.1);
    artboard.advance(0.4);
    controller.findInput<bool>('sleepy')!.value = true;
    artboard.advance(1.0);
    controller.findInput<bool>('sleepy')!.value = false;
    artboard.advance(1.0);
  });
}
