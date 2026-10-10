import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrshare/services/hotspot_service.dart';
import 'package:qrshare/services/qr_payload.dart';
import 'package:qrshare/services/transfer_client.dart';
import 'package:qrshare/services/transfer_server.dart';
import 'package:qrshare/theme.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.files});

  final List<PlatformFile> files;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final String _sid;
  QrPayload? _payload;
  HotspotCredentials? _creds;

  // Hotspot startup
  bool _starting = false;

  // Real transfer (waiting for receiver)
  bool _serving = false;
  bool _done = false;
  String? _error;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    final rand = Random.secure();
    _sid = List.generate(8, (_) => rand.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  @override
  void dispose() {
    HotspotService().stop();
    super.dispose();
  }

  int? _androidSdkInt() {
    final version = Platform.operatingSystemVersion;
    final match = RegExp(r'SDK (\d+)').firstMatch(version);
    return match == null ? null : int.parse(match.group(1)!);
  }

  Future<String?> _wifiPermission() async {
    final sdk = _androidSdkInt();
    if (sdk != null && sdk >= 33) {
      final ok = await Permission.nearbyWifiDevices.request().isGranted;
      if (!ok) return 'nearby';           // sentinel so UI can show "Open Settings"
    }
    final service = await Permission.location.serviceStatus;
    if (!service.isEnabled) {
      return 'Please enable Location in system settings and try again';
    }
    final ok = await Permission.location.request().isGranted;
    return ok ? null : 'Location permission is required to create a hotspot';
  }

  Future<void> _startHotspot() async {
    setState(() { _starting = true; _error = null; });
    try {
      final issue = await _wifiPermission();
      if (issue != null) throw StateError(issue);
      final creds = await HotspotService().start();
      if (!mounted) return;
      setState(() {
        _creds = creds;
        _payload = QrPayload(
          ssid: creds.ssid,
          pass: creds.password,
          sec: 'WPA2',
          port: 8888,
          sid: _sid,
        );
        _starting = false;
      });
    } catch (e) {
      if (mounted) setState(() { _starting = false; _error = e.toString(); });
    }
  }

  /// Starts the real transfer server and waits for the receiver to connect.
  Future<void> _waitForReceiver() async {
    final payload = _payload;
    if (payload == null) return;
    setState(() { _serving = true; _done = false; _error = null; _progress = 0; });
    try {
      final server = TransferServer(files: widget.files)
        ..onProgress = (sent, total) => _setProgress(sent / total);
      final listening = await server.bind();
      // Serve blocks until the receiver connects and finishes
      await server.serve(listening, payload.sid);
      if (mounted) setState(() { _serving = false; _done = true; });
    } catch (e) {
      if (mounted) setState(() { _serving = false; _error = e.toString(); });
    }
  }

  /// Loopback self-test — connects to itself on 127.0.0.1
  Future<void> _runLoopback() async {
    final payload = _payload;
    if (payload == null) return;
    setState(() { _serving = true; _done = false; _error = null; _progress = 0; });
    try {
      final server = TransferServer(files: widget.files)
        ..onProgress = (sent, total) => _setProgress(sent / total);
      final listening = await server.bind();
      final serveFuture = server.serve(listening, payload.sid);
      final docs = await getApplicationDocumentsDirectory();
      final clientFuture = TransferClient().receive(
        host: '127.0.0.1',
        sessionId: payload.sid,
        saveDir: docs.path,
        onProgress: (r, t) => _setProgress(r / t),
      );
      await Future.wait([serveFuture, clientFuture]);
      if (mounted) setState(() { _serving = false; _done = true; });
    } catch (e) {
      if (mounted) setState(() { _serving = false; _error = e.toString(); });
    }
  }

  void _setProgress(double pct) {
    final newPct = (pct * 100).floor();
    if (newPct != (_progress * 100).floor() && mounted) {
      setState(() => _progress = pct);
    }
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    final totalSize =
        widget.files.fold<int>(0, (s, f) => s + (f.lengthSync() ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── PHASE 1 – start hotspot ─────────────────────────────────
          if (payload == null) ...[
            _SectionHeader(icon: Icons.wifi_tethering_rounded, label: 'Start Hotspot'),
            const SizedBox(height: 8),
            Text(
              'Create a Wi-Fi hotspot so the receiver can join and download your files.',
              style: TextStyle(color: kColorTextMuted, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            _InfoCard(children: [
              Row(children: [
                const Icon(Icons.folder_rounded, size: 18),
                const SizedBox(width: 8),
                Text('${widget.files.length} file${widget.files.length == 1 ? '' : 's'} ready',
                    style: const TextStyle(color: kColorText, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(_formatSize(totalSize),
                    style: TextStyle(color: kColorTextMuted, fontSize: 13)),
              ]),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _starting ? null : _startHotspot,
                icon: _starting
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kColorBg))
                    : const Icon(Icons.wifi_tethering_rounded),
                label: Text(_starting ? 'Starting hotspot…' : 'Start hotspot'),
              ),
            ),
            // "Open settings" if permission was denied
            if (_error == 'StateError: nearby') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Open app settings'),
                ),
              ),
            ],
          ]

          // ── PHASE 2 – QR shown, waiting for receiver ─────────────────
          else ...[
            _SectionHeader(icon: Icons.qr_code_2_rounded, label: 'Scan to receive'),
            const SizedBox(height: 8),
            Text(
              'Have the receiver scan this QR code with QRShare.',
              style: TextStyle(color: kColorTextMuted, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            // QR card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: QrImageView(
                  data: payload.encode(),
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square, color: kColorBg),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square, color: kColorBg),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Hotspot info
            if (_creds != null)
              _InfoCard(children: [
                _InfoRow(label: 'Network',    value: _creds!.ssid,       icon: Icons.wifi_rounded),
                const Divider(height: 20),
                _InfoRow(label: 'Password',   value: _creds!.password,   icon: Icons.lock_rounded),
                const Divider(height: 20),
                _InfoRow(label: 'Session ID', value: payload.sid,        icon: Icons.tag_rounded),
              ]),
            const SizedBox(height: 20),
            // File summary
            _InfoCard(children: [
              Row(children: [
                const Icon(Icons.folder_rounded, size: 18),
                const SizedBox(width: 8),
                Text('${widget.files.length} file${widget.files.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: kColorText, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(_formatSize(totalSize),
                    style: TextStyle(color: kColorTextMuted, fontSize: 13)),
              ]),
            ]),
            const SizedBox(height: 20),
            // ── "Wait for receiver" — the real transfer button ─────────
            if (!_done) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _serving ? null : _waitForReceiver,
                  icon: _serving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kColorBg))
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: Text(_serving ? 'Waiting for receiver…' : 'Wait for receiver'),
                ),
              ),
              const SizedBox(height: 12),
              // ── Loopback self-test button ───────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _serving ? null : _runLoopback,
                  icon: const Icon(Icons.loop_rounded),
                  label: const Text('Run loopback test'),
                ),
              ),
            ],
            // Progress bar
            if (_serving || _progress > 0) ...[
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: _progress, minHeight: 6),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${(_progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: kColorAccent, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ],
            // Done banner
            if (_done) ...[
              const SizedBox(height: 20),
              _StatusBanner(
                icon: Icons.check_circle_rounded,
                label: 'Transfer complete — hashes verified',
                color: kColorSuccess,
              ),
            ],
          ],

          // Error banner (always)
          if (_error != null && _error != 'StateError: nearby') ...[
            const SizedBox(height: 20),
            _StatusBanner(icon: Icons.error_rounded, label: _error!, color: kColorError),
            // Offer settings link if it's a permission error
            if (_error!.toLowerCase().contains('permission')) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Open app settings'),
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: kColorAccent, size: 20),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color: kColorText, fontSize: 18, fontWeight: FontWeight.w700)),
    ]);
  }
}

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
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
    return Row(children: [
      Icon(icon, size: 16, color: kColorAccent),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: kColorTextMuted, fontSize: 12)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(value,
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: kColorText, fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.label, required this.color});
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
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
