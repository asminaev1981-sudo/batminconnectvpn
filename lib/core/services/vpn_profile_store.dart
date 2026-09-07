import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VpnProfileStore {
  VpnProfileStore({FlutterSecureStorage? storage, AssetBundle? assetBundle})
      : _storage = storage ?? const FlutterSecureStorage(),
        _assetBundle = assetBundle ?? rootBundle;

  static const _awgProfileKey = 'batmin_awg31_profile';
  static const _bundledAwgProfile = 'assets/config/batmin_amneziawg.conf';
  final FlutterSecureStorage _storage;
  final AssetBundle _assetBundle;

  Future<String?> readAmneziaWgProfile() async {
    final savedProfile = await _storage.read(key: _awgProfileKey);
    if (savedProfile?.trim().isNotEmpty == true) return savedProfile!.trim();

    // A valid server-matched profile is shipped with Batmin Connect so AWG
    // and AUTO work immediately after installation. A manually saved profile
    // remains an explicit override for future per-user provisioning.
    try {
      final bundledProfile = await _assetBundle.loadString(_bundledAwgProfile);
      return bundledProfile.trim().isEmpty ? null : bundledProfile.trim();
    } on FlutterError {
      return null;
    }
  }

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
