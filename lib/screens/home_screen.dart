import 'package:flutter/material.dart';
import 'package:qrshare/screens/receive_screen.dart';
import 'package:qrshare/screens/send_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QRShare')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Offline file transfer'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SendScreen()),
                );
              },
              icon: const Icon(Icons.upload),
              label: const Text('Send files'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ReceiveScreen()),
                );
              },
              icon: const Icon(Icons.download),
              label: const Text('Receive files'),
            ),
          ],
        ),
      ),
    );
  }
}
