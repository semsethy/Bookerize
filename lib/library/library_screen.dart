import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/book_repository.dart';
import '../data/providers.dart';
import '../reader/reader_screen.dart';
import '../theme.dart';

/// ConsumerWidget is Riverpod's StatelessWidget: the extra `ref` argument is
/// how a widget reads shared state, and watching a provider rebuilds the widget
/// whenever that state changes.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupProvider);
    final library = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Library',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 28,
            letterSpacing: -0.6,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _import(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Add a book',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: startup.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            _Message(title: "Couldn't open your library", detail: '$e'),
        data: (_) => library.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _Message(title: "Couldn't read your library", detail: '$e'),
          data: (books) => books.isEmpty
              ? const _Message(
                  title: 'No books yet',
                  detail: 'Tap + to add a PDF from Files or iCloud Drive.',
                )
              : _Shelf(books: books),
        ),
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = picked?.path;
    if (path == null) return;

    final outcome = await ref.read(bookRepositoryProvider).importFrom(path);
    if (!context.mounted) return;

    final message = switch (outcome.result) {
      ImportResult.added when !outcome.hasTextLayer =>
        '${outcome.title} added. It has no text layer, so word lookup and '
            'explanations will not work on it.',
      ImportResult.added => '${outcome.title} added.',
      ImportResult.alreadyPresent =>
        '${outcome.title} is already on your shelf.',
      ImportResult.failed => "That file couldn't be opened as a PDF.",
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: outcome.hasTextLayer
            ? const Duration(seconds: 3)
            : const Duration(seconds: 6),
      ),
    );
  }
}

class _Shelf extends ConsumerWidget {
  const _Shelf({required this.books});

  final List<Book> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 18,
        mainAxisSpacing: 24,
        childAspectRatio: 0.50,
      ),
      itemCount: books.length,
      itemBuilder: (context, i) => _BookTile(book: books[i]),
    );
  }
}

class _BookTile extends ConsumerWidget {
  const _BookTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(bookRepositoryProvider);
    final coverPath = repo.coverPathOf(book);
    final finished = book.lastPage >= book.pageCount;
    final progress = book.pageCount == 0 ? 0.0 : book.lastPage / book.pageCount;
    final started = book.lastOpenedAt != null;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ReaderScreen(bookId: book.id)),
      ),
      onLongPress: () => _confirmRemove(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x38000000),
                    blurRadius: 16,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: coverPath != null && File(coverPath).existsSync()
                    // contain, not cover: page proportions differ book to book,
                    // and cropping eats the title off the edges.
                    ? ColoredBox(
                        color: Colors.white,
                        child: Image.file(File(coverPath), fit: BoxFit.contain),
                      )
                    : const ColoredBox(
                        color: Color(0xFF17181C),
                        child: Center(
                          child: Icon(
                            Icons.menu_book_outlined,
                            color: Colors.white38,
                            size: 34,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
              letterSpacing: -0.1,
              color: Paper.ink,
            ),
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: started ? progress.clamp(0.0, 1.0) : 0,
              minHeight: 3,
              backgroundColor: Paper.rule,
              valueColor: AlwaysStoppedAnimation(
                finished ? Paper.marker : Paper.ink,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Real page numbers, not a percentage — "p. 47 / 137" tells you
          // something about how much book is left; "34%" doesn't.
          Text(
            !started
                ? 'Not started'
                : finished
                ? 'Finished'
                : 'p. ${book.lastPage} / ${book.pageCount}',
            style: const TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.4,
              color: Paper.soft,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${book.title}?'),
        content: const Text(
          'The PDF and your place in it are deleted from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(bookRepositoryProvider).remove(book);
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Paper.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Paper.soft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
