import 'package:flutter/material.dart';

class Logo extends StatefulWidget {
  const Logo({super.key});

  @override
  State<Logo> createState() => _LogoState();
}

class _LogoState extends State<Logo> {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: 40,
      height: 40,
      fit: BoxFit.fitHeight,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => Icon(Icons.voice_chat, size: 32),
    );
  }
}
