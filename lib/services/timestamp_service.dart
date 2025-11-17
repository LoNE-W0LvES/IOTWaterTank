import 'package:dio/dio.dart';
import '../models/timestamp_sync.dart';
import '../config/app_config.dart';
import 'api_client.dart';

/// Service for timestamp synchronization with server and device
class TimestampService {
  static const Duration _timeout = Duration(seconds: 5);
  final ApiClient _apiClient = ApiClient();

  /// Get current timestamp from server
  /// GET /api/timeSync?deviceId={deviceId}
  /// Returns server timestamp in milliseconds
  Future<ServerTimestampResponse?> getServerTimestamp(String deviceId) async {
    try {
      final response = await _apiClient.get(
        '/api/timeSync',
        queryParameters: {'deviceId': deviceId},
        options: Options(
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return ServerTimestampResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      AppConfig.debugLog('Failed to get server timestamp: $e');
      return null;
    }
  }

  /// Get timestamp from device via local IP
  /// GET http://{device_ip}/{device_id}/timestamp
  Future<TimestampSyncResponse?> getDeviceTimestamp(
    String deviceId, {
    String? localIp,
  }) async {
    if (localIp == null || localIp.isEmpty) {
      AppConfig.debugLog('Device local IP not available for timestamp sync');
      return null;
    }

    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'http://$localIp',
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
      ));

      final response = await dio.get('/$deviceId/timestamp');

      if (response.statusCode == 200 && response.data != null) {
        return TimestampSyncResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      AppConfig.debugLog('Failed to get device timestamp from $localIp: $e');
      return null;
    }
  }

  /// Sync timestamp with device
  /// First tries to get server timestamp, then syncs device
  /// Returns the timestamp sync response from device
  Future<TimestampSyncResponse?> syncDeviceTimestamp(
    String deviceId, {
    String? localIp,
  }) async {
    if (localIp == null || localIp.isEmpty) {
      AppConfig.debugLog('Cannot sync device timestamp: No local IP');
      return null;
    }

    try {
      // Step 1: Get server timestamp
      final serverTimestamp = await getServerTimestamp(deviceId);

      if (serverTimestamp != null) {
        AppConfig.debugLog(
          'Server timestamp obtained: ${serverTimestamp.serverTime}',
        );
      } else {
        AppConfig.debugLog('Server timestamp unavailable, device will use millis()');
      }

      // Step 2: Get device's current timestamp state
      final deviceTimestamp = await getDeviceTimestamp(
        deviceId,
        localIp: localIp,
      );

      if (deviceTimestamp != null) {
        AppConfig.debugLog(
          'Device timestamp: ${deviceTimestamp.timestamp}, '
          'source: ${deviceTimestamp.source}, '
          'drift: ${deviceTimestamp.drift}ms',
        );

        // Check if device needs to sync with server
        if (!deviceTimestamp.isServerSynced && serverTimestamp != null) {
          AppConfig.debugLog(
            'Device using local time, server available - device should sync',
          );
        }
      }

      return deviceTimestamp;
    } catch (e) {
      AppConfig.debugLog('Error syncing device timestamp: $e');
      return null;
    }
  }

  /// Calculate time drift between server and device
  /// Returns drift in milliseconds (positive = device is ahead)
  int calculateDrift({
    required int serverTimestamp,
    required int deviceTimestamp,
  }) {
    return deviceTimestamp - serverTimestamp;
  }

  /// Get current timestamp with fallback strategy
  /// Priority: Server > Device Local > System time
  Future<int> getCurrentTimestamp(
    String deviceId, {
    String? localIp,
  }) async {
    // Try server first
    final serverTimestamp = await getServerTimestamp(deviceId);
    if (serverTimestamp != null) {
      return serverTimestamp.serverTime;
    }

    // Try device if local IP available
    if (localIp != null && localIp.isNotEmpty) {
      final deviceTimestamp = await getDeviceTimestamp(
        deviceId,
        localIp: localIp,
      );
      if (deviceTimestamp != null) {
        return deviceTimestamp.timestamp;
      }
    }

    // Fallback to system time
    return DateTime.now().millisecondsSinceEpoch;
  }
}
