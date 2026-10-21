import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/vpn_profile.dart';

class ProfileStore {
  static const _profilesKey = 'vpn_profiles_v1';

  Future<List<VpnProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);

    if (raw == null || raw.trim().isEmpty) {
      return <VpnProfile>[];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return <VpnProfile>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => VpnProfile.fromJson(
              Map<String, Object?>.from(item),
            ),
          )
          .where((profile) => profile.id.isNotEmpty)
          .toList(growable: false);
    } on FormatException {
      return <VpnProfile>[];
    }
  }

  Future<void> save(List<VpnProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();

    final payload = jsonEncode(
      profiles.map((profile) => profile.toJson()).toList(),
    );

    await prefs.setString(_profilesKey, payload);
  }

  Future<List<VpnProfile>> upsert(VpnProfile profile) async {
    final profiles = (await load()).toList();

    final index =
        profiles.indexWhere((item) => item.id == profile.id);

    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }

    await save(profiles);

    return profiles;
  }

  Future<List<VpnProfile>> remove(String id) async {
    final profiles = (await load())
        .where((profile) => profile.id != id)
        .toList();

    await save(profiles);

    return profiles;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profilesKey);
  }
}