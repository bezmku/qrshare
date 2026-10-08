import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qrshare/services/qr_payload.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});
  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  QrPayload? _payload;
  String? _error;
  void _handleDetect(BarcodeCapture capture) {
    if (_payload != null || _error != null) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null) return;
    final decoded = QrPayload.decode(raw);
    if (decoded == null) {
      setState(() => _error = 'Not a QRShare QR code');
      return;
    }
    setState(() => _payload = decoded);
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: payload == null
          ? Stack(
              children: [
                MobileScanner(onDetect: _handleDetect),
                if (_error != null)
                  Align(
                    alignment: Alignment.bottomCenter,

                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.black.withValues(alpha: 0.7),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : _PayloadView(payload: payload),
    );
  }
}

class _PayloadView extends StatelessWidget {
  const _PayloadView({required this.payload});
  final QrPayload payload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Found a session!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text('Session: ${payload.sid}'),
          Text('Hotspot: ${payload.ssid}'),
          Text('Port: ${payload.port}'),
          const SizedBox(height: 24),
          const Text(
            '(Connecting comes in a later step)',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
