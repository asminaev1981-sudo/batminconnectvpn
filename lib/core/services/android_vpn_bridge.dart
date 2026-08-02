import 'dart:io';

import 'package:flutter/services.dart';

enum NativeVpnState { stopped, starting, ready, stopping, error, unsupported }

class NativeVpnStatus {
  const NativeVpnStatus({
    required this.state,
    this.message = '',
    this.engineAvailable = false,
  });

  final NativeVpnState state;
  final String message;
  final bool engineAvailable;
}

class AndroidVpnBridge {
  static const MethodChannel _channel = MethodChannel('pro.batmin.connect/vpn');

  bool get isSupported => Platform.isAndroid;

  Future<bool> prepare() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('prepare') ?? false;
  }

  Future<void> start({required String profileJson}) async {
    if (!isSupported) {
      throw UnsupportedError('VPN bridge is currently available only on Android');
    }
    await _channel.invokeMethod<void>('start', <String, Object?>{
      'profileJson': profileJson,
    });
  }

  Future<void> stop() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('stop');
  }

  Future<NativeVpnStatus> status() async {
    if (!isSupported) {
      return const NativeVpnStatus(state: NativeVpnState.unsupported);
    }
    final raw = await _channel.invokeMapMethod<String, Object?>('statusDetails');
    final value = raw?['state'] as String? ?? 'error';
    return NativeVpnStatus(
      state: NativeVpnState.values.firstWhere(
        (state) => state.name == value,
        orElse: () => NativeVpnState.error,
      ),
      message: raw?['message'] as String? ?? '',
      engineAvailable: raw?['engineAvailable'] as bool? ?? false,
    );
  }

  Future<List<String>> logs() async {
    if (!isSupported) return const <String>[];
    final result = await _channel.invokeListMethod<String>('logs');
    return result ?? const <String>[];
  }
}
