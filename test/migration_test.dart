@TestOn('mac-os')
library;

import 'dart:io';

import 'package:bookerize/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Upgrading must never cost a reader their library or their place in it.
///
/// Phase 5 added the explanation cache, taking the schema from v1 to v2. Anyone
/// who has been reading already has a v1 database on their phone, and this is
/// the only test that can tell us their books survive meeting the new one.
void main() {
  late Directory temp;
  late String path;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('bookerize_migration');
    path = '${temp.path}/bookerize.sqlite';

    // Build the database exactly as version 1 left it.
    final v1 = sqlite3.open(path);
    v1.execute('''
      CREATE TABLE books (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        file_name TEXT NOT NULL UNIQUE,
        cover_file_name TEXT NULL,
        page_count INTEGER NOT NULL,
        last_page INTEGER NOT NULL DEFAULT 1,
        has_text_layer INTEGER NOT NULL DEFAULT 1,
        added_at INTEGER NOT NULL,
        last_opened_at INTEGER NULL
      );
    ''');
    v1.execute('''
      INSERT INTO books (title, file_name, page_count, last_page, added_at, last_opened_at)
      VALUES ('The Communication Book', 'book.pdf', 137, 47, 1787000000, 1787000000);
    ''');
    v1.execute('PRAGMA user_version = 1;');
    v1.close();
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('a v1 library survives the upgrade with its page intact', () async {
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    final shelf = await db.watchLibrary().first;

    expect(shelf, hasLength(1));
    expect(shelf.single.title, 'The Communication Book');
    expect(shelf.single.lastPage, 47, reason: 'their place must not move');
    expect(shelf.single.pageCount, 137);
  });

  test('the upgrade adds the cache and it works', () async {
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    await db.cacheAnswer(id: 'word|x|y', kind: 'word', answer: 'an answer');

    expect(await db.cachedAnswer('word|x|y'), 'an answer');
    expect(await db.cachedAnswer('never asked'), isNull);
  });

  test('the schema version is left at 2', () async {
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    await db.watchLibrary().first; // force the migration to run
    await db.close();

    final raw = sqlite3.open(path);
    addTearDown(raw.close);

    expect(raw.select('PRAGMA user_version').first.values.first, 2);
  });

  test('opening twice does not run the migration again', () async {
    final first = AppDatabase.forTesting(NativeDatabase(File(path)));
    await first.cacheAnswer(id: 'a', kind: 'word', answer: 'kept');
    await first.close();

    final second = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(second.close);

    expect(
      await second.cachedAnswer('a'),
      'kept',
      reason: 'a second open must not recreate the table and lose the cache',
    );
  });
}
