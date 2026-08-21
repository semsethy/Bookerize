import 'dart:ui';

import 'package:bookerize/reader/word_finder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds char rects for a line of text laid out left to right.
///
/// [glyph] is the width of a normal letter; [space] the width given to a
/// whitespace character. Real measurements from the sample book: a genuine word
/// space is 0.65-0.97 of a glyph, letter-spacing is 0.27.
({String text, List<Rect> rects}) line(
  String text, {
  double glyph = 10,
  double space = 8,
  double top = 0,
  double height = 12,
  double startX = 0,
  double extraGapBefore = 0,
  Set<int> gapIndices = const {},
}) {
  final rects = <Rect>[];
  var x = startX;
  for (var i = 0; i < text.length; i++) {
    if (gapIndices.contains(i)) x += extraGapBefore;
    final width = text[i].trim().isEmpty ? space : glyph;
    rects.add(Rect.fromLTWH(x, top, width, height));
    x += width;
  }
  return (text: text, rects: rects);
}

void main() {
  group('ordinary text', () {
    test('splits on real word spaces', () {
      final l = line('the quick fox');
      final finder = WordFinder.build(fullText: l.text, charRects: l.rects);

      expect(finder.words.map((w) => w.text), ['the', 'quick', 'fox']);
    });

    test('a press inside a word returns that word', () {
      final l = line('the quick fox');
      final finder = WordFinder.build(fullText: l.text, charRects: l.rects);

      // "quick" starts after "the" (3 glyphs) + a space.
      final quick = finder.words[1];
      expect(finder.wordAt(quick.bounds.center)?.text, 'quick');
    });

    test('punctuation is trimmed but apostrophes survive', () {
      final l = line('("didn\'t") well-worn.');
      final finder = WordFinder.build(fullText: l.text, charRects: l.rects);

      expect(finder.words.map((w) => w.text), ["didn't", 'well-worn']);
    });

    test('a press far from any word returns nothing', () {
      final l = line('the quick fox');
      final finder = WordFinder.build(fullText: l.text, charRects: l.rects);

      expect(finder.wordAt(const Offset(500, 400)), isNull);
    });

    test('a page with no text at all yields no words', () {
      // 46 of the sample book's 137 pages are illustrations. This must be
      // silent, not an error.
      final finder = WordFinder.build(fullText: '', charRects: const []);

      expect(finder.words, isEmpty);
      expect(finder.wordAt(const Offset(10, 10)), isNull);
    });
  });

  group('letter-spaced headings', () {
    // The measured case: whitespace glyphs at 0.27 of a letter are spacing,
    // not word breaks, and the real breaks show up as wide gaps instead.
    test('T H E  B O O K reads as two words, not eleven letters', () {
      final l = line(
        'T H E B O O K',
        glyph: 11,
        space: 11 * 0.27, // measured letter-spacing
        extraGapBefore: 11 * 0.9, // measured word gap
        gapIndices: {6}, // before "B"
      );
      final finder = WordFinder.build(fullText: l.text, charRects: l.rects);

      expect(finder.words.map((w) => w.text), ['THE', 'BOOK']);
    });

    test('pressing any letter of a spaced heading returns the whole word', () {
      final l = line(
        'T H E B O O K',
        glyph: 11,
        space: 11 * 0.27,
        extraGapBefore: 11 * 0.9,
        gapIndices: {6},
      );
      final finder = WordFinder.build(fullText: l.text, charRects: l.rects);

      // Press the "H" — the middle letter of the first word.
      expect(finder.wordAt(l.rects[2].center)?.text, 'THE');
    });
  });

  group('multiple lines', () {
    test('words are found per line, not run together', () {
      final first = line('hello world', top: 0);
      final second = line('second line', top: 20);
      final text = '${first.text}\n${second.text}';
      final rects = <Rect>[
        ...first.rects,
        const Rect.fromLTWH(0, 0, 0, 0), // the newline: no glyph
        ...second.rects,
      ];

      final finder = WordFinder.build(fullText: text, charRects: rects);
      expect(finder.words.map((w) => w.text), [
        'hello',
        'world',
        'second',
        'line',
      ]);
    });
  });

  group('sentenceAround', () {
    const passage =
        'Most conversations fail. The repair is unglamorous. You wait.';

    test('returns the sentence the word sits in', () {
      final index = passage.indexOf('repair');
      expect(
        WordFinder.sentenceAround(passage, index),
        'The repair is unglamorous.',
      );
    });

    test('handles the first sentence', () {
      expect(WordFinder.sentenceAround(passage, 2), 'Most conversations fail.');
    });

    test('handles the last sentence', () {
      final index = passage.indexOf('wait');
      expect(WordFinder.sentenceAround(passage, index), 'You wait.');
    });

    test('folds the hard wraps PDFs put in the middle of sentences', () {
      const wrapped = 'That pause is where\nreciprocity begins, given\nroom.';
      final index = wrapped.indexOf('reciprocity');

      expect(
        WordFinder.sentenceAround(wrapped, index),
        'That pause is where reciprocity begins, given room.',
      );
    });

    test('does not treat an abbreviation as the end of a sentence', () {
      const withAbbrev =
          'Ask a real question, e.g. one you cannot answer. Then wait.';
      final index = withAbbrev.indexOf('cannot');

      expect(
        WordFinder.sentenceAround(withAbbrev, index),
        'Ask a real question, e.g. one you cannot answer.',
      );
    });

    test('empty text is handled without throwing', () {
      expect(WordFinder.sentenceAround('', 0), '');
    });
  });
}
