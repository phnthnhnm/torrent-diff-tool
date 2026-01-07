import 'dart:convert';

import 'package:http/http.dart' as http;

import 'logging_client.dart';

class QBittorrentService {
  final http.Client _client;
  String? _cookie;

  QBittorrentService([http.Client? client])
    : _client = client ?? LoggingClient();

  String _baseUrl(String host, int port, bool useHttps) =>
      '${useHttps ? 'https' : 'http'}://$host:$port';

  Future<void> login(
    String host,
    int port,
    bool useHttps,
    String username,
    String password,
  ) async {
    final base = _baseUrl(host, port, useHttps);
    final uri = Uri.parse('$base/api/v2/auth/login');
    final res = await _client.post(
      uri,
      body: {'username': username, 'password': password},
      headers: {'Referer': base},
    );
    if (res.statusCode != 200)
      throw Exception('qBittorrent login failed (${res.statusCode})');
    final setCookie = res.headers['set-cookie'];
    if (setCookie != null) {
      _cookie = setCookie.split(';').first;
    }
  }

  Future<void> addTorrentBytes(
    String host,
    int port,
    bool useHttps,
    List<int> bytes, {
    String? savePath,
    bool paused = true,
  }) async {
    final base = _baseUrl(host, port, useHttps);
    final uri = Uri.parse('$base/api/v2/torrents/add');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Referer'] = base;
    if (_cookie != null) request.headers['Cookie'] = _cookie!;
    request.files.add(
      http.MultipartFile.fromBytes(
        'torrents',
        bytes,
        filename: 'upload.torrent',
      ),
    );
    if (savePath != null) request.fields['savepath'] = savePath;
    request.fields['paused'] = paused ? 'true' : 'false';

    final streamed = await _client.send(request);
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200)
      throw Exception('Failed to add torrent (${resp.statusCode})');
  }

  Future<List<Map<String, dynamic>>> getTorrents(
    String host,
    int port,
    bool useHttps,
  ) async {
    final base = _baseUrl(host, port, useHttps);
    final uri = Uri.parse('$base/api/v2/torrents/info');
    final res = await _client.get(
      uri,
      headers: {'Referer': base, if (_cookie != null) 'Cookie': _cookie!},
    );
    if (res.statusCode != 200) throw Exception('Failed to get torrents');
    final List<dynamic> data = json.decode(res.body);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getTorrentFiles(
    String host,
    int port,
    bool useHttps,
    String hash,
  ) async {
    final base = _baseUrl(host, port, useHttps);
    final uri = Uri.parse('$base/api/v2/torrents/files?hash=$hash');
    final res = await _client.get(
      uri,
      headers: {'Referer': base, if (_cookie != null) 'Cookie': _cookie!},
    );
    if (res.statusCode != 200) throw Exception('Failed to get torrent files');
    final List<dynamic> data = json.decode(res.body);
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> setFilePriority(
    String host,
    int port,
    bool useHttps,
    String hash,
    String ids,
    int priority,
  ) async {
    final base = _baseUrl(host, port, useHttps);
    final uri = Uri.parse('$base/api/v2/torrents/filePrio');

    /// Set file priority. Use `index` field (recommended) when passing torrent file
    /// indexes as returned by `/torrents/files`.
    // Use 'id' as the form field name (server expects 'id' even when the
    // values are file 'index' numbers returned by /torrents/files).
    final res = await _client.post(
      uri,
      body: {'hash': hash, 'id': ids, 'priority': priority.toString()},
      headers: {'Referer': base, if (_cookie != null) 'Cookie': _cookie!},
    );
    if (res.statusCode != 200)
      throw Exception('Failed to set file priority (${res.statusCode})');
  }

  Future<void> startTorrents(
    String host,
    int port,
    bool useHttps,
    String hashes,
  ) async {
    final base = _baseUrl(host, port, useHttps);
    // Use POST for mutating API calls.
    final uriPost = Uri.parse('$base/api/v2/torrents/start');
    final res = await _client.post(
      uriPost,
      body: {'hashes': hashes},
      headers: {'Referer': base, if (_cookie != null) 'Cookie': _cookie!},
    );
    if (res.statusCode != 200)
      throw Exception('Failed to start torrent(s) (${res.statusCode})');
  }
}
