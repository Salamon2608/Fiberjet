import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:fiberjet/services/api_service.dart';

/// Data service for all admin-related API calls.
class AdminDataService {
  // ── Dashboard ──────────────────────────────────────────────
  static Future<ApiResult> getDashboard() =>
      ApiService.get('/admin/dashboard');

  // ── Users ──────────────────────────────────────────────────
  static Future<ApiResult> getUsers({
    String? search,
    String? planType,
    String? status,
    String? kycStatus,
    String? role,
    bool? isVip,
    int page = 1,
    int limit = 20,
  }) =>
      ApiService.get('/admin/users', queryParams: {
        if (search != null) 'search': search,
        if (planType != null) 'plan_type': planType,
        if (status != null) 'status': status,
        if (kycStatus != null) 'kyc_status': kycStatus,
        if (role != null) 'role': role,
        if (isVip != null) 'is_vip': '$isVip',
        'page': '$page',
        'limit': '$limit',
      });

  static Future<ApiResult> createUser(Map<String, dynamic> userData) =>
      ApiService.post('/admin/users', body: userData);

  static Future<ApiResult> toggleUserBlock(String userId, {String? reason}) =>
      ApiService.put('/admin/users/$userId/block', body: {
        if (reason != null) 'reason': reason,
      });

  static Future<ApiResult> toggleVip(String userId) =>
      ApiService.post('/admin/users/$userId/vip');

  static Future<ApiResult> approveUser(String userId, String action, {String? reason}) =>
      ApiService.put('/admin/users/$userId/approve', body: {
        'action': action,
        if (reason != null) 'reason': reason,
      });

  static Future<ApiResult> getUserAuditLogs(String userId) =>
      ApiService.get('/admin/users/$userId/audit');

  static Future<ApiResult> getUser(String userId) =>
      ApiService.get('/admin/users/$userId');

  static Future<ApiResult> updateUser(String userId, Map<String, dynamic> data) =>
      ApiService.put('/admin/users/$userId', body: data);

  static Future<ApiResult> deleteUser(String userId) =>
      ApiService.delete('/admin/users/$userId');

  static Future<ApiResult> getUserBills(String userId) =>
      ApiService.get('/admin/users/$userId/bills');

  static Future<ApiResult> linkModem(String userId, Map<String, dynamic> modemData) =>
      ApiService.post('/admin/users/$userId/modem', body: modemData);

  static Future<ApiResult> getModem(String userId) =>
      ApiService.get('/admin/users/$userId/modem');


  // ── Sales Persons ──────────────────────────────────────────
  static Future<ApiResult> getSalesPersons() =>
      ApiService.get('/admin/sales_persons');

  static Future<ApiResult> approveSalesPerson(String id, String action) =>
      ApiService.post('/admin/sales_persons/$id/approve', body: {
        'action': action,
      });

  static Future<ApiResult> getSalesDocuments(String salesId) =>
      ApiService.get('/admin/sales_persons/$salesId/documents');

  static Future<ApiResult> getGlobalLeads({String? stage, String? salesPersonId, String? search}) =>
      ApiService.get('/admin/leads', queryParams: {
        if (stage != null) 'stage': stage,
        if (salesPersonId != null) 'sales_person_id': salesPersonId,
        if (search != null) 'search': search,
      });

  static Future<ApiResult> getLeadAnalytics() =>
      ApiService.get('/admin/leads/analytics');

  // ── Technicians ────────────────────────────────────────────
  static Future<ApiResult> getTechnicians() =>
      ApiService.get('/admin/technicians');

  static Future<ApiResult> assignJob({
    required String jobId,
    required String technicianId,
  }) =>
      ApiService.post('/admin/jobs/$jobId/assign', body: {
        'technician_id': technicianId,
      });

  static Future<ApiResult> getTechnicianActivities() =>
      ApiService.get('/admin/technicians/activities');

  // ── Ads ────────────────────────────────────────────────────
  static Future<ApiResult> getAds() =>
      ApiService.get('/admin/ads');

  static Future<ApiResult> createAd({
    required String title,
    String? imageUrl,
    Uint8List? imageBytes,
    String? imageFileName,
    List<String>? targetRoles,
    String? startDate,
    String? endDate,
  }) async {
    final fields = {
      'title': title,
      'target_roles': (targetRoles ?? []).join(','),
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (imageUrl != null) 'image_url': imageUrl,
    };

    if (imageBytes != null) {
      final file = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: imageFileName ?? 'upload.jpg',
      );
      return ApiService.postMultipart('/admin/ads', fields: fields, files: [file]);
    }

    return ApiService.post('/admin/ads', body: {
      ...fields,
      'target_roles': targetRoles ?? [],
    });
  }

  static Future<ApiResult> updateAd(String id, Map<String, dynamic> updates) =>
      ApiService.put('/admin/ads/$id', body: updates);

  static Future<ApiResult> deleteAd(String id) =>
      ApiService.delete('/admin/ads/$id');

  // ── Plans ──────────────────────────────────────────────────
  static Future<ApiResult> getPlans({
    String? category,
    String? isActive,
    String? search,
  }) =>
      ApiService.get('/admin/plans', queryParams: {
        if (category != null) 'category': category,
        if (isActive != null) 'is_active': isActive,
        if (search != null) 'search': search,
      });

  static Future<ApiResult> createPlan(Map<String, dynamic> planData) =>
      ApiService.post('/admin/plans', body: planData);

  static Future<ApiResult> updatePlan(String id, Map<String, dynamic> updates) =>
      ApiService.put('/admin/plans/$id', body: updates);

  static Future<ApiResult> deletePlan(String id) =>
      ApiService.delete('/admin/plans/$id');

  // ── Categories ─────────────────────────────────────────────
  static Future<ApiResult> getCategories({bool includeInactive = false}) =>
      ApiService.get('/admin/categories', queryParams: {
        if (includeInactive) 'include_inactive': 'true',
      });

  static Future<ApiResult> createCategory(Map<String, dynamic> data) =>
      ApiService.post('/admin/categories', body: data);

  static Future<ApiResult> updateCategory(String id, Map<String, dynamic> updates) =>
      ApiService.put('/admin/categories/$id', body: updates);

  static Future<ApiResult> deleteCategory(String id) =>
      ApiService.delete('/admin/categories/$id');

  // ── OTT Platforms ──────────────────────────────────────────
  static Future<ApiResult> getOttPlatforms({bool includeInactive = false}) =>
      ApiService.get('/admin/ott_platforms', queryParams: {
        if (includeInactive) 'include_inactive': 'true',
      });

  static Future<ApiResult> createOttPlatform(Map<String, dynamic> data) =>
      ApiService.post('/admin/ott_platforms', body: data);

  static Future<ApiResult> updateOttPlatform(String id, Map<String, dynamic> updates) =>
      ApiService.put('/admin/ott_platforms/$id', body: updates);

  static Future<ApiResult> deleteOttPlatform(String id) =>
      ApiService.delete('/admin/ott_platforms/$id');

  // ── Payouts ────────────────────────────────────────────────
  static Future<ApiResult> getPendingPayouts({String? role}) =>
      ApiService.get('/admin/payouts/approve', queryParams: {
        'status': 'pending',
        if (role != null) 'role': role,
      });

  static Future<ApiResult> approvePayout(String payoutId) =>
      ApiService.post('/admin/payouts/approve', body: {
        'payout_id': payoutId,
        'action': 'approve',
      });

  static Future<ApiResult> rejectPayout(String payoutId) =>
      ApiService.post('/admin/payouts/approve', body: {
        'payout_id': payoutId,
        'action': 'reject',
      });

  // ── Financials ─────────────────────────────────────────────
  static Future<ApiResult> getFinancials() =>
      ApiService.get('/admin/financials');

  // ── Complaints ─────────────────────────────────────────────
  static Future<ApiResult> getAllComplaints({String? status, int page = 1}) =>
      ApiService.get('/admin/complaints', queryParams: {
        if (status != null) 'status': status,
        'page': '$page',
      });

  // ── Audit Logs ─────────────────────────────────────────────
  static Future<ApiResult> getAuditLogs({
    String? userId,
    String? action,
    String? dateFrom,
    String? dateTo,
    int page = 1,
  }) =>
      ApiService.get('/admin/audit_logs', queryParams: {
        if (userId != null) 'user_id': userId,
        if (action != null) 'action': action,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
        'page': '$page',
      });

  // ── Maps / Live Tracking ───────────────────────────────────
  static Future<ApiResult> getLiveMapData() =>
      ApiService.get('/admin/map/live');

  static Future<ApiResult> bulkApprovePayouts(List<String> payoutIds) =>
      ApiService.post('/admin/payouts/bulk_approve', body: {
        'payout_ids': payoutIds,
      });
}
