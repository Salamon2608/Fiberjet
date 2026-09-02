import 'package:fiberjet/services/api_service.dart';
import 'package:http/http.dart' as http;

/// Data service for all sales-related API calls.
class SalesDataService {
  // ── Dashboard ─────────────────────────────────────────────
  static Future<ApiResult> getDashboard() =>
      ApiService.get('/sales/dashboard');

  // ── Leads ──────────────────────────────────────────────────
  static Future<ApiResult> getLeads({String? stage, String? search}) =>
      ApiService.get('/sales/leads', queryParams: {
        if (stage != null) 'stage': stage,
        if (search != null) 'search': search,
      });

  static Future<ApiResult> getLead(String id) =>
      ApiService.get('/sales/leads/$id');

  static Future<ApiResult> createLead({
    required String customerName,
    required String phone,
    String? email,
    String? address,
  }) =>
      ApiService.post('/sales/leads', body: {
        'customer_name': customerName,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        'address': address ?? '',
      });

  static Future<ApiResult> updateLead(String id, Map<String, dynamic> updates) =>
      ApiService.patch('/sales/leads/$id', body: updates);

  static Future<ApiResult> deleteLead(String id) =>
      ApiService.delete('/sales/leads/$id');

  // ── Lead Documents (KYC Upload) ────────────────────────────
  static Future<ApiResult> getLeadDocuments(String leadId) =>
      ApiService.get('/sales/leads/$leadId/documents');

  static Future<ApiResult> uploadLeadDocuments(
    String leadId, {
    List<int>? idProofBytes,
    String? idProofFilename,
    List<int>? addressProofBytes,
    String? addressProofFilename,
  }) async {
    final files = <http.MultipartFile>[];

    if (idProofBytes != null && idProofBytes.isNotEmpty) {
      files.add(http.MultipartFile.fromBytes(
        'id_proof',
        idProofBytes,
        filename: idProofFilename ?? 'id_proof.jpg',
      ));
    }

    if (addressProofBytes != null && addressProofBytes.isNotEmpty) {
      files.add(http.MultipartFile.fromBytes(
        'address_proof',
        addressProofBytes,
        filename: addressProofFilename ?? 'address_proof.jpg',
      ));
    }

    return ApiService.postMultipart(
      '/sales/leads/$leadId/documents',
      files: files,
    );
  }

  // ── Lead Comments ──────────────────────────────────────────
  static Future<ApiResult> getLeadComments(String leadId) =>
      ApiService.get('/sales/leads/$leadId/comments');

  static Future<ApiResult> addLeadComment(String leadId, String comment, {String type = 'general'}) =>
      ApiService.post('/sales/leads/$leadId/comments', body: {
        'comment': comment,
        'type': type,
      });

  // ── Technicians ────────────────────────────────────────────
  static Future<ApiResult> getTechnicians() =>
      ApiService.get('/sales/technicians');

  // ── Commissions ────────────────────────────────────────────
  static Future<ApiResult> getCommissions() =>
      ApiService.get('/sales/commission');

  // ── Payouts ────────────────────────────────────────────────
  static Future<ApiResult> requestPayout({
    required double amount,
    String? bankAccount,
    String? upiId,
    String? aadhaar,
  }) =>
      ApiService.post('/sales/payouts/request', body: {
        'amount': amount,
        if (bankAccount != null) 'bank_account': bankAccount,
        if (upiId != null) 'upi_id': upiId,
        if (aadhaar != null) 'aadhaar': aadhaar,
      });

  // ── Customer Bills ─────────────────────────────────────────
  static Future<ApiResult> getCustomerBills(String customerId) =>
      ApiService.get('/sales/customer/$customerId/bills');

  // ── Complaints / Support Tickets ──────────────────────────
  static Future<ApiResult> getComplaints({String? status}) =>
      ApiService.get('/sales/complaints', queryParams: {
        if (status != null) 'status': status,
      });

  static Future<ApiResult> updateComplaintStatus({
    required String complaintId,
    required String status,
    String? resolutionNote,
  }) =>
      ApiService.post('/sales/complaints', body: {
        'complaint_id': complaintId,
        'status': status,
        if (resolutionNote != null) 'resolution_note': resolutionNote,
      });
}
