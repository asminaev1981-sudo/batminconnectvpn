import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/connection_state.dart';
import 'android_vpn_bridge.dart';

class ConnectionController extends ChangeNotifier {
  ConnectionController({AndroidVpnBridge? bridge})
      : _bridge = bridge ?? AndroidVpnBridge();

  final AndroidVpnBridge _bridge;
  Timer? _statusTimer;
  bool _operationInProgress = false;

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

      final profileJson = await rootBundle.loadString(
        'assets/config/batmin_hysteria2.json',
      );
      _setSnapshot(const ConnectionSnapshot(
        status: TunnelStatus.connecting,
        message: 'Запускаю VPN-службу и передаю профиль Hysteria2…',
      ));

      await _bridge.start(profileJson: profileJson);
      _startStatusPolling();
      await _refreshNativeStatus();
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
      await _bridge.stop();
      _statusTimer?.cancel();
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
      (_) => _refreshNativeStatus(),
    );
  }

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
