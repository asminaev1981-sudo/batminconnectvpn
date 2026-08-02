import 'package:flutter/material.dart';
class ServersPage extends StatelessWidget {
  const ServersPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Серверы')),
    body: const ListTile(leading: Icon(Icons.check_circle), title: Text('Netherlands'), subtitle: Text('Основной сервер • 24 ms')),
  );
}
