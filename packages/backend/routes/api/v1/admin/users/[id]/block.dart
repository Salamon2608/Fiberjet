import 'dart:io';

import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

/// PUT /api/v1/admin/users/:id/block → Toggle user active/blocked status
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.put) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final db = context.read<PostgresService>();

  // Get current status
  final userResult = await db.query(
    'SELECT id, name, status FROM users WHERE id = @id LIMIT 1',
    substitutionValues: {'id': id},
  );

  if (userResult.isEmpty) {
    return ApiResponse.error(
      message: 'User not found',
      statusCode: HttpStatus.notFound,
    );
  }

  final body = await request.json() as Map<String, dynamic>;
  final reason = body['reason'] as String? ?? 'No reason provided';

  final currentStatus = userResult.first.toColumnMap()['status'] as String;
  final newStatus = currentStatus == 'blocked' ? 'active' : 'blocked';

  await db.withTransaction((tx) async {
    await tx.execute(
      Sql.named('UPDATE users SET status = @status WHERE id = @id'),
      parameters: {'id': id, 'status': newStatus},
    );

    await tx.execute(
      Sql.named('''
      INSERT INTO audit_logs (user_id, action, target_table, target_id, new_values)
      VALUES (@adminId, @action, 'users', @userId, @newValues)
      '''),
      parameters: {
        'adminId': id, // In a real app, this would be authenticated admin's ID
        'action': newStatus == 'blocked' ? 'USER_BLOCKED' : 'USER_UNBLOCKED',
        'userId': id,
        'newValues': {'status': newStatus, 'reason': reason},
      },
    );
  });

  return ApiResponse.success(
    message: 'User status changed to $newStatus',
    data: {'user_id': id, 'new_status': newStatus},
  );
}
