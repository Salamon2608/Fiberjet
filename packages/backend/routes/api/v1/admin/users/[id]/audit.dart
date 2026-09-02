import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/users/[id]/audit
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresService>();

  try {
    final result = await db.query(
      '''
      SELECT id, action, target_table, target_id, old_values, new_values, ip_address, user_agent, created_at
      FROM audit_logs
      WHERE user_id = @userId
      ORDER BY created_at DESC
      LIMIT 50
      ''',
      substitutionValues: {'userId': id},
    );

    final logs = result.map((r) {
      final map = r.toColumnMap();
      return <String, dynamic>{
        for (final entry in map.entries)
          entry.key: entry.value is DateTime
              ? (entry.value as DateTime).toIso8601String()
              : entry.value,
      };
    }).toList();

    return ApiResponse.success(data: logs);
  } catch (e) {
    return ApiResponse.error(message: 'Failed to fetch audit logs: $e');
  }
}
