import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Something went wrong in a way worth telling the reader about.
class AiException implements Exception {
  const AiException(this.message);

  /// Written for a reader, not a developer: what happened, and what to do.
  final String message;

  @override
  String toString() => message;
}

/// Talks to the Bookerize proxy.
///
/// It never sees a Gemini key, a model name, or a prompt — those all live in
/// the Worker, so changing any of them is a redeploy rather than an App Store
/// release. All this knows is: send a question, receive text as it arrives.
class AiClient {
  AiClient({required this.baseUrl, required this.token, Dio? dio})
    : _dio = dio ?? Dio();

  final String baseUrl;
  final String token;
  final Dio _dio;

  /// What a word means in the sentence it was found in.
  Stream<String> wordInContext({
    required String word,
    required String sentence,
  }) {
    return _stream('/v1/word', {'word': word, 'sentence': sentence});
  }

  /// The same sentence, in plainer English.
  Stream<String> explainSentence({required String sentence}) {
    return _stream('/v1/explain', {'sentence': sentence});
  }

  Stream<String> _stream(String path, Map<String, Object?> body) async* {
    late final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        '$baseUrl$path',
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'authorization': 'Bearer $token',
            // Without this the server may gzip the stream, and dio does not
            // decompress it for ResponseType.stream — the bytes then parsed to
            // nothing and the card sat there empty. Compressing an event
            // stream also buffers it, defeating the point of streaming.
            'accept-encoding': 'identity',
          },
          // The proxy caps the answer length, so a slow reply is a broken one.
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 20),
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (error) {
      throw AiException(_networkMessage(error));
    }

    final status = response.statusCode ?? 0;
    if (status != 200) {
      throw AiException(await _statusMessage(status, response.data));
    }

    final body_ = response.data;
    if (body_ == null) throw const AiException('The answer never arrived.');

    var produced = false;
    await for (final text in _parseSse(body_.stream)) {
      produced = true;
      yield text;
    }

    if (!produced) {
      // Silence means something upstream changed shape. Say so, rather than
      // leaving the reader looking at a blank card wondering.
      throw const AiException('The answer came back empty. Try again.');
    }
  }

  /// Turns the proxy's `data:` lines back into text.
  ///
  /// The proxy already flattened Gemini's several event types down to one
  /// shape, so there is only `{"text":...}`, `{"error":...}` and `[DONE]`.
  Stream<String> _parseSse(Stream<List<int>> bytes) async* {
    var buffer = '';

    await for (final chunk in bytes) {
      buffer += utf8.decode(chunk, allowMalformed: true);

      var split = buffer.indexOf('\n\n');
      while (split != -1) {
        final block = buffer.substring(0, split);
        buffer = buffer.substring(split + 2);

        for (final line in block.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          final payload = line.substring(6).trim();
          if (payload == '[DONE]') return;

          final decoded = _decode(payload);
          final error = decoded?['error'];
          if (error is String) throw AiException(error);

          final text = decoded?['text'];
          if (text is String && text.isNotEmpty) yield text;
        }
        split = buffer.indexOf('\n\n');
      }
    }
  }

  Map<String, Object?>? _decode(String payload) {
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      // A half-written payload is not worth failing the whole answer over.
      return null;
    }
  }

  String _networkMessage(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionError || DioExceptionType.connectionTimeout =>
        'No connection. The dictionary above still works.',
      DioExceptionType.receiveTimeout || DioExceptionType.sendTimeout =>
        'That took too long. Try again in a moment.',
      DioExceptionType.cancel => 'Cancelled.',
      _ => 'Could not reach the server.',
    };
  }

  Future<String> _statusMessage(int status, ResponseBody? body) async {
    if (status == 401) {
      return 'This copy of the app is not set up to ask. Check its token.';
    }
    if (status == 429) {
      return 'Slow down a moment and try again.';
    }
    if (status >= 500) {
      return 'The server is having trouble. Try again shortly.';
    }
    return 'That request was refused ($status).';
  }
}
