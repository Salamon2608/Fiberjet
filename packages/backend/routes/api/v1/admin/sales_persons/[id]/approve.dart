import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/admin/sales_persons/:id/approve → Approve or reject a sales rep
/// Body: { "action": "approve" | "reject" }
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final action = body['action'] as String?;

  if (action == null || !['approve', 'reject'].contains(action)) {
    return ApiResponse.error(message: 'action must be "approve" or "reject"');
  }

  final db = context.read<PostgresService>();

  final newStatus = action == 'approve' ? 'active' : 'rejected';

  final result = await db.query(
    'UPDATE users SET status = @status WHERE id = @id RETURNING id, name, status',
    substitutionValues: {'id': id, 'status': newStatus},
  );

  if (result.isEmpty) {
    return ApiResponse.error(message: 'User not found', statusCode: HttpStatus.notFound);
  }

  return ApiResponse.success(
    message: 'Sales person ${action}d successfully',
    data: result.first.toColumnMap(),
  );
}
