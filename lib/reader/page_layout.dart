import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

/// Lays the book out as a single horizontal strip, one page per slot.
///
/// Every slot is the same width — the widest page in the book plus a gutter —
/// so the distance between any two neighbouring pages is identical. That
/// uniform pitch is what makes snapping to a page a simple bit of arithmetic
/// instead of a search through varying page widths.
///
/// Pages narrower or shorter than the largest are centred in their slot, so a
/// book that mixes page sizes doesn't jitter as you turn through it.
PdfPageLayout layoutPagesHorizontally(
  List<PdfPage> pages,
  PdfViewerParams params,
) {
  final widest = pages.fold(0.0, (m, page) => math.max(m, page.width));
  final tallest = pages.fold(0.0, (m, page) => math.max(m, page.height));

  final gutter = params.margin;
  final slotWidth = widest + gutter;

  final rects = <Rect>[];
  var x = gutter;
  for (final page in pages) {
    rects.add(
      Rect.fromLTWH(
        x + (widest - page.width) / 2,
        gutter + (tallest - page.height) / 2,
        page.width,
        page.height,
      ),
    );
    x += slotWidth;
  }

  return PdfPageLayout(
    pageLayouts: rects,
    documentSize: Size(x, tallest + gutter * 2),
  );
}

/// The page whose slot is closest to the middle of what you're looking at.
///
/// Returns a 1-based page number, matching how pdfrx and the database count.
int nearestPageNumber(PdfPageLayout layout, Rect visible) {
  final centre = visible.center.dx;
  var best = 0;
  var bestDistance = double.infinity;

  for (var i = 0; i < layout.pageLayouts.length; i++) {
    final distance = (layout.pageLayouts[i].center.dx - centre).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      best = i;
    }
  }
  return best + 1;
}

/// The distance between neighbouring page slots, in document coordinates.
///
/// Every slot is the same width, so any adjacent pair gives the pitch.
double pagePitch(PdfPageLayout layout) {
  if (layout.pageLayouts.length < 2) return layout.documentSize.width;
  return layout.pageLayouts[1].center.dx - layout.pageLayouts[0].center.dx;
}

/// Whether the view is already sitting squarely on a page.
///
/// Used to leave the view alone when nothing moved. Every gesture ends with an
/// interaction-end — including a long-press to select a word — and animating
/// the view "back" to the page it never left would cancel that selection.
bool isRestingOnPage(
  PdfPageLayout layout,
  Rect visible, {
  double tolerance = 0.02,
}) {
  final pitch = pagePitch(layout);
  if (pitch <= 0) return true;

  final page = nearestPageNumber(layout, visible);
  final drift = (layout.pageLayouts[page - 1].center.dx - visible.center.dx)
      .abs();
  return drift <= pitch * tolerance;
}
