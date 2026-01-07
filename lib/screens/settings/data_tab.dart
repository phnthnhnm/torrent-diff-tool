import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataTab extends StatefulWidget {
  const DataTab({super.key});

  @override
  State<DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<DataTab> {
  static const _key = 'data_folder';
  String? _folder;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _folder = prefs.getString(_key);
    });
  }

  Future<void> _pickFolder() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, result);
      setState(() {
        _folder = result;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data folder saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Folder',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_folder ?? 'Not set'),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Choose Folder'),
                onPressed: _pickFolder,
              ),
              const SizedBox(width: 12),
              if (_folder != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                  onPressed: () async {
                    try {
                      if (Platform.isWindows) {
                        Process.start('cmd', ['/C', 'start', '', _folder!]);
                      } else if (Platform.isMacOS) {
                        Process.start('open', [_folder!]);
                      } else {
                        Process.start('xdg-open', [_folder!]);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to open folder: $e')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
