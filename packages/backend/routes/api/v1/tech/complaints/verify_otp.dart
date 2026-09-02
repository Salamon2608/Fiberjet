import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/tech/complaints/verify_otp
/// Body: { "complaint_id": "uuid", "otp": "4-digit-code" }
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final body = await request.json() as Map<String, dynamic>;
  final complaintId = body['complaint_id'] as String?;
  final otp = body['otp'] as String?;

  if (complaintId == null || complaintId.isEmpty) {
    return ApiResponse.error(message: 'complaint_id is required');
  }

  if (otp == null || otp.trim().isEmpty) {
    return ApiResponse.error(message: 'OTP is required');
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  final complaintResult = await db.query(
    'SELECT * FROM complaints WHERE id = @id LIMIT 1',
    substitutionValues: {'id': complaintId},
  );

  if (complaintResult.isEmpty) {
    return ApiResponse.error(
      message: 'Ticket not found',
      statusCode: HttpStatus.notFound,
    );
  }

  final complaint = complaintResult.first.toColumnMap();
  final storedOtp = complaint['visit_otp']?.toString().trim();

  // Validate OTP
  if (storedOtp == null || storedOtp != otp.trim()) {
    return ApiResponse.error(
      message: 'Invalid arrival OTP. Please ask the customer to check their FiberJet app screen.',
      statusCode: HttpStatus.badRequest,
    );
  }

  // Update complaint: mark OTP verified, arrived_at, and transition to in_progress
  final updateResult = await db.query(
    '''
    UPDATE complaints
    SET is_otp_verified = TRUE,
        arrived_at = NOW(),
        status = 'in_progress',
        assigned_to = COALESCE(assigned_to, @techId),
        updated_at = NOW()
    WHERE id = @id
    RETURNING *
    ''',
    substitutionValues: {
      'id': complaintId,
      'techId': user.id,
    },
  );

  final updatedRow = updateResult.first.toColumnMap();

  // Record audit log
  try {
    await db.query(
      '''
      INSERT INTO audit_logs (user_id, action, target_table, target_id, new_values)
      VALUES (@techId, 'verify_arrival_otp', 'complaints', @complaintId,
        jsonb_build_object('technician_name', @techName, 'status', 'in_progress', 'is_otp_verified', true))
      ''',
      substitutionValues: {
        'techId': user.id,
        'complaintId': complaintId,
        'techName': user.name,
      },
    );
  } catch (_) {}

  return ApiResponse.success(
    message: 'Arrival verified successfully! Marked as reached.',
    data: updatedRow,
  );
}
