import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qrshare/services/download_saver.dart';
import 'package:qrshare/services/hotspot_service.dart';
import 'package:qrshare/services/qr_payload.dart';
import 'package:qrshare/services/transfer_client.dart';
import 'package:qrshare/services/wifi_permissions.dart';
import 'package:qrshare/theme.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  QrPayload? _payload;
  String? _error;
  String? _gateway;
  final List<Map<String, dynamic>> _received = [];
  TransferClient? _client;
  bool _busy = false;
  bool _cancelled = false;
  bool _done = false;
  double _progress = 0;

  @override
  void dispose() {
    _client?.cancel();
    HotspotService().leave();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_payload != null || _error != null || _busy || _done) return;
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

  void _setProgress(double pct) {
    final newPct = (pct * 100).floor();
    if (newPct != (_progress * 100).floor() && mounted) {
      setState(() => _progress = pct);
    }
  }

  void _cancel() {
    _cancelled = true;
    _client?.cancel();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  Future<void> _connectAndReceive() async {
    final payload = _payload;
    if (payload == null) return;
    setState(() {
      _busy = true;
      _cancelled = false;
      _error = null;
      _progress = 0;
      _received.clear();
    });
    try {
      final permissionIssue = await ensureWifiPermission();
      if (permissionIssue != null) throw StateError(permissionIssue);

      final gateway = await HotspotService()
          .join(ssid: payload.ssid, password: payload.pass);
      if (!mounted) return;
      setState(() => _gateway = gateway);

      final docs = await getApplicationDocumentsDirectory();
      _client = TransferClient();
      final result = await _client!.receive(
        host: gateway,
        sessionId: payload.sid,
        saveDir: docs.path,
        onProgress: (received, total) => _setProgress(received / total),
      );

      final files = (result['files'] as List).cast<Map<String, dynamic>>();
      final received = <Map<String, dynamic>>[];
      for (final file in files) {
        final localPath = file['path'] as String;
        final name = file['name'] as String;
        final publicUri = await DownloadSaver.publish(localPath, name);
        received.add({
          'name': name,
          'size': file['size'],
          'uri': publicUri ?? localPath,
          'public': publicUri != null,
        });
        if (publicUri != null) {
          try { await File(localPath).delete(); } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
        _received..clear()..addAll(received);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _cancelled ? 'Cancelled' : e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive files'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final payload = _payload;

    // ── Scanner view (before QR detected) ─────────────────────────────────
    if (payload == null) {
      return Stack(
        children: [
          MobileScanner(onDetect: _handleDetect),
          // Top overlay label
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kColorBg.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Text(
                'Point your camera at\nthe sender\'s QR code',
                style: TextStyle(
                    color: kColorText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Scan frame overlay
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: kColorAccent, width: 2.5),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // Error snack at bottom
          if (_error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: kColorError.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kColorError.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: kColorError, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: kColorError, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // ── Post-scan view ─────────────────────────────────────────────────────
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Session info card
        _InfoCard(children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: kColorAccent, size: 20),
              const SizedBox(width: 8),
              const Text('Session found',
                  style: TextStyle(
                      color: kColorText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const Divider(height: 24),
          _InfoRow(label: 'Network', value: payload.ssid, icon: Icons.wifi_rounded),
          const SizedBox(height: 12),
          _InfoRow(label: 'Session', value: payload.sid, icon: Icons.tag_rounded),
          const SizedBox(height: 12),
          _InfoRow(label: 'Port', value: '${payload.port}', icon: Icons.router_rounded),
        ]),
        const SizedBox(height: 20),

        // Gateway connected badge
        if (_gateway != null && !_done)
          _StatusBanner(
            icon: Icons.wifi_rounded,
            label: 'Connected via $_gateway',
            color: kColorAccent,
          ),
        if (_gateway != null && !_done) const SizedBox(height: 16),

        // Action buttons
        if (!_done) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _connectAndReceive,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kColorBg),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(_busy ? 'Receiving…' : 'Connect & receive'),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
              ),
            ),
          ],
        ],

        // Progress bar
        if (_busy || _progress > 0) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    color: kColorAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ],
          ),
        ],

        // Done state
        if (_done) ...[
          _StatusBanner(
            icon: Icons.check_circle_rounded,
            label: 'Received ${_received.length} file${_received.length == 1 ? '' : 's'} — hashes verified',
            color: kColorSuccess,
          ),
          const SizedBox(height: 8),
          _StatusBanner(
            icon: Icons.folder_rounded,
            label: 'Saved to Downloads',
            color: kColorAccent,
          ),
          const SizedBox(height: 20),
          ..._received.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: kColorSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kColorBgLight.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: kColorAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.insert_drive_file_rounded,
                            color: kColorAccent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f['name'] as String,
                              style: const TextStyle(
                                  color: kColorText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatSize(f['size'] as int),
                              style: TextStyle(
                                  color: kColorTextMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SmallIconBtn(
                            icon: Icons.open_in_new_rounded,
                            onPressed: (f['public'] as bool)
                                ? () => DownloadSaver.open(f['uri'] as String)
                                : null,
                          ),
                          const SizedBox(width: 4),
                          _SmallIconBtn(
                            icon: Icons.share_rounded,
                            onPressed: (f['public'] as bool)
                                ? () => DownloadSaver.share(f['uri'] as String)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],

        // Error
        if (_error != null) ...[
          const SizedBox(height: 16),
          _StatusBanner(
            icon: Icons.error_rounded,
            label: _error!,
            color: kColorError,
          ),
        ],
      ],
    );
  }
}

// ─── Shared small widgets ────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kColorBgLight.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kColorAccent),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: kColorTextMuted, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: kColorText, fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  const _SmallIconBtn({required this.icon, this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onPressed != null
              ? kColorAccent.withValues(alpha: 0.12)
              : kColorBgLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onPressed != null ? kColorAccent : kColorTextMuted,
        ),
      ),
    );
  }
}
