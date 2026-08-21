import 'package:bookerize/main.dart' as app;
import 'package:bookerize/reader/reader_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// Runs on a real simulator against the real PDF engine and the real database.
///
///     flutter test integration_test -d <device-id>
///
/// This exists because the one thing unit tests cannot reach is a finger: the
/// promise "turn a page and your place is kept" is made of gestures.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// pumpAndSettle is no use here — a loading spinner never settles, and pdfrx
  /// keeps rendering — so we pump in slices for a fixed stretch of time.
  Future<void> settle(WidgetTester tester, {int seconds = 4}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'open a book, turn pages, and the shelf remembers where you got to',
    (tester) async {
      app.main();
      await settle(tester, seconds: 6);

      // --- the shelf ---
      final bookTile = find.textContaining('Communication');
      expect(
        bookTile,
        findsOneWidget,
        reason: 'the bundled sample book should be on the shelf',
      );

      await tester.tap(bookTile);
      await settle(tester, seconds: 8);

      // --- the reader opened ---
      expect(find.byType(PdfViewer), findsOneWidget);

      // Chrome is hidden until you ask for it: the page is the whole screen.
      // It stays in the tree so it can slide, so ask it whether it's showing.
      expect(
        _chromeShowing(tester),
        isFalse,
        reason: 'the page should be the whole screen until you ask for chrome',
      );

      // Tapping the middle reveals it and tells us which page we're on.
      final viewer = find.byType(PdfViewer);
      await tester.tapAt(tester.getCenter(viewer));
      await settle(tester, seconds: 2);

      expect(_chromeShowing(tester), isTrue);
      expect(find.byType(Slider), findsOneWidget);

      final startingPage = _pageFromChrome(tester);
      expect(
        startingPage,
        isNotNull,
        reason: 'the chrome should show the current page',
      );

      // Hide it again so it can't intercept the swipe.
      await tester.tapAt(tester.getCenter(viewer));
      await settle(tester, seconds: 2);

      // --- turn the page by swiping ---
      await tester.fling(viewer, const Offset(-320, 0), 900);
      await settle(tester, seconds: 4);

      await tester.tapAt(tester.getCenter(viewer));
      await settle(tester, seconds: 2);

      final afterSwipe = _pageFromChrome(tester);
      expect(afterSwipe, isNotNull);
      expect(
        afterSwipe!,
        greaterThan(startingPage!),
        reason: 'swiping left should move forward through the book',
      );

      // --- and the shelf knows about it ---
      await tester.tapAt(tester.getCenter(viewer)); // hide chrome
      await settle(tester, seconds: 1);
      await tester.tapAt(
        tester.getCenter(viewer),
      ); // show it again for the back button
      await settle(tester, seconds: 2);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await settle(tester, seconds: 4);

      expect(
        find.textContaining('p. $afterSwipe /'),
        findsOneWidget,
        reason: 'the page reached by swiping should be saved and shown on the shelf',
      );
    },
  );
}

bool _chromeShowing(WidgetTester tester) =>
    tester.widget<ReaderChrome>(find.byType(ReaderChrome)).visible;

/// Reads "Page 47 of 137" out of the reader chrome.
int? _pageFromChrome(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text));
  for (final text in texts) {
    final data = text.data;
    if (data == null || !data.startsWith('Page ')) continue;
    final match = RegExp(r'Page (\d+) of').firstMatch(data);
    if (match != null) return int.parse(match.group(1)!);
  }
  return null;
}
