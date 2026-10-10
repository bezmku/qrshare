import 'package:flutter/services.dart';

class DownloadSaver {
  static const MethodChannel _channel = MethodChannel('qrshare/files');

  /// Copies [path] into the public Downloads folder as [name].
  /// Returns the public content:// uri, or null if it failed.
  static Future<String?> publish(String path, String name) async {
    try {
      return await _channel.invokeMethod<String>('publishToDownloads', {
        'path': path,
        'name': name,
      });
    } catch (_) {
      return null;
    }
  }

  static Future<void> open(String uri) =>
      _channel.invokeMethod('openFile', {'uri': uri});

  static Future<void> share(String uri) =>
      _channel.invokeMethod('shareFile', {'uri': uri});
}
