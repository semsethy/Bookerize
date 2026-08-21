import 'dart:io';

import 'package:pdfrx_engine/pdfrx_engine.dart';

String f(double v) => v.toStringAsFixed(3);

Future<void> probe(PdfDocument doc, int pageNumber, String label) async {
  final text = await doc.pages[pageNumber - 1].loadStructuredText();
  final full = text.fullText;
  final rects = text.charRects;

  final lines = <List<int>>[];
  for (var i = 0; i < full.length && i < rects.length; i++) {
    final r = rects[i];
    if (r.width <= 0 && r.height <= 0) continue;
    var placed = false;
    for (final line in lines) {
      final ref = rects[line.first];
      final overlap =
          (r.top < ref.top ? r.top : ref.top) -
          (r.bottom > ref.bottom ? r.bottom : ref.bottom);
      final minHeight = r.height < ref.height ? r.height : ref.height;
      if (overlap > minHeight * 0.5) {
        line.add(i);
        placed = true;
        break;
      }
    }
    if (!placed) lines.add([i]);
  }

  stdout.writeln('\n===== $label (page $pageNumber) =====');
  var shown = 0;
  for (final line in lines) {
    if (line.length < 8) continue;
    line.sort((a, b) => rects[a].left.compareTo(rects[b].left));
    final content = line.map((i) => full[i]).join();
    if (content.trim().length < 8) continue;

    final glyphWidths = <double>[];
    for (final i in line) {
      if (full[i].trim().isNotEmpty && rects[i].width > 0)
        glyphWidths.add(rects[i].width);
    }
    if (glyphWidths.isEmpty) continue;
    glyphWidths.sort();
    final median = glyphWidths[glyphWidths.length ~/ 2];

    final spaceRatios = <String>[];
    for (final i in line) {
      if (full[i].trim().isEmpty) spaceRatios.add(f(rects[i].width / median));
    }

    stdout.writeln(
      '"${content.length > 46 ? content.substring(0, 46) : content.trimRight()}"',
    );
    stdout.writeln('   whitespace width / median glyph: $spaceRatios');
    if (++shown >= 3) break;
  }
}

Future<void> main(List<String> args) async {
  await pdfrxInitialize();
  final doc = await PdfDocument.openFile(args.first);
  await probe(doc, 3, 'LETTER-SPACED HEADING');
  await probe(doc, 47, 'NORMAL BODY TEXT');
  await doc.dispose();
}
