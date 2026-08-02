enum TunnelStatus {
  disconnected,
  preparing,
  connecting,
  connected,
  disconnecting,
  error,
}

class ConnectionSnapshot {
  const ConnectionSnapshot({
    required this.status,
    this.serverName = 'Netherlands',
    this.pingMs = 0,
    this.downloadMbps = 0,
    this.uploadMbps = 0,
    this.message = '',
  });

  final TunnelStatus status;
  final String serverName;
  final int pingMs;
  final double downloadMbps;
  final double uploadMbps;
  final String message;

  ConnectionSnapshot copyWith({
    TunnelStatus? status,
    String? serverName,
    int? pingMs,
    double? downloadMbps,
    double? uploadMbps,
    String? message,
  }) {
    return ConnectionSnapshot(
      status: status ?? this.status,
      serverName: serverName ?? this.serverName,
      pingMs: pingMs ?? this.pingMs,
      downloadMbps: downloadMbps ?? this.downloadMbps,
      uploadMbps: uploadMbps ?? this.uploadMbps,
      message: message ?? this.message,
    );
  }
}
