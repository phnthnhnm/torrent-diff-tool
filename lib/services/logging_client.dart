import 'dart:async';

import 'package:http/http.dart' as http;

class LoggingClient extends http.BaseClient {
  final http.Client _inner;

  LoggingClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final safeHeaders = Map<String, String>.from(request.headers);
    safeHeaders.remove('Cookie');
    safeHeaders.remove('Authorization');

    print('➡ ${request.method} ${request.url}');
    print('Headers: $safeHeaders');

    // Log body for simple Request
    try {
      if (request is http.Request) {
        final body = request.body;
        if (body.isNotEmpty) {
          final snippet = body.length > 2000
              ? '${body.substring(0, 2000)}...'
              : body;
          print('Body: $snippet');
        }
      } else if (request is http.MultipartRequest) {
        print('Multipart fields: ${request.fields}');
        print(
          'Multipart files: ${request.files.map((f) => f.filename).toList()}',
        );
      }
    } catch (e) {
      print('Failed to read request body for logging: $e');
    }

    final start = DateTime.now();
    final streamed = await _inner.send(request);
    final response = await http.Response.fromStream(streamed);
    final elapsed = DateTime.now().difference(start);

    final bodySnippet = response.body.length > 2000
        ? '${response.body.substring(0, 2000)}...'
        : response.body;
    print(
      '⬅ ${response.statusCode} ${request.url} (${elapsed.inMilliseconds}ms)',
    );
    print('Response headers: ${response.headers}');
    print('Response body: $bodySnippet');

    // Reconstruct StreamedResponse so callers can still read the body
    return http.StreamedResponse(
      Stream.fromIterable([response.bodyBytes]),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: response.request,
    );
  }

  @override
  void close() => _inner.close();
}
