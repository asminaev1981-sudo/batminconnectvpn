import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/connection_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _profileController = TextEditingController();
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final value = await context.read<ConnectionController>().hasAmneziaWgProfile();
      if (mounted) setState(() => _hasProfile = value);
    });
  }

  @override
  void dispose() {
    _profileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Настройки')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const SwitchListTile(value: true, onChanged: null, title: Text('Автоподключение')),
      ListTile(
        title: const Text('AmneziaWG 3.1'),
        subtitle: Text(_hasProfile ? 'Профиль защищённо сохранён' : 'Профиль не установлен'),
        trailing: Icon(_hasProfile ? Icons.check_circle : Icons.warning_amber),
      ),
      TextField(
        controller: _profileController,
        minLines: 4,
        maxLines: 8,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'Профиль AWG 3.1',
          hintText: '[Interface]\n…\n[Peer]\n…',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        icon: const Icon(Icons.lock),
        label: const Text('СОХРАНИТЬ ПРОФИЛЬ'),
        onPressed: () async {
          try {
            await context.read<ConnectionController>()
                .saveAmneziaWgProfile(_profileController.text);
            _profileController.clear();
            if (mounted) {
              setState(() => _hasProfile = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Профиль AWG 3.1 сохранён защищённо.')),
              );
            }
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$error')),
              );
            }
          }
        },
      ),
      const ListTile(title: Text('Версия'), trailing: Text('0.6.9')),
    ]),
  );
}
