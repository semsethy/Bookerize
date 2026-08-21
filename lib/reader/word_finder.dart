import 'dart:math' as math;
import 'dart:ui';

/// A word as it appears on the page, and where it sits in the page's text.
class PageWord {
  const PageWord({
    required this.text,
    required this.start,
    required this.end,
    required this.bounds,
  });

  /// The word with any letter-spacing removed: `T H E` becomes `THE`.
  final String text;

  /// Range in the page's full text, `end` exclusive. Used to find the sentence
  /// this word sits in.
  final int start;
  final int end;

  /// Where the word is on the page, in the same coordinates as the hit-test.
  final Rect bounds;
}

/// Turns a page's characters into words you can hit-test with a fingertip.
///
/// ## Why this can't just split on spaces
///
/// Chapter headings in the sample book are letter-spaced, and the text layer
/// reports them literally: `T H E   C O M M U N I C A T I O N   B O O K`.
/// Splitting on whitespace would hand back a single letter.
///
/// Two measurements taken from the sample book separate the cases, and neither
/// is close to its threshold:
///
/// | signal                        | letter-spacing | real word break |
/// |-------------------------------|----------------|-----------------|
/// | whitespace glyph width        | 0.27           | 0.65 - 0.97     |
/// | gap between adjacent glyphs   | 0.03 - 0.11    | 0.84 - 0.90     |
///
/// Both are expressed as a fraction of the line's median glyph width, so they
/// hold at any font size. Body text never produced a gap above 0.17.
class WordFinder {
  WordFinder._(this._words);

  final List<PageWord> _words;

  List<PageWord> get words => List.unmodifiable(_words);

  /// A whitespace glyph at least this wide (relative to the median glyph on the
  /// line) is a real space between words.
  static const spaceWidthRatio = 0.45;

  /// A gap at least this wide between two glyphs separates words, even when
  /// there is no space character at all.
  static const gapRatio = 0.5;

  /// How far outside a word a press still counts, as a fraction of line height.
  /// Fingers are imprecise; the gap between lines is not.
  static const touchSlack = 0.35;

  /// [charRects] must be in the same coordinate space as the points later
  /// passed to [wordAt], and must line up index-for-index with [fullText].
  factory WordFinder.build({
    required String fullText,
    required List<Rect> charRects,
  }) {
    final lines = _groupIntoLines(fullText, charRects);
    final words = <PageWord>[];
    for (final line in lines) {
      words.addAll(_splitLineIntoWords(line, fullText, charRects));
    }
    return WordFinder._(words);
  }

  /// The word under [point], or null if there isn't one.
  ///
  /// Null is the normal answer, not an error: 46 of the sample book's 137 pages
  /// are illustrations with no text at all, and a press in a margin is a press
  /// on nothing. Callers must fail silently.
  PageWord? wordAt(Offset point) {
    PageWord? nearest;
    var nearestDistance = double.infinity;

    for (final word in _words) {
      if (word.bounds.contains(point)) return word;

      // Allow a little slack vertically (fingers) but require the press to be
      // roughly within the word horizontally.
      final slack = word.bounds.height * touchSlack;
      final forgiving = Rect.fromLTRB(
        word.bounds.left - slack,
        word.bounds.top - slack,
        word.bounds.right + slack,
        word.bounds.bottom + slack,
      );
      if (!forgiving.contains(point)) continue;

      final distance = (word.bounds.center - point).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = word;
      }
    }
    return nearest;
  }

  /// The sentence containing [index] in [fullText], tidied for display.
  ///
  /// PDF text arrives broken across lines, so newlines are folded into spaces —
  /// otherwise the sentence handed to the dictionary (and, in Phase 5, to the
  /// model) would be full of hard wraps that aren't in the book.
  static String sentenceAround(String fullText, int index) {
    if (fullText.isEmpty) return '';
    final safeIndex = index.clamp(0, fullText.length - 1);

    var start = safeIndex;
    while (start > 0) {
      final char = fullText[start - 1];
      if (_isSentenceEnd(char) && _looksLikeBoundary(fullText, start - 1)) {
        break;
      }
      start--;
    }

    var end = safeIndex;
    while (end < fullText.length) {
      if (_isSentenceEnd(fullText[end]) && _looksLikeBoundary(fullText, end)) {
        end++;
        break;
      }
      end++;
    }

    return fullText
        .substring(start, math.min(end, fullText.length))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isSentenceEnd(String char) =>
      char == '.' || char == '!' || char == '?';

  /// Distinguishes the full stop that ends a sentence from the one in "e.g."
  /// or "Dr." — the next non-space character has to look like a new start.
  static bool _looksLikeBoundary(String text, int stopIndex) {
    // A single letter before the stop is almost always an initial or an
    // abbreviation: "e.g.", "J. Smith".
    if (stopIndex >= 1) {
      final before = text[stopIndex - 1];
      final beforeThat = stopIndex >= 2 ? text[stopIndex - 2] : ' ';
      if (_isLetter(before) && !_isLetter(beforeThat)) return false;
    }

    var i = stopIndex + 1;
    while (i < text.length && _isWhitespace(text[i])) {
      i++;
    }
    if (i >= text.length) return true;

    final next = text[i];
    return next == next.toUpperCase() && next != next.toLowerCase() ||
        _isQuote(next);
  }

  static bool _isLetter(String c) => c.toUpperCase() != c.toLowerCase();

  static bool _isWhitespace(String c) => c.trim().isEmpty;

  static bool _isQuote(String c) =>
      c == '"' || c == "'" || c == '‘' || c == '“';

  // ---------------------------------------------------------------- internals

  /// Characters that share a line, in reading order.
  static List<List<int>> _groupIntoLines(
    String fullText,
    List<Rect> charRects,
  ) {
    final lines = <List<int>>[];
    final limit = math.min(fullText.length, charRects.length);

    for (var i = 0; i < limit; i++) {
      final rect = charRects[i];
      if (rect.height <= 0 && rect.width <= 0) continue;

      var placed = false;
      for (final line in lines) {
        final reference = charRects[line.first];
        final overlap =
            math.min(rect.bottom, reference.bottom) -
            math.max(rect.top, reference.top);
        final shorter = math.min(rect.height, reference.height);
        if (shorter > 0 && overlap > shorter * 0.5) {
          line.add(i);
          placed = true;
          break;
        }
      }
      if (!placed) lines.add(<int>[i]);
    }

    for (final line in lines) {
      line.sort((a, b) => charRects[a].left.compareTo(charRects[b].left));
    }
    return lines;
  }

  static List<PageWord> _splitLineIntoWords(
    List<int> line,
    String fullText,
    List<Rect> charRects,
  ) {
    if (line.isEmpty) return const [];

    final glyphWidths = <double>[];
    for (final i in line) {
      if (fullText[i].trim().isNotEmpty && charRects[i].width > 0) {
        glyphWidths.add(charRects[i].width);
      }
    }
    if (glyphWidths.isEmpty) return const [];
    glyphWidths.sort();
    final median = glyphWidths[glyphWidths.length ~/ 2];
    if (median <= 0) return const [];

    final spaceLimit = median * spaceWidthRatio;
    final gapLimit = median * gapRatio;

    final words = <PageWord>[];
    var group = <int>[];

    void flush() {
      final word = _wordFrom(group, fullText, charRects);
      if (word != null) words.add(word);
      group = <int>[];
    }

    for (var k = 0; k < line.length; k++) {
      final index = line[k];
      final isSpace = fullText[index].trim().isEmpty;

      // A wide whitespace glyph is a real space; a narrow one is letter-spacing.
      if (isSpace && charRects[index].width >= spaceLimit) {
        flush();
        continue;
      }
      // A zero-size whitespace glyph is a line ending, not a space in a word.
      if (isSpace && charRects[index].width <= 0) {
        flush();
        continue;
      }

      group.add(index);

      if (k + 1 < line.length) {
        final gap = charRects[line[k + 1]].left - charRects[index].right;
        if (gap >= gapLimit) flush();
      }
    }
    flush();

    return words;
  }

  static PageWord? _wordFrom(
    List<int> group,
    String fullText,
    List<Rect> charRects,
  ) {
    if (group.isEmpty) return null;

    final buffer = StringBuffer();
    for (final i in group) {
      final char = fullText[i];
      // Drop the letter-spacing gaps: "T H E" is the word "THE".
      if (char.trim().isNotEmpty) buffer.write(char);
    }

    final raw = buffer.toString();
    final trimmed = _trimPunctuation(raw);
    if (trimmed.isEmpty) return null;

    var bounds = charRects[group.first];
    for (final i in group) {
      bounds = bounds.expandToInclude(charRects[i]);
    }

    return PageWord(
      text: trimmed,
      start: group.first,
      end: group.last + 1,
      bounds: bounds,
    );
  }

  /// Strips quotes, brackets and trailing stops, but keeps word-internal
  /// apostrophes and hyphens: `("didn't")` becomes `didn't`.
  static String _trimPunctuation(String word) {
    var start = 0;
    var end = word.length;
    while (start < end && !_isWordCharacter(word[start])) {
      start++;
    }
    while (end > start && !_isWordCharacter(word[end - 1])) {
      end--;
    }
    return word.substring(start, end);
  }

  static bool _isWordCharacter(String c) {
    if (_isLetter(c)) return true;
    return RegExp(r'[0-9]').hasMatch(c);
  }
}
