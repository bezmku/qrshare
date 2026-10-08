import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrshare/services/qr_payload.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});
  @override
  State<StatefulWidget> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final QrPayload _payload;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan to connect')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(data: _payload.encode(), size: 280),
            const SizedBox(height: 24),
            Text('Session: ${_payload.sid}'),
            const SizedBox(height: 8),
            const Text(
              'Hotspot: (not started yet)',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
