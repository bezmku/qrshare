import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

int? androidSdkInt() {
  final match =
      RegExp(r'SDK (\d+)').firstMatch(Platform.operatingSystemVersion);
  return match == null ? null : int.parse(match.group(1)!);
}

Future<String?> ensureWifiPermission() async {
  final sdk = androidSdkInt();
  if (sdk != null && sdk >= 33) {
    final ok = await Permission.nearbyWifiDevices.request().isGranted;
    return ok ? null : 'Nearby Wi-Fi devices permission is required';
  }
  final service = await Permission.location.serviceStatus;
  if (!service.isEnabled) {
    return 'Please enable Location in system settings and try again';
  }
  final ok = await Permission.location.request().isGranted;
  return ok ? null : 'Location permission is required';
}
