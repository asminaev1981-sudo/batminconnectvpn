import 'package:flutter/material.dart';
class AuthPage extends StatelessWidget {
  const AuthPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Активация')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const TextField(decoration: InputDecoration(labelText: 'Токен активации')),
        const SizedBox(height: 16),
        FilledButton(onPressed: () {}, child: const Text('Активировать')),
      ]),
    ),
  );
}
