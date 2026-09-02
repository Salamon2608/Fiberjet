import 'package:fiberjet/services/api_service.dart';

/// Data service for all technician-related API calls.
class TechDataService {
  // ── Dashboard ─────────────────────────────────────────────
  static Future<ApiResult> getDashboard() =>
      ApiService.get('/tech/dashboard');

  static Future<ApiResult> toggleStatus(bool isOnline) =>
      ApiService.post('/tech/toggle_status', body: {'is_online': isOnline});

  // ── Jobs ───────────────────────────────────────────────────
  static Future<ApiResult> getJobs({String? status}) =>
      ApiService.get('/tech/jobs', queryParams: {
        if (status != null) 'status': status,
      });

  static Future<ApiResult> getJob(String id) =>
      ApiService.get('/tech/jobs/$id');

  static Future<ApiResult> updateJobStatus(String id, String status, {String? macAddress, String? otp}) =>
      ApiService.post('/tech/jobs/$id/status', body: {
        'status': status,
        if (macAddress != null) 'mac_address': macAddress,
        if (otp != null) 'otp': otp,
      });

  static Future<ApiResult> updateJobChecklist(String id, Map<String, dynamic> checklist) =>
      ApiService.patch('/tech/jobs/$id', body: {'checklist': checklist});

  // ── Job Rejection ──────────────────────────────────────────
  static Future<ApiResult> rejectJob({
    required String jobId,
    required String reason,
    required String comment,
  }) =>
      ApiService.post('/tech/jobs/$jobId/reject', body: {
        'reason': reason,
        'comment': comment,
      });

  // ── Photos ─────────────────────────────────────────────────
  static Future<ApiResult> uploadJobPhoto({
    required String jobId,
    required String photoType,
    required String filePath,
  }) =>
      ApiService.post('/tech/jobs/$jobId/upload_photo', body: {
        'photo_type': photoType,
        'file_path': filePath,
      });

  // ── Chat ───────────────────────────────────────────────────
  static Future<ApiResult> getJobChat(String jobId) =>
      ApiService.get('/tech/jobs/$jobId/chat');

  static Future<ApiResult> sendJobMessage({
    required String jobId,
    required String message,
  }) =>
      ApiService.post('/tech/jobs/$jobId/chat', body: {'message': message});

  // ── Rating ─────────────────────────────────────────────────
  static Future<ApiResult> rateCustomer({
    required String jobId,
    required int stars,
    String? comment,
  }) =>
      ApiService.post('/tech/jobs/$jobId/rate', body: {
        'stars': stars,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });

  // ── Earnings ───────────────────────────────────────────────
  static Future<ApiResult> getEarnings() =>
      ApiService.get('/tech/earnings');

  static Future<ApiResult> requestPayout({
    required double amount,
    String? bankAccount,
    String? upiId,
    String? aadhaar,
  }) =>
      ApiService.post('/tech/payouts/request', body: {
        'amount': amount,
        if (bankAccount != null) 'bank_account': bankAccount,
        if (upiId != null) 'upi_id': upiId,
        if (aadhaar != null) 'aadhaar': aadhaar,
      });

  // ── Job Pool ──────────────────────────────────────────────
  static Future<ApiResult> getJobPool() =>
      ApiService.get('/tech/pool');

  static Future<ApiResult> claimPoolTask({
    required String taskType,
    required String taskId,
  }) =>
      ApiService.post('/tech/pool/claim', body: {
        'task_type': taskType,
        'task_id': taskId,
      });

  // ── Complaints / Support Tickets ──────────────────────────
  static Future<ApiResult> getComplaints({String? status}) =>
      ApiService.get('/tech/complaints', queryParams: {
        if (status != null) 'status': status,
      });

  static Future<ApiResult> updateComplaintStatus({
    required String complaintId,
    required String status,
    String? resolutionNote,
  }) =>
      ApiService.post('/tech/complaints', body: {
        'complaint_id': complaintId,
        'status': status,
        if (resolutionNote != null) 'resolution_note': resolutionNote,
      });

  /// Verify in-app customer OTP and mark technician as reached
  static Future<ApiResult> verifyComplaintOtp({
    required String complaintId,
    required String otp,
  }) =>
      ApiService.post('/tech/complaints/verify_otp', body: {
        'complaint_id': complaintId,
        'otp': otp,
      });

  // ── Customer Management ───────────────────────────────────
  static Future<ApiResult> getCustomers({String? search}) =>
      ApiService.get('/tech/customers', queryParams: {
        if (search != null && search.isNotEmpty) 'search': search,
      });

  static Future<ApiResult> getCustomerDetail(String customerId) =>
      ApiService.get('/tech/customers/$customerId');

  static Future<ApiResult> updateCustomerDetail(String customerId, Map<String, dynamic> data) =>
      ApiService.put('/tech/customers/$customerId', body: data);

  // ── Modem / Router Monitoring ─────────────────────────────
  static Future<ApiResult> getModemInfo(String customerId) =>
      ApiService.get('/tech/modem/$customerId');

  static Future<ApiResult> rebootModem(String customerId) =>
      ApiService.post('/tech/modem/$customerId');

  // ── Notifications ─────────────────────────────────────────
  static Future<ApiResult> getNotifications() =>
      ApiService.get('/tech/notifications');

  static Future<ApiResult> markNotificationsRead() =>
      ApiService.patch('/tech/notifications');

  // ── Activity Log ──────────────────────────────────────────
  static Future<ApiResult> getActivityLog() =>
      ApiService.get('/tech/activity_log');

  // ── GPS Location ──────────────────────────────────────────
  static Future<ApiResult> updateLocation({
    required double latitude,
    required double longitude,
  }) =>
      ApiService.post('/tech/location', body: {
        'latitude': latitude,
        'longitude': longitude,
      });
}
