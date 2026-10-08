import 'dart:convert';

class QrPayload {
  final int v;
  final String ssid;
  final String pass;
  final String sec;
  final int port;
  final String sid;

  const QrPayload({
    this.v = 1,
    required this.ssid,
    required this.pass,
    this.sec = 'WPA2',
    this.port = 8888,
    required this.sid,
  });

  String encode() => jsonEncode({
    'v': v,
    'ssid': ssid,
    'pass': pass,
    'sec': sec,
    'port': port,
    'sid': sid,
  });
  static QrPayload? decode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['v'] != 1) return null;
      return QrPayload(
        ssid: map['ssid'] as String,
        pass: map['pass'] as String,
        sec: map['sec'] as String? ?? 'WPA2',
        port: (map['port'] as num?)?.toInt() ?? 8888,
        sid: map['sid'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}
