import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VpnProfileStore {
  VpnProfileStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _awgProfileKey = 'batmin_awg31_profile';
  final FlutterSecureStorage _storage;

  Future<String?> readAmneziaWgProfile() => _storage.read(key: _awgProfileKey);

  Future<void> saveAmneziaWgProfile(String profile) async {
    final normalized = profile.trim();
    if (!normalized.contains('[Interface]') ||
        !normalized.contains('[Peer]') ||
        !normalized.contains('PrivateKey') ||
        !normalized.contains('Endpoint')) {
      throw const FormatException('Некорректный профиль AmneziaWG');
    }
    await _storage.write(key: _awgProfileKey, value: normalized);
  }

  Future<bool> hasAmneziaWgProfile() async =>
      (await readAmneziaWgProfile())?.isNotEmpty == true;
}
