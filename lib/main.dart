import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/connection_controller.dart';
import 'core/theme/batmin_theme.dart';
import 'features/splash/splash_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ConnectionController(),
      child: const BatminConnectApp(),
    ),
  );
}

class BatminConnectApp extends StatelessWidget {
  const BatminConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Batmin Connect',
      debugShowCheckedModeBanner: false,
      theme: BatminTheme.dark(),
      home: const SplashPage(),
    );
  }
}
