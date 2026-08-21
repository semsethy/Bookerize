import 'package:bookerize/data/app_database.dart';
import 'package:bookerize/data/book_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('titleFromFileName', () {
    test('turns a snake_case file name into a readable title', () {
      expect(
        BookRepository.titleFromFileName('the_communication_book_44_ideas.pdf'),
        'The Communication Book 44 Ideas',
      );
    });

    test('collapses separators and never returns an empty title', () {
      expect(BookRepository.titleFromFileName('a--b__c.pdf'), 'A B C');
      expect(BookRepository.titleFromFileName('.pdf'), 'Untitled');
    });
  });

  group('AppDatabase', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> addBook({required String fileName, int pages = 137}) {
      return db.insertBook(
        BooksCompanion.insert(
          title: 'A Book',
          fileName: fileName,
          pageCount: pages,
          addedAt: DateTime.now(),
        ),
      );
    }

    test('a new book starts on page 1 and counts as unopened', () async {
      final id = await addBook(fileName: 'one.pdf');
      final book = await db.bookById(id);

      expect(book.lastPage, 1);
      expect(book.lastOpenedAt, isNull);
    });

    test('the page you left is what you get back', () async {
      final id = await addBook(fileName: 'one.pdf');

      await db.saveLastPage(id, 47);

      // Reading it back is what the reader screen does on open.
      final reopened = await db.bookById(id);
      expect(reopened.lastPage, 47);
      expect(reopened.lastOpenedAt, isNotNull);
    });

    test('the same file cannot be added twice', () async {
      await addBook(fileName: 'one.pdf');
      expect(addBook(fileName: 'one.pdf'), throwsA(isA<Exception>()));
    });

    test(
      'findByFileName is how seeding avoids duplicating a bundled book',
      () async {
        await addBook(fileName: 'one.pdf');

        expect(await db.findByFileName('one.pdf'), isNotNull);
        expect(await db.findByFileName('two.pdf'), isNull);
      },
    );

    test('the library lists most recently read first', () async {
      final older = await addBook(fileName: 'older.pdf');
      final newer = await addBook(fileName: 'newer.pdf');

      await db.saveLastPage(older, 12);

      final shelf = await db.watchLibrary().first;
      expect(shelf.map((b) => b.id).toList(), [older, newer]);
    });

    test('removing a book takes it off the shelf', () async {
      final id = await addBook(fileName: 'one.pdf');
      await db.deleteBook(id);

      expect(await db.watchLibrary().first, isEmpty);
    });
  });
}
