import 'package:flutter/services.dart';

class HotspotCredentials {
  const HotspotCredentials({
    required this.ssid,
    required this.password,
    required this.bssid,
  });
  final String ssid;
  final String password;
  final String bssid;
}

class HotspotService {
  static const MethodChannel _channel = MethodChannel('qrshare/hotspot');
  Future<HotspotCredentials> start() async {
    final map = await _channel.invokeMapMethod<String, String>('startHotspot');
    if (map == null) {
      throw StateError('Could not read hotspot credentials');
    }
    return HotspotCredentials(
      ssid: map['ssid'] ?? '',
      password: map['password'] ?? '',
      bssid: map['bssid'] ?? '',
    );
  }

  Future<void> stop() => _channel.invokeMethod('stopHotspot');

  Future<String> join({required String ssid, required String password}) async {
    final gateway = await _channel.invokeMethod<String>('joinHotspot', {
      'ssid': ssid,
      'password': password,
    });
    if (gateway == null) {
      throw StateError('Could not determine gateway IP');
    }
    return gateway;
  }

  Future<void> leave() => _channel.invokeMethod('leaveHotspot');
}
