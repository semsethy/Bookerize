import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'book_repository.dart';

/// Riverpod holds one instance of each of these for the whole app and hands it
/// to any widget that asks. That's the whole idea: no passing objects down
/// through constructors, and no global variables either.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(ref.watch(databaseProvider));
});

/// Runs once at launch: makes the storage folders and copies in any bundled book.
final startupProvider = FutureProvider<void>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  await repo.init();
  await repo.seedBundledBooks();
});

/// A live view of the shelf. Because it's a Stream from Drift, importing a book
/// updates the library screen on its own.
final libraryProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(databaseProvider).watchLibrary();
});
