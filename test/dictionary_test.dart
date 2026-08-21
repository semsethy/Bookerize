@TestOn('mac-os')
library;

import 'dart:io';

import 'package:bookerize/dictionary/dictionary.dart';
import 'package:bookerize/dictionary/morphy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Morphy', () {
    test('keeps the word itself as the first candidate', () {
      // "bus" is not the plural of "bu".
      expect(Morphy.candidates('bus', 'n').first, 'bus');
    });

    test('strips regular plurals', () {
      expect(Morphy.candidates('conversations', 'n'), contains('conversation'));
      expect(Morphy.candidates('boxes', 'n'), contains('box'));
      expect(Morphy.candidates('stories', 'n'), contains('story'));
    });

    test('strips verb endings', () {
      expect(Morphy.candidates('talked', 'v'), contains('talk'));
      expect(Morphy.candidates('listening', 'v'), contains('listen'));
      expect(Morphy.candidates('carries', 'v'), contains('carry'));
    });

    test('undoubles a consonant before -ing and -ed', () {
      expect(Morphy.candidates('running', 'v'), contains('run'));
      expect(Morphy.candidates('stopped', 'v'), contains('stop'));
    });

    test('never strips a word down to nothing', () {
      for (final pos in Morphy.partsOfSpeech) {
        for (final candidate in Morphy.candidates('is', pos)) {
          expect(candidate.length, greaterThanOrEqualTo(2));
        }
      }
    });
  });

  group('Dictionary', () {
    final file = File('assets/dictionary/wordnet.sqlite');
    if (!file.existsSync()) {
      test(
        'dictionary checks (skipped: run tool/build_wordnet.py)',
        () {},
        skip: true,
      );
      return;
    }

    late Dictionary dictionary;
    setUpAll(() => dictionary = Dictionary.openFile(file.path));
    tearDownAll(() => dictionary.close());

    test('finds a word as written', () {
      final results = dictionary.lookup('reciprocity');

      expect(results, isNotEmpty);
      expect(results.first.partOfSpeech, 'noun');
      expect(results.first.gloss, contains('mutual'));
    });

    test('finds a plural under its singular', () {
      final results = dictionary.lookup('conversations');

      expect(results, isNotEmpty);
      expect(results.first.lemma, 'conversation');
    });

    test('finds an irregular form through the exception list', () {
      expect(dictionary.lookup('geese').first.lemma, 'goose');
      expect(dictionary.lookup('ran').first.lemma, 'run');
    });

    test('is not case sensitive — headings are shouted', () {
      // Long-pressing "T H E  B O O K" hands us "BOOK".
      expect(dictionary.lookup('BOOK'), isNotEmpty);
      expect(dictionary.lookup('Book').first.lemma, 'book');
    });

    test('an unknown word returns nothing, and that is not an error', () {
      // Proper nouns and foreign words are simply absent.
      expect(dictionary.lookup('Tschäppeler'), isEmpty);
      expect(dictionary.lookup('zzqxwv'), isEmpty);
      expect(dictionary.lookup(''), isEmpty);
    });

    test('numerals are in WordNet, which is harmless', () {
      // Long-pressing "44" in "44 IDEAS" gives "being four more than forty".
      // Odd, but it is a real answer and not worth suppressing.
      expect(dictionary.lookup('44'), isNotEmpty);
    });

    test(
      'picks the sense a reader meant, not the first part of speech tried',
      () {
        // The bug this guards: trying nouns first made "are" resolve to
        // "a unit of surface area equal to 100 square meters".
        final are = dictionary.lookup('are');

        expect(are, isNotEmpty);
        expect(are.first.lemma, 'be');
        expect(are.first.partOfSpeech, 'verb');
        expect(are.first.gloss, isNot(contains('surface area')));
      },
    );

    test('common words resolve to their common sense', () {
      expect(dictionary.lookup('was').first.lemma, 'be');
      expect(dictionary.lookup('said').first.lemma, 'say');
      expect(dictionary.lookup('people').first.partOfSpeech, 'noun');
    });

    test('returns senses in WordNet order, most common first', () {
      final results = dictionary.lookup('listen');

      expect(results.length, greaterThan(1));
      expect(results.first.gloss, contains('hear'));
    });
  });
}
