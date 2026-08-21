import 'dart:async';

import 'package:bookerize/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// Guards non-negotiable #2: pdfrx's native text selection must keep working.
///
/// Phases 4 and 5 — long-press a word for its meaning, select a sentence to have
/// it explained — are built entirely on this. Phase 3's paging was deliberately
/// built from the viewer's own hooks (a horizontal layout plus a snap on
/// interaction-end) rather than by wrapping the viewer in a gesture detector,
/// precisely so it wouldn't swallow the drags selection needs.
///
/// ## What this test can and cannot prove
///
/// It drives selection **programmatically**, not with a finger. A synthesised
/// long-press does not reach pdfrx's selection at all: verified by long-pressing
/// a bare `PdfViewer` with no configuration of ours under this same harness,
/// which also selected nothing. That is a limitation of the test harness, not of
/// the app.
///
/// So this proves the selection machinery is alive and the text layer is
/// reachable **through our paging configuration**, which is the regression worth
/// catching. Whether a real finger selects text still needs a human on a device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, {int seconds = 4}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'text is still selectable through the paged reader',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      app.main();
      await settle(tester, seconds: 6);

      await tester.tap(find.textContaining('Communication'));
      await settle(tester, seconds: 8);

      final viewerFinder = find.byType(PdfViewer);
      expect(viewerFinder, findsOneWidget);

      final controller = tester.widget<PdfViewer>(viewerFinder).controller;
      expect(
        controller,
        isNotNull,
        reason: 'the reader supplies its own controller',
      );

      final selection = controller!.textSelectionDelegate;

      expect(
        selection.isTextSelectionEnabled,
        isTrue,
        reason:
            'text selection must never be switched off — Phases 4-5 need it',
      );
      expect(
        selection.hasSelectedText,
        isFalse,
        reason: 'nothing should be selected before the reader does anything',
      );

      // Page 47 is dense body text. Page 1 is the cover, and 46 of the 137 pages
      // are full-page illustrations with nothing to select.
      //
      // Not awaited: goToPage animates, and the animation can only advance while
      // the test pumps frames. Awaiting it here would deadlock.
      unawaited(controller.goToPage(pageNumber: 47));
      await settle(tester, seconds: 4);

      // Reach the text layer the way Phase 4's word lookup will: straight off
      // the document the viewer has open. Not selectAllText() — that paints a
      // selection across all 137 pages, and pdfrx crashes on the 46 that hold
      // only an illustration. That crash is why this reader takes "Select All"
      // off the context menu.
      final page = controller.document.pages[46]; // page 47, 0-indexed
      final pageText = await page.loadText();

      expect(
        pageText?.fullText.trim(),
        isNotEmpty,
        reason: 'the text layer must be reachable — word lookup depends on it',
      );
      expect(
        pageText!.charRects,
        isNotEmpty,
        reason: 'per-character rects are what Phase 4 hit-tests a long-press against',
      );
    },
  );
}
