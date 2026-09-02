import 'package:shared_preferences/shared_preferences.dart';

/// Simple secure storage abstraction for JWT token persistence.
/// Uses SharedPreferences instead of in-memory variables to survive hot restarts.
class StorageService {
  /// Save JWT token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// Retrieve stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Clear stored token
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// Mark onboarding as complete for the given user (or globally if userId is null)
  static Future<void> setOnboardingComplete([String? userId]) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId != null && userId.isNotEmpty) {
      await prefs.setBool('onboarding_complete_$userId', true);
    }
    await prefs.setBool('onboarding_complete', true);
  }

  /// Check if onboarding has been completed for the given user
  static Future<bool> isOnboardingComplete([String? userId]) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId != null && userId.isNotEmpty) {
      final userCompleted = prefs.getBool('onboarding_complete_$userId');
      if (userCompleted != null) return userCompleted;
    }
    return false;
  }
}
