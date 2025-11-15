import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'api_client.dart';
import '../utils/api_exception.dart';

/// Authentication service for managing user sessions
class AuthService {
  final ApiClient _apiClient = ApiClient();
  SharedPreferences? _prefs;

  /// Initialize the auth service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _apiClient.initialize();
  }

  /// Sign in with email and password
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        AppConfig.signInEndpoint,
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        // Check if we have the session cookie
        final cookies = await _apiClient.getCookies(AppConfig.baseUrl);
        final sessionCookie = cookies.firstWhere(
          (cookie) => cookie.name == AppConfig.sessionCookieName,
          orElse: () => Cookie('', ''),
        );

        if (sessionCookie.value.isNotEmpty) {
          // Save session state
          await _saveSessionState(true);

          // Return user data if available
          final data = response.data;
          if (data is Map<String, dynamic>) {
            return data;
          }
        }
      }

      throw ApiException(
        message: 'Login failed. Please check your credentials.',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.fromError(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Try to call the sign out endpoint
      try {
        await _apiClient.post(AppConfig.signOutEndpoint);
      } catch (e) {
        // Ignore errors from sign out endpoint
        print('Sign out endpoint error: $e');
      }

      // Clear local session data
      await _apiClient.clearCookies();
      await _saveSessionState(false);
    } catch (e) {
      throw ApiException.fromError(e);
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final isLoggedIn = _prefs?.getBool(AppConfig.sessionStorageKey) ?? false;

      if (!isLoggedIn) return false;

      // Check if we have valid cookies
      final cookies = await _apiClient.getCookies(AppConfig.baseUrl);
      final sessionCookie = cookies.firstWhere(
        (cookie) => cookie.name == AppConfig.sessionCookieName,
        orElse: () => Cookie('', ''),
      );

      return sessionCookie.value.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Save session state to local storage
  Future<void> _saveSessionState(bool isLoggedIn) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(AppConfig.sessionStorageKey, isLoggedIn);
  }

  /// Clear all session data
  Future<void> clearSession() async {
    await _apiClient.clearCookies();
    await _saveSessionState(false);
  }
}
