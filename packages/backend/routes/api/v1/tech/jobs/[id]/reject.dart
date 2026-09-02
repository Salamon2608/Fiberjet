import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/services/websocket_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/tech/jobs/:id/reject → Reject a job with reason + comment
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
        message: 'Method not allowed',
        statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final reason = body['reason'] as String?;
  final comment = body['comment'] as String?;

  if (reason == null || reason.isEmpty) {
    return ApiResponse.error(message: 'reason is required');
  }
  if (comment == null || comment.isEmpty) {
    return ApiResponse.error(message: 'comment is required');
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // Update job status to rejected with reason
  final result = await db.query(
    '''
    UPDATE jobs
    SET status = 'rejected',
        rejection_reason = @reason,
        checklist = COALESCE(checklist, '{}'::jsonb) || jsonb_build_object(
          'rejection_reason', @reason,
          'rejection_comment', @comment,
          'rejected_at', NOW()::text,
          'rejected_by', @techName
        )
    WHERE id = @id AND technician_id = @techId
    RETURNING id, status, customer_id
    ''',
    substitutionValues: {
      'id': id,
      'techId': user.id,
      'reason': reason,
      'comment': comment,
      'techName': user.name,
    },
  );

  if (result.isEmpty) {
    return ApiResponse.error(
        message: 'Job not found', statusCode: HttpStatus.notFound);
  }

  final updatedJob = result.first.toColumnMap();

  // Send push notification to all admins
  try {
    final admins = await db.query(
      '''
      SELECT u.id FROM users u
      JOIN roles r ON u.role_id = r.id
      WHERE r.name = 'admin'
      ''',
    );

    final wsService = context.read<WebsocketService>();
    for (final admin in admins) {
      final adminId = admin.toColumnMap()['id'].toString();
      wsService.dispatchEvent(
        adminId,
        'job_rejected',
        {
          'message': '${user.name} rejected Job #${id.substring(0, 6)}',
          'reason': reason,
          'comment': comment,
          'job_id': id,
        },
      );
    }
  } catch (_) {
    // Non-critical — log and continue
  }

  return ApiResponse.success(
    message: 'Job rejected successfully',
    data: updatedJob,
  );
}
