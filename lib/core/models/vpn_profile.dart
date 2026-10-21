enum VpnProfileType {
  hysteria2,
  amneziaWg,
  vless,
  singBox,
  unknown,
}

enum VpnProfileSource {
  file,
  clipboard,
  qrCamera,
  qrImage,
  url,
  batmin,
  unknown,
}

class VpnProfile {
  const VpnProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.rawConfig,
    this.server,
    this.port,
    this.source = VpnProfileSource.unknown,
    this.enabled = true,
  });

  final String id;
  final String name;
  final VpnProfileType type;
  final String rawConfig;
  final String? server;
  final int? port;
  final VpnProfileSource source;
  final bool enabled;

  VpnProfile copyWith({
    String? id,
    String? name,
    VpnProfileType? type,
    String? rawConfig,
    String? server,
    int? port,
    VpnProfileSource? source,
    bool? enabled,
  }) {
    return VpnProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      rawConfig: rawConfig ?? this.rawConfig,
      server: server ?? this.server,
      port: port ?? this.port,
      source: source ?? this.source,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'type': type.name,
        'rawConfig': rawConfig,
        'server': server,
        'port': port,
        'source': source.name,
        'enabled': enabled,
      };

  factory VpnProfile.fromJson(Map<String, Object?> json) {
    final typeName =
        json['type'] as String? ?? VpnProfileType.unknown.name;
    final sourceName =
        json['source'] as String? ?? VpnProfileSource.unknown.name;

    return VpnProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'VPN profile',
      type: VpnProfileType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => VpnProfileType.unknown,
      ),
      rawConfig: json['rawConfig'] as String? ?? '',
      server: json['server'] as String?,
      port: (json['port'] as num?)?.toInt(),
      source: VpnProfileSource.values.firstWhere(
        (value) => value.name == sourceName,
        orElse: () => VpnProfileSource.unknown,
      ),
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}