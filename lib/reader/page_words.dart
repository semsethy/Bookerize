import 'dart:ui';

import 'package:pdfrx/pdfrx.dart';

import 'word_finder.dart';

/// Loads a page's text once and keeps it, so a long-press is instant.
///
/// Reading the text layer and converting every character rectangle costs real
/// time on a dense page. A reader long-presses several words on the same page,
/// so the work is done once per page and cached.
class PageWords {
  PageWords({required this.finder, required this.fullText});

  final WordFinder finder;
  final String fullText;

  /// The sentence a word sits in, for the "what does it mean here?" question.
  String sentenceFor(PageWord word) =>
      WordFinder.sentenceAround(fullText, word.start);
}

/// Builds [PageWords] for pages, remembering the ones it has already done.
class PageWordCache {
  PageWordCache({this.maxPages = 6});

  /// A book is read a page at a time, so a small cache covers the pages in
  /// play while keeping character rectangles off the heap for a 137-page book.
  final int maxPages;

  final _cache = <int, PageWords>{};
  final _order = <int>[];

  /// Text and word boxes for [pageNumber], in document coordinates.
  ///
  /// Returns null when the page has no text at all — 46 of the sample book's
  /// 137 pages are illustrations, and that must stay silent.
  Future<PageWords?> forPage({
    required PdfDocument document,
    required PdfPageLayout layout,
    required int pageNumber,
  }) async {
    final cached = _cache[pageNumber];
    if (cached != null) return cached;

    if (pageNumber < 1 || pageNumber > document.pages.length) return null;
    final page = document.pages[pageNumber - 1];
    final pageRect = layout.pageLayouts[pageNumber - 1];

    final text = await page.loadStructuredText();
    if (text.fullText.trim().isEmpty) return null;

    // Character boxes arrive in PDF coordinates, which run bottom-up. The taps
    // we hit-test against are in the viewer's document coordinates, which run
    // top-down. pdfrx knows how to bridge the two.
    final rects = <Rect>[
      for (final rect in text.charRects)
        rect.toRectInDocument(page: page, pageRect: pageRect),
    ];

    final built = PageWords(
      finder: WordFinder.build(fullText: text.fullText, charRects: rects),
      fullText: text.fullText,
    );

    _cache[pageNumber] = built;
    _order.add(pageNumber);
    while (_order.length > maxPages) {
      _cache.remove(_order.removeAt(0));
    }
    return built;
  }

  /// Page layouts change when the viewer re-lays out, which invalidates every
  /// cached rectangle.
  void clear() {
    _cache.clear();
    _order.clear();
  }
}
