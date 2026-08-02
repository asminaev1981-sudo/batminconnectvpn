import 'package:flutter/material.dart';
class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Диагностика')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Проверка подключения', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      const Text('Интернет, DNS, API Batmin, UDP/QUIC и доступность сервера.'),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.build), label: const Text('Запустить диагностику')),
    ]),
  );
}
