import '../models/vpn_profile.dart';
import 'profile_parser.dart';
import 'profile_store.dart';

class ProfileImportService {
  ProfileImportService({
    ProfileParser? parser,
    ProfileStore? store,
  })  : _parser = parser ?? const ProfileParser(),
        _store = store ?? ProfileStore();

  final ProfileParser _parser;
  final ProfileStore _store;

  Future<VpnProfile> importText(
    String input, {
    String? name,
    VpnProfileSource source = VpnProfileSource.unknown,
  }) async {
    final profile = _parser.parse(
      input,
      name: name,
      source: source,
    );

    if (profile.type == VpnProfileType.unknown) {
      throw const FormatException(
        'Unsupported VPN configuration',
      );
    }

    await _store.upsert(profile);

    return profile;
  }

  Future<VpnProfile> importClipboard(
    String clipboardText, {
    String? name,
  }) {
    return importText(
      clipboardText,
      name: name,
      source: VpnProfileSource.clipboard,
    );
  }

  Future<VpnProfile> importFileContent(
    String fileContent, {
    String? fileName,
  }) {
    return importText(
      fileContent,
      name: _profileNameFromFile(fileName),
      source: VpnProfileSource.file,
    );
  }

  Future<VpnProfile> importQr(
    String qrData, {
    String? name,
    bool fromImage = false,
  }) {
    return importText(
      qrData,
      name: name,
      source: fromImage
          ? VpnProfileSource.qrImage
          : VpnProfileSource.qrCamera,
    );
  }

  Future<VpnProfile> importUrl(
    String url, {
    String? name,
  }) {
    return importText(
      url,
      name: name,
      source: VpnProfileSource.url,
    );
  }

  Future<List<VpnProfile>> getProfiles() {
    return _store.load();
  }

  Future<List<VpnProfile>> deleteProfile(
    String profileId,
  ) {
    return _store.remove(profileId);
  }

  Future<List<VpnProfile>> setEnabled(
    String profileId,
    bool enabled,
  ) async {
    final profiles = await _store.load();

    final index = profiles.indexWhere(
      (profile) => profile.id == profileId,
    );

    if (index < 0) {
      throw StateError(
        'VPN profile not found: $profileId',
      );
    }

    final updated = profiles[index].copyWith(
      enabled: enabled,
    );

    final mutable = profiles.toList();
    mutable[index] = updated;

    await _store.save(mutable);

    return mutable;
  }

  String? _profileNameFromFile(String? fileName) {
    if (fileName == null || fileName.trim().isEmpty) {
      return null;
    }

    final normalized = fileName
        .replaceAll('\\', '/')
        .split('/')
        .last
        .trim();

    if (normalized.isEmpty) {
      return null;
    }

    final dot = normalized.lastIndexOf('.');

    if (dot <= 0) {
      return normalized;
    }

    return normalized.substring(0, dot);
  }
}