import 'package:flutter/material.dart';

class SendScreen extends StatelessWidget {
  const SendScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send')),
      body: const Center(child: Text('Send screen')),
    );
  }
}
