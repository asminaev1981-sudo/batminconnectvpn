
import 'package:flutter/material.dart';

import '../../core/models/vpn_profile.dart';
import '../../core/services/profile_import_service.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  final ProfileImportService _profiles = ProfileImportService();

  List<VpnProfile> _items = <VpnProfile>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _profiles.getProfiles();

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _setEnabled(
    VpnProfile profile,
    bool enabled,
  ) async {
    try {
      final items = await _profiles.setEnabled(
        profile.id,
        enabled,
      );

      if (!mounted) return;

      setState(() {
        _items = items;
      });
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _deleteProfile(VpnProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить профиль?'),
        content: Text(profile.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ОТМЕНА'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final items = await _profiles.deleteProfile(profile.id);

      if (!mounted) return;

      setState(() {
        _items = items;
      });
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _typeLabel(VpnProfileType type) {
    return switch (type) {
      VpnProfileType.hysteria2 => 'Hysteria2',
      VpnProfileType.amneziaWg => 'AmneziaWG',
      VpnProfileType.vless => 'VLESS',
      VpnProfileType.singBox => 'sing-box',
      VpnProfileType.unknown => 'Неизвестный',
    };
  }

  String _endpoint(VpnProfile profile) {
    final server = profile.server;

    if (server == null || server.isEmpty) {
      return 'Сервер не определён';
    }

    if (profile.port == null) {
      return server;
    }

    return '$server:${profile.port}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN-профили'),
        actions: [
          IconButton(
            onPressed: _loadProfiles,
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showMessage(
            'Импорт профиля подключим следующим шагом',
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfiles,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 80),
          const Icon(
            Icons.error_outline,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Не удалось загрузить профили',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.vpn_key_outlined,
            size: 64,
          ),
          const SizedBox(height: 20),
          Text(
            'Профилей пока нет',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          const Text(
            'Добавьте конфигурацию AmneziaWG, '
            'Hysteria2, VLESS или sing-box.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _items.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final profile = _items[index];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_typeLabel(profile.type)} • '
                            '${_endpoint(profile)}',
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: profile.enabled,
                      onChanged: (value) =>
                          _setEnabled(profile, value),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          _deleteProfile(profile),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Удалить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
