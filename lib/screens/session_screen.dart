import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrshare/services/qr_payload.dart';
import 'package:qrshare/services/transfer_client.dart';
import 'package:qrshare/services/transfer_server.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.files});

  final List<PlatformFile> files;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final QrPayload _payload;
  bool _running = false;
  bool _done = false;
  String? _error;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    final rand = Random.secure();
    final sid = List.generate(
      8,
      (_) => rand.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _payload = QrPayload(ssid: 'QRShare-TEST', pass: 'testpass123', sid: sid);
  }

  Future<void> _runLoopback() async {
    setState(() {
      _running = true;
      _done = false;
      _error = null;
      _progress = 0;
    });
    try {
      final server = TransferServer(files: widget.files)
        ..onProgress = (sent, total) => _setProgress(sent / total);
      final listening = await server.bind();
      final serveFuture = server.serve(listening, _payload.sid);

      final docs = await getApplicationDocumentsDirectory();
      final clientFuture = TransferClient().receive(
        host: '127.0.0.1',
        sessionId: _payload.sid,
        saveDir: docs.path,
        onProgress: (received, total) => _setProgress(received / total),
      );

      await Future.wait([serveFuture, clientFuture]);
      if (mounted) {
        setState(() {
          _running = false;
          _done = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _running = false;
          _error = e.toString();
        });
      }
    }
  }

  void _setProgress(double pct) {
    final newPct = (pct * 100).floor();
    if (newPct != (_progress * 100).floor() && mounted) {
      setState(() => _progress = pct);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSize = widget.files.fold<int>(
      0,
      (s, f) => s + (f.lengthSync() ?? 0),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Scan to connect')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: QrImageView(data: _payload.encode(), size: 240)),
          const SizedBox(height: 16),
          Center(child: Text('Session: ${_payload.sid}')),
          const SizedBox(height: 24),
          Text('${widget.files.length} file(s) · ${totalSize} bytes'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _running ? null : _runLoopback,
            child: const Text('Run transfer test (loopback)'),
          ),
          if (_running) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text('${(_progress * 100).toStringAsFixed(0)}%'),
          ],
          if (_done) ...[
            const SizedBox(height: 16),
            const Text(
              'Transfer complete — hashes verified',
              style: TextStyle(color: Colors.green),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
