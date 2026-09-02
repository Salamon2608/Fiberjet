import 'package:fiberjet/services/api_service.dart';

/// Data service for all customer-related API calls.
class CustomerDataService {
  /// Fetch dashboard data including user profile, active plan, and complaints.
  static Future<ApiResult> getDashboardData() =>
      ApiService.get('/customer/dashboard');

  /// Fetch notifications for the customer.
  static Future<ApiResult> getNotifications() =>
      ApiService.get('/customer/notifications');

  /// Fetch available plans for the customer.
  static Future<ApiResult> getPlans() =>
      ApiService.get('/customer/plans');

  /// Buy a new plan.
  static Future<ApiResult> buyPlan(String planId) =>
      ApiService.post('/customer/plans/buy', body: {'plan_id': planId});

  /// Fetch user's subscription details (active, queued, history).
  static Future<ApiResult> getMySubscriptions() =>
      ApiService.get('/customer/my_subscriptions');

  /// Save a speed test result to the backend.
  static Future<ApiResult> saveSpeedTest({
    required double downloadMbps,
    required double uploadMbps,
    required double pingMs,
    required double jitterMs,
  }) =>
      ApiService.post('/customer/speed_test', body: {
        'download_mbps': downloadMbps,
        'upload_mbps': uploadMbps,
        'ping_ms': pingMs,
        'jitter_ms': jitterMs,
      });

  /// Fetch speed test history with averages (last 30 by default).
  static Future<ApiResult> getSpeedTestHistory({int limit = 30}) =>
      ApiService.get('/customer/speed_test',
          queryParams: {'limit': limit.toString()});

  /// Fetch the authenticated user's profile (works for any role).
  static Future<ApiResult> getProfile() =>
      ApiService.get('/auth/profile');

  /// Update the authenticated user's profile.
  static Future<ApiResult> updateProfile(Map<String, dynamic> data) =>
      ApiService.put('/auth/profile', body: data);

  /// Change password for the authenticated user.
  static Future<ApiResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      ApiService.post('/auth/change-password', body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });

  // ── Complaints & Support ────────────────────────────────────

  /// Fetch user's complaints/tickets with optional status filter.
  static Future<ApiResult> getComplaints({String? status}) =>
      ApiService.get('/customer/complaints', queryParams: {
        if (status != null && status.isNotEmpty) 'status': status,
      });

  /// Create a new complaint/support ticket.
  static Future<ApiResult> createComplaint({
    required String category,
    required String description,
    String? title,
    double? latitude,
    double? longitude,
  }) =>
      ApiService.post('/customer/complaints', body: {
        'title': title ?? 'Support Ticket',
        'category': category,
        'description': description,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });

  // ── Modem / ONT Info ────────────────────────────────────────

  /// Fetch modem/ONT info for the customer.
  static Future<ApiResult> getModemInfo() =>
      ApiService.get('/customer/modem_info');

  static Future<ApiResult> rebootModem() =>
      ApiService.post('/customer/modem_reboot');

  // ── Network Scanner ──────────────────────────────────────────

  static Future<ApiResult> getNetworkDevices() =>
      ApiService.get('/customer/network_devices');

  /// Triggers a real-time network scan on the backend server.
  static Future<ApiResult> triggerNetworkScan() =>
      ApiService.post('/customer/network_devices');

  static Future<ApiResult> updateDeviceAccess(String id, String accessLevel) =>
      ApiService.post('/customer/network_devices/$id/status', body: {'access_level': accessLevel});

  // ── Notification Preferences ────────────────────────────────

  /// Fetch user's notification preferences.
  static Future<ApiResult> getNotificationPreferences() =>
      ApiService.get('/customer/notification_preferences');

  /// Update user's notification preferences.
  static Future<ApiResult> updateNotificationPreferences(Map<String, dynamic> prefs) =>
      ApiService.put('/customer/notification_preferences', body: prefs);

  // ── Forgot / Reset Password ─────────────────────────────────

  /// Request password reset OTP.
  static Future<ApiResult> forgotPassword(String phone) =>
      ApiService.post('/auth/forgot-password', body: {'phone': phone});

  /// Reset password with OTP code.
  static Future<ApiResult> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) =>
      ApiService.post('/auth/reset-password', body: {
        'phone': phone,
        'code': code,
        'new_password': newPassword,
      });

  // ── Promo Ad Campaigns ──────────────────────────────────────

  /// Fetch active and scheduled promotional ad campaigns.
  static Future<ApiResult> getAds() =>
      ApiService.get('/customer/ads');

  /// Record an impression for a specific promotional ad campaign.
  static Future<ApiResult> recordAdImpression(String adId) =>
      ApiService.post('/customer/ads/$adId/impression');

  /// Record a click for a specific promotional ad campaign.
  static Future<ApiResult> recordAdClick(String adId) =>
      ApiService.post('/customer/ads/$adId/click');
}
