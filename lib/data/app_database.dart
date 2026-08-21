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

/// Every answer the model has ever given, keyed by exactly what was asked.
///
/// Nothing is ever asked twice. A second look at the same word in the same
/// sentence is instant, free, and works with no signal — which is most of what
/// makes the feature feel cheap to use rather than something to ration.
class Explanations extends Table {
  /// `kind|word|sentence` — the whole question, so a different sentence is a
  /// different answer even for the same word.
  TextColumn get id => text()();

  /// `word` or `sentence`.
  TextColumn get kind => text()();

  TextColumn get answer => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Books, Explanations])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2 added the explanation cache. Existing readers keep their books and
      // their place; they just start with an empty cache.
      if (from < 2) await m.createTable(explanations);
    },
  );

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

  Future<String?> cachedAnswer(String id) async {
    final row = await (select(
      explanations,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    return row?.answer;
  }

  Future<void> cacheAnswer({
    required String id,
    required String kind,
    required String answer,
  }) {
    return into(explanations).insertOnConflictUpdate(
      ExplanationsCompanion.insert(
        id: id,
        kind: kind,
        answer: answer,
        createdAt: DateTime.now(),
      ),
    );
  }
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
