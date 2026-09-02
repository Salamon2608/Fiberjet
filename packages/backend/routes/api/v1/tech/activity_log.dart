import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/tech/activity_log → Fetch technician's activity history
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  final result = await db.query(
    '''
    SELECT id, action, target_table, target_id, old_values, new_values, ip_address, created_at
    FROM audit_logs
    WHERE user_id = @techId
    ORDER BY created_at DESC
    LIMIT 50
    ''',
    substitutionValues: {'techId': user.id},
  );

  final logs = result.map((r) => r.toColumnMap()).toList();

  return ApiResponse.success(data: {'activity_logs': logs, 'total': logs.length});
}
