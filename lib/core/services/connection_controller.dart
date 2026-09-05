import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/connection_state.dart';
import '../models/vpn_protocol.dart';
import 'android_vpn_bridge.dart';
import 'vpn_profile_store.dart';

class ConnectionController extends ChangeNotifier {
  ConnectionController({AndroidVpnBridge? bridge, VpnProfileStore? profileStore})
      : _bridge = bridge ?? AndroidVpnBridge(),
        _profileStore = profileStore ?? VpnProfileStore();

  final AndroidVpnBridge _bridge;
  final VpnProfileStore _profileStore;
  static const hysteriaPorts = <int>[443, 2053, 2096, 8443];
  static const amneziaWg31Port = 5182;

  VpnProtocol _selectedProtocol = VpnProtocol.hysteria2;

  VpnProtocol get selectedProtocol => _selectedProtocol;
  VpnProtocol? _activeProtocol;
  int? _activePort;
  VpnProtocol? get activeProtocol => _activeProtocol;
  int? get activePort => _activePort;

  void selectProtocol(VpnProtocol protocol) {
    if (_operationInProgress) {
      return;
    }
    if (_snapshot.status != TunnelStatus.disconnected &&
        _snapshot.status != TunnelStatus.error) {
      return;
    }
    _selectedProtocol = protocol;
    notifyListeners();
  }

  Timer? _statusTimer;
  bool _operationInProgress = false;
  bool _telemetryInProgress = false;
  NativeTelemetry? _previousTelemetry;

  ConnectionSnapshot _snapshot = const ConnectionSnapshot(
    status: TunnelStatus.disconnected,
  );

  ConnectionSnapshot get snapshot => _snapshot;

  Future<void> toggle() async {
    if (_operationInProgress) return;
    switch (_snapshot.status) {
      case TunnelStatus.connected:
      case TunnelStatus.connecting:
      case TunnelStatus.preparing:
        await disconnect();
        return;
      case TunnelStatus.disconnected:
      case TunnelStatus.error:
        await connect();
        return;
      case TunnelStatus.disconnecting:
        return;
    }
  }

  Future<void> connect() async {
    _operationInProgress = true;
    _setSnapshot(const ConnectionSnapshot(
      status: TunnelStatus.preparing,
      message: 'Запрашиваю разрешение Android VPN…',
    ));

    try {
      final allowed = await _bridge.prepare();
      if (!allowed) {
        _setError('Разрешение на создание VPN-подключения не выдано.');
        return;
      }

      switch (_selectedProtocol) {
        case VpnProtocol.hysteria2:
          await _connectHysteriaWithFallback();
          break;
        case VpnProtocol.amneziaWg:
          await _connectAmneziaWg();
          break;
        case VpnProtocol.auto:
          try {
            await _connectHysteriaWithFallback();
          } catch (_) {
            await _connectAmneziaWg();
          }
          break;
      }
    } on PlatformException catch (error) {
      _setError(error.message ?? error.code);
    } catch (error) {
      _setError('Ошибка запуска: $error');
    } finally {
      _operationInProgress = false;
    }
  }

  Future<void> disconnect() async {
    _operationInProgress = true;
    _setSnapshot(_snapshot.copyWith(
      status: TunnelStatus.disconnecting,
      message: 'Останавливаю VPN-службу…',
    ));
    try {
      switch (_activeProtocol ?? _selectedProtocol) {
        case VpnProtocol.hysteria2:
          await _bridge.stop();
          break;
        case VpnProtocol.amneziaWg:
          await _bridge.stopAmneziaWg();
          break;
        case VpnProtocol.auto:
          await _bridge.stop();
          await _bridge.stopAmneziaWg();
          break;
      }
      _statusTimer?.cancel();
      _activeProtocol = null;
      _activePort = null;
      _previousTelemetry = null;
      _setSnapshot(const ConnectionSnapshot(
        status: TunnelStatus.disconnected,
        message: 'VPN отключён.',
      ));
    } on PlatformException catch (error) {
      _setError(error.message ?? error.code);
    } catch (error) {
      _setError('Ошибка остановки: $error');
    } finally {
      _operationInProgress = false;
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshActiveStatus(),
    );
  }

  Future<void> _connectHysteriaWithFallback() async {
    final source = await rootBundle.loadString('assets/config/batmin_hysteria2.json');
    Object? lastError;
    for (final port in hysteriaPorts) {
      try {
        final profile = jsonDecode(source) as Map<String, dynamic>;
        final outbounds = profile['outbounds'] as List<dynamic>;
        final outbound = outbounds.cast<Map<String, dynamic>>().firstWhere(
              (value) => value['type'] == 'hysteria2',
            );
        outbound['server_port'] = port;
        _setSnapshot(ConnectionSnapshot(
          status: TunnelStatus.connecting,
          message: 'Проверяю Hysteria2, UDP $port…',
        ));
        await _bridge.start(profileJson: jsonEncode(profile));
        await _waitForHysteriaReady();
        _activeProtocol = VpnProtocol.hysteria2;
        _activePort = port;
        _startStatusPolling();
        _setSnapshot(ConnectionSnapshot(
          status: TunnelStatus.connected,
          message: 'Hysteria2 подключён через UDP $port.',
        ));
        return;
      } catch (error) {
        lastError = error;
        await _bridge.stop();
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
    throw StateError('Все порты Hysteria2 недоступны: $lastError');
  }

  Future<void> _waitForHysteriaReady() async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final native = await _bridge.status();
      if (native.state == NativeVpnState.ready && native.engineAvailable) return;
      if (native.state == NativeVpnState.error ||
          native.state == NativeVpnState.stopped) {
        throw StateError(native.message);
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException('Hysteria2 не перешёл в рабочее состояние');
  }

  Future<void> _connectAmneziaWg() async {
    final configText = await _profileStore.readAmneziaWgProfile();
    if (configText == null || configText.isEmpty) {
      throw StateError(
        'Профиль AmneziaWG 3.1 не установлен. Добавьте его в настройках.',
      );
    }
    _setSnapshot(const ConnectionSnapshot(
      status: TunnelStatus.connecting,
      message: 'Запускаю AmneziaWG 3.1…',
    ));
    await _bridge.startAmneziaWg(configText: configText);
    final state = await _bridge.amneziaWgStatus();
    if (state != 'up') throw StateError('AmneziaWG не перешёл в состояние UP');
    _activeProtocol = VpnProtocol.amneziaWg;
    _activePort = amneziaWg31Port;
    _startStatusPolling();
    _setSnapshot(const ConnectionSnapshot(
      status: TunnelStatus.connected,
      message: 'AmneziaWG 3.1 подключён через UDP 5182.',
    ));
  }

  Future<void> _refreshActiveStatus() async {
    if (_activeProtocol == VpnProtocol.amneziaWg) {
      final state = await _bridge.amneziaWgStatus();
      if (state != 'up') {
        _statusTimer?.cancel();
        _setError('Соединение AmneziaWG остановлено: $state');
      }
      await _refreshTelemetry();
      return;
    }
    await _refreshNativeStatus();
    await _refreshTelemetry();
  }

  Future<void> _refreshTelemetry() async {
    if (_telemetryInProgress || _snapshot.status != TunnelStatus.connected) {
      return;
    }
    _telemetryInProgress = true;
    try {
      final current = await _bridge.telemetry();
      final previous = _previousTelemetry;
      _previousTelemetry = current;
      if (previous == null) {
        _setSnapshot(_snapshot.copyWith(
          pingMs: current.pingMs > 0 ? current.pingMs : 0,
        ));
        return;
      }
      final elapsedMs = current.timestampMs - previous.timestampMs;
      if (elapsedMs <= 0) return;
      final rxDelta = current.rxBytes - previous.rxBytes;
      final txDelta = current.txBytes - previous.txBytes;
      final seconds = elapsedMs / 1000.0;
      _setSnapshot(_snapshot.copyWith(
        pingMs: current.pingMs > 0 ? current.pingMs : _snapshot.pingMs,
        downloadMbps: rxDelta > 0 ? (rxDelta * 8) / seconds / 1000000 : 0,
        uploadMbps: txDelta > 0 ? (txDelta * 8) / seconds / 1000000 : 0,
      ));
    } catch (_) {
      // Telemetry must never interrupt an otherwise healthy VPN tunnel.
    } finally {
      _telemetryInProgress = false;
    }
  }

  Future<void> saveAmneziaWgProfile(String profile) =>
      _profileStore.saveAmneziaWgProfile(profile);

  Future<bool> hasAmneziaWgProfile() =>
      _profileStore.hasAmneziaWgProfile();

  Future<void> _refreshNativeStatus() async {
    try {
      final native = await _bridge.status();
      switch (native.state) {
        case NativeVpnState.starting:
          _setSnapshot(_snapshot.copyWith(
            status: TunnelStatus.connecting,
            message: native.message,
          ));
          return;
        case NativeVpnState.ready:
          _setSnapshot(_snapshot.copyWith(
            status: native.engineAvailable
                ? TunnelStatus.connected
                : TunnelStatus.error,
            message: native.message,
          ));
          if (!native.engineAvailable) _statusTimer?.cancel();
          return;
        case NativeVpnState.stopping:
          _setSnapshot(_snapshot.copyWith(
            status: TunnelStatus.disconnecting,
            message: native.message,
          ));
          return;
        case NativeVpnState.stopped:
          _statusTimer?.cancel();
          _setSnapshot(const ConnectionSnapshot(
            status: TunnelStatus.disconnected,
            message: 'VPN-служба остановлена.',
          ));
          return;
        case NativeVpnState.error:
          _statusTimer?.cancel();
          _setError(native.message.isEmpty
              ? 'VPN-служба завершилась с ошибкой.'
              : native.message);
          return;
        case NativeVpnState.unsupported:
          _statusTimer?.cancel();
          _setError('Эта сборка поддерживает VPN только на Android.');
          return;
      }
    } catch (error) {
      _statusTimer?.cancel();
      _setError('Не удалось получить состояние VPN-службы: $error');
    }
  }

  void _setError(String message) {
    _setSnapshot(ConnectionSnapshot(
      status: TunnelStatus.error,
      message: message,
    ));
  }

  void _setSnapshot(ConnectionSnapshot value) {
    _snapshot = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }
}
