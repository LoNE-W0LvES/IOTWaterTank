import 'package:equatable/equatable.dart';

/// Timestamp synchronization response from device
class TimestampSyncResponse extends Equatable {
  final int timestamp; // Unix timestamp in milliseconds
  final String source; // "server" or "device"
  final int drift; // Milliseconds drift (if calculated)
  final int? lastSync; // Last sync millis (device internal)
  final int? uptime; // Device uptime in milliseconds

  const TimestampSyncResponse({
    required this.timestamp,
    required this.source,
    required this.drift,
    this.lastSync,
    this.uptime,
  });

  /// Check if timestamp is from server
  bool get isServerSynced => source.toLowerCase() == 'server';

  /// Check if timestamp is from device (millis)
  bool get isDeviceTime => source.toLowerCase() == 'device';

  factory TimestampSyncResponse.fromJson(Map<String, dynamic> json) {
    return TimestampSyncResponse(
      timestamp: json['timestamp'] as int? ?? 0,
      source: json['source'] as String? ?? 'device',
      drift: json['drift'] as int? ?? 0,
      lastSync: json['lastSync'] as int?,
      uptime: json['uptime'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'source': source,
      'drift': drift,
      if (lastSync != null) 'lastSync': lastSync,
      if (uptime != null) 'uptime': uptime,
    };
  }

  @override
  List<Object?> get props => [timestamp, source, drift, lastSync, uptime];
}

/// Server timestamp response
class ServerTimestampResponse extends Equatable {
  final int timestamp; // Unix timestamp in milliseconds
  final String timezone; // Timezone (e.g., "UTC")

  const ServerTimestampResponse({
    required this.timestamp,
    required this.timezone,
  });

  factory ServerTimestampResponse.fromJson(Map<String, dynamic> json) {
    return ServerTimestampResponse(
      timestamp: json['timestamp'] as int? ?? 0,
      timezone: json['timezone'] as String? ?? 'UTC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'timezone': timezone,
    };
  }

  @override
  List<Object?> get props => [timestamp, timezone];
}
