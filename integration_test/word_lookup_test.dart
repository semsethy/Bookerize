import 'dart:async';

import 'package:bookerize/dictionary/word_card.dart';
import 'package:bookerize/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// Phase 4's promise, on a real device: long-press a word, get its meaning.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, {int seconds = 4}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<PdfViewerController> openBookAt(WidgetTester tester, int page) async {
    app.main();
    await settle(tester, seconds: 6);
    await tester.tap(find.textContaining('Communication'));
    await settle(tester, seconds: 8);

    final controller = tester
        .widget<PdfViewer>(find.byType(PdfViewer))
        .controller!;
    // Not awaited: the animation only advances while the test pumps frames.
    unawaited(controller.goToPage(pageNumber: page));
    await settle(tester, seconds: 4);
    return controller;
  }

  testWidgets(
    'long-pressing body text shows a definition',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      await openBookAt(tester, 47); // dense body text

      expect(find.byType(WordCard), findsNothing);

      final viewer = find.byType(PdfViewer);
      await tester.longPressAt(tester.getCenter(viewer));
      await settle(tester, seconds: 3);

      expect(
        find.byType(WordCard),
        findsOneWidget,
        reason: 'a long-press in the middle of a text page should find a word',
      );

      final card = tester.widget<WordCard>(find.byType(WordCard));
      expect(card.lookup.word.trim(), isNotEmpty);
      expect(
        card.lookup.sentence.trim(),
        isNotEmpty,
        reason: 'the containing sentence is what Phase 5 needs for context',
      );
      expect(
        card.lookup.sentence,
        isNot(contains('\n')),
        reason: "the PDF's hard wraps should be folded out",
      );

      // Tapping anywhere puts the card away.
      await tester.tapAt(tester.getCenter(viewer));
      await settle(tester, seconds: 2);
      expect(find.byType(WordCard), findsNothing);
    },
  );

  testWidgets(
    'long-pressing an illustration page does nothing at all',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      final controller = await openBookAt(tester, 47);

      // Find a page with no text layer — 46 of the 137 are illustrations.
      var illustration = -1;
      for (var i = 1; i <= controller.document.pages.length; i++) {
        final text = await controller.document.pages[i - 1].loadText();
        if ((text?.fullText.trim().length ?? 0) == 0) {
          illustration = i;
          break;
        }
      }
      expect(illustration, greaterThan(0));

      unawaited(controller.goToPage(pageNumber: illustration));
      await settle(tester, seconds: 4);

      await tester.longPressAt(tester.getCenter(find.byType(PdfViewer)));
      await settle(tester, seconds: 3);

      // Silence is the requirement: no card, and no error of any kind.
      expect(find.byType(WordCard), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
