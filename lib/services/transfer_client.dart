import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'protocol.dart';

class TransferClient {
  Future<Map<String, dynamic>> receive({
    required String host,
    required String sessionId,
    required String saveDir,
    void Function(int received, int total)? onProgress,
  }) async {
    final socket = await Socket.connect(
      host,
      kPort,
      timeout: const Duration(seconds: 15),
    );
    final io = FramedProtocol(socket);
    try {
      io.sendJson(frameHello, {'v': kVersion, 'sid': sessionId});

      final (ackType, _) = await io.nextFrame();
      if (ackType != frameAck) {
        throw const FormatException('Expected ACK from sender');
      }

      final (manifestType, manifestPayload) = await io.nextFrame();
      if (manifestType != frameManifest) {
        throw const FormatException('Expected MANIFEST from sender');
      }
      final manifest =
          (jsonDecode(utf8.decode(manifestPayload))
                  as Map<String, dynamic>)['files']
              as List<dynamic>;

      var received = 0;
      final total = manifest.fold<int>(0, (sum, f) => sum + (f['size'] as int));
      final done = <Map<String, dynamic>>[];

      for (final rawEntry in manifest) {
        final entry = rawEntry as Map<String, dynamic>;
        final (startType, startPayload) = await io.nextFrame();
        if (startType != frameFileStart) {
          throw const FormatException('Expected FILE_START');
        }
        final start =
            jsonDecode(utf8.decode(startPayload)) as Map<String, dynamic>;
        final name = (start['name'] as String).split('/').last;
        final size = start['size'] as int;
        final expectedHash = start['sha256'] as String;

        final partPath = '$saveDir/$name.part';
        final out = File(partPath).openWrite();
        var bytesLeft = size;

        try {
          while (bytesLeft > 0) {
            final (type, payload) = await io.nextFrame();
            if (type != frameFileData || payload.length > bytesLeft) {
              throw FormatException('Unexpected frame while receiving $name');
            }
            out.add(payload);
            bytesLeft -= payload.length;
            received += payload.length;
            onProgress?.call(received, total);
          }

          final (endType, endPayload) = await io.nextFrame();
          if (endType != frameFileEnd) {
            throw const FormatException('Expected FILE_END');
          }
          jsonDecode(utf8.decode(endPayload));

          await out.flush();
          final digest = await sha256.bind(File(partPath).openRead()).first;
          if (digest.toString() != expectedHash) {
            io.sendJson(frameError, {
              'name': name,
              'message': 'SHA-256 mismatch',
            });
            throw StateError('SHA-256 mismatch for $name');
          }

          await out.close();
          await File(partPath).rename('$saveDir/$name');
          done.add({'name': name, 'size': size});
          io.sendJson(frameAck, {'name': name, 'ok': true});
        } catch (e) {
          await out.close();
          if (await File(partPath).exists()) {
            await File(partPath).delete();
          }
          rethrow;
        }
      }

      final (sessionType, _) = await io.nextFrame();
      if (sessionType != frameSessionEnd) {
        throw const FormatException('Expected SESSION_END');
      }

      return {'files': done, 'totalBytes': total};
    } finally {
      io.close();
    }
  }
}
