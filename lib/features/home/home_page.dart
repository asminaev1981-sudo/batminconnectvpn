import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/connection_state.dart';
import '../../core/services/connection_controller.dart';
import '../diagnostics/diagnostics_page.dart';
import '../servers/servers_page.dart';
import '../settings/settings_page.dart';
import 'widgets/animated_bat.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConnectionController>();
    final state = controller.snapshot;
    final connected = state.status == TunnelStatus.connected;
    final connecting = state.status == TunnelStatus.connecting || state.status == TunnelStatus.preparing;
    final busy = connecting || state.status == TunnelStatus.disconnecting;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              sliver: SliverList.list(
                children: [
                  const _Header(),
                  const SizedBox(height: 6),
                  Center(
                    child: AnimatedBat(active: connected, connecting: connecting),
                  ),
                  Text(
                    connected
                        ? 'СОЕДИНЕНИЕ ЗАЩИЩЕНО'
                        : connecting
                            ? 'УСТАНАВЛИВАЮ СОЕДИНЕНИЕ…'
                            : state.status == TunnelStatus.error
                                ? 'ТРЕБУЕТСЯ ВНИМАНИЕ'
                                : 'ГОТОВ К ПОДКЛЮЧЕНИЮ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          letterSpacing: 1.7,
                          color: connected
                              ? const Color(0xFF58F0A7)
                              : const Color(0xFF9BA7C2),
                        ),
                  ),
                  const SizedBox(height: 20),
                  _ServerCard(
                    name: state.serverName,
                    address: '94.141.98.124:443',
                    connected: connected,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 62,
                    child: FilledButton.icon(
                      onPressed: busy ? null : controller.toggle,
                      icon: Icon(connected ? Icons.power_settings_new : Icons.shield_rounded),
                      label: Text(connected ? 'ОТКЛЮЧИТЬ' : 'ПОДКЛЮЧИТЬ'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Expanded(child: _Metric(label: 'PING', value: state.pingMs == 0 ? '—' : '${state.pingMs} ms')),
                      const SizedBox(width: 10),
                      Expanded(child: _Metric(label: '↓', value: '${state.downloadMbps.toStringAsFixed(1)} Mbps')),
                      const SizedBox(width: 10),
                      Expanded(child: _Metric(label: '↑', value: '${state.uploadMbps.toStringAsFixed(1)} Mbps')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Expanded(child: _Action(icon: Icons.health_and_safety_outlined, label: 'Доктор', page: DiagnosticsPage())),
                      const SizedBox(width: 10),
                      Expanded(child: _Action(icon: Icons.dns_outlined, label: 'Серверы', page: ServersPage())),
                      const SizedBox(width: 10),
                      Expanded(child: _Action(icon: Icons.settings_outlined, label: 'Настройки', page: SettingsPage())),
                    ],
                  ),
                  if (state.message.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline),
                            const SizedBox(width: 12),
                            Expanded(child: Text(state.message)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('BATMIN CONNECT', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 2.2)),
          const SizedBox(height: 4),
          Text('Secure. Fast. Intelligent.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF7E8AA6))),
        ],
      );
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.name, required this.address, required this.connected});
  final String name;
  final String address;
  final bool connected;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: const Color(0xFF171D31), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.public),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(address, style: const TextStyle(color: Color(0xFF7E8AA6)))])),
              Icon(Icons.circle, size: 11, color: connected ? const Color(0xFF58F0A7) : const Color(0xFF566078)),
            ],
          ),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(children: [Text(label, style: const TextStyle(color: Color(0xFF7E8AA6))), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
        ),
      );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.page});
  final IconData icon;
  final String label;
  final Widget page;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Column(children: [Icon(icon), const SizedBox(height: 8), Text(label, maxLines: 1)]),
          ),
        ),
      );
}
