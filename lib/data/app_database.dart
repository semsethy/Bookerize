import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Drift generates the boring half of this file (the `_$AppDatabase` class, the
// `Book` data class, the companions) into app_database.g.dart. `part` glues the
// two together — regenerate with:
//   dart run build_runner build --delete-conflicting-outputs
part 'app_database.g.dart';

/// One row per imported book.
///
/// Paths are stored **relative** to the app's documents directory on purpose.
/// iOS hands the app a freshly-named container directory on some updates and on
/// every reinstall, so an absolute path saved today can point nowhere tomorrow.
/// Storing the bare file name and rebuilding the full path at read time survives
/// that; storing `/var/mobile/.../books/x.pdf` does not.
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 300)();

  /// File name inside `<documents>/books/`.
  TextColumn get fileName => text().unique()();

  /// File name inside `<documents>/covers/`. Null if the cover failed to render.
  TextColumn get coverFileName => text().nullable()();

  IntColumn get pageCount => integer()();

  /// 1-based, matching how pdfrx numbers pages.
  IntColumn get lastPage => integer().withDefault(const Constant(1))();

  /// False for scanned PDFs — no embedded text means no word lookup later.
  BoolColumn get hasTextLayer => boolean().withDefault(const Constant(true))();

  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [Books])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Most recently read first; never-opened books fall back to when they were added.
  ///
  /// `watch()` returns a Stream that re-emits whenever the underlying table
  /// changes, so the library screen updates itself after an import without
  /// anyone having to remember to refresh it.
  Stream<List<Book>> watchLibrary() {
    return (select(books)..orderBy([
          (b) => OrderingTerm.desc(coalesce([b.lastOpenedAt, b.addedAt])),
        ]))
        .watch();
  }

  Future<Book?> findByFileName(String fileName) {
    return (select(
      books,
    )..where((b) => b.fileName.equals(fileName))).getSingleOrNull();
  }

  Future<Book> bookById(int id) {
    return (select(books)..where((b) => b.id.equals(id))).getSingle();
  }

  Future<int> insertBook(BooksCompanion book) => into(books).insert(book);

  /// Written on every page turn, so force-quitting never costs you your place.
  Future<void> saveLastPage(int id, int page) {
    return (update(books)..where((b) => b.id.equals(id))).write(
      BooksCompanion(
        lastPage: Value(page),
        lastOpenedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteBook(int id) =>
      (delete(books)..where((b) => b.id.equals(id))).go();
}

QueryExecutor _openConnection() {
  // LazyDatabase defers opening the file until the first query, so we can do
  // the async documents-directory lookup without making the constructor async.
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    return NativeDatabase.createInBackground(
      File(p.join(dir.path, 'bookerize.sqlite')),
    );
  });
}
