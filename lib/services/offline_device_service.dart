import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import '../models/control_data.dart';
import '../utils/api_exception.dart';
import 'api_client.dart';

/// Service for offline-capable device operations
/// Tries local IP first, then falls back to server
class OfflineDeviceService {
  final ApiClient _apiClient;
  Dio? _localDio;

  OfflineDeviceService() : _apiClient = ApiClient();

  Future<void> initialize() async {
    await _apiClient.initialize();

    // Create a separate Dio instance for local connections
    _localDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      validateStatus: (status) => status! < 500,
    ));
  }

  /// Get device data with offline support
  /// Tries local IP first, then falls back to server
  Future<Device> getDevice(String deviceId, {String? localIp}) async {
    // Try local connection first if IP is available
    if (localIp != null && localIp.isNotEmpty) {
      try {
        print('Attempting to fetch device from local IP: $localIp');
        final localDevice = await _getDeviceFromLocal(deviceId, localIp);

        // Cache the data locally
        await _cacheDeviceData(deviceId, localDevice);

        print('Successfully fetched device from local IP');
        return localDevice;
      } catch (e) {
        print('Local connection failed: $e');
        print('Falling back to server...');
      }
    }

    // Fall back to server
    try {
      final response = await _apiClient.get('/devices/$deviceId');
      final device = Device.fromJson(response.data);

      // Cache the data locally
      await _cacheDeviceData(deviceId, device);

      return device;
    } catch (e) {
      // Try to return cached data if available
      final cachedDevice = await _getCachedDeviceData(deviceId);
      if (cachedDevice != null) {
        print('Using cached device data (offline mode)');
        return cachedDevice;
      }

      throw ApiException('Failed to fetch device data');
    }
  }

  /// Get device from local IP
  Future<Device> _getDeviceFromLocal(String deviceId, String localIp) async {
    if (_localDio == null) throw Exception('Service not initialized');

    final url = 'http://$localIp/api/device';
    final response = await _localDio!.get(url);

    if (response.statusCode == 200) {
      return Device.fromJson(response.data);
    } else {
      throw ApiException('Local device returned status ${response.statusCode}');
    }
  }

  /// Update control data with offline support
  Future<bool> updateControl(
    String deviceId,
    String key,
    dynamic value,
    String type, {
    String? localIp,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Try local connection first if IP is available
    if (localIp != null && localIp.isNotEmpty) {
      try {
        print('Attempting to update control via local IP: $localIp');
        await _updateControlLocal(deviceId, key, value, type, timestamp, localIp);

        // Also queue for server sync
        await _queueControlUpdate(deviceId, key, value, type, timestamp);

        print('Control updated via local IP');
        return true;
      } catch (e) {
        print('Local control update failed: $e');
        print('Falling back to server...');
      }
    }

    // Try server
    try {
      await _apiClient.patch('/devices/$deviceId/control', data: {
        key: {
          'type': type,
          'value': value,
          'lastModified': timestamp,
        }
      });

      // Remove from queue if it was there
      await _removeFromQueue(deviceId, key);

      return true;
    } catch (e) {
      // Queue for later sync
      await _queueControlUpdate(deviceId, key, value, type, timestamp);
      print('Control update queued for sync (offline mode)');
      return true; // Return true since it's queued
    }
  }

  /// Update control on local device
  Future<void> _updateControlLocal(
    String deviceId,
    String key,
    dynamic value,
    String type,
    int timestamp,
    String localIp,
  ) async {
    if (_localDio == null) throw Exception('Service not initialized');

    final url = 'http://$localIp/api/control';
    final response = await _localDio!.post(url, data: {
      key: {
        'type': type,
        'value': value,
        'lastModified': timestamp,
      }
    });

    if (response.statusCode != 200) {
      throw ApiException('Local control update failed with status ${response.statusCode}');
    }
  }

  /// Cache device data locally
  Future<void> _cacheDeviceData(String deviceId, Device device) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'device_cache_$deviceId';
    final jsonString = jsonEncode(device.toJson());
    await prefs.setString(cacheKey, jsonString);
    await prefs.setInt('${cacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// Get cached device data
  Future<Device?> _getCachedDeviceData(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'device_cache_$deviceId';
    final jsonString = prefs.getString(cacheKey);

    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString);
        return Device.fromJson(json);
      } catch (e) {
        print('Error parsing cached device data: $e');
        return null;
      }
    }

    return null;
  }

  /// Queue control update for later sync
  Future<void> _queueControlUpdate(
    String deviceId,
    String key,
    dynamic value,
    String type,
    int timestamp,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final queueKey = 'sync_queue';

    // Get existing queue
    final queueJson = prefs.getString(queueKey);
    List<Map<String, dynamic>> queue = [];

    if (queueJson != null) {
      queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
    }

    // Add new item or update existing
    final existingIndex = queue.indexWhere(
      (item) => item['deviceId'] == deviceId && item['key'] == key,
    );

    final updateData = {
      'deviceId': deviceId,
      'key': key,
      'value': value,
      'type': type,
      'timestamp': timestamp,
    };

    if (existingIndex >= 0) {
      // Update existing entry if timestamp is newer
      if (timestamp > (queue[existingIndex]['timestamp'] as int)) {
        queue[existingIndex] = updateData;
      }
    } else {
      queue.add(updateData);
    }

    // Save queue
    await prefs.setString(queueKey, jsonEncode(queue));
  }

  /// Remove item from sync queue
  Future<void> _removeFromQueue(String deviceId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final queueKey = 'sync_queue';

    final queueJson = prefs.getString(queueKey);
    if (queueJson != null) {
      List<Map<String, dynamic>> queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
      queue.removeWhere((item) => item['deviceId'] == deviceId && item['key'] == key);
      await prefs.setString(queueKey, jsonEncode(queue));
    }
  }

  /// Sync pending changes to server
  Future<SyncResult> syncPendingChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final queueKey = 'sync_queue';
    final queueJson = prefs.getString(queueKey);

    if (queueJson == null) {
      return SyncResult(synced: 0, failed: 0);
    }

    List<Map<String, dynamic>> queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));

    int synced = 0;
    int failed = 0;
    List<Map<String, dynamic>> failedItems = [];

    for (final item in queue) {
      try {
        // Fetch current server data to compare timestamps
        final serverDevice = await _apiClient.get('/devices/${item['deviceId']}');
        final serverControlData = serverDevice.data['controlData'] ?? {};
        final serverControl = serverControlData[item['key']];

        int? serverTimestamp = serverControl?['lastModified'];
        int localTimestamp = item['timestamp'] as int;

        // Only sync if local change is newer (last-write-wins)
        if (serverTimestamp == null || localTimestamp > serverTimestamp) {
          await _apiClient.patch('/devices/${item['deviceId']}/control', data: {
            item['key']: {
              'type': item['type'],
              'value': item['value'],
              'lastModified': localTimestamp,
            }
          });

          synced++;
          print('Synced ${item['key']} for device ${item['deviceId']}');
        } else {
          print('Skipped ${item['key']} - server has newer data');
          synced++; // Count as synced since we resolved the conflict
        }
      } catch (e) {
        print('Failed to sync ${item['key']}: $e');
        failed++;
        failedItems.add(item);
      }
    }

    // Update queue with only failed items
    await prefs.setString(queueKey, jsonEncode(failedItems));

    return SyncResult(synced: synced, failed: failed);
  }

  /// Get sync queue status
  Future<int> getPendingChangesCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString('sync_queue');

    if (queueJson == null) return 0;

    List<Map<String, dynamic>> queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
    return queue.length;
  }

  /// Clear all cached data and pending changes
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith('device_cache_') || key == 'sync_queue') {
        await prefs.remove(key);
      }
    }
  }
}

/// Result of sync operation
class SyncResult {
  final int synced;
  final int failed;

  SyncResult({required this.synced, required this.failed});

  bool get hasFailures => failed > 0;
  bool get allSynced => failed == 0 && synced > 0;
}
