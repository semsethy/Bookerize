@TestOn('mac-os')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bookerize/ai/ai_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the client against a real HTTP server speaking real SSE.
///
/// Streaming is the kind of thing that passes a mocked test and fails on a
/// socket, so this uses one.
class FakeProxy {
  late HttpServer _server;
  final requests = <({String path, Map<String, Object?> body, String? auth})>[];

  /// What the next request will be answered with.
  List<String> chunks = const [];
  int status = 200;
  String? midStreamError;

  /// Sends the SSE payload in pieces that do not line up with record
  /// boundaries, which is what a real socket does.
  bool splitAwkwardly = false;

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_serve());
  }

  Future<void> _serve() async {
    await for (final request in _server) {
      final raw = await utf8.decoder.bind(request).join();
      requests.add((
        path: request.uri.path,
        body: jsonDecode(raw) as Map<String, Object?>,
        auth: request.headers.value('authorization'),
      ));

      if (status != 200) {
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"error":"nope"}');
        await request.response.close();
        continue;
      }

      request.response.statusCode = 200;
      request.response.headers.set('content-type', 'text/event-stream');

      final buffer = StringBuffer();
      for (final chunk in chunks) {
        buffer.write('data: ${jsonEncode({'text': chunk})}\n\n');
      }
      if (midStreamError != null) {
        buffer.write('data: ${jsonEncode({'error': midStreamError})}\n\n');
      }
      buffer.write('data: [DONE]\n\n');

      final payload = buffer.toString();
      if (splitAwkwardly) {
        // Deliberately cut mid-JSON.
        for (var i = 0; i < payload.length; i += 7) {
          request.response.write(
            payload.substring(i, (i + 7).clamp(0, payload.length)),
          );
          await request.response.flush();
        }
      } else {
        request.response.write(payload);
      }
      await request.response.close();
    }
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  late FakeProxy proxy;
  late AiClient client;

  setUp(() async {
    proxy = FakeProxy();
    await proxy.start();
    client = AiClient(baseUrl: proxy.baseUrl, token: 'test-token');
  });

  tearDown(() => proxy.stop());

  test('streams the answer back in pieces', () async {
    proxy.chunks = ['It means ', 'give and take.'];

    final pieces = await client
        .wordInContext(word: 'reciprocity', sentence: 'A sentence.')
        .toList();

    expect(pieces, ['It means ', 'give and take.']);
    expect(pieces.join(), 'It means give and take.');
  });

  test('survives chunks split mid-payload', () async {
    // The failure this guards: half a JSON object parsed as if it were whole.
    proxy.chunks = ['The pause ', 'is where it begins.'];
    proxy.splitAwkwardly = true;

    final answer = await client.explainSentence(sentence: 'A sentence.').join();

    expect(answer, 'The pause is where it begins.');
  });

  test('sends the token and the question', () async {
    proxy.chunks = ['ok'];

    await client
        .wordInContext(word: 'reciprocity', sentence: 'That pause.')
        .drain<void>();

    final request = proxy.requests.single;
    expect(request.path, '/v1/word');
    expect(request.auth, 'Bearer test-token');
    expect(request.body['word'], 'reciprocity');
    expect(request.body['sentence'], 'That pause.');
  });

  test('explaining a sentence hits the other endpoint', () async {
    proxy.chunks = ['plainer'];

    await client.explainSentence(sentence: 'A hard one.').drain<void>();

    expect(proxy.requests.single.path, '/v1/explain');
    expect(proxy.requests.single.body, {'sentence': 'A hard one.'});
  });

  test('an error mid-stream surfaces as an exception', () async {
    // The proxy reports a late failure inside the stream, because the status
    // line has already gone out by then.
    proxy.chunks = ['partial '];
    proxy.midStreamError = 'The answer stopped early.';

    expect(
      client.explainSentence(sentence: 'A sentence.'),
      emitsInOrder(['partial ', emitsError(isA<AiException>())]),
    );
  });

  test('a refused token is explained in words a reader can act on', () async {
    proxy.status = 401;

    await expectLater(
      client.explainSentence(sentence: 'A sentence.').toList(),
      throwsA(
        isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('token'),
        ),
      ),
    );
  });

  test('being rate limited says so plainly', () async {
    proxy.status = 429;

    await expectLater(
      client.explainSentence(sentence: 'A sentence.').toList(),
      throwsA(
        isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('Slow down'),
        ),
      ),
    );
  });

  test('no connection points the reader back at the dictionary', () async {
    // Nothing listening on this port.
    final offline = AiClient(baseUrl: 'http://127.0.0.1:1', token: 't');

    await expectLater(
      offline.explainSentence(sentence: 'A sentence.').toList(),
      throwsA(
        isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('dictionary'),
        ),
      ),
    );
  });
}
