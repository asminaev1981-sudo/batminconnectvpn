import 'dart:convert';

import '../models/vpn_profile.dart';

class ProfileParser {
  const ProfileParser();

  VpnProfile parse(
    String input, {
    String? name,
    VpnProfileSource source = VpnProfileSource.unknown,
  }) {
    final raw = input.trim();

    if (raw.isEmpty) {
      throw const FormatException('VPN profile is empty');
    }

    final type = detectType(raw);
    final endpoint = _extractEndpoint(raw, type);

    return VpnProfile(
      id: _makeId(raw),
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : _defaultName(type, endpoint.$1),
      type: type,
      rawConfig: raw,
      server: endpoint.$1,
      port: endpoint.$2,
      source: source,
    );
  }

  VpnProfileType detectType(String input) {
    final raw = input.trim();
    final lower = raw.toLowerCase();

    if (lower.startsWith('hysteria2://') ||
        lower.startsWith('hy2://')) {
      return VpnProfileType.hysteria2;
    }

    if (lower.startsWith('vless://')) {
      return VpnProfileType.vless;
    }

    if (_looksLikeAmneziaWg(raw)) {
      return VpnProfileType.amneziaWg;
    }

    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);

        if (decoded is Map<String, dynamic>) {
          final outbounds = decoded['outbounds'];

          if (outbounds is List) {
            for (final outbound in outbounds) {
              if (outbound is! Map) {
                continue;
              }

              final type =
                  outbound['type']?.toString().toLowerCase();

              if (type == 'hysteria2') {
                return VpnProfileType.hysteria2;
              }

              if (type == 'vless') {
                return VpnProfileType.vless;
              }
            }
          }

          return VpnProfileType.singBox;
        }
      } on FormatException {
        // Continue detection below.
      }
    }

    return VpnProfileType.unknown;
  }

  bool _looksLikeAmneziaWg(String raw) {
    final lower = raw.toLowerCase();

    if (!lower.contains('[interface]') ||
        !lower.contains('[peer]')) {
      return false;
    }

    const markers = <String>[
      'jc =',
      'jmin =',
      'jmax =',
      's1 =',
      's2 =',
      'h1 =',
      'h2 =',
      'h3 =',
      'h4 =',
    ];

    return markers.any(lower.contains);
  }

  (String?, int?) _extractEndpoint(
    String raw,
    VpnProfileType type,
  ) {
    switch (type) {
      case VpnProfileType.hysteria2:
      case VpnProfileType.vless:
        final uri = Uri.tryParse(raw);

        if (uri != null && uri.host.isNotEmpty) {
          return (
            uri.host,
            uri.hasPort ? uri.port : null,
          );
        }

        return (null, null);

      case VpnProfileType.amneziaWg:
        final match = RegExp(
          r'^\s*Endpoint\s*=\s*(.+):(\d+)\s*$',
          caseSensitive: false,
          multiLine: true,
        ).firstMatch(raw);

        if (match == null) {
          return (null, null);
        }

        return (
          match.group(1)?.trim(),
          int.tryParse(match.group(2)!),
        );

      case VpnProfileType.singBox:
        try {
          final decoded = jsonDecode(raw);

          if (decoded is! Map<String, dynamic>) {
            return (null, null);
          }

          final outbounds = decoded['outbounds'];

          if (outbounds is! List) {
            return (null, null);
          }

          for (final outbound in outbounds) {
            if (outbound is! Map) {
              continue;
            }

            final server =
                outbound['server']?.toString();
            final port = outbound['server_port'];

            if (server != null && server.isNotEmpty) {
              return (
                server,
                port is num ? port.toInt() : null,
              );
            }
          }
        } on FormatException {
          return (null, null);
        }

        return (null, null);

      case VpnProfileType.unknown:
        return (null, null);
    }
  }

  String _defaultName(
    VpnProfileType type,
    String? server,
  ) {
    final label = switch (type) {
      VpnProfileType.hysteria2 => 'Hysteria2',
      VpnProfileType.amneziaWg => 'AmneziaWG',
      VpnProfileType.vless => 'VLESS',
      VpnProfileType.singBox => 'sing-box',
      VpnProfileType.unknown => 'VPN profile',
    };

    return server == null
        ? label
        : '$label · $server';
  }

  String _makeId(String raw) {
    var hash = 0x811c9dc5;

    for (final unit in utf8.encode(raw)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return hash
        .toRadixString(16)
        .padLeft(8, '0');
  }
}