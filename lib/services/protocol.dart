import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const String kVersion = 'QRShare-1.0';
const int kPort = 8888;
const int kChunkSize = 64 * 1024;

const int frameHello = 1;
const int frameAck = 2;
const int frameManifest = 3;
const int frameFileStart = 4;
const int frameFileData = 5;
const int frameFileEnd = 6;
const int frameSessionEnd = 7;
const int frameError = 8;

class FramedProtocol {
  FramedProtocol(this._socket) {
    _sub = _socket.listen(
      _onData,
      onDone: _onDone,
      onError: _onError,
      cancelOnError: true,
    );
  }
  final Socket _socket;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  final List<_ReadRequest> _queue = [];
  StreamSubscription<Uint8List>? _sub;

  void _onData(Uint8List chunk) {
    _buffer.add(chunk);
    _drain();
  }

  void _drain() {
    while (_queue.isNotEmpty) {
      final req = _queue.first;
      if (_buffer.length < req.length) return;
      final bytes = _buffer.takeBytes();
      final payload = Uint8List.fromList(bytes.sublist(0, req.length));
      _buffer.add(bytes.sublist(req.length));
      _queue.removeAt(0);
      if (!req.completer.isCompleted) {
        req.completer.complete(payload);
      }
    }
  }

  void _onDone() {
    final error = const SocketException('Connection closed by peer');
    for (final req in _queue) {
      if (!req.completer.isCompleted) req.completer.completeError(error);
    }
    _queue.clear();
  }

  void _onError(Object e) {
    final error = e is Error ? e : Exception('Socket error: $e');
    for (final req in _queue) {
      if (!req.completer.isCompleted) req.completer.completeError(error);
    }
    _queue.clear();
  }

  Future<(int, Uint8List)> nextFrame() async {
    final header = await _read(5);
    final type = header[0];
    final length =
        (header[1] << 24) | (header[2] << 16) | (header[3] << 8) | header[4];
    final payload = await _read(length);
    return (type, payload);
  }

  Future<Uint8List> _read(int n) {
    final completer = Completer<Uint8List>();
    _queue.add(_ReadRequest(n, completer));
    _drain();
    return completer.future;
  }

  void send(int type, List<int> payload) {
    final length = payload.length;
    final frame = Uint8List(5 + length);
    frame[0] = type;
    frame[1] = (length >> 24) & 0xff;
    frame[2] = (length >> 16) & 0xff;
    frame[3] = (length >> 8) & 0xff;
    frame[4] = length & 0xff;
    frame.setRange(5, frame.length, payload);
    _socket.add(frame);
  }

  void sendJson(int type, Map<String, dynamic> map) {
    send(type, utf8.encode(jsonEncode(map)));
  }

  void close() {
    _sub?.cancel();
    _socket.close();
  }
}

class _ReadRequest {
  _ReadRequest(this.length, this.completer);
  final int length;
  final Completer<Uint8List> completer;
}
