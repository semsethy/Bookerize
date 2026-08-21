@TestOn('mac-os')
library;

import 'package:bookerize/ai/ai_client.dart';
import 'package:bookerize/ai/explainer.dart';
import 'package:bookerize/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A client that records what it was asked and replays a fixed answer.
class RecordingClient extends AiClient {
  RecordingClient({this.answer = const ['a', 'b']})
    : super(baseUrl: 'http://unused', token: 'unused');

  final List<String> answer;
  int calls = 0;

  @override
  Stream<String> wordInContext({
    required String word,
    required String sentence,
  }) async* {
    calls++;
    yield* Stream.fromIterable(answer);
  }

  @override
  Stream<String> explainSentence({required String sentence}) async* {
    calls++;
    yield* Stream.fromIterable(answer);
  }
}

void main() {
  late AppDatabase db;
  late RecordingClient client;
  late Explainer explainer;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = RecordingClient();
    explainer = Explainer(database: db, client: client);
  });

  tearDown(() => db.close());

  test('the first ask reaches the model', () async {
    final answer = await explainer
        .wordInContext(word: 'reciprocity', sentence: 'A sentence.')
        .join();

    expect(answer, 'ab');
    expect(client.calls, 1);
  });

  test('the same question is never asked twice', () async {
    await explainer
        .wordInContext(word: 'reciprocity', sentence: 'A sentence.')
        .drain<void>();
    final second = await explainer
        .wordInContext(word: 'reciprocity', sentence: 'A sentence.')
        .join();

    expect(second, 'ab', reason: 'the cached answer should come back whole');
    expect(client.calls, 1, reason: 'the second look must cost nothing');
  });

  test(
    'the same word in a different sentence is a different question',
    () async {
      // The whole point of the feature is that context changes the answer.
      await explainer
          .wordInContext(word: 'pause', sentence: 'One sentence.')
          .drain<void>();
      await explainer
          .wordInContext(word: 'pause', sentence: 'A different sentence.')
          .drain<void>();

      expect(client.calls, 2);
    },
  );

  test('a word answer and a sentence answer do not collide', () async {
    await explainer.wordInContext(word: 'x', sentence: 'S').drain<void>();
    await explainer.explainSentence(sentence: 'S').drain<void>();

    expect(client.calls, 2);
  });

  test(
    'a failed answer is not cached, so a bad moment is not permanent',
    () async {
      final failing = _FailingClient();
      final e = Explainer(database: db, client: failing);

      await expectLater(
        e.explainSentence(sentence: 'A sentence.').toList(),
        throwsA(isA<AiException>()),
      );

      // Now it works; the earlier failure must not have been remembered.
      final working = RecordingClient(answer: const ['fine']);
      final e2 = Explainer(database: db, client: working);
      expect(await e2.explainSentence(sentence: 'A sentence.').join(), 'fine');
    },
  );

  test('an empty answer is not cached either', () async {
    final empty = RecordingClient(answer: const ['', '   ']);
    final e = Explainer(database: db, client: empty);
    await e.explainSentence(sentence: 'A sentence.').drain<void>();

    final working = RecordingClient(answer: const ['real answer']);
    final e2 = Explainer(database: db, client: working);
    expect(
      await e2.explainSentence(sentence: 'A sentence.').join(),
      'real answer',
    );
  });

  test(
    'with no proxy configured it says so instead of failing obscurely',
    () async {
      final unconfigured = Explainer(database: db, client: null);

      expect(unconfigured.isAvailable, isFalse);
      await expectLater(
        unconfigured.explainSentence(sentence: 'A sentence.').toList(),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('dictionary'),
          ),
        ),
      );
    },
  );

  test('a cached answer is available with no client at all', () async {
    // Which is what "works on a plane" means in practice.
    await explainer.explainSentence(sentence: 'A sentence.').drain<void>();

    final offline = Explainer(database: db, client: null);
    expect(await offline.explainSentence(sentence: 'A sentence.').join(), 'ab');
  });
}

class _FailingClient extends AiClient {
  _FailingClient() : super(baseUrl: 'http://unused', token: 'unused');

  @override
  Stream<String> explainSentence({required String sentence}) async* {
    yield 'half an ';
    throw const AiException('The answer stopped early.');
  }
}
