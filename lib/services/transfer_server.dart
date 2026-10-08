import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

import 'protocol.dart';

class TransferServer {
  TransferServer({required this.files});

  final List<PlatformFile> files;
  void Function(int sent, int total)? onProgress;

  Future<ServerSocket> bind() =>
      ServerSocket.bind(InternetAddress.anyIPv4, kPort);

  Future<void> serve(ServerSocket server, String sessionId) async {
    final socket = await server.first;
    final io = FramedProtocol(socket);
    try {
      final (type, payload) = await io.nextFrame();
      if (type != frameHello) {
        throw const FormatException('Expected HELLO from receiver');
      }
      final hello = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      if (hello['v'] != kVersion) {
        throw const FormatException('Protocol version mismatch');
      }
      if (hello['sid'] != sessionId) {
        throw const FormatException('Wrong session id');
      }
      io.sendJson(frameAck, {'v': kVersion, 'sid': sessionId});

      final manifest = <Map<String, dynamic>>[];
      for (final file in files) {
        final path = file.path;
        if (path == null) {
          throw StateError('File "${file.name}" has no local path');
        }
        final digest = await sha256.bind(File(path).openRead()).first;
        final size = await file.length();
        if (size == null) {
          throw StateError('Couldn\'t determine size of "${file.name}');
        }
        manifest.add({
          'name': file.name,
          'size': size,
          'sha256': digest.toString(),
        });
      }

      io.sendJson(frameManifest, {'files': manifest});

      var sent = 0;
      final total = files.fold<int>(0, (sum, f) => sum + (f.lengthSync() ?? 0));

      for (final entry in manifest) {
        final path = File(
          files.firstWhere((f) => f.name == entry['name']).path!,
        );
        io.sendJson(frameFileStart, entry);
        await for (final chunk in path.openRead()) {
          sent += chunk.length;
          io.send(frameFileData, chunk);
          onProgress?.call(sent, total);
        }
        io.sendJson(frameFileEnd, {'name': entry['name']});

        final (ackType, ackPayload) = await io.nextFrame();
        if (ackType != frameAck) {
          throw const FormatException('Expected ACK after file');
        }
        final ack = jsonDecode(utf8.decode(ackPayload)) as Map<String, dynamic>;
        if (ack['ok'] != true) {
          throw StateError('Receiver rejected ${entry['name']}');
        }
      }

      io.sendJson(frameSessionEnd, {'status': 'ok'});
    } finally {
      io.close();
      server.close();
    }
  }
}
