import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/app_database.dart';
import '../data/providers.dart';
import '../theme.dart';

/// Opens a book at the page you left it on, and writes your position back on
/// every page turn.
///
/// The book is looked up by id rather than passed in as an object, so the page
/// this screen restores is always the one in the database — not a copy that
/// went stale while the library screen was on screen.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.bookId, super.key});

  final int bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final Future<Book> _book = _openBook();

  int? _lastSaved;

  /// Opening a book counts as reading it, even if you never turn a page.
  /// pdfrx only reports page changes the reader actually makes, so without this
  /// the shelf would still say "Not started" after a whole session.
  Future<Book> _openBook() async {
    final db = ref.read(databaseProvider);
    final book = await db.bookById(widget.bookId);
    _lastSaved = book.lastPage;
    await db.saveLastPage(book.id, book.lastPage);
    return book;
  }

  void _onPageChanged(int? pageNumber) {
    if (pageNumber == null || pageNumber == _lastSaved) return;
    _lastSaved = pageNumber;
    // Fire and forget: a page turn shouldn't wait on a disk write.
    ref.read(databaseProvider).saveLastPage(widget.bookId, pageNumber);
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
                // pdfrx numbers pages from 1, and so does the database.
                initialPageNumber: book.lastPage,
                params: PdfViewerParams(
                  backgroundColor: Paper.ground,
                  onPageChanged: _onPageChanged,
                ),
              ),
            ),
            // The page is the whole screen; the only chrome is a way back.
            Positioned(
              left: 4,
              top: MediaQuery.of(context).padding.top + 2,
              child: _BackButton(title: book.title),
            ),
          ],
        );
      },
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 7, 15, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chevron_left, size: 20, color: Paper.ink),
              const SizedBox(width: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Paper.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
