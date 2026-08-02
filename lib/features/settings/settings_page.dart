import 'package:flutter/material.dart';
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Настройки')),
    body: const Column(children: [
      SwitchListTile(value: true, onChanged: null, title: Text('Автоподключение')),
      ListTile(title: Text('Версия'), trailing: Text('0.2.0')),
    ]),
  );
}
