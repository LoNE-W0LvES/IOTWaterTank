import 'package:dio/dio.dart';
import '../models/timestamp_sync.dart';
import '../config/app_config.dart';
import 'api_client.dart';

/// Service for timestamp synchronization with server and device
///
/// Synchronization Flow:
/// 1. App → Server: Get server timestamp (GET /api/timeSync?deviceId={id})
/// 2. App → Device: Get device timestamp (GET http://{ip}/{id}/timestamp)
/// 3. App: Check drift - if > 5 seconds, send correction
/// 4. App → Device: Send corrected timestamp (POST http://{ip}/{id}/timestamp)
/// 5. Device → Server: Device syncs data and timestamp with server (heartbeat)
/// 6. App → Device: Verify correction (GET http://{ip}/{id}/timestamp)
///
/// This ensures device time stays synchronized with server time for accurate
/// telemetry timestamps and data consistency.
class TimestampService {
  static const Duration _timeout = Duration(seconds: 5);
  static const int _maxDriftMs = 5000; // 5 seconds max acceptable drift
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
      AppConfig.deviceLog('Failed to get server timestamp: $e');
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
      AppConfig.deviceLog('Device local IP not available for timestamp sync');
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
      AppConfig.deviceLog('Failed to get device timestamp from $localIp: $e');
      return null;
    }
  }

  /// Send corrected timestamp to device via local IP
  /// POST http://{device_ip}/{device_id}/timestamp
  /// Body: { "timestamp": unixTimestampInMs }
  Future<bool> sendTimestampToDevice(
    String deviceId,
    int timestamp, {
    String? localIp,
  }) async {
    if (localIp == null || localIp.isEmpty) {
      AppConfig.deviceLog('Device local IP not available for sending timestamp');
      return false;
    }

    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'http://$localIp',
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
      ));

      final response = await dio.post(
        '/$deviceId/timestamp',
        data: {'timestamp': timestamp},
      );

      if (response.statusCode == 200) {
        AppConfig.deviceLog('Timestamp sent to device: $timestamp');
        return true;
      }
      return false;
    } catch (e) {
      AppConfig.deviceLog('Failed to send timestamp to device at $localIp: $e');
      return false;
    }
  }

  /// Sync timestamp with device and correct if drift is too large
  /// 1. Get server timestamp
  /// 2. Get device timestamp
  /// 3. Check drift - if > maxDrift, send correction
  /// 4. Device will then sync with server
  /// Returns the timestamp sync response from device
  Future<TimestampSyncResponse?> syncDeviceTimestamp(
    String deviceId, {
    String? localIp,
  }) async {
    if (localIp == null || localIp.isEmpty) {
      AppConfig.deviceLog('Cannot sync device timestamp: No local IP');
      return null;
    }

    try {
      // Step 1: Get server timestamp
      final serverTimestamp = await getServerTimestamp(deviceId);

      if (serverTimestamp != null) {
        AppConfig.deviceLog(
          'Server timestamp obtained: ${serverTimestamp.serverTime}',
        );
      } else {
        AppConfig.deviceLog('Server timestamp unavailable, device will use millis()');
      }

      // Step 2: Get device's current timestamp state
      final deviceTimestamp = await getDeviceTimestamp(
        deviceId,
        localIp: localIp,
      );

      if (deviceTimestamp != null) {
        AppConfig.deviceLog(
          'Device timestamp: ${deviceTimestamp.timestamp}, '
          'source: ${deviceTimestamp.source}, '
          'drift: ${deviceTimestamp.drift}ms',
        );

        // Step 3: Check drift and correct if needed
        if (serverTimestamp != null) {
          final currentDrift = calculateDrift(
            serverTimestamp: serverTimestamp.serverTime,
            deviceTimestamp: deviceTimestamp.timestamp,
          );

          final driftAbs = currentDrift.abs();

          AppConfig.deviceLog('Calculated drift: ${currentDrift}ms (abs: ${driftAbs}ms)');

          // If drift is too large, send corrected timestamp to device
          if (driftAbs > _maxDriftMs) {
            AppConfig.deviceLog(
              'Drift exceeds threshold ($_maxDriftMs ms). Sending correction to device...',
            );

            final corrected = await sendTimestampToDevice(
              deviceId,
              serverTimestamp.serverTime,
              localIp: localIp,
            );

            if (corrected) {
              AppConfig.deviceLog('Timestamp correction sent. Waiting for device to sync with server...');

              // Wait a bit for device to process and sync with server
              await Future.delayed(const Duration(seconds: 2));

              // Get updated timestamp from device after correction
              final updatedTimestamp = await getDeviceTimestamp(
                deviceId,
                localIp: localIp,
              );

              if (updatedTimestamp != null) {
                AppConfig.deviceLog(
                  'Device timestamp after correction: ${updatedTimestamp.timestamp}, '
                  'source: ${updatedTimestamp.source}, drift: ${updatedTimestamp.drift}ms',
                );
                return updatedTimestamp;
              }
            } else {
              AppConfig.deviceLog('Failed to send timestamp correction to device');
            }
          } else {
            AppConfig.deviceLog('Drift within acceptable range');
          }
        }
      }

      return deviceTimestamp;
    } catch (e) {
      AppConfig.deviceLog('Error syncing device timestamp: $e');
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
  ///
  /// Note: System time is used as last resort to keep app running,
  /// but if both server and device are offline, the device won't be
  /// able to save data anyway. App will keep trying to reconnect.
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

    // Fallback to system time (app keeps running until server/device reconnects)
    return DateTime.now().millisecondsSinceEpoch;
  }
}
