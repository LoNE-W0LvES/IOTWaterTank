/// Application configuration
/// This file contains all configurable settings for the IoT app
/// Modify these values to customize for different projects
class AppConfig {
  // API Configuration
  static const String baseUrl = 'http://103.136.236.16';
  static const String apiPrefix = '/api';

  // API Endpoints
  static const String signInEndpoint = '$apiPrefix/auth/sign-in/email';
  static const String signOutEndpoint = '$apiPrefix/auth/sign-out';
  static const String devicesEndpoint = '$apiPrefix/devices';

  // Session Configuration
  static const String sessionCookieName = 'better-auth.session_token';
  static const String sessionStorageKey = 'user_session';

  // App Configuration
  static const String appName = 'IoT Water Tank';
  static const String appVersion = '1.0.0';

  // Timeouts (in seconds)
  static const int connectionTimeout = 30;
  static const int receiveTimeout = 30;

  // Refresh Configuration
  static const int autoRefreshInterval = 30; // seconds

  // Device Status
  static const int deviceActiveThreshold = 300; // seconds (5 minutes)

  // UI Configuration
  static const bool enableDebugMode = true;
  static const int maxRetryAttempts = 3;

  // System Control Data Keys (these are typically not user-editable)
  static const List<String> systemControlKeys = [
    'force_update',
    'config_update',
  ];

  /// Check if a control key is a system key
  static bool isSystemControl(String key) {
    return systemControlKeys.contains(key);
  }

  /// Get full URL for an endpoint
  static String getUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
}
