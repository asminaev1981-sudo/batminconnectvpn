import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api/batmin_api.dart';
import '../../core/services/android_vpn_bridge.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  final BatminApi _api = BatminApi();
  final AndroidVpnBridge _bridge = AndroidVpnBridge();

  bool _running = false;
  final List<_DiagnosticResult> _results = [];

  Future<void> _runDiagnostics() async {
    if (_running) return;

    setState(() {
      _running = true;
      _results.clear();
    });

    await _check(
      'Платформа',
      () async {
        if (!Platform.isAndroid) {
          return const _DiagnosticResult(
            'Платформа',
            false,
            'VPN поддерживается только на Android',
          );
        }

        return const _DiagnosticResult(
          'Платформа',
          true,
          'Android обнаружен',
        );
      },
    );

    await _check(
      'Batmin API',
      () async {
        final health = await _api.health();

        return _DiagnosticResult(
          'Batmin API',
          true,
          health.isEmpty
              ? 'API отвечает'
              : 'API отвечает: ${health.toString()}',
        );
      },
    );

    await _check(
      'VPN Bridge',
      () async {
        if (!_bridge.isSupported) {
          return const _DiagnosticResult(
            'VPN Bridge',
            false,
            'Android VPN Bridge недоступен',
          );
        }

        return const _DiagnosticResult(
          'VPN Bridge',
          true,
          'Android VPN Bridge доступен',
        );
      },
    );

    await _check(
      'Native engine',
      () async {
        final native = await _bridge.status();

        if (!native.engineAvailable) {
          return _DiagnosticResult(
            'Native engine',
            false,
            native.message.isEmpty
                ? 'libbox engine недоступен'
                : native.message,
          );
        }

        return _DiagnosticResult(
          'Native engine',
          true,
          native.message.isEmpty ? 'libbox engine загружен' : native.message,
        );
      },
    );

    await _check(
      'VPN-служба',
      () async {
        final native = await _bridge.status();

        final state = native.state.name;

        final failed = native.state == NativeVpnState.error ||
            native.state == NativeVpnState.unsupported;

        return _DiagnosticResult(
          'VPN-служба',
          !failed,
          native.message.isEmpty
              ? 'Состояние: $state'
              : 'Состояние: $state — ${native.message}',
        );
      },
    );

    if (mounted) {
      setState(() {
        _running = false;
      });
    }
  }

  Future<void> _check(
    String name,
    Future<_DiagnosticResult> Function() action,
  ) async {
    try {
      final result = await action();

      if (mounted) {
        setState(() => _results.add(result));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results.add(
            _DiagnosticResult(
              name,
              false,
              _friendlyError(e),
            ),
          );
        });
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is SocketException) {
      return 'Нет соединения с сервером';
    }

    if (error is HttpException) {
      return 'Ошибка HTTP: ${error.message}';
    }

    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final finished = !_running && _results.isNotEmpty;
    final problems = _results.where((r) => !r.ok).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Диагностика'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Batmin Doctor',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Проверка API, Android VPN Bridge, native libbox и состояния VPN-службы.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _running ? null : _runDiagnostics,
            icon: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.health_and_safety_outlined),
            label: Text(
              _running ? 'Выполняется проверка...' : 'Запустить диагностику',
            ),
          ),
          const SizedBox(height: 24),
          if (_results.isEmpty && !_running)
            const _InfoCard(
              icon: Icons.info_outline,
              title: 'Диагностика ещё не запускалась',
              text: 'Нажмите кнопку выше для полной проверки.',
            ),
          ..._results.map(
            (result) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  result.ok ? Icons.check_circle_outline : Icons.error_outline,
                ),
                title: Text(result.name),
                subtitle: Text(result.message),
                trailing: Text(
                  result.ok ? 'OK' : 'ОШИБКА',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: result.ok ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ),
            ),
          ),
          if (finished) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      problems == 0
                          ? Icons.verified_outlined
                          : Icons.warning_amber_rounded,
                      size: 42,
                      color: problems == 0
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      problems == 0 ? 'СИСТЕМА ГОТОВА' : 'ТРЕБУЕТСЯ ВНИМАНИЕ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      problems == 0
                          ? 'Все доступные проверки пройдены.'
                          : 'Обнаружено проблем: $problems. Причины указаны выше.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiagnosticResult {
  const _DiagnosticResult(
    this.name,
    this.ok,
    this.message,
  );

  final String name;
  final bool ok;
  final String message;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(text),
      ),
    );
  }
}
