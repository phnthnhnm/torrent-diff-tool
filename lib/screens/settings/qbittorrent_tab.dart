import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QBittorrentTab extends StatefulWidget {
  const QBittorrentTab({super.key});

  @override
  State<QBittorrentTab> createState() => _QBittorrentTabState();
}

class _QBittorrentTabState extends State<QBittorrentTab> {
  static const _hostKey = 'qbt_host';
  static const _portKey = 'qbt_port';
  static const _usernameKey = 'qbt_username';
  static const _passwordKey = 'qbt_password';
  static const _useHttpsKey = 'qbt_use_https';

  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _useHttps = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hostController.text = prefs.getString(_hostKey) ?? '';
      _portController.text = prefs.getString(_portKey) ?? '8080';
      _usernameController.text = prefs.getString(_usernameKey) ?? '';
      _passwordController.text = prefs.getString(_passwordKey) ?? '';
      _useHttps = prefs.getBool(_useHttpsKey) ?? false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, _hostController.text);
    await prefs.setString(_portKey, _portController.text);
    await prefs.setString(_usernameKey, _usernameController.text);
    await prefs.setString(_passwordKey, _passwordController.text);
    await prefs.setBool(_useHttpsKey, _useHttps);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('qBittorrent settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'qBittorrent WebUI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Host (IP or hostname)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _useHttps,
                  onChanged: (v) {
                    setState(() {
                      _useHttps = v ?? false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                const Text('Use HTTPS'),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
