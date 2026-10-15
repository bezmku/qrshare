import 'package:flutter/material.dart';
import 'package:qrshare/screens/receive_screen.dart';
import 'package:qrshare/screens/send_screen.dart';
import 'package:qrshare/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 56),
              // Logo / Wordmark
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kColorAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: kColorBg,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'QRShare',
                    style: TextStyle(
                      color: kColorText,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Fast offline file transfer\nover a direct Wi-Fi hotspot.',
                style: TextStyle(
                  color: kColorTextMuted,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              // Send card
              _ModeCard(
                icon: Icons.upload_rounded,
                title: 'Send files',
                subtitle: 'Create a hotspot & share your QR code',
                onTap: () =>
                    Navigator.push(context, _slideRoute(const SendScreen())),
              ),
              const SizedBox(height: 16),
              // Receive card
              _ModeCard(
                icon: Icons.download_rounded,
                title: 'Receive files',
                subtitle: 'Scan the sender\'s QR code to connect',
                onTap: () =>
                    Navigator.push(context, _slideRoute(const ReceiveScreen())),
              ),
              const SizedBox(height: 48),
              Center(
                child: Text(
                  'No internet required • End-to-end ',
                  style: TextStyle(
                    color: kColorTextMuted.withValues(alpha: 0.6),
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  PageRoute<void> _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }
}

class _ModeCard extends StatefulWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kColorSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _pressed
                  ? kColorAccent.withValues(alpha: 0.5)
                  : kColorBgLight.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: kColorAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: kColorAccent, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: kColorText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(color: kColorTextMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: kColorTextMuted.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
