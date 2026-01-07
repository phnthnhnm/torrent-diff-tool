import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
        title: const Text("Comic Torrent Differ"),
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
          ],
        ),
      ),
    );
  }
}
