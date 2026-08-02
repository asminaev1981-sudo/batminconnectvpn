import 'dart:async';
import 'package:flutter/material.dart';
import '../home/home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 72),
            SizedBox(height: 16),
            Text('BATMIN CONNECT', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 2)),
            SizedBox(height: 8),
            Text('Secure connection by Batmin Platform'),
          ],
        ),
      ),
    );
  }
}
