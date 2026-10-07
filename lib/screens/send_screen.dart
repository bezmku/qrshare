import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});
  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final List<PlatformFile> _files = [];

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty && mounted) {
      setState(() {
        _files.addAll(result);
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB ';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB ';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)}GB ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send')),
      body: Column(
        children: [
          Expanded(
            child: _files.isEmpty
                ? const Center(child: Text('No files Selected'))
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(file.name),
                        subtitle: Text(_formatSize(file.lengthSync() ?? 0)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _files.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.add),
              label: const Text('Select files'),
            ),
          ),
        ],
      ),
    );
  }
}
