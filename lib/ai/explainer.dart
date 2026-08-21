import 'dart:async';

import '../data/app_database.dart';
import 'ai_client.dart';
import 'ai_config.dart';

/// Asks the model, but only ever once per question.
///
/// Every answer is stored against the exact question that produced it. Ask
/// again — next week, on a train, with no signal — and it comes straight back
/// from the database: instant and free. That is what makes the feature
/// something you use freely rather than ration.
class Explainer {
  Explainer({required AppDatabase database, AiClient? client})
    : _db = database,
      _client =
          client ??
          (AiConfig.isConfigured
              ? AiClient(baseUrl: AiConfig.baseUrl, token: AiConfig.token)
              : null);

  final AppDatabase _db;
  final AiClient? _client;

  /// False on a build with no proxy configured. The UI asks first and offers
  /// nothing it cannot deliver.
  bool get isAvailable => _client != null;

  /// What [word] means inside [sentence].
  Stream<String> wordInContext({
    required String word,
    required String sentence,
  }) {
    return _askOnce(
      kind: 'word',
      question: '$word|$sentence',
      ask: () => _client!.wordInContext(word: word, sentence: sentence),
    );
  }

  /// [sentence], in plainer English.
  Stream<String> explainSentence({required String sentence}) {
    return _askOnce(
      kind: 'sentence',
      question: sentence,
      ask: () => _client!.explainSentence(sentence: sentence),
    );
  }

  Stream<String> _askOnce({
    required String kind,
    required String question,
    required Stream<String> Function() ask,
  }) async* {
    final id = '$kind|$question';

    final cached = await _db.cachedAnswer(id);
    if (cached != null) {
      // Deliberately whole, not re-typed chunk by chunk. Streaming exists to
      // hide latency; there is none to hide, and faking it would waste the
      // reader's time to look busy.
      yield cached;
      return;
    }

    if (_client == null) {
      throw const AiException(
        'This copy of the app has no server to ask. The dictionary above '
        'works either way.',
      );
    }

    final answer = StringBuffer();
    await for (final chunk in ask()) {
      answer.write(chunk);
      yield chunk;
    }

    final complete = answer.toString().trim();
    // Never cache an empty or failed answer — that would make one bad moment
    // permanent.
    if (complete.isNotEmpty) {
      await _db.cacheAnswer(id: id, kind: kind, answer: complete);
    }
  }
}
