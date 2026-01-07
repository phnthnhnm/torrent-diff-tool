import 'dart:io';

import 'package:dtorrent_parser/dtorrent_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/qbittorrent_service.dart';
import '../torrent_service.dart';
import '../widgets/file_row.dart';
import '../widgets/result_list.dart';
import 'settings/settings_screen.dart';

class DiffScreen extends StatefulWidget {
  const DiffScreen({super.key});

  @override
  State<DiffScreen> createState() => _DiffScreenState();
}

class _DiffScreenState extends State<DiffScreen> {
  final TorrentService _torrentService = TorrentService();

  String? _oldPath;
  String? _newPath;
  String? _inlineErrorMessage;

  List<String> _addedFiles = [];
  List<String> _removedFiles = [];
  bool _hasCompared = false;

  Future<void> _pickNewFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['torrent'],
    );

    if (result == null) return;
    final newPath = result.files.single.path;
    if (newPath == null) return;

    final prefs = await SharedPreferences.getInstance();
    final dataFolder = prefs.getString('data_folder');
    if (dataFolder == null) {
      setState(() {
        _newPath = newPath;
        _oldPath = null;
        _inlineErrorMessage = 'Data folder not set in Settings';
      });
      return;
    }

    final fileName = Uri.file(newPath).pathSegments.last;
    final candidate = dataFolder + Platform.pathSeparator + fileName;
    final exists = await File(candidate).exists();
    if (!exists) {
      setState(() {
        _newPath = newPath;
        _oldPath = null;
        _inlineErrorMessage = 'No matching old torrent found in data folder';
      });
      return;
    }

    setState(() {
      _newPath = newPath;
      _oldPath = candidate;
      _inlineErrorMessage = null;
    });
  }

  Future<void> _openInQbittorrent() async {
    if (_newPath == null) return;

    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('qbt_host');
    final portStr = prefs.getString('qbt_port');
    final username = prefs.getString('qbt_username') ?? '';
    final password = prefs.getString('qbt_password') ?? '';
    final useHttps = prefs.getBool('qbt_use_https') ?? false;

    if (host == null || portStr == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('qBittorrent settings not configured')),
        );
      }
      return;
    }

    final port = int.tryParse(portStr) ?? 8080;

    final qb = QBittorrentService();
    try {
      await qb.login(host, port, useHttps, username, password);

      final bytes = await File(_newPath!).readAsBytes();
      await qb.addTorrentBytes(host, port, useHttps, bytes, paused: true);

      final torrent = await Torrent.parseFromFile(_newPath!);
      final name = torrent.name;

      String? hash;
      for (var i = 0; i < 8; i++) {
        final list = await qb.getTorrents(host, port, useHttps);
        final found = list.firstWhere(
          (t) => t['name'] == name,
          orElse: () => {},
        );
        if (found.isNotEmpty) {
          hash = found['hash'] as String?;
          break;
        }
        await Future.delayed(const Duration(seconds: 1));
      }

      if (hash == null)
        throw Exception('Could not find torrent in qBittorrent');

      final files = await qb.getTorrentFiles(host, port, useHttps, hash);
      final allIds = files.map((f) => f['index'].toString()).join('|');

      // Deselect everything
      if (allIds.isNotEmpty) {
        await qb.setFilePriority(host, port, useHttps, hash, allIds, 0);
      }

      // Select added files (match by basename or suffix to handle path differences)
      final idsToKeep = <String>[];
      for (var f in files) {
        final qbName = f['name'] as String;
        final qbBase = p.basename(qbName);
        final matched = _addedFiles.any((added) {
          final addedBase = p.basename(added);
          return addedBase == qbBase || added.endsWith(qbName) || qbName.endsWith(addedBase);
        });
        if (matched) idsToKeep.add(f['index'].toString());
      }
      if (idsToKeep.isNotEmpty) {
        await qb.setFilePriority(
          host,
          port,
          useHttps,
          hash,
          idsToKeep.join('|'),
          1,
        );
      }

      await qb.startTorrents(host, port, useHttps, hash);

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Torrent added to qBittorrent')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('qBittorrent error: $e')));
    }
  }

  Future<void> _processDiff() async {
    if (_newPath == null) return;

    // Ensure data folder and old path still valid
    final prefs = await SharedPreferences.getInstance();
    final dataFolder = prefs.getString('data_folder');
    if (dataFolder == null) {
      setState(() {
        _oldPath = null;
        _inlineErrorMessage = 'Data folder not set in Settings';
      });
      return;
    }

    final fileName = Uri.file(_newPath!).pathSegments.last;
    final candidate = dataFolder + Platform.pathSeparator + fileName;
    final exists = await File(candidate).exists();
    if (!exists) {
      setState(() {
        _oldPath = null;
        _inlineErrorMessage = 'No matching old torrent found in data folder';
      });
      return;
    }

    try {
      final oldFiles = await _torrentService.getFilesFromTorrent(candidate);
      final newFiles = await _torrentService.getFilesFromTorrent(_newPath!);

      final result = _torrentService.compare(oldFiles, newFiles);
      if (!mounted) return;
      setState(() {
        _addedFiles = result['added']!;
        _removedFiles = result['removed']!;
        _hasCompared = true;
        _oldPath = candidate;
        _inlineErrorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error processing files: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Torrent Diff Tool"),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Report a Bug',
            onPressed: () async {
              final url = Uri.parse(
                'https://github.com/phnthnhnm/torrent_diff_tool/issues/new',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- Input Section ---
            FileRow(label: "New Torrent", path: _newPath, onPick: _pickNewFile),
            const SizedBox(height: 6),
            if (_inlineErrorMessage != null)
              Text(
                _inlineErrorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            if (_oldPath != null)
              Text(
                'Using old torrent: ${_oldPath != null ? Uri.file(_oldPath!).pathSegments.last : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: (_newPath != null) ? _processDiff : null,
              icon: const Icon(Icons.compare_arrows),
              label: const Text("Compare Torrents"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blueAccent,
              ),
            ),

            const Divider(height: 40),

            // --- Results Section ---
            Expanded(
              child: _hasCompared
                  ? ResultList(
                      addedFiles: _addedFiles,
                      removedFiles: _removedFiles,
                    )
                  : const Center(child: Text("Select files to see changes")),
            ),
            if (_hasCompared && _addedFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: ElevatedButton.icon(
                  onPressed: _openInQbittorrent,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in qBittorrent (select added files)'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
