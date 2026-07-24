// Next Evolution Phase 4 — SSE parsing across adversarial chunk boundaries.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/assistant/sse_client.dart';

Stream<List<int>> _chunks(List<String> parts) =>
    Stream.fromIterable(parts.map(utf8.encode));

void main() {
  test('parses a clean frame sequence', () async {
    final events = await parseSseStream(_chunks([
      'event: delta\ndata: {"text":"Hel"}\n\n'
          'event: delta\ndata: {"text":"lo"}\n\n'
          'event: done\ndata: {"usage":{}}\n\n',
    ])).toList();
    expect(events.map((e) => e.event), ['delta', 'delta', 'done']);
    expect(events[0].data['text'], 'Hel');
  });

  test('reassembles frames split mid-line and mid-JSON across chunks',
      () async {
    final events = await parseSseStream(_chunks([
      'event: del',
      'ta\ndata: {"te',
      'xt":"Hi"}\n',
      '\nevent: done\nda',
      'ta: {}\n\n',
    ])).toList();
    expect(events.map((e) => e.event), ['delta', 'done']);
    expect(events[0].data['text'], 'Hi');
  });

  test('reassembles multi-byte UTF-8 split across chunks', () async {
    final frame = 'event: delta\ndata: {"text":"paw 🐾"}\n\n';
    final bytes = utf8.encode(frame);
    // Split inside the 4-byte emoji sequence.
    final cut = bytes.length - 5;
    final events = await parseSseStream(Stream.fromIterable([
      bytes.sublist(0, cut),
      bytes.sublist(cut),
    ])).toList();
    expect(events.single.data['text'], 'paw 🐾');
  });

  test('skips malformed frames without killing the stream', () async {
    final events = await parseSseStream(_chunks([
      'event: delta\ndata: not-json\n\n',
      ': comment frame\n\n',
      'event: delta\ndata: {"text":"ok"}\n\n',
    ])).toList();
    expect(events.single.data['text'], 'ok');
  });

  test('newlines inside JSON strings survive framing', () async {
    final events = await parseSseStream(_chunks([
      'event: delta\ndata: {"text":"line1\\nline2"}\n\n',
    ])).toList();
    expect(events.single.data['text'], 'line1\nline2');
  });
}
