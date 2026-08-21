@TestOn('mac-os')
library;

import 'dart:io';
import 'dart:ui';

import 'package:bookerize/reader/word_finder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// Runs the word finder against a real PDF rather than synthetic rectangles.
///
/// Synthetic tests can be self-fulfilling: they prove the code does what the
/// test author imagined the page looks like. This one opens whatever book is in
/// assets/books/ and checks the results against what is actually printed.
///
/// Skips when the folder is empty — sample books are gitignored.
void main() {
  final books = Directory('assets/books');
  final pdf = books.existsSync()
      ? books
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.pdf'))
            .firstOrNull
      : null;

  if (pdf == null) {
    test(
      'real book checks (skipped: no PDF in assets/books/)',
      () {},
      skip: true,
    );
    return;
  }

  late PdfDocument doc;

  setUpAll(() async {
    await pdfrxInitialize();
    doc = await PdfDocument.openFile(pdf.path);
  });

  tearDownAll(() async => doc.dispose());

  Future<WordFinder> finderFor(int pageNumber) async {
    final page = doc.pages[pageNumber - 1];
    final text = await page.loadStructuredText();
    final height = page.height;
    final rects = [
      for (final r in text.charRects)
        Rect.fromLTRB(r.left, height - r.top, r.right, height - r.bottom),
    ];
    return WordFinder.build(fullText: text.fullText, charRects: rects);
  }

  test('body text splits into the words actually printed', () async {
    final finder = await finderFor(47);
    final words = finder.words.map((w) => w.text.toLowerCase()).toList();

    expect(words, contains('conversation'));
    expect(words, contains('listening'));
    expect(words, contains('attention'));

    // Nothing should have been glued together across a word space.
    expect(
      words.any((w) => w.length > 24),
      isFalse,
      reason: 'a very long "word" means a real space was missed',
    );
  });

  test('a letter-spaced heading comes back as whole words', () async {
    // Page 3 prints "T H E  C O M M U N I C A T I O N  B O O K".
    final finder = await finderFor(3);
    final words = finder.words.map((w) => w.text.toUpperCase()).toList();

    expect(words, contains('THE'));
    expect(words, contains('COMMUNICATION'));
    expect(words, contains('BOOK'));

    // The failure this guards against: one letter per "word".
    final singleLetters = words.where((w) => w.length == 1).length;
    expect(
      singleLetters,
      lessThan(4),
      reason: 'letter-spacing was treated as word breaks: $words',
    );
  });

  test('an illustration-only page yields no words, silently', () async {
    // Find a page with no text layer — 46 of 137 are illustrations.
    var illustrationPage = -1;
    for (var i = 1; i <= doc.pages.length; i++) {
      final text = await doc.pages[i - 1].loadText();
      if ((text?.fullText.trim().length ?? 0) == 0) {
        illustrationPage = i;
        break;
      }
    }
    expect(
      illustrationPage,
      greaterThan(0),
      reason: 'the sample book should have illustration-only pages',
    );

    final finder = await finderFor(illustrationPage);
    expect(finder.words, isEmpty);
    expect(finder.wordAt(const Offset(300, 400)), isNull);
  });

  test(
    'every word on a text page can be found by pressing its middle',
    () async {
      final finder = await finderFor(47);
      final sample = finder.words.take(60);

      for (final word in sample) {
        final hit = finder.wordAt(word.bounds.center);
        expect(
          hit?.text,
          word.text,
          reason: 'pressing the middle of "${word.text}" found "${hit?.text}"',
        );
      }
    },
  );
}
