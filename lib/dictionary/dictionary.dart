import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'morphy.dart';

/// One meaning of a word.
class Definition {
  const Definition({
    required this.lemma,
    required this.partOfSpeech,
    required this.gloss,
    this.tagCount = 0,
  });

  /// The base form the meaning was found under: `conversation` for
  /// `conversations`. Shown when it differs from what was pressed, so it's
  /// never a mystery why a different word appears in the card.
  final String lemma;

  /// `noun`, `verb`, `adjective` or `adverb`.
  final String partOfSpeech;

  final String gloss;

  /// How often this sense is the one meant, in WordNet's tagged corpus.
  /// Zero for the great majority of senses, which were never tagged.
  final int tagCount;
}

/// The offline dictionary: WordNet 3.1, bundled with the app.
///
/// Instant, free, and works on a plane. Phase 5 adds "what does it mean *here*"
/// on top; this answers "what does it mean" at all.
class Dictionary {
  Dictionary._(this._db);

  final Database _db;

  static const _asset = 'assets/dictionary/wordnet.sqlite';

  static const _posNames = {
    'n': 'noun',
    'v': 'verb',
    'a': 'adjective',
    'r': 'adverb',
  };

  /// Copies the bundled database out of the app bundle on first run.
  ///
  /// Flutter assets aren't files on disk, and SQLite needs a real path.
  static Future<Dictionary> open() async {
    final documents = await getApplicationDocumentsDirectory();
    final file = File(p.join(documents.path, 'wordnet.sqlite'));

    if (!await file.exists()) {
      final data = await rootBundle.load(_asset);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    return Dictionary._(sqlite3.open(file.path, mode: OpenMode.readOnly));
  }

  /// Opens a dictionary file directly. Used by tests, which have the built
  /// asset on disk and no app bundle to copy it out of.
  static Dictionary openFile(String path) =>
      Dictionary._(sqlite3.open(path, mode: OpenMode.readOnly));

  void close() => _db.close();

  /// Meanings of [word], or an empty list if the dictionary has never heard of
  /// it. An empty list is a normal answer — proper nouns, foreign words and
  /// numbers are all absent — and callers must not treat it as an error.
  List<Definition> lookup(String word) {
    final cleaned = word.trim().toLowerCase();
    if (cleaned.isEmpty) return const [];

    // Gather across every part of speech before choosing, rather than taking
    // whichever part of speech is tried first. Trying nouns first meant that
    // pressing "are" returned a unit of area rather than the verb "be".
    final found = <Definition>[];
    for (final pos in Morphy.partsOfSpeech) {
      for (final candidate in _candidatesFor(cleaned, pos)) {
        final senses = _sensesFor(candidate, pos);
        if (senses.isNotEmpty) {
          found.addAll(senses);
          break; // the first candidate that exists is this part of speech's answer
        }
      }
    }
    if (found.isEmpty) return const [];

    // Most-used sense first. WordNet tagged only a fraction of its senses, so
    // ties are common; those keep WordNet's own ordering, which already puts
    // the more familiar sense first.
    found.sort((a, b) => b.tagCount.compareTo(a.tagCount));
    return found.take(6).toList();
  }

  /// WordNet's exception list first, then the regular detachment rules.
  List<String> _candidatesFor(String word, String pos) {
    final exceptions = _db.select(
      'SELECT base FROM exceptions WHERE inflected = ? AND pos = ?',
      [word, pos],
    );

    return [
      for (final row in exceptions) row['base'] as String,
      ...Morphy.candidates(word, pos),
    ];
  }

  List<Definition> _sensesFor(String lemma, String pos) {
    final rows = _db.select(
      'SELECT lemma, pos, gloss, tag_count FROM senses '
      'WHERE lemma = ? AND pos = ? ORDER BY rank',
      [lemma, pos],
    );

    return [
      for (final row in rows)
        Definition(
          lemma: row['lemma'] as String,
          partOfSpeech: _posNames[row['pos'] as String] ?? '',
          gloss: row['gloss'] as String,
          tagCount: row['tag_count'] as int,
        ),
    ];
  }
}
