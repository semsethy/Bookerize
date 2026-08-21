import 'package:bookerize/reader/page_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// A layout of `count` uniform slots, matching what layoutPagesHorizontally
/// produces for a book whose pages are all the same size (the common case, and
/// exactly what the sample book is: 137 pages, all 612x792).
PdfPageLayout _uniformLayout({
  int count = 5,
  double pageWidth = 612,
  double pageHeight = 792,
  double gutter = 16,
}) {
  final rects = <Rect>[];
  var x = gutter;
  for (var i = 0; i < count; i++) {
    rects.add(Rect.fromLTWH(x, gutter, pageWidth, pageHeight));
    x += pageWidth + gutter;
  }
  return PdfPageLayout(
    pageLayouts: rects,
    documentSize: Size(x, pageHeight + gutter * 2),
  );
}

void main() {
  group('nearestPageNumber', () {
    final layout = _uniformLayout();

    Rect viewOf(PdfPageLayout l, int oneBasedPage) =>
        l.pageLayouts[oneBasedPage - 1];

    test('resting squarely on a page returns that page', () {
      for (var page = 1; page <= 5; page++) {
        expect(nearestPageNumber(layout, viewOf(layout, page)), page);
      }
    });

    test('page numbers are 1-based, matching pdfrx and the database', () {
      expect(nearestPageNumber(layout, viewOf(layout, 1)), 1);
    });

    test('drifting just past halfway commits to the next page', () {
      final page2 = viewOf(layout, 2);
      final page3 = viewOf(layout, 3);
      final pitch = page3.center.dx - page2.center.dx;

      // A drag that has moved 60% of the way toward page 3.
      final drifted = page2.translate(pitch * 0.6, 0);
      expect(nearestPageNumber(layout, drifted), 3);
    });

    test('stopping short of halfway falls back to the page you came from', () {
      final page2 = viewOf(layout, 2);
      final page3 = viewOf(layout, 3);
      final pitch = page3.center.dx - page2.center.dx;

      final barelyMoved = page2.translate(pitch * 0.4, 0);
      expect(nearestPageNumber(layout, barelyMoved), 2);
    });

    test('overscrolling past the last page still returns the last page', () {
      final last = viewOf(layout, 5);
      expect(nearestPageNumber(layout, last.translate(9999, 0)), 5);
    });

    test(
      'overscrolling before the first page still returns the first page',
      () {
        final first = viewOf(layout, 1);
        expect(nearestPageNumber(layout, first.translate(-9999, 0)), 1);
      },
    );

    test('a one-page book always snaps to page 1', () {
      final single = _uniformLayout(count: 1);
      expect(nearestPageNumber(single, viewOf(single, 1).translate(500, 0)), 1);
    });
  });

  group('isRestingOnPage', () {
    final layout = _uniformLayout();

    test('sitting on a page counts as resting', () {
      for (var page = 1; page <= 5; page++) {
        expect(isRestingOnPage(layout, layout.pageLayouts[page - 1]), isTrue);
      }
    });

    test('a nudge too small to see still counts as resting', () {
      // Guards the case that matters: every gesture ends with an interaction
      // end, including a long-press to select a word. Snapping "back" to the
      // page you never left would cancel that selection.
      final page2 = layout.pageLayouts[1];
      expect(isRestingOnPage(layout, page2.translate(2, 0)), isTrue);
    });

    test('a real drag is not resting', () {
      final page2 = layout.pageLayouts[1];
      final pitch = pagePitch(layout);
      expect(isRestingOnPage(layout, page2.translate(pitch * 0.3, 0)), isFalse);
    });

    test('pitch is the distance between neighbouring pages', () {
      expect(pagePitch(layout), 612 + 16);
    });

    test('a one-page book is always resting', () {
      final single = _uniformLayout(count: 1);
      expect(isRestingOnPage(single, single.pageLayouts[0]), isTrue);
    });
  });
}
