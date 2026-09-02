import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// PUT /api/v1/admin/users/:id/approve → Approve or reject a user (KYC / Onboarding)
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.put) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresService>();
  
  final body = await request.json() as Map<String, dynamic>;
  final action = body['action'] as String?; // 'approve', 'reject', or 'resubmit'
  final reason = body['reason'] as String?;

  if (action != 'approve' && action != 'reject' && action != 'resubmit') {
    return ApiResponse.error(message: 'Invalid action', statusCode: HttpStatus.badRequest);
  }

  final userResult = await db.query(
    'SELECT id, name FROM users WHERE id = @id LIMIT 1',
    substitutionValues: {'id': id},
  );

  if (userResult.isEmpty) {
    return ApiResponse.error(message: 'User not found', statusCode: HttpStatus.notFound);
  }

  String newKycStatus;
  String newStatus;

  if (action == 'approve') {
    newKycStatus = 'verified';
    newStatus = 'active';
  } else if (action == 'reject') {
    newKycStatus = 'rejected';
    newStatus = 'blocked';
  } else {
    newKycStatus = 'resubmit';
    newStatus = 'pending';
  }

  await db.query(
    '''
    UPDATE users 
    SET status = @status, kyc_status = @kycStatus, kyc_rejection_reason = @reason
    WHERE id = @id
    ''',
    substitutionValues: {
      'id': id, 
      'status': newStatus,
      'kycStatus': newKycStatus,
      'reason': reason,
    },
  );

  return ApiResponse.success(
    message: 'User ${action}d successfully',
    data: {'user_id': id, 'status': newStatus},
  );
}
