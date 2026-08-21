import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../ai/explain_sheet.dart';
import '../data/app_database.dart';
import '../data/providers.dart';
import '../dictionary/word_card.dart';
import '../theme.dart';
import 'page_layout.dart';
import 'page_words.dart';
import 'reader_chrome.dart';

/// One page per screen, turned by swiping sideways.
///
/// This is built *on top of* pdfrx's own viewer rather than by putting page
/// images in a PageView. That matters: pdfrx's text selection only works inside
/// its viewer, and Phases 4–5 (word lookup, sentence explanation) are built on
/// that selection. So the paging here is done with the viewer's own hooks —
/// a horizontal layout, plus a snap on `onInteractionEnd` — and never by
/// wrapping the viewer in a gesture detector that would swallow the drags
/// selection needs.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.bookId, super.key});

  final int bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final Future<Book> _book = _openBook();
  final _controller = PdfViewerController();

  int? _lastSaved;
  int _pageNumber = 1;
  int _pageCount = 1;
  bool _chromeVisible = false;
  bool _snapping = false;

  final _pageWords = PageWordCache();
  WordLookup? _lookup;

  /// The zoom at which exactly one page fills the screen. Captured once the
  /// viewer is ready so we can tell "resting on a page" from "zoomed in".
  double? _fitZoom;

  /// Opening a book counts as reading it, even if you never turn a page.
  /// pdfrx only reports page changes the reader actually makes, so without this
  /// the shelf would still say "Not started" after a whole session.
  Future<Book> _openBook() async {
    final db = ref.read(databaseProvider);
    final book = await db.bookById(widget.bookId);
    _lastSaved = book.lastPage;
    _pageNumber = book.lastPage;
    _pageCount = book.pageCount;
    await db.saveLastPage(book.id, book.lastPage);
    return book;
  }

  void _onPageChanged(int? pageNumber) {
    if (pageNumber == null) return;
    if (mounted) setState(() => _pageNumber = pageNumber);
    if (pageNumber == _lastSaved) return;
    _lastSaved = pageNumber;
    // Fire and forget: a page turn shouldn't wait on a disk write.
    ref.read(databaseProvider).saveLastPage(widget.bookId, pageNumber);
  }

  /// Settle on whole pages after every drag, however slow.
  ///
  /// pdfrx only runs its scroll physics on a fling, so relying on a snapping
  /// ScrollPhysics would leave a slow drag resting between two pages.
  Future<void> _snapToNearestPage(ScaleEndDetails _) async {
    if (_snapping || !_controller.isReady) return;

    // Leave the reader alone while zoomed in: they're inspecting a diagram,
    // not turning a page, and yanking the view to a page edge would fight them.
    final fit = _fitZoom;
    if (fit != null && _controller.currentZoom > fit * 1.02) return;

    // Every gesture ends here, including a long-press to select a word. If the
    // view never moved, snapping it "back" to the page it never left cancels
    // that selection — which would break Phases 4-5. Leave it alone.
    if (isRestingOnPage(_controller.layout, _controller.visibleRect)) return;

    // Belt and braces: never yank the view while the reader has text selected.
    if (_controller.textSelectionDelegate.hasSelectedText) return;

    final target = nearestPageNumber(
      _controller.layout,
      _controller.visibleRect,
    );

    _snapping = true;
    try {
      await _controller.goToPage(
        pageNumber: target,
        duration: const Duration(milliseconds: 220),
      );
    } finally {
      _snapping = false;
    }
  }

  Future<void> _goToPage(int pageNumber) async {
    if (!_controller.isReady) return;
    final clamped = pageNumber.clamp(1, _pageCount);
    if (clamped == _pageNumber) return;
    await _controller.goToPage(pageNumber: clamped);
  }

  /// Long-press a word to look it up.
  ///
  /// Nothing happens when there is no word under the finger. That is the normal
  /// case on 46 of this book's 137 pages, which are illustrations — an error
  /// there would teach the reader the app is broken (non-negotiable #3).
  Future<void> _lookUpWordAt(Offset documentPosition) async {
    if (!_controller.isReady) return;

    final layout = _controller.layout;
    final pageNumber = _pageAt(layout, documentPosition);
    if (pageNumber == null) return;

    final words = await _pageWords.forPage(
      document: _controller.document,
      layout: layout,
      pageNumber: pageNumber,
    );
    if (words == null) return; // a page with no text: stay silent

    final word = words.finder.wordAt(documentPosition);
    if (word == null) return; // a margin, or the space between words

    final dictionary = await ref.read(dictionaryProvider.future);
    if (!mounted) return;

    setState(() {
      _lookup = WordLookup(
        word: word.text,
        sentence: words.sentenceFor(word),
        definitions: dictionary.lookup(word.text),
      );
    });
  }

  /// Which page a document-space point falls on.
  int? _pageAt(PdfPageLayout layout, Offset point) {
    for (var i = 0; i < layout.pageLayouts.length; i++) {
      if (layout.pageLayouts[i].contains(point)) return i + 1;
    }
    return null;
  }

  /// Selecting a sentence and asking for it in plainer words.
  ///
  /// The selected text comes from pdfrx, so it is exactly what the reader
  /// dragged over — including the hard wraps a PDF puts mid-sentence, which the
  /// proxy folds out before asking.
  Future<void> _explainSelection() async {
    final selection = _controller.textSelectionDelegate;
    if (!selection.hasSelectedText) return;

    final sentence = (await selection.getSelectedText()).trim();
    if (!mounted || sentence.isEmpty) return;

    await ExplainSheet.show(context, sentence);
  }

  void _dismissLookup() {
    if (_lookup != null) setState(() => _lookup = null);
  }

  /// pdfrx hands us taps from its own gesture pipeline, so we get edge-tap
  /// paging without adding a competing GestureDetector.
  bool _onTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    if (details.type == PdfViewerGeneralTapType.longPress) {
      _lookUpWordAt(details.documentPosition);
      return true;
    }

    if (details.type != PdfViewerGeneralTapType.tap) return false;

    // Any tap puts the card away first, rather than also turning a page.
    if (_lookup != null) {
      _dismissLookup();
      return true;
    }

    // Never steal a tap that lands on text the reader has selected — that's
    // their selection, and Phase 4 hangs off it.
    if (details.tapOn == PdfViewerPart.selectedText) return false;

    final width = MediaQuery.of(context).size.width;
    final x = details.localPosition.dx;
    const edge = 0.22;

    if (x < width * edge) {
      _goToPage(_pageNumber - 1);
      return true;
    }
    if (x > width * (1 - edge)) {
      _goToPage(_pageNumber + 1);
      return true;
    }

    setState(() => _chromeVisible = !_chromeVisible);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // The reader must not depend on the library screen having run first:
    // storage has to be ready before a book row can become a file path.
    // startupProvider is cached, so this resolves instantly once it has run.
    final startup = ref.watch(startupProvider);

    return Scaffold(
      backgroundColor: Paper.ground,
      body: startup.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't open your library.\n$e")),
        data: (_) => _viewer(),
      ),
    );
  }

  Widget _viewer() {
    return FutureBuilder<Book>(
      future: _book,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final book = snapshot.data;
        if (book == null) {
          return const Center(child: Text('That book is no longer here.'));
        }

        final path = ref.read(bookRepositoryProvider).pdfPathOf(book);

        return Stack(
          children: [
            Positioned.fill(
              child: PdfViewer.file(
                path,
                controller: _controller,
                // pdfrx numbers pages from 1, and so does the database.
                initialPageNumber: book.lastPage,
                params: PdfViewerParams(
                  backgroundColor: Paper.ground,
                  margin: 16,
                  layoutPages: layoutPagesHorizontally,
                  // maxPagesVisible: 1 makes "fit one page" the furthest you
                  // can zoom out, so a page always fills the screen.
                  sizeDelegateProvider:
                      const PdfViewerSizeDelegateProviderSmart(
                        maxPagesVisible: 1,
                      ),
                  onViewerReady: (document, controller) {
                    _fitZoom = controller.currentZoom;
                    // Cached word boxes are in document coordinates, which a
                    // re-layout invalidates.
                    _pageWords.clear();
                  },
                  // pdfrx's built-in "Select All" paints a selection across
                  // every page at once. On a book with text-free pages — 46 of
                  // the 137 in the sample book — it asks an empty fragment list
                  // for its last element and brings down the painter. Take the
                  // item off the menu until Phase 4 replaces this toolbar.
                  customizeContextMenuItems: (params, items) {
                    items.removeWhere(
                      (item) => item.type == ContextMenuButtonType.selectAll,
                    );
                    // Phase 5 wires this to the model. It is here now so the
                    // toolbar's final shape is settled before anything depends
                    // on it.
                    if (params.textSelectionDelegate.hasSelectedText) {
                      items.add(
                        ContextMenuButtonItem(
                          label: 'Explain',
                          onPressed: _explainSelection,
                        ),
                      );
                    }
                  },
                  onPageChanged: _onPageChanged,
                  onInteractionEnd: _snapToNearestPage,
                  onGeneralTap: _onTap,
                ),
              ),
            ),
            if (_lookup != null)
              WordCard(lookup: _lookup!, onDismiss: _dismissLookup),
            ReaderChrome(
              visible: _chromeVisible,
              title: book.title,
              pageNumber: _pageNumber,
              pageCount: _pageCount,
              onSeek: _goToPage,
            ),
          ],
        );
      },
    );
  }
}
