import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/explainer.dart';
import '../dictionary/dictionary.dart';
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

/// The bundled offline dictionary. Opened once and kept for the app's lifetime;
/// a long-press should never wait on a file copy.
final dictionaryProvider = FutureProvider<Dictionary>((ref) async {
  final dictionary = await Dictionary.open();
  ref.onDispose(dictionary.close);
  return dictionary;
});

/// Runs once at launch: makes the storage folders and copies in any bundled book.
final startupProvider = FutureProvider<void>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  await repo.init();
  await repo.seedBundledBooks();
  // Get the dictionary out of the app bundle now rather than on first press.
  await ref.watch(dictionaryProvider.future);
});

/// Asks the model, through the proxy, and remembers every answer.
final explainerProvider = Provider<Explainer>((ref) {
  return Explainer(database: ref.watch(databaseProvider));
});

/// A live view of the shelf. Because it's a Stream from Drift, importing a book
/// updates the library screen on its own.
final libraryProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(databaseProvider).watchLibrary();
});
